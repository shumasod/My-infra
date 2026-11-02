#!/bin/bash
set -euo pipefail

#
# セキュアな一時ファイル管理ツール
# 作成日: 2026-11-02
# バージョン: 1.0
#
# 脆弱性対応: 一時ファイルの安全でない作成・競合状態・シンボリックリンク攻撃
# CVE該当: CWE-377 (Insecure Temporary File), CWE-362 (Race Condition)
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare command_name="audit"
declare target_dir="${TMPDIR:-/tmp}"
declare fix_mode=0
declare report_file=""

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション]

一時ファイルのセキュリティ脆弱性を検査・修正します。

コマンド:
  audit                一時ファイルの脆弱性監査 (デフォルト)
  scan <ディレクトリ>  スクリプト内の危険なtmp使用を検出
  cleanup              安全でない一時ファイルを削除
  monitor              一時ファイル作成をリアルタイム監視
  report               セキュリティレポート生成

オプション:
  -h, --help           このヘルプを表示
  -v, --version        バージョン情報を表示
  -d, --dir <パス>     対象ディレクトリ [デフォルト: /tmp]
  --fix                自動修正モード
  -o, --output <ファイル> レポート出力先

脆弱性概要:
  - /tmp/<予測可能な名前> への書き込み (CWE-377)
  - mktemp を使わない一時ファイル作成
  - tmpファイルへのシンボリックリンク攻撃
  - レース条件を含む tmp ファイル操作
EOF
}

check_dangerous_patterns() {
    local file="$1"
    python3 - "$file" <<'PYEOF'
import sys, re

filepath = sys.argv[1]
try:
    with open(filepath) as f:
        content = f.read()
except:
    sys.exit(0)

RED    = "\033[1;31m"
YELLOW = "\033[1;33m"
RESET  = "\033[0m"
BOLD   = "\033[1m"

patterns = [
    (r'(?<![a-zA-Z_])/tmp/[a-zA-Z0-9_-]+(?!\$|\()',
     "予測可能な/tmpパス使用", "HIGH"),
    (r'TMPFILE\s*=\s*["\']?/tmp/',
     "固定tmpファイル名への代入", "HIGH"),
    (r'>\s*/tmp/[^$\(]',
     "固定tmpパスへのリダイレクト", "HIGH"),
    (r'touch\s+/tmp/',
     "touch による tmpファイル作成", "MEDIUM"),
    (r'cat\s+.*>\s*/tmp/',
     "catによる tmpへの書き込み", "MEDIUM"),
    (r'echo\s+.*>+\s*/tmp/',
     "echoによる tmpへの書き込み", "MEDIUM"),
    (r'rm\s+-rf?\s+/tmp/',
     "tmpディレクトリ以下の危険な削除", "MEDIUM"),
    (r'\$\(mktemp\)\s*&&',
     "mktempのエラーチェック不足", "LOW"),
]

findings = []
for i, line in enumerate(content.splitlines(), 1):
    for pat, desc, sev in patterns:
        if re.search(pat, line):
            findings.append((i, line.strip(), desc, sev))

if findings:
    for lineno, line, desc, sev in findings:
        color = RED if sev == "HIGH" else YELLOW
        print(f"  {color}[{sev}]{RESET} 行{lineno}: {desc}")
        print(f"    {BOLD}{line[:80]}{RESET}")
PYEOF
}

