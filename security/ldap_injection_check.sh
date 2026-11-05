#!/bin/bash
set -euo pipefail

#
# LDAPインジェクション対策ツール
# 作成日: 2026-11-05
# バージョン: 1.0
#
# 脆弱性対応: LDAPインジェクション脆弱性の検出と対策
# CVE該当: CWE-90 (LDAP Injection)
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare command_name="scan"

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション]

LDAPインジェクション脆弱性を検出・対策します。

コマンド:
  scan <パス>           脆弱性スキャン (デフォルト)
  validate <入力>       LDAP入力の検証
  sanitize <入力>       LDAP特殊文字のエスケープ
  test-query <フィルタ> LDAPフィルタの安全性確認

オプション:
  -h, --help            このヘルプを表示
  -v, --version         バージョン情報を表示

脆弱性概要:
  CWE-90: LDAPインジェクション
  危険文字: * ( ) \ NUL
  対策: 入力値のエスケープ・ホワイトリスト検証
EOF
}

cmd_scan() {
    local path="${1:-.}"
    log_info "LDAPインジェクション脆弱性スキャン: $path"
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
RESET  = "\033[0m"
BOLD   = "\033[1m"

patterns = [
    (r'ldapsearch.*-b\s+.*\$\{?[A-Za-z_]\w*', "ldapsearch のベースDNに未検証変数", "HIGH"),
    (r'ldapsearch.*\$\{?[A-Za-z_]\w*.*\)', "LDAPフィルタに未検証変数", "CRITICAL"),
    (r'ldapadd|ldapmodify.*-f.*\$\{?[A-Za-z_]\w*', "LDIFファイルパスに未検証変数", "HIGH"),
    (r'ldapwhoami.*-D.*\$\{?[A-Za-z_]\w*', "LDAP DNに未検証変数", "HIGH"),
    (r'\(uid=.*\$\{?[A-Za-z_]\w*', "LDAPフィルタ uid= に未検証変数", "CRITICAL"),
    (r'\(cn=.*\$\{?[A-Za-z_]\w*', "LDAPフィルタ cn= に未検証変数", "CRITICAL"),
    (r'\(mail=.*\$\{?[A-Za-z_]\w*', "LDAPフィルタ mail= に未検証変数", "HIGH"),
    (r'ldap_bind.*\$\{?[A-Za-z_]\w*', "LDAP認証に未検証変数", "HIGH"),
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
    color = "\033[1;35m" if sev == "CRITICAL" else (RED if sev == "HIGH" else YELLOW)
    print(f"  {color}[{sev}]{RESET} 行{lineno:4d}: {desc}")
    print(f"    {BOLD}{line[:80]}{RESET}")
PYEOF
)
        if [[ -n "$result" ]]; then
            (( issues++ ))
            printf "${C_BOLD}%s${C_RESET}\n" "$file"
            echo "$result"
            echo ""
        fi
    done < <(find "$path" -name "*.sh" -type f 2>/dev/null | sort)

    printf "スキャン完了: %d ファイル中 %d 件に問題\n" "$total" "$issues"
    [[ "$issues" -gt 0 ]] && log_error "LDAP入力をエスケープしてください" || log_success "問題なし"
}

cmd_validate() {
    local input="${1:-}"
    [[ -z "$input" ]] && error_exit "検証する入力を指定してください"

    local dangerous_chars='\*\(\)\\/'
    local has_danger=false

    printf "入力値: %s\n\n" "$input"

    # LDAP特殊文字の確認
    local found_chars=()
    [[ "$input" == *"*"* ]]  && found_chars+=("* (ワイルドカード - 全一致)")
    [[ "$input" == *"("* ]]  && found_chars+=("( (フィルタ開始)")
    [[ "$input" == *")"* ]]  && found_chars+=("') (フィルタ終了)")
    [[ "$input" == *"\\"* ]] && found_chars+=("\\ (エスケープ文字)")
    [[ "$input" == *"/"* ]]  && found_chars+=("/ (DN区切り)")
    [[ "$input" == *$'\0'* ]] && found_chars+=("NUL (ヌル文字)")

    if [[ ${#found_chars[@]} -gt 0 ]]; then
        log_warning "LDAP危険文字を検出:"
        for c in "${found_chars[@]}"; do
            printf "  %s\n" "$c"
        done
        has_danger=true
    fi

    # DNインジェクション確認
    if [[ "$input" =~ [a-zA-Z]+=.*,.* ]]; then
        log_error "DN構造パターン検出 (インジェクションの可能性)"
        has_danger=true
    fi

    if [[ "$has_danger" == "false" ]]; then
        log_success "安全なLDAP入力"
    fi
}

cmd_sanitize() {
    local input="${1:-}"
    [[ -z "$input" ]] && error_exit "サニタイズする文字列を指定してください"

    printf "元の文字列: %s\n" "$input"
    printf "エスケープ済み: "

    # RFC 4515 / RFC 4514 に準拠したLDAPエスケープ
    python3 -c "
import sys

data = '''$input'''
result = ''
for c in data:
    if c == '\\\\':
        result += '\\\\5c'
    elif c == '*':
        result += '\\\\2a'
    elif c == '(':
        result += '\\\\28'
    elif c == ')':
        result += '\\\\29'
    elif c == '\x00':
        result += '\\\\00'
    elif c == '/':
        result += '\\\\2f'
    else:
        result += c
print(result)
"
}

cmd_test_query() {
    local filter="${1:-}"
    [[ -z "$filter" ]] && error_exit "LDAPフィルタを指定してください"

    log_info "LDAPフィルタ安全性確認: $filter"
    echo ""

    # 危険なフィルタパターン
    local dangerous=false

    if [[ "$filter" == *"*)"* ]] || [[ "$filter" == *")("* ]]; then
        log_error "フィルタ操作のパターン検出 (インジェクションの可能性)"
        dangerous=true
    fi

    if [[ "$filter" =~ \|\( ]] || [[ "$filter" =~ \!\( ]]; then
        log_warning "OR/NOT演算子の組み合わせ (意図的かどうか確認)"
    fi

    if [[ "$filter" == *"objectClass=*"* ]]; then
        log_warning "objectClass=* はすべてのエントリに一致します"
    fi

    local nesting
    nesting=$(echo "$filter" | tr -cd '(' | wc -c)
    if [[ "$nesting" -gt 5 ]]; then
        log_warning "深いネスト ($nesting 層) - インジェクションの可能性"
        dangerous=true
    fi

    if [[ "$dangerous" == "false" ]]; then
        log_success "フィルタ構造は正常"
    fi
    printf "\n推奨: LDAPクエリには必ず入力値をエスケープして使用してください\n"
}

parse_arguments() {
    [[ $# -eq 0 ]] && return 0
    case "$1" in
        scan|validate|sanitize|test-query)
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
        scan)        cmd_scan        "${POSITIONAL[0]:-.}" ;;
        validate)    cmd_validate    "${POSITIONAL[0]:-}" ;;
        sanitize)    cmd_sanitize    "${POSITIONAL[0]:-}" ;;
        test-query)  cmd_test_query  "${POSITIONAL[0]:-}" ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
