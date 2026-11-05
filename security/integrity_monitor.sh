#!/bin/bash
set -euo pipefail

#
# ファイル整合性監視ツール
# 作成日: 2026-11-05
# バージョン: 1.0
#
# 脆弱性対応: ファイル改ざん検知・整合性監視
# CVE該当: CWE-345 (Insufficient Verification of Data Authenticity), CWE-494 (Download Without Integrity Check)
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare command_name="check"
declare baseline_file="/var/lib/integrity_monitor/baseline.sha256"
declare target_dirs=""
declare -i alert_on_change=0

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション]

ファイル整合性を監視・検証します。

コマンド:
  baseline <パス>      ベースライン(基準ハッシュ)作成
  check [パス]         整合性チェック (デフォルト)
  diff                 変更ファイルの差分表示
  watch <パス>         リアルタイム監視
  report               整合性レポート生成

オプション:
  -h, --help           このヘルプを表示
  -v, --version        バージョン情報を表示
  -b, --baseline <ファイル> ベースラインファイル
  -a, --alert          変更検出時にアラート

脆弱性概要:
  CWE-345: データ認証の不十分な検証
  CWE-494: 整合性チェックなしのダウンロード
  対策: SHA-256ハッシュによるファイル整合性検証
EOF
}

get_target_dirs() {
    if [[ -n "$target_dirs" ]]; then
        echo "$target_dirs"
    else
        echo "/etc /usr/bin /usr/sbin /bin /sbin"
    fi
}

cmd_baseline() {
    local path="${1:-}"
    local dirs
    if [[ -n "$path" ]]; then
        dirs="$path"
    else
        dirs=$(get_target_dirs)
    fi

    log_info "ベースライン作成: $dirs"
    echo ""

    local baseline_dir
    baseline_dir=$(dirname "$baseline_file")
    mkdir -p "$baseline_dir" 2>/dev/null || {
        baseline_file="$(pwd)/integrity_baseline.sha256"
        log_warning "デフォルトパスに書き込めないため使用: $baseline_file"
    }

    local count=0
    {
        echo "# 整合性ベースライン"
        echo "# 作成日時: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "# ホスト: $(hostname)"
        echo "# 対象: $dirs"
        echo "#"
        for dir in $dirs; do
            [[ ! -d "$dir" ]] && continue
            find "$dir" -type f -not -name "*.log" 2>/dev/null | sort | \
            while IFS= read -r file; do
                local hash
                hash=$(sha256sum "$file" 2>/dev/null || true)
                if [[ -n "$hash" ]]; then
                    echo "$hash"
                    (( count++ )) || true
                fi
            done
        done
    } > "$baseline_file"

    local actual_count
    actual_count=$(grep -c "^[0-9a-f]" "$baseline_file" 2>/dev/null || echo 0)
    log_success "ベースライン作成完了: $actual_count ファイル -> $baseline_file"
    echo ""
}