cmd_audit() {
    log_info "一時ファイルセキュリティ監査: $target_dir"
    echo ""

    local world_writable sticky_bit_missing dangerous_perms
    world_writable=$(find "$target_dir" -maxdepth 1 -perm -o+w -not -type l 2>/dev/null | wc -l)
    sticky_bit_missing=0

    if [[ ! -k "$target_dir" ]]; then
        sticky_bit_missing=1
        log_warning "/tmp にスティッキービットが設定されていません (CWE-732)"
    else
        log_success "/tmp スティッキービット: 設定済み"
    fi

    echo ""
    printf "${C_BOLD}【/tmp ディレクトリ状態】${C_RESET}\n\n"

    local total_files owned_by_root world_writable_files symlinks
    total_files=$(find "$target_dir" -maxdepth 1 2>/dev/null | wc -l)
    owned_by_root=$(find "$target_dir" -maxdepth 1 -user root 2>/dev/null | wc -l)
    world_writable_files=$(find "$target_dir" -maxdepth 1 -perm -o+w -not -type d 2>/dev/null | wc -l)
    symlinks=$(find "$target_dir" -maxdepth 1 -type l 2>/dev/null | wc -l)

    printf "  %-30s %s\n" "総ファイル数:"        "$total_files"
    printf "  %-30s %s\n" "rootが所有:"           "$owned_by_root"
    printf "  %-30s " "other書き込み可能ファイル:"
    if [[ "$world_writable_files" -gt 0 ]]; then
        printf "${C_RED}%s (危険)${C_RESET}\n" "$world_writable_files"
    else
        printf "${C_GREEN}0${C_RESET}\n"
    fi
    printf "  %-30s " "シンボリックリンク:"
    if [[ "$symlinks" -gt 0 ]]; then
        printf "${C_YELLOW}%s (要確認)${C_RESET}\n" "$symlinks"
    else
        printf "${C_GREEN}0${C_RESET}\n"
    fi

    echo ""
    printf "${C_BOLD}【危険なシンボリックリンク検出】${C_RESET}\n\n"
    local found_dangerous=0
    while IFS= read -r link; do
        local target
        target=$(readlink "$link" 2>/dev/null || echo "unknown")
        if [[ "$target" == /* && "$target" != /tmp/* ]]; then
            printf "  ${C_RED}[危険]${C_RESET} %s -> %s\n" "$link" "$target"
            (( found_dangerous++ ))
        fi
    done < <(find "$target_dir" -maxdepth 2 -type l 2>/dev/null)

    if [[ "$found_dangerous" -eq 0 ]]; then
        printf "  ${C_GREEN}危険なシンボリックリンクなし${C_RESET}\n"
    fi
    echo ""
}

cmd_scan() {
    local scan_path="${1:-.}"
    log_info "スクリプト内の危険な一時ファイル使用を検出: $scan_path"
    echo ""

    local files_checked=0 files_with_issues=0

    while IFS= read -r file; do
        (( files_checked++ ))
        local output
        output=$(check_dangerous_patterns "$file")
        if [[ -n "$output" ]]; then
            (( files_with_issues++ ))
            printf "${C_BOLD}${C_YELLOW}%s${C_RESET}\n" "$file"
            echo "$output"
            echo ""
        fi
    done < <(find "$scan_path" -name "*.sh" -type f 2>/dev/null)

    printf "スキャン完了: %d ファイル中 %d ファイルに問題を検出\n" \
        "$files_checked" "$files_with_issues"
    echo ""
}

cmd_cleanup() {
    log_info "危険な一時ファイルのクリーンアップ"
    echo ""

    local old_files
    old_files=$(find "$target_dir" -maxdepth 1 -type f -mtime +7 2>/dev/null | wc -l)
    printf "  7日以上経過した一時ファイル: %s 件\n" "$old_files"

    if [[ "$old_files" -eq 0 ]]; then
        log_success "クリーンアップ対象なし"
        return
    fi

    if ! confirm "古い一時ファイルを削除しますか？"; then
        log_info "キャンセルしました"
        return
    fi

    local deleted=0
    while IFS= read -r file; do
        rm -f "$file" && (( deleted++ ))
    done < <(find "$target_dir" -maxdepth 1 -type f -mtime +7 2>/dev/null)

    log_success "削除完了: $deleted ファイル"
    echo ""
}

cmd_monitor() {
    log_info "一時ファイル作成モニタリング (Ctrl+C で終了)"
    echo ""

    if command -v inotifywait &>/dev/null; then
        inotifywait -m "$target_dir" -e create -e moved_to --format '%T %e %w%f' --timefmt '%H:%M:%S' 2>/dev/null | \
        while IFS= read -r line; do
            local ts event file
            ts=$(echo "$line" | awk '{print $1}')
            event=$(echo "$line" | awk '{print $2}')
            file=$(echo "$line" | awk '{print $3}')

            local owner
            owner=$(stat -c "%U" "$file" 2>/dev/null || echo "unknown")
            local perms
            perms=$(stat -c "%a" "$file" 2>/dev/null || echo "???")

            if [[ "$perms" =~ [67]$ ]]; then
                printf "${C_RED}[%s] %s: %s (所有者:%s, パーミッション:%s) [危険]${C_RESET}\n" \
                    "$ts" "$event" "$file" "$owner" "$perms"
            else
                printf "${C_DIM}[%s] %s: %s (所有者:%s)${C_RESET}\n" \
                    "$ts" "$event" "$file" "$owner"
            fi
        done
    else
        log_warning "inotifywait が見つかりません。ポーリングモードで監視します"
        local prev_count
        prev_count=$(find "$target_dir" -maxdepth 1 2>/dev/null | wc -l)
        while true; do
            sleep 2
            local curr_count
            curr_count=$(find "$target_dir" -maxdepth 1 2>/dev/null | wc -l)
            if [[ "$curr_count" -ne "$prev_count" ]]; then
                log_info "$(date +%H:%M:%S) ファイル数変化: $prev_count -> $curr_count"
                prev_count="$curr_count"
            fi
        done
    fi
}

cmd_report() {
    local out="${report_file:-/tmp/secure_tmpfile_report_$$.txt}"
    log_info "セキュリティレポート生成: $out"
    {
        echo "# 一時ファイルセキュリティレポート"
        echo "生成日時: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "ホスト: $(hostname)"
        echo ""
        echo "## /tmp 状態"
        ls -la "$target_dir" 2>/dev/null | head -20
        echo ""
        echo "## スティッキービット"
        ls -ld "$target_dir" 2>/dev/null
        echo ""
        echo "## 危険なシンボリックリンク"
        find "$target_dir" -maxdepth 2 -type l -exec ls -la {} \; 2>/dev/null
    } > "$out"
    log_success "レポート生成完了: $out"
}

parse_arguments() {
    [[ $# -eq 0 ]] && return 0
    case "$1" in
        audit|scan|cleanup|monitor|report)
            command_name="$1"; shift ;;
    esac

    local positional=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -d|--dir)     [[ $# -lt 2 ]] && error_exit "--dir には値が必要です"; target_dir="$2"; shift 2 ;;
            --fix)        fix_mode=1; shift ;;
            -o|--output)  [[ $# -lt 2 ]] && error_exit "--output には値が必要です"; report_file="$2"; shift 2 ;;
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
        audit)   cmd_audit ;;
        scan)    cmd_scan   "${POSITIONAL[0]:-.}" ;;
        cleanup) cmd_cleanup ;;
        monitor) cmd_monitor ;;
        report)  cmd_report ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
