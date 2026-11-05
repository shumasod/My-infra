#!/bin/bash
set -euo pipefail

#
# ログインジェクション対策ツール
# 作成日: 2026-11-05
# バージョン: 1.0
#
# 脆弱性対応: ログインジェクション攻撃の検出・防止
# CVE該当: CWE-117 (Improper Output Neutralization for Logs), CWE-93 (CRLF Injection)
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare command_name="scan"

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション]

ログインジェクション脆弱性を検出・防止します。

コマンド:
  scan <パス>          ログインジェクション脆弱性スキャン (デフォルト)
  sanitize <文字列>    入力値のサニタイズ処理
  analyze <ログファイル> ログファイルの異常検出
  monitor <ログファイル> ログのリアルタイム監視

オプション:
  -h, --help           このヘルプを表示
  -v, --version        バージョン情報を表示

脆弱性概要:
  CWE-117: ログ出力の不適切なサニタイズ
  CWE-93: CRLFインジェクションによるログ偽造
  攻撃例: ユーザー入力にCR/LFを含めてログを偽造
EOF
}

scan_log_injection() {
    local file="$1"
    python3 - "$file" <<'PYEOF'
import sys, re

filepath = sys.argv[1]
try:
    with open(filepath, errors='replace') as f:
        lines = f.readlines()
except:
    sys.exit(0)

RED    = "\033[1;31m"
YELLOW = "\033[1;33m"
CYAN   = "\033[1;36m"
RESET  = "\033[0m"
BOLD   = "\033[1m"

patterns = [
    (r'(?:echo|printf|logger)\s+.*\$(?:1|2|3|@|\*|[A-Za-z_]\w*)',
     "未サニタイズ変数をログ出力", "HIGH"),
    (r'(?:echo|printf)\s+.*\$(?:USER|USERNAME|LOGNAME|HOME|SHELL)',
     "ユーザー提供データをログ出力", "HIGH"),
    (r'log_(?:info|warning|error|debug)\s+.*\$(?![({\[])',
     "ログ関数に未サニタイズ変数", "MEDIUM"),
    (r'(?:echo|printf).*\\n.*\$',
     "改行文字を含むログ出力", "MEDIUM"),
    (r'(?:echo|printf).*\\r',
     "CR文字を含むログ出力", "HIGH"),
    (r'tee\s+.*(?:append|>>).*\$',
     "変数パスへのteeログ", "MEDIUM"),
    (r'2>&1.*>>.*\$',
     "変数パスへのリダイレクト", "LOW"),
]

findings = []
for i, line in enumerate(lines, 1):
    s = line.rstrip()
    if s.lstrip().startswith('#'):
        continue
    for pat, desc, sev in patterns:
        if re.search(pat, s):
            findings.append((i, s.strip(), desc, sev))
            break

for lineno, line, desc, sev in findings:
    color = RED if sev == "HIGH" else YELLOW
    print(f"  {color}[{sev}]{RESET} 行{lineno:4d}: {desc}")
    print(f"    {BOLD}{line[:80]}{RESET}")
PYEOF
}

cmd_scan() {
    local path="${1:-.}"
    log_info "ログインジェクション脆弱性スキャン: $path"
    echo ""

    local total=0 issues=0
    while IFS= read -r file; do
        (( total++ ))
        local result
        result=$(scan_log_injection "$file")
        if [[ -n "$result" ]]; then
            (( issues++ ))
            printf "${C_BOLD}%s${C_RESET}\n" "$file"
            echo "$result"
            echo ""
        fi
    done < <(find "$path" -name "*.sh" -type f 2>/dev/null | sort)

    printf "スキャン完了: %d ファイル中 %d 件にログインジェクション脆弱性\n" "$total" "$issues"
    if [[ "$issues" -gt 0 ]]; then
        log_error "ログ出力前に入力値をサニタイズしてください"
    else
        log_success "ログインジェクション脆弱性なし"
    fi
    echo ""
}

