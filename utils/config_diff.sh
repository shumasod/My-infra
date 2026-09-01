#!/bin/bash
set -euo pipefail

#
# 設定ファイル差分ツール
# 作成日: 2026-09-01
# バージョン: 1.0
#
# 設定ファイルの差分確認・バックアップ・テンプレート管理を行います
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare command_name="diff"
declare backup_dir="${HOME}/.config_backup"
declare context_lines=3
declare output_format="color"
declare ignore_comments=0
declare ignore_blanks=1

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション] <ファイル...>

設定ファイルの差分・管理ツールです。

コマンド:
  diff <ファイル1> <ファイル2>  2ファイルを比較
  backup <ファイル...>          ファイルをバックアップ
  restore <ファイル>            バックアップから復元
  history <ファイル>            変更履歴を表示
  watch <ファイル...>           ファイル変更を監視
  audit <ディレクトリ>          設定ディレクトリを監査
  template <ファイル>           テンプレートを生成

オプション:
  -h, --help              このヘルプを表示
  -v, --version           バージョン情報を表示
  -b, --backup-dir <パス> バックアップ先 [デフォルト: ~/.config_backup]
  -C, --context <数>      コンテキスト行数 [デフォルト: 3]
  -f, --format <形式>     出力形式 (color|unified|html) [デフォルト: color]
  --ignore-comments       コメント行を無視
  --keep-blanks           空行を保持 (デフォルトは無視)

例:
  $PROG_NAME diff /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
  $PROG_NAME backup /etc/nginx/nginx.conf /etc/ssh/sshd_config
  $PROG_NAME history /etc/nginx/nginx.conf
  $PROG_NAME watch /etc/nginx/ /etc/ssh/
  $PROG_NAME audit /etc
EOF
}

get_backup_path() {
    local file="$1"
    local ts
    ts=$(date +"%Y%m%d_%H%M%S")
    local safe_name
    safe_name="${file//\//_}"
    echo "${backup_dir}/${safe_name}_${ts}"
}

strip_comments() {
    local file="$1"
    local ext="${file##*.}"
    case "$ext" in
        conf|cfg|ini|yaml|yml)
            grep -v "^\s*#\|^\s*;" "$file" 2>/dev/null || cat "$file"
            ;;
        *)
            cat "$file"
            ;;
    esac
}

cmd_diff() {
    local f1="${1:-}" f2="${2:-}"
    [[ -z "$f1" || -z "$f2" ]] && error_exit "2つのファイルを指定してください"
    [[ ! -f "$f1" ]] && error_exit "ファイルが見つかりません: $f1"
    [[ ! -f "$f2" ]] && error_exit "ファイルが見つかりません: $f2"

    log_info "差分確認: $f1 vs $f2"
    echo ""

    local tmp1 tmp2
    tmp1=$(mktemp)
    tmp2=$(mktemp)
    trap "rm -f $tmp1 $tmp2" EXIT

    if (( ignore_comments )); then
        strip_comments "$f1" > "$tmp1"
        strip_comments "$f2" > "$tmp2"
    else
        cp "$f1" "$tmp1"
        cp "$f2" "$tmp2"
    fi

    local diff_args=("-u" "--context=$context_lines")
    (( ignore_blanks )) && diff_args+=("-B")

    local diff_result
    if ! diff_result=$(diff "${diff_args[@]}" "$tmp1" "$tmp2" 2>/dev/null); then
        if [[ "$output_format" == "color" ]]; then
            echo "$diff_result" | while IFS= read -r line; do
                case "${line:0:1}" in
                    "+") printf "${C_GREEN}%s${C_RESET}\n" "$line" ;;
                    "-") printf "${C_RED}%s${C_RESET}\n" "$line" ;;
                    "@") printf "${C_CYAN}%s${C_RESET}\n" "$line" ;;
                    *) printf "${C_DIM}%s${C_RESET}\n" "$line" ;;
                esac
            done
        else
            echo "$diff_result"
        fi

        local added removed
        added=$(echo "$diff_result" | grep -c "^+" || true)
        removed=$(echo "$diff_result" | grep -c "^-" || true)
        echo ""
        printf "  追加行: ${C_GREEN}+%d${C_RESET}  削除行: ${C_RED}-%d${C_RESET}\n" \
            "$added" "$removed"
    else
        log_success "差分なし: ファイルは同一です"
    fi
    echo ""
}

