#!/bin/bash
set -euo pipefail

#
# クロスサイトスクリプティング (XSS) 防止ツール
# 作成日: 2026-11-05
# バージョン: 1.0
#
# 脆弱性対応: XSS脆弱性の検出とHTML出力のサニタイズ
# CVE該当: CWE-79 (Reflected XSS), CWE-80 (Stored XSS)
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare command_name="scan"

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション]

XSS脆弱性の検出とHTML出力のサニタイズを行います。

コマンド:
  scan <パス>           脆弱性スキャン (デフォルト)
  sanitize <文字列>     HTMLエスケープ
  check-csp <URL/ファイル> Content-Security-Policy 確認
  validate <HTML>       HTML入力の安全性検証

オプション:
  -h, --help            このヘルプを表示
  -v, --version         バージョン情報を表示

脆弱性概要:
  CWE-79:  反射型XSS (ユーザー入力をHTMLにそのまま出力)
  CWE-80:  保存型XSS (入力値をDBに保存後にHTMLに出力)
  対策: HTMLエスケープ・CSPヘッダー・入力検証
EOF
}

cmd_scan() {
    local path="${1:-.}"
    log_info "XSS脆弱性スキャン: $path"
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
    # HTMLへの直接変数埋め込み
    (r'echo.*<[a-zA-Z].*>.*\$\{?[A-Za-z_]\w*', "HTMLタグに未エスケープ変数を出力 (CWE-79)", "CRITICAL"),
    (r'printf.*<[a-zA-Z].*>.*\$\{?[A-Za-z_]\w*', "HTMLタグに未エスケープ変数をprintf出力", "CRITICAL"),
    (r'cat\s*<<.*EOF.*\n(?:.*\n)*?.*\$\{?(?:1|2|3|@|\*|[A-Za-z_]\w*)',
     "ヒアドキュメントHTML内の未エスケープ変数", "HIGH"),

    # JavaScriptへの直接埋め込み
    (r'echo.*<script.*>.*\$\{?[A-Za-z_]\w*', "scriptタグに未エスケープ変数", "CRITICAL"),
    (r'echo.*javascript:.*\$\{?[A-Za-z_]\w*', "javascript: URLに未検証変数", "HIGH"),

    # イベントハンドラへの埋め込み
    (r'echo.*on(?:click|load|error|mouse|key)=.*\$\{?[A-Za-z_]\w*',
     "イベントハンドラに未エスケープ変数", "HIGH"),

    # HTMLコメントへの埋め込み
    (r'echo.*<!--.*\$\{?[A-Za-z_]\w*', "HTMLコメントに変数 (エスケープ不要でも危険)", "MEDIUM"),

    # Content-Security-Policy なし
    (r'Content-Type:\s*text/html', "CSPヘッダーなしのHTML出力を確認", "LOW"),

    # curl レスポンスをHTMLに
    (r'\$\(curl.*\).*>.*\.html', "curlレスポンスを直接HTMLに書き込み", "HIGH"),
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
    [[ "$issues" -gt 0 ]] && log_error "HTML出力を必ずエスケープしてください" || log_success "問題なし"
}

cmd_sanitize() {
    local input="${1:-}"
    [[ -z "$input" ]] && error_exit "サニタイズする文字列を指定してください"

    printf "元の文字列: %s\n" "$input"
    printf "HTMLエスケープ: "
    python3 -c "
import sys, html
data = '''$input'''
print(html.escape(data, quote=True))
"
    printf "URLエンコード: "
    python3 -c "
import sys
from urllib.parse import quote
data = '''$input'''
print(quote(data, safe=''))
"
}

cmd_check_csp() {
    local target="${1:-}"
    [[ -z "$target" ]] && error_exit "URL またはHTMLファイルを指定してください"

    log_info "Content-Security-Policy 確認: $target"
    echo ""

    if [[ -f "$target" ]]; then
        # ファイルからCSPメタタグ確認
        if grep -qi "content-security-policy" "$target" 2>/dev/null; then
            log_success "CSPメタタグあり:"
            grep -i "content-security-policy" "$target" | head -3
        else
            log_error "CSPメタタグなし"
        fi

        # 危険なインラインスクリプト確認
        local inline_scripts
        inline_scripts=$(grep -c '<script>' "$target" 2>/dev/null || echo 0)
        if [[ "$inline_scripts" -gt 0 ]]; then
            log_warning "インラインスクリプト ${inline_scripts} 件 (CSP unsafe-inline が必要)"
        fi

        # 危険なeval使用確認
        if grep -qE '\beval\s*\(' "$target" 2>/dev/null; then
            log_error "eval() 使用検出 (CSP unsafe-eval が必要、または削除推奨)"
        fi
    fi

    echo ""
    printf "${C_BOLD}推奨CSPヘッダー:${C_RESET}\n"
    printf "  Content-Security-Policy: default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; object-src 'none'; frame-ancestors 'none';\n"
}

cmd_validate() {
    local html="${1:-}"
    [[ -z "$html" ]] && error_exit "検証するHTML文字列を指定してください"

    local is_safe=true

    # スクリプトタグ
    if echo "$html" | grep -qi '<script'; then
        log_error "scriptタグを検出"
        is_safe=false
    fi

    # JavaScriptスキーム
    if echo "$html" | grep -qiE 'javascript\s*:'; then
        log_error "javascript: スキームを検出"
        is_safe=false
    fi

    # イベントハンドラ属性
    if echo "$html" | grep -qiE '\bon\w+\s*='; then
        log_error "イベントハンドラ属性を検出 (onXXX=)"
        is_safe=false
    fi

    # データURL
    if echo "$html" | grep -qiE 'data\s*:\s*text/html'; then
        log_warning "data:text/html URI を検出"
        is_safe=false
    fi

    if [[ "$is_safe" == "true" ]]; then
        log_success "危険なXSSパターンなし"
    fi
}

parse_arguments() {
    [[ $# -eq 0 ]] && return 0
    case "$1" in
        scan|sanitize|check-csp|validate)
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
        scan)       cmd_scan       "${POSITIONAL[0]:-.}" ;;
        sanitize)   cmd_sanitize   "${POSITIONAL[0]:-}" ;;
        check-csp)  cmd_check_csp  "${POSITIONAL[0]:-}" ;;
        validate)   cmd_validate   "${POSITIONAL[0]:-}" ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