cmd_sanitize() {
    local input="${1:-}"
    [[ -z "$input" ]] && error_exit "サニタイズする文字列を指定してください"

    log_info "ログ入力値サニタイズ"
    echo ""

    python3 - "$input" <<'PYEOF'
import sys, re

input_str = sys.argv[1]

GREEN  = "\033[1;32m"
RED    = "\033[1;31m"
YELLOW = "\033[1;33m"
CYAN   = "\033[1;36m"
RESET  = "\033[0m"

# 危険なパターン検出
issues = []
if '\n' in input_str or '\\n' in input_str:
    issues.append("改行文字 (\\n) を含む - ログ偽造可能")
if '\r' in input_str or '\\r' in input_str:
    issues.append("復帰文字 (\\r) を含む - CRLF インジェクション")
if '\x00' in input_str:
    issues.append("Null バイト (\\x00) を含む")
if re.search(r'\x1b\[', input_str):
    issues.append("ANSIエスケープシーケンスを含む - ターミナル制御")
if len(input_str) > 1024:
    issues.append(f"過大な入力 ({len(input_str)} 文字) - DoS可能性")

print(f"  元の入力: '{input_str[:80]}'")
print()

if issues:
    print(f"  {RED}[危険] 以下の問題を検出:{RESET}")
    for issue in issues:
        print(f"    • {issue}")
else:
    print(f"  {GREEN}[安全] 危険なパターンなし{RESET}")

# サニタイズ処理
sanitized = input_str
sanitized = re.sub(r'[\r\n]', ' ', sanitized)   # 改行除去
sanitized = re.sub(r'\x00', '', sanitized)       # Nullバイト除去
sanitized = re.sub(r'\x1b\[[0-9;]*[mGKHF]', '', sanitized)  # ANSIエスケープ除去
sanitized = sanitized[:1024]                     # 長さ制限

print()
print(f"  {CYAN}サニタイズ済み: '{sanitized[:80]}'{RESET}")

# シェルでのサニタイズ方法
print()
print(f"  シェルでのサニタイズ方法:")
print(f"    sanitized=$(echo \"$input\" | tr -d '\\r\\n' | head -c 1024)")
print(f"    logger \"User input: $sanitized\"")
PYEOF
    echo ""
}

cmd_analyze() {
    local logfile="${1:-}"
    [[ -z "$logfile" ]] && error_exit "ログファイルを指定してください"
    [[ ! -f "$logfile" ]] && error_exit "ファイルが見つかりません: $logfile"

    log_info "ログファイル異常検出: $logfile"
    echo ""

    python3 - "$logfile" <<'PYEOF'
import sys, re

logfile = sys.argv[1]
try:
    with open(logfile, errors='replace') as f:
        lines = f.readlines()
except Exception as e:
    print(f"  エラー: {e}")
    sys.exit(0)

RED    = "\033[1;31m"
YELLOW = "\033[1;33m"
GREEN  = "\033[1;32m"
RESET  = "\033[0m"

suspicious = []
for i, line in enumerate(lines, 1):
    # CRLF インジェクションの痕跡
    if '\r' in line:
        suspicious.append((i, "CR文字を含む行", "HIGH"))
    # ANSIエスケープシーケンス
    if re.search(r'\x1b\[', line):
        suspicious.append((i, "ANSIエスケープシーケンス", "MEDIUM"))
    # 異常に長い行
    if len(line) > 10000:
        suspicious.append((i, f"異常に長い行 ({len(line)} 文字)", "MEDIUM"))
    # Null バイト
    if '\x00' in line:
        suspicious.append((i, "Nullバイト", "HIGH"))

print(f"  総行数: {len(lines)}")
print(f"  疑わしい行: {len(suspicious)}")
print()

if suspicious:
    print(f"  {RED}【疑わしい行の詳細】{RESET}\n")
    for lineno, reason, sev in suspicious[:20]:
        color = RED if sev == "HIGH" else YELLOW
        print(f"  {color}[{sev}]{RESET} 行{lineno}: {reason}")
else:
    print(f"  {GREEN}異常なし{RESET}")
PYEOF
    echo ""
}

cmd_monitor() {
    local logfile="${1:-}"
    [[ -z "$logfile" ]] && error_exit "監視するログファイルを指定してください"
    [[ ! -f "$logfile" ]] && error_exit "ファイルが見つかりません: $logfile"

    log_info "ログ監視開始: $logfile (Ctrl+C で終了)"
    echo ""

    tail -f "$logfile" 2>/dev/null | while IFS= read -r line; do
        if echo "$line" | grep -qP '\r|\x00|\x1b\['; then
            printf "${C_RED}[インジェクション疑い]${C_RESET} %s\n" "${line//[^[:print:]]/?}"
        elif echo "$line" | grep -qiE "failed|error|warning|attack|injection|traversal"; then
            printf "${C_YELLOW}[要注意]${C_RESET} %s\n" "$line"
        else
            printf "${C_DIM}%s${C_RESET}\n" "$line"
        fi
    done
}

parse_arguments() {
    [[ $# -eq 0 ]] && return 0
    case "$1" in
        scan|sanitize|analyze|monitor)
            command_name="$1"; shift ;;
    esac
    local positional=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
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
        scan)     cmd_scan     "${POSITIONAL[0]:-.}" ;;
        sanitize) cmd_sanitize "${POSITIONAL[0]:-}" ;;
        analyze)  cmd_analyze  "${POSITIONAL[0]:-}" ;;
        monitor)  cmd_monitor  "${POSITIONAL[0]:-}" ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