cmd_check() {
    local path="${1:-}"

    if [[ ! -f "$baseline_file" ]]; then
        log_warning "ベースラインファイルが見つかりません: $baseline_file"
        log_info "まず 'baseline' コマンドでベースラインを作成してください"
        return
    fi

    log_info "整合性チェック (ベースライン: $baseline_file)"
    echo ""

    local modified=0 missing=0 added=0

    while IFS= read -r line; do
        [[ "$line" =~ ^# ]] && continue
        [[ -z "$line" ]] && continue

        local hash file
        hash=$(echo "$line" | awk '{print $1}')
        file=$(echo "$line" | awk '{print $2}')

        if [[ ! -f "$file" ]]; then
            printf "  ${C_RED}[削除]${C_RESET} %s\n" "$file"
            (( missing++ ))
        else
            local current_hash
            current_hash=$(sha256sum "$file" 2>/dev/null | awk '{print $1}' || echo "ERROR")
            if [[ "$current_hash" != "$hash" ]]; then
                printf "  ${C_RED}[改ざん]${C_RESET} %s\n" "$file"
                local mtime
                mtime=$(stat -c "%y" "$file" 2>/dev/null | cut -d. -f1 || echo "unknown")
                printf "    最終変更: %s\n" "$mtime"
                (( modified++ ))
            fi
        fi
    done < "$baseline_file"

    echo ""
    if [[ "$modified" -gt 0 || "$missing" -gt 0 ]]; then
        log_error "整合性違反: 改ざん $modified 件, 削除 $missing 件"
        (( alert_on_change )) && {
            logger -t integrity_monitor "ALERT: $modified modified, $missing missing files detected"
        }
    else
        log_success "整合性チェック OK: 変更なし"
    fi
    echo ""
}

cmd_diff() {
    if [[ ! -f "$baseline_file" ]]; then
        error_exit "ベースラインファイルが見つかりません: $baseline_file"
    fi

    log_info "変更ファイルの差分表示"
    echo ""

    while IFS= read -r line; do
        [[ "$line" =~ ^# ]] && continue
        [[ -z "$line" ]] && continue

        local hash file
        hash=$(echo "$line" | awk '{print $1}')
        file=$(echo "$line" | awk '{print $2}')

        [[ ! -f "$file" ]] && continue

        local current_hash
        current_hash=$(sha256sum "$file" 2>/dev/null | awk '{print $1}' || echo "")
        if [[ "$current_hash" != "$hash" ]]; then
            printf "${C_BOLD}%s${C_RESET}\n" "$file"
            printf "  ベースライン: %s\n" "${hash:0:16}..."
            printf "  現在値:       %s\n" "${current_hash:0:16}..."
            local mtime size
            mtime=$(stat -c "%y" "$file" 2>/dev/null | cut -d. -f1 || echo "")
            size=$(stat -c "%s" "$file" 2>/dev/null || echo "")
            printf "  最終変更: %s, サイズ: %s bytes\n" "$mtime" "$size"
            echo ""
        fi
    done < "$baseline_file"
}

cmd_watch() {
    local path="${1:-.}"
    log_info "ファイル整合性リアルタイム監視: $path (Ctrl+C で終了)"
    echo ""

    if command -v inotifywait &>/dev/null; then
        inotifywait -m -r "$path" -e modify -e create -e delete -e moved_to \
            --format '%T %e %w%f' --timefmt '%H:%M:%S' 2>/dev/null | \
        while IFS= read -r line; do
            local ts event file
            ts=$(echo "$line" | awk '{print $1}')
            event=$(echo "$line" | awk '{print $2}')
            file=$(echo "$line" | awk '{print $3}')
            case "$event" in
                MODIFY*)
                    printf "${C_YELLOW}[%s MODIFY]${C_RESET} %s\n" "$ts" "$file"
                    ;;
                CREATE*|MOVED_TO*)
                    printf "${C_GREEN}[%s CREATE]${C_RESET} %s\n" "$ts" "$file"
                    ;;
                DELETE*)
                    printf "${C_RED}[%s DELETE]${C_RESET} %s\n" "$ts" "$file"
                    ;;
                *)
                    printf "${C_DIM}[%s %s]${C_RESET} %s\n" "$ts" "$event" "$file"
                    ;;
            esac
        done
    else
        log_warning "inotifywait が見つかりません。ポーリングモードで監視"
        local snapshot_file
        snapshot_file=$(mktemp)
        find "$path" -type f -exec sha256sum {} \; 2>/dev/null | sort > "$snapshot_file"

        while true; do
            sleep 10
            local new_snapshot
            new_snapshot=$(mktemp)
            find "$path" -type f -exec sha256sum {} \; 2>/dev/null | sort > "$new_snapshot"
            local changes
            changes=$(diff "$snapshot_file" "$new_snapshot" 2>/dev/null | grep "^[<>]" || true)
            if [[ -n "$changes" ]]; then
                printf "${C_RED}[%s 変更検出]${C_RESET}\n%s\n" "$(date +%H:%M:%S)" "$changes"
                cp "$new_snapshot" "$snapshot_file"
            fi
            rm -f "$new_snapshot"
        done
        rm -f "$snapshot_file"
    fi
}

parse_arguments() {
    [[ $# -eq 0 ]] && return 0
    case "$1" in
        baseline|check|diff|watch|report)
            command_name="$1"; shift ;;
    esac
    local positional=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -b|--baseline) [[ $# -lt 2 ]] && error_exit "--baseline には値が必要です"; baseline_file="$2"; shift 2 ;;
            -a|--alert)   alert_on_change=1; shift ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  positional+=("$1"); shift ;;
        esac
    done
    POSITIONAL=("${positional[@]+"${positional[@]}"}")
}

declare -a POSITIONAL=()

main() {
    parse_arguments "$@"
    case "$command_name" in
        baseline) cmd_baseline "${POSITIONAL[0]:-}" ;;
        check)    cmd_check    "${POSITIONAL[0]:-}" ;;
        diff)     cmd_diff ;;
        watch)    cmd_watch    "${POSITIONAL[0]:-.}" ;;
        report)
            cmd_check
            cmd_diff
            ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
