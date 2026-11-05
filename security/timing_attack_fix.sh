#!/bin/bash
set -euo pipefail

#
# タイミング攻撃対策ツール
# 作成日: 2026-11-05
# バージョン: 1.0
#
# 脆弱性対応: タイミング攻撃・サイドチャネル攻撃の検出と防止
# CWE-208: Information Exposure Through Timing Discrepancy
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare command_name="scan"

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション]

タイミング攻撃の脆弱性を検出・防止します。

コマンド:
  scan <パス>          タイミング攻撃脆弱性スキャン (デフォルト)
  compare <A> <B>      定時間比較テスト
  fix-guide            修正ガイドラインの表示

オプション:
  -h, --help           このヘルプを表示
  -v, --version        バージョン情報を表示

脆弱性概要:
  CWE-208: タイミング差分による情報漏洩
  攻撃例: パスワード/トークン比較時間の差からバイト値を特定
  対策: hmac.compare_digest() / 定時間比較関数の使用
EOF
}

cmd_scan() {
    local path="${1:-.}"
    log_info "タイミング攻撃脆弱性スキャン: $path"
    echo ""

    local total=0 issues=0
    while IFS= read -r file; do
        (( total++ ))
        local result
        result=$(python3 - "$file" <<'PYEOF'
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
    (r'if\s+\[\s+["\']?\$(?:password|passwd|token|secret|key|hash)\s*[=!]=',
     "通常の文字列比較でパスワード/トークンを比較 (タイミング攻撃可能)", "HIGH"),
    (r'if\s+\[\[.*(?:password|passwd|token|secret|key)\s*[=!]=',
     "[[ ]] でパスワード/トークンを比較 (タイミング攻撃可能)", "HIGH"),
    (r'test\s+["\']?\$(?:password|token|secret)\s*[=!]=',
     "test コマンドでトークン比較 (タイミング攻撃可能)", "HIGH"),
    (r'if\s+(?:password|token|secret)\s*==\s*["\']',
     "Pythonでの通常文字列比較 (早期リターンの可能性)", "MEDIUM"),
    (r'(?:password|token|secret)\s*!=\s*["\']',
     "Pythonでの通常文字列比較 (!=)", "MEDIUM"),
]

findings = []
for i, line in enumerate(lines, 1):
    s = line.rstrip()
    if s.lstrip().startswith('#'):
        continue
    for pat, desc, sev in patterns:
        if re.search(pat, s, re.IGNORECASE):
            findings.append((i, s.strip(), desc, sev))
            break

for lineno, line, desc, sev in findings:
    color = RED if sev == "HIGH" else YELLOW
    print(f"  {color}[{sev}]{RESET} 行{lineno:4d}: {desc}")
    print(f"    {BOLD}{line[:80]}{RESET}")
    print(f"    {CYAN}→ 定時間比較関数を使用してください{RESET}")
PYEOF
)
        if [[ -n "$result" ]]; then
            (( issues++ ))
            printf "${C_BOLD}%s${C_RESET}\n" "$file"
            echo "$result"
            echo ""
        fi
    done < <(find "$path" \( -name "*.sh" -o -name "*.py" \) -type f 2>/dev/null | sort)

    printf "スキャン完了: %d ファイル中 %d 件にタイミング攻撃脆弱性\n" "$total" "$issues"
    [[ "$issues" -gt 0 ]] && log_error "定時間比較を実装してください" || log_success "脆弱性なし"
    echo ""
}

cmd_compare() {
    local a="${1:-}"
    local b="${2:-}"
    [[ -z "$a" || -z "$b" ]] && error_exit "2つの文字列を指定してください"

    log_info "定時間比較テスト"
    echo ""

    python3 - "$a" "$b" <<'PYEOF'
import sys, hmac, time

a = sys.argv[1].encode()
b = sys.argv[2].encode()

GREEN = "\033[1;32m"
RED   = "\033[1;31m"
RESET = "\033[0m"

start = time.perf_counter_ns()
_ = (a == b)
t_normal = time.perf_counter_ns() - start

start = time.perf_counter_ns()
_ = hmac.compare_digest(a, b)
t_safe = time.perf_counter_ns() - start

result = "一致" if hmac.compare_digest(a, b) else "不一致"
color = GREEN if hmac.compare_digest(a, b) else RED
print(f"  比較結果: {color}{result}{RESET}")
print()
print(f"  通常比較時間:    {t_normal:,} ns  (タイミング漏洩リスクあり)")
print(f"  定時間比較時間:  {t_safe:,} ns   (安全)")
print()
print(f"  hmac.compare_digest() を使用してください")
PYEOF
    echo ""
}

cmd_fix_guide() {
    log_info "タイミング攻撃修正ガイドライン"
    echo ""
    cat <<'GUIDE'
  【シェルスクリプト - タイミング攻撃の修正】

  危険: 通常の文字列比較
    if [[ "$user_token" == "$expected_token" ]]; then

  安全: HMACベースの定時間比較
    secure_compare() {
      local a="$1" b="$2"
      python3 -c "
import sys, hmac
a, b = sys.argv[1].encode(), sys.argv[2].encode()
sys.exit(0 if hmac.compare_digest(a, b) else 1)
" "$a" "$b"
    }

  【Python - タイミング攻撃の修正】

  危険:
    if user_token == expected_token:

  安全:
    import hmac
    if hmac.compare_digest(user_token.encode(), expected_token.encode()):

GUIDE
    echo ""
}

parse_arguments() {
    [[ $# -eq 0 ]] && return 0
    case "$1" in
        scan|compare|fix-guide)
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
        scan)      cmd_scan    "${POSITIONAL[0]:-.}" ;;
        compare)   cmd_compare "${POSITIONAL[0]:-}" "${POSITIONAL[1]:-}" ;;
        fix-guide) cmd_fix_guide ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