cmd_backup() {
    local files=("$@")
    [[ ${#files[@]} -eq 0 ]] && error_exit "バックアップするファイルを指定してください"

    mkdir -p "$backup_dir"
    log_info "バックアップ先: $backup_dir"
    echo ""

    local success=0 failed=0
    for f in "${files[@]}"; do
        if [[ ! -f "$f" ]]; then
            log_error "ファイルが見つかりません: $f"
            (( failed++ ))
            continue
        fi

        local dest
        dest=$(get_backup_path "$f")
        cp "$f" "$dest"
        local size
        size=$(stat -c%s "$dest" 2>/dev/null || echo 0)
        printf "  ${C_GREEN}%s${C_RESET} -> %s (%d bytes)\n" "$f" "$(basename "$dest")" "$size"
        (( success++ ))
    done

    echo ""
    printf "  成功: ${C_GREEN}%d${C_RESET}  失敗: ${C_RED}%d${C_RESET}\n" "$success" "$failed"
    echo ""
}

cmd_restore() {
    local target="${1:-}"
    [[ -z "$target" ]] && error_exit "復元するファイルを指定してください"

    local safe_name="${target//\//_}"
    local -a backups=()
    while IFS= read -r f; do
        backups+=("$f")
    done < <(find "$backup_dir" -maxdepth 1 -name "${safe_name}_*" | sort -r)

    if [[ ${#backups[@]} -eq 0 ]]; then
        log_error "バックアップが見つかりません: $target"
        return 1
    fi

    log_info "利用可能なバックアップ:"
    echo ""
    local idx=0
    for b in "${backups[@]}"; do
        local mtime
        mtime=$(stat -c%Y "$b" 2>/dev/null || echo 0)
        local date_str
        date_str=$(date -d "@$mtime" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "N/A")
        printf "  ${C_CYAN}[%d]${C_RESET} %s  (%s)\n" "$idx" "$(basename "$b")" "$date_str"
        (( idx++ ))
    done

    echo ""
    local choice
    read -rp "  復元するバックアップ番号を入力 (0-$(( ${#backups[@]} - 1 ))): " choice
    if [[ ! "$choice" =~ ^[0-9]+$ ]] || (( choice >= ${#backups[@]} )); then
        log_warning "キャンセルしました"
        return
    fi

    local selected="${backups[$choice]}"
    log_info "差分確認:"
    diff -u "$target" "$selected" 2>/dev/null | head -30 || true
    echo ""

    if ! confirm "このバックアップで復元しますか？" "n"; then
        log_warning "キャンセルしました"
        return
    fi

    cp "$selected" "$target"
    log_success "復元完了: $target"
}

cmd_history() {
    local target="${1:-}"
    [[ -z "$target" ]] && error_exit "ファイルを指定してください"

    local safe_name="${target//\//_}"
    local -a backups=()
    while IFS= read -r f; do
        backups+=("$f")
    done < <(find "$backup_dir" -maxdepth 1 -name "${safe_name}_*" | sort -r)

    if [[ ${#backups[@]} -eq 0 ]]; then
        log_warning "バックアップ履歴がありません: $target"
        return
    fi

    log_info "変更履歴: $target (${#backups[@]} バックアップ)"
    echo ""

    local prev="${backups[-1]}"
    for (( i = ${#backups[@]} - 2; i >= 0; i-- )); do
        local curr="${backups[$i]}"
        local mtime
        mtime=$(stat -c%Y "$curr" 2>/dev/null || echo 0)
        local date_str
        date_str=$(date -d "@$mtime" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "N/A")
        printf "${C_BOLD}${C_CYAN}=== %s ===${C_RESET}\n" "$date_str"

        local diff_out
        if diff_out=$(diff -u "$prev" "$curr" 2>/dev/null); then
            printf "${C_DIM}(変更なし)${C_RESET}\n"
        else
            echo "$diff_out" | grep "^[+-]" | grep -v "^[+-][+-][+-]" | head -20 | \
            while IFS= read -r line; do
                case "${line:0:1}" in
                    "+") printf "${C_GREEN}%s${C_RESET}\n" "$line" ;;
                    "-") printf "${C_RED}%s${C_RESET}\n"   "$line" ;;
                esac
            done
        fi
        echo ""
        prev="$curr"
    done
}

cmd_watch() {
    local targets=("$@")
    [[ ${#targets[@]} -eq 0 ]] && error_exit "監視するファイルまたはディレクトリを指定してください"

    if ! command -v inotifywait &>/dev/null; then
        log_warning "inotifywait が見つかりません。ポーリングモードで監視します"
        _watch_polling "${targets[@]}"
        return
    fi

    log_info "ファイル変更監視: ${targets[*]}"
    log_info "変更があった場合、自動バックアップを作成します (Ctrl+C で終了)"
    echo ""

    mkdir -p "$backup_dir"
    inotifywait -m -e modify,create,delete,move \
        --format "%T %e %w%f" --timefmt "%Y-%m-%d %H:%M:%S" \
        "${targets[@]}" 2>/dev/null | \
    while IFS=' ' read -r date time event file; do
        printf "${C_YELLOW}[%s %s] %s: %s${C_RESET}\n" "$date" "$time" "$event" "$file"
        if [[ "$event" == "MODIFY" && -f "$file" ]]; then
            local dest
            dest=$(get_backup_path "$file")
            cp "$file" "$dest"
            printf "  ${C_GREEN}バックアップ作成: %s${C_RESET}\n" "$(basename "$dest")"
        fi
    done
}

_watch_polling() {
    local targets=("$@")
    declare -A last_hash=()
    mkdir -p "$backup_dir"

    for f in "${targets[@]}"; do
        [[ -f "$f" ]] && last_hash["$f"]=$(md5sum "$f" | awk '{print $1}')
    done

    while true; do
        for f in "${targets[@]}"; do
            [[ ! -f "$f" ]] && continue
            local curr
            curr=$(md5sum "$f" | awk '{print $1}')
            if [[ "${last_hash[$f]:-}" != "$curr" ]]; then
                local ts
                ts=$(get_timestamp)
                printf "${C_YELLOW}[%s] 変更検出: %s${C_RESET}\n" "$(date '+%H:%M:%S')" "$f"
                local dest
                dest=$(get_backup_path "$f")
                cp "$f" "$dest"
                printf "  ${C_GREEN}バックアップ: %s${C_RESET}\n" "$(basename "$dest")"
                last_hash["$f"]="$curr"
            fi
        done
        sleep 5
    done
}

cmd_audit() {
    local dir="${1:-.}"
    log_info "設定ディレクトリ監査: $dir"
    echo ""

    printf "${C_BOLD}【パーミッション確認】${C_RESET}\n\n"
    find "$dir" -maxdepth 2 -type f \
        \( -name "*.conf" -o -name "*.cfg" -o -name "*.ini" -o -name "*.yaml" -o -name "*.yml" \) \
        2>/dev/null | head -30 | while IFS= read -r f; do
        local perm owner
        perm=$(stat -c "%a" "$f" 2>/dev/null || echo "?")
        owner=$(stat -c "%U:%G" "$f" 2>/dev/null || echo "?")
        local color="$C_GREEN"
        local warn=""
        (( perm > 644 )) && { color="$C_YELLOW"; warn=" [書き込み可]"; }
        (( perm > 700 && perm != 755 )) && { color="$C_RED"; warn=" [要確認]"; }
        printf "  ${color}%3s${C_RESET}  %-15s %s%s\n" "$perm" "$owner" "$f" "$warn"
    done

    echo ""
    printf "${C_BOLD}【機密情報パターン検索】${C_RESET}\n\n"
    local patterns=("password\s*=" "secret\s*=" "api.key\s*=" "token\s*=" "passwd\s*=")
    for pat in "${patterns[@]}"; do
        local matches
        matches=$(grep -rl "$pat" "$dir" --include="*.conf" --include="*.cfg" \
            --include="*.ini" --include="*.env" 2>/dev/null | head -5 || true)
        if [[ -n "$matches" ]]; then
            printf "  ${C_RED}[要確認] パターン: %s${C_RESET}\n" "$pat"
            while IFS= read -r f; do
                printf "    %s\n" "$f"
            done <<< "$matches"
        fi
    done
    echo ""
}

cmd_template() {
    local f="${1:-}"
    [[ -z "$f" || ! -f "$f" ]] && error_exit "有効なファイルを指定してください"

    log_info "テンプレート生成: $f"
    echo ""

    sed 's/=.*/=<value>/g; s/: .*/: <value>/g' "$f" 2>/dev/null | \
        grep -v "^\s*#" | head -50
    echo ""
    log_success "テンプレート出力完了"
}

parse_arguments() {
    [[ $# -eq 0 ]] && { show_usage; exit 0; }
    case "$1" in
        diff|backup|restore|history|watch|audit|template)
            command_name="$1"; shift ;;
    esac

    local positional=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)     show_usage; exit 0 ;;
            -v|--version)  echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -b|--backup-dir) [[ $# -lt 2 ]] && error_exit "--backup-dir には値が必要です"; backup_dir="$2"; shift 2 ;;
            -C|--context)  [[ $# -lt 2 ]] && error_exit "--context には値が必要です"; context_lines="$2"; shift 2 ;;
            -f|--format)   [[ $# -lt 2 ]] && error_exit "--format には値が必要です"; output_format="$2"; shift 2 ;;
            --ignore-comments) ignore_comments=1; shift ;;
            --keep-blanks) ignore_blanks=0; shift ;;
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
        diff)     cmd_diff    "${POSITIONAL[0]:-}" "${POSITIONAL[1]:-}" ;;
        backup)   cmd_backup  "${POSITIONAL[@]+"${POSITIONAL[@]}"}" ;;
        restore)  cmd_restore "${POSITIONAL[0]:-}" ;;
        history)  cmd_history "${POSITIONAL[0]:-}" ;;
        watch)    cmd_watch   "${POSITIONAL[@]+"${POSITIONAL[@]}"}" ;;
        audit)    cmd_audit   "${POSITIONAL[0]:-.}" ;;
        template) cmd_template "${POSITIONAL[0]:-}" ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
