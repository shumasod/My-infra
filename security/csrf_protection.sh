#!/bin/bash
set -euo pipefail

#
# CSRF (クロスサイトリクエストフォージェリ) 対策ツール
# 作成日: 2026-11-05
# バージョン: 1.0
#
# 脆弱性対応: CSRF脆弱性の検出とトークン管理
# CVE該当: CWE-352 (Cross-Site Request Forgery)
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"
readonly TOKEN_LENGTH=32

declare command_name="scan"

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション]

CSRF脆弱性の検出とトークン管理を行います。

コマンド:
  scan <パス>           脆弱性スキャン (デフォルト)
  generate-token        CSRFトークンの生成
  verify-token <token>  トークンの検証
  check-headers <URL>   セキュリティヘッダーの確認

オプション:
  -h, --help            このヘルプを表示
  -v, --version         バージョン情報を表示

脆弱性概要:
  CWE-352: CSRF (ユーザーの意図しない操作の実行)
  攻撃: 認証済みユーザーに悪意ある操作を実行させる
  対策: CSRFトークン・SameSite Cookie・Origin確認
EOF
}

cmd_scan() {
    local path="${1:-.}"
    log_info "CSRF脆弱性スキャン: $path"
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
    # Originヘッダーなしのcurl POST
    (r'curl\s+.*-X\s+POST(?!.*(?:Origin|Referer|csrf))', "POSTリクエストにCSRF対策なし", "HIGH"),
    (r'curl\s+.*-d\s+.*(?!.*csrf)', "データ送信にCSRFトークンなし", "MEDIUM"),

    # Cookieのみの認証
    (r'Cookie:\s*session', "Cookieのみの認証 (CSRFトークン要確認)", "MEDIUM"),

    # HTMLフォームにCSRFトークンなし
    (r'<form\s+method=["\']post["\'](?!.*csrf)', "POSTフォームにCSRFトークンなし", "HIGH"),

    # Set-Cookie にSameSiteなし
    (r'Set-Cookie:.*(?!.*SameSite)', "CookieにSameSite属性なし", "MEDIUM"),

    # Referer/Originチェックなし
    (r'HTTP_HOST.*==.*SERVER_NAME', "Originの不完全な確認", "LOW"),

    # CORS設定が過度に緩い
    (r'Access-Control-Allow-Origin:\s*\*', "CORS: 全オリジン許可 (過度に緩い)", "HIGH"),
    (r'Access-Control-Allow-Credentials:\s*true.*\*', "CORS: 認証情報+全オリジン許可", "CRITICAL"),
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
    [[ "$issues" -gt 0 ]] && log_error "CSRFトークンを実装してください" || log_success "問題なし"
}

cmd_generate_token() {
    local token
    token=$(python3 -c "
import secrets, hashlib, time
token = secrets.token_urlsafe($TOKEN_LENGTH)
print(token)
")
    printf "${C_GREEN}CSRFトークン:${C_RESET} %s\n" "$token"
    printf "\n使用方法:\n"
    printf "  フォームに hidden フィールドとして埋め込む:\n"
    printf "  <input type=\"hidden\" name=\"csrf_token\" value=\"%s\">\n\n" "$token"
    printf "  サーバー側でセッションに保存・照合する\n"
}

cmd_verify_token() {
    local token="${1:-}"
    [[ -z "$token" ]] && error_exit "検証するトークンを指定してください"

    local len=${#token}

    printf "トークン: %s\n" "$token"
    printf "長さ: %d 文字\n\n" "$len"

    local is_valid=true

    if [[ "$len" -lt 20 ]]; then
        log_error "トークンが短すぎます (最低20文字推奨)"
        is_valid=false
    fi

    # Base64URL文字のみを確認
    if ! echo "$token" | grep -qE '^[A-Za-z0-9_=-]+$'; then
        log_error "不正な文字を含む可能性"
        is_valid=false
    fi

    # エントロピー確認 (簡易)
    local unique_chars
    unique_chars=$(echo "$token" | fold -w1 | sort -u | wc -l)
    if [[ "$unique_chars" -lt 10 ]]; then
        log_warning "エントロピーが低い可能性 (ユニーク文字: $unique_chars)"
    fi

    if [[ "$is_valid" == "true" ]]; then
        log_success "トークン形式は正常"
    fi
}

cmd_check_headers() {
    local url="${1:-}"
    [[ -z "$url" ]] && error_exit "URLを指定してください"

    log_info "セキュリティヘッダー確認: $url"
    echo ""

    local headers
    if ! headers=$(curl -sI --max-time 10 "$url" 2>/dev/null); then
        log_error "接続失敗: $url"
        return 1
    fi

    local checks=(
        "X-Frame-Options:クリックジャッキング防止"
        "X-Content-Type-Options:MIMEスニッフィング防止"
        "Content-Security-Policy:CSPポリシー"
        "X-XSS-Protection:XSS保護 (旧ブラウザ)"
        "Strict-Transport-Security:HSTS"
        "Referrer-Policy:リファラーポリシー"
    )

    for check in "${checks[@]}"; do
        local header="${check%%:*}"
        local desc="${check##*:}"
        if echo "$headers" | grep -qi "^${header}:"; then
            printf "  ${C_GREEN}[OK]${C_RESET}    %s (%s)\n" "$header" "$desc"
        else
            printf "  ${C_RED}[なし]${C_RESET}  %s (%s)\n" "$header" "$desc"
        fi
    done

    # SameSite Cookie確認
    echo ""
    if echo "$headers" | grep -qi "Set-Cookie"; then
        if echo "$headers" | grep -qi "SameSite"; then
            log_success "SameSite Cookie 設定あり"
        else
            log_warning "SameSite Cookie 設定なし"
        fi
    fi
}

parse_arguments() {
    [[ $# -eq 0 ]] && return 0
    case "$1" in
        scan|generate-token|verify-token|check-headers)
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
        scan)             cmd_scan           "${POSITIONAL[0]:-.}" ;;
        generate-token)   cmd_generate_token ;;
        verify-token)     cmd_verify_token   "${POSITIONAL[0]:-}" ;;
        check-headers)    cmd_check_headers  "${POSITIONAL[0]:-}" ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
