#!/bin/bash
set -euo pipefail

#
# XMLインジェクション対策ツール
# 作成日: 2026-11-05
# バージョン: 1.0
#
# 脆弱性対応: XMLインジェクション・XXE脆弱性の検出と対策
# CVE該当: CWE-91 (XML Injection), CWE-611 (XXE - XML External Entity)
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare command_name="scan"

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション]

XMLインジェクション・XXE脆弱性を検出します。

コマンド:
  scan <パス>          脆弱性スキャン (デフォルト)
  validate <XML文字列> XML入力の検証
  xxe-check <ファイル> XXEパターン確認
  sanitize <入力>      XML文字列のサニタイズ

オプション:
  -h, --help           このヘルプを表示
  -v, --version        バージョン情報を表示

脆弱性概要:
  CWE-91:  XMLインジェクション (特殊文字の未エスケープ)
  CWE-611: XXE (外部エンティティ参照の悪用)
  対策: XML特殊文字のエスケープ・外部エンティティ無効化
EOF
}

cmd_scan() {
    local path="${1:-.}"
    log_info "XMLインジェクション脆弱性スキャン: $path"
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
    (r'<[^>]*\$\{?[A-Za-z_]\w*', "変数をXMLタグに直接埋め込み (CWE-91)", "HIGH"),
    (r'xmllint\s+.*--noent', "外部エンティティ展開有効 (CWE-611)", "CRITICAL"),
    (r'DOCTYPE\s+.*SYSTEM', "DOCTYPE SYSTEM 宣言 (XXE リスク)", "HIGH"),
    (r'<!ENTITY\s+%', "パラメータエンティティ定義 (XXEリスク)", "HIGH"),
    (r'curl.*xml.*\$\{?[A-Za-z_]\w*', "未サニタイズ変数をXMLペイロードに", "HIGH"),
    (r'echo.*<[a-zA-Z].*>.*\$\{?[A-Za-z_]\w*', "変数をXML出力に直接展開", "MEDIUM"),
    (r'xpath\s+.*\$\{?[A-Za-z_]\w*', "XPath式への未検証変数 (Injection)", "HIGH"),
    (r'saxonb-xslt|xsltproc.*--param\s+\S+\s+\$', "XSLTパラメータへの未検証変数", "MEDIUM"),
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
    [[ "$issues" -gt 0 ]] && log_error "XML入力をエスケープしてください" || log_success "問題なし"
}

cmd_validate() {
    local input="${1:-}"
    [[ -z "$input" ]] && error_exit "XML入力を指定してください"

    local unsafe=()
    [[ "$input" == *"<"* ]]  && unsafe+=("< (タグ開始)")
    [[ "$input" == *">"* ]]  && unsafe+=("< (タグ終了)")
    [[ "$input" == *"&"* ]]  && unsafe+=("& (エンティティ)")
    [[ "$input" == *'"'* ]]  && unsafe+=("\" (属性区切り)")
    [[ "$input" == *"'"* ]]  && unsafe+=("' (属性区切り)")

    if [[ ${#unsafe[@]} -gt 0 ]]; then
        log_warning "XML危険文字を検出:"
        for c in "${unsafe[@]}"; do
            printf "  %s\n" "$c"
        done
        printf "\nエスケープ済み: "
        echo "$input" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&apos;/g'
    else
        log_success "安全なXML入力"
    fi
}

cmd_xxe_check() {
    local file="${1:-}"
    [[ -z "$file" ]] && error_exit "ファイルを指定してください"
    [[ ! -f "$file" ]] && error_exit "ファイルが見つかりません: $file"

    log_info "XXEパターン確認: $file"
    echo ""

    local xxe_patterns=(
        "DOCTYPE.*SYSTEM"
        "DOCTYPE.*PUBLIC"
        "<!ENTITY"
        "SYSTEM.*file://"
        "SYSTEM.*http://"
        "noent"
    )

    local found=0
    for pat in "${xxe_patterns[@]}"; do
        if grep -qiE "$pat" "$file" 2>/dev/null; then
            (( found++ ))
            printf "  ${C_RED}[XXEリスク]${C_RESET} パターン検出: %s\n" "$pat"
            grep -niE "$pat" "$file" | head -3 | while IFS= read -r line; do
                printf "    行 %s\n" "$line"
            done
        fi
    done

    if [[ "$found" -eq 0 ]]; then
        log_success "XXEパターンなし"
    else
        echo ""
        log_warning "対策: xmllint --noent の代わりに --nonet を使用し、外部エンティティを無効化"
    fi
}

cmd_sanitize() {
    local input="${1:-}"
    [[ -z "$input" ]] && error_exit "サニタイズする文字列を指定してください"

    printf "元の文字列: %s\n" "$input"
    printf "サニタイズ: "
    echo "$input" | python3 -c "
import sys, html
data = sys.stdin.read().rstrip()
print(html.escape(data, quote=True))
"
}

parse_arguments() {
    [[ $# -eq 0 ]] && return 0
    case "$1" in
        scan|validate|xxe-check|sanitize)
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
        scan)       cmd_scan      "${POSITIONAL[0]:-.}" ;;
        validate)   cmd_validate  "${POSITIONAL[0]:-}" ;;
        xxe-check)  cmd_xxe_check "${POSITIONAL[0]:-}" ;;
        sanitize)   cmd_sanitize  "${POSITIONAL[0]:-}" ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
