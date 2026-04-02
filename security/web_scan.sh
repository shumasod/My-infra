#!/bin/bash
set -euo pipefail

#
# ウェブセキュリティ診断スクリプト
# 作成日: 2026-03-29
# バージョン: 1.0
#
# 【重要】本スクリプトは以下の対象にのみ使用してください:
#   - 自己が所有・管理するウェブサイト
#   - 書面による許諾を得たサイト（ペネトレーションテスト等）
#   - CTF・セキュリティ研究の専用環境
#
# 無許可のサイトへの使用は不正アクセス禁止法違反となります。
#

# 共通ライブラリの読み込み
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"
readonly CURL_TIMEOUT=10
readonly CURL_OPTS=(-s -m "$CURL_TIMEOUT" --max-redirs 0 -D -)

# ===== スコア管理 =====
declare -i SCORE=0
declare -i MAX_SCORE=0
declare -a FINDINGS=()      # 問題点リスト
declare -a PASSES=()        # 合格項目リスト
declare -a WARNINGS=()      # 警告リスト

# 診断対象
declare TARGET_URL=""
declare TARGET_HOST=""
declare REPORT_FILE=""

# ===== ヘルプ =====

show_usage() {
    cat <<EOF
使用方法: ${PROG_NAME} [オプション] <URL>

【重要】授権済みサイトのみを対象としてください。

オプション:
  -o, --output FILE   レポートをファイルに保存
  -h, --help          このヘルプを表示
  -v, --version       バージョン表示

例:
  ${PROG_NAME} https://example.com
  ${PROG_NAME} -o report.txt https://example.com
EOF
}

# ===== 免責確認 =====

confirm_authorization() {
    echo -e "\n${C_YELLOW}${C_BOLD}  ⚠️  重要な確認事項 ⚠️${C_RESET}"
    echo -e "${C_YELLOW}  ┌────────────────────────────────────────────────┐"
    echo -e "  │ 本ツールは以下の場合のみ使用が許可されます:     │"
    echo -e "  │  1. 自己が所有・管理するサイト                  │"
    echo -e "  │  2. 書面による診断委託を受けたサイト            │"
    echo -e "  │  3. CTF・専用テスト環境                         │"
    echo -e "  │                                                  │"
    echo -e "  │ 無許可の使用は不正アクセス禁止法違反です。      │"
    echo -e "  └────────────────────────────────────────────────┘${C_RESET}\n"

    printf "  対象サイトへの診断権限がありますか？ [yes/no]: "
    read -r ans
    if [[ "${ans,,}" != "yes" ]]; then
        echo -e "\n  ${C_RED}診断を中止します。${C_RESET}\n"
        exit 1
    fi
}

# ===== URL 検証・正規化 =====

validate_url() {
    local url="$1"

    # https:// または http:// で始まるか確認
    if ! [[ "$url" =~ ^https?:// ]]; then
        log_error "URL は https:// または http:// で始めてください: $url"
        exit 1
    fi

    # ホスト名を抽出（プロトコルとパスを除去）
    TARGET_HOST=$(echo "$url" | sed -E 's|^https?://([^/]+).*|\1|')

    if [[ -z "$TARGET_HOST" ]]; then
        log_error "ホスト名を抽出できませんでした: $url"
        exit 1
    fi

    TARGET_URL="$url"
    log_info "診断対象: ${TARGET_URL} (ホスト: ${TARGET_HOST})"
}

# ===== HTTPレスポンス取得 =====

fetch_headers() {
    local url="$1"
    # ヘッダーのみ取得（ボディは破棄）。リダイレクトは追わない
    curl "${CURL_OPTS[@]}" -o /dev/null "$url" 2>/dev/null || true
}

fetch_headers_follow() {
    local url="$1"
    # リダイレクトを追ってヘッダー取得（最大10回）
    curl -s -m "$CURL_TIMEOUT" --max-redirs 10 -D - -o /dev/null "$url" 2>/dev/null || true
}

# ===== 引数解析 =====

parse_arguments() {
    if [[ $# -eq 0 ]]; then
        show_usage
        exit 1
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "${PROG_NAME} v${VERSION}"; exit 0 ;;
            -o|--output)
                [[ $# -lt 2 ]] && { log_error "--output にはファイルパスが必要です"; exit 1; }
                REPORT_FILE="$2"
                shift 2
                ;;
            http://*|https://*)
                validate_url "$1"
                shift
                ;;
            *)
                log_error "不明な引数: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    if [[ -z "$TARGET_URL" ]]; then
        log_error "診断対象URLを指定してください"
        show_usage
        exit 1
    fi
}

# ===== チェック結果記録ヘルパー =====
# check_pass LABEL POINT "説明"
check_pass() {
    local label="$1" point="${2:-10}" desc="$3"
    SCORE=$(( SCORE + point ))
    MAX_SCORE=$(( MAX_SCORE + point ))
    PASSES+=( "$(printf '[PASS +%2d] %-38s %s' "$point" "$label" "$desc")" )
    echo -e "  ${C_GREEN}✅ PASS${C_RESET}  ${C_BOLD}${label}${C_RESET}  ${C_DIM}${desc}${C_RESET}"
}

# check_fail LABEL POINT "説明"
check_fail() {
    local label="$1" point="${2:-10}" desc="$3"
    MAX_SCORE=$(( MAX_SCORE + point ))
    FINDINGS+=( "$(printf '[FAIL  -%d] %-38s %s' "$point" "$label" "$desc")" )
    echo -e "  ${C_RED}❌ FAIL${C_RESET}  ${C_BOLD}${label}${C_RESET}  ${C_DIM}${desc}${C_RESET}"
}

# check_warn LABEL "説明"
check_warn() {
    local label="$1" desc="$2"
    WARNINGS+=( "$(printf '[WARN     ] %-38s %s' "$label" "$desc")" )
    echo -e "  ${C_YELLOW}⚠️  WARN${C_RESET}  ${C_BOLD}${label}${C_RESET}  ${C_DIM}${desc}${C_RESET}"
}

# ===== セキュリティヘッダーチェック =====

check_https_redirect() {
    echo -e "\n${C_BOLD}  [1] HTTP → HTTPS リダイレクト${C_RESET}"
    local http_url="http://${TARGET_HOST}/"
    local location
    location=$(curl -s -m "$CURL_TIMEOUT" --max-redirs 0 -D - -o /dev/null "$http_url" 2>/dev/null \
        | grep -i '^location:' | tr -d '\r' | sed 's/^[Ll]ocation: //' || echo "")

    if [[ "$location" =~ ^https:// ]]; then
        check_pass "HTTPS Redirect" 10 "http:// → https:// へリダイレクトされています"
    else
        check_fail "HTTPS Redirect" 10 "HTTP からの自動リダイレクトがありません (location: ${location:-なし})"
    fi
}

check_hsts() {
    local headers="$1"
    echo -e "\n${C_BOLD}  [2] HSTS (Strict-Transport-Security)${C_RESET}"
    local hsts
    hsts=$(echo "$headers" | grep -i '^strict-transport-security:' | tr -d '\r' || echo "")

    if [[ -n "$hsts" ]]; then
        local max_age
        max_age=$(echo "$hsts" | grep -oP 'max-age=\K[0-9]+' || echo "0")
        if [[ "$max_age" -ge 31536000 ]]; then
            check_pass "HSTS" 10 "max-age=${max_age} (1年以上)"
        else
            check_warn "HSTS" "max-age=${max_age} が短すぎます (推奨: 31536000以上)"
        fi
        # includeSubDomains / preload チェック
        if echo "$hsts" | grep -qi 'includeSubDomains'; then
            check_pass "HSTS includeSubDomains" 5 "サブドメインにも適用されています"
        else
            check_warn "HSTS includeSubDomains" "includeSubDomains が未設定"
        fi
    else
        check_fail "HSTS" 10 "Strict-Transport-Security ヘッダーがありません"
    fi
}

check_csp() {
    local headers="$1"
    echo -e "\n${C_BOLD}  [3] Content-Security-Policy (CSP)${C_RESET}"
    local csp
    csp=$(echo "$headers" | grep -i '^content-security-policy:' | tr -d '\r' || echo "")

    if [[ -n "$csp" ]]; then
        # unsafe-inline / unsafe-eval の検出
        if echo "$csp" | grep -q "'unsafe-inline'"; then
            check_warn "CSP unsafe-inline" "'unsafe-inline' が含まれています（XSSリスク）"
        fi
        if echo "$csp" | grep -q "'unsafe-eval'"; then
            check_warn "CSP unsafe-eval" "'unsafe-eval' が含まれています（XSSリスク）"
        fi
        check_pass "CSP" 15 "Content-Security-Policy が設定されています"
    else
        check_fail "CSP" 15 "Content-Security-Policy ヘッダーがありません（XSS対策なし）"
    fi
}

check_x_frame_options() {
    local headers="$1"
    echo -e "\n${C_BOLD}  [4] X-Frame-Options${C_RESET}"
    local val
    val=$(echo "$headers" | grep -i '^x-frame-options:' | tr -d '\r' | sed 's/^[^:]*: //' || echo "")

    if [[ -n "$val" ]]; then
        case "${val^^}" in
            DENY|SAMEORIGIN) check_pass "X-Frame-Options" 10 "${val} (クリックジャッキング対策済み)" ;;
            *)               check_warn "X-Frame-Options" "値が不適切: ${val}" ;;
        esac
    else
        check_fail "X-Frame-Options" 10 "X-Frame-Options がありません（クリックジャッキングリスク）"
    fi
}

check_x_content_type() {
    local headers="$1"
    echo -e "\n${C_BOLD}  [5] X-Content-Type-Options${C_RESET}"
    local val
    val=$(echo "$headers" | grep -i '^x-content-type-options:' | tr -d '\r' | sed 's/^[^:]*: //' || echo "")

    if [[ "${val,,}" == "nosniff" ]]; then
        check_pass "X-Content-Type-Options" 5 "nosniff (MIMEスニッフィング防止)"
    else
        check_fail "X-Content-Type-Options" 5 "nosniff が設定されていません"
    fi
}

check_referrer_policy() {
    local headers="$1"
    echo -e "\n${C_BOLD}  [6] Referrer-Policy${C_RESET}"
    local val
    val=$(echo "$headers" | grep -i '^referrer-policy:' | tr -d '\r' | sed 's/^[^:]*: //' || echo "")
    local safe_policies=("no-referrer" "no-referrer-when-downgrade" "strict-origin" "strict-origin-when-cross-origin")

    if [[ -n "$val" ]]; then
        local safe=false
        for p in "${safe_policies[@]}"; do
            [[ "${val,,}" == "$p" ]] && safe=true && break
        done
        if $safe; then
            check_pass "Referrer-Policy" 5 "${val}"
        else
            check_warn "Referrer-Policy" "値を確認してください: ${val}"
        fi
    else
        check_warn "Referrer-Policy" "Referrer-Policy が未設定（ブラウザデフォルト動作）"
    fi
}

check_permissions_policy() {
    local headers="$1"
    echo -e "\n${C_BOLD}  [7] Permissions-Policy${C_RESET}"
    local val
    val=$(echo "$headers" | grep -i '^permissions-policy:' | tr -d '\r' || echo "")

    if [[ -n "$val" ]]; then
        check_pass "Permissions-Policy" 5 "ブラウザAPI権限が制限されています"
    else
        check_warn "Permissions-Policy" "Permissions-Policy が未設定"
    fi
}

check_server_header() {
    local headers="$1"
    echo -e "\n${C_BOLD}  [8] Server ヘッダー情報漏洩${C_RESET}"
    local val
    val=$(echo "$headers" | grep -i '^server:' | tr -d '\r' | sed 's/^[^:]*: //' || echo "")

    if [[ -z "$val" ]]; then
        check_pass "Server Header" 5 "Server ヘッダーが非公開"
    elif echo "$val" | grep -qiP '(apache|nginx|iis|php|version|[0-9]+\.[0-9]+)'; then
        check_fail "Server Header" 5 "バージョン情報が露出: ${val}"
    else
        check_warn "Server Header" "Server ヘッダーが公開: ${val}"
    fi
}

check_x_powered_by() {
    local headers="$1"
    echo -e "\n${C_BOLD}  [9] X-Powered-By 情報漏洩${C_RESET}"
    local val
    val=$(echo "$headers" | grep -i '^x-powered-by:' | tr -d '\r' | sed 's/^[^:]*: //' || echo "")

    if [[ -z "$val" ]]; then
        check_pass "X-Powered-By" 5 "X-Powered-By ヘッダーが非公開"
    else
        check_fail "X-Powered-By" 5 "技術スタックが露出: ${val}"
    fi
}

check_cookies() {
    local headers="$1"
    echo -e "\n${C_BOLD}  [10] Cookie セキュリティ属性${C_RESET}"
    local cookies
    cookies=$(echo "$headers" | grep -i '^set-cookie:' | tr -d '\r' || echo "")

    if [[ -z "$cookies" ]]; then
        echo -e "  ${C_DIM}  Set-Cookie ヘッダーなし（スキップ）${C_RESET}"
        return
    fi

    local all_secure=true all_httponly=true all_samesite=true
    while IFS= read -r cookie; do
        [[ -z "$cookie" ]] && continue
        echo -e "  ${C_DIM}  Cookie: ${cookie:0:80}...${C_RESET}"
        echo "$cookie" | grep -qi 'secure'   || all_secure=false
        echo "$cookie" | grep -qi 'httponly' || all_httponly=false
        echo "$cookie" | grep -qi 'samesite' || all_samesite=false
    done <<< "$cookies"

    $all_secure   && check_pass "Cookie Secure"   5 "全 Cookie に Secure 属性あり" \
                  || check_fail "Cookie Secure"   5 "Secure 属性が欠落している Cookie があります"
    $all_httponly && check_pass "Cookie HttpOnly" 5 "全 Cookie に HttpOnly 属性あり" \
                  || check_fail "Cookie HttpOnly" 5 "HttpOnly 属性が欠落している Cookie があります"
    $all_samesite && check_pass "Cookie SameSite" 5 "全 Cookie に SameSite 属性あり" \
                  || check_warn "Cookie SameSite"   "SameSite 属性が欠落している Cookie があります"
}

run_header_checks() {
    local headers="$1"
    check_https_redirect
    check_hsts          "$headers"
    check_csp           "$headers"
    check_x_frame_options "$headers"
    check_x_content_type  "$headers"
    check_referrer_policy "$headers"
    check_permissions_policy "$headers"
    check_server_header   "$headers"
    check_x_powered_by    "$headers"
    check_cookies         "$headers"
}

# ===== SSL/TLS チェック =====

check_ssl() {
    echo -e "\n${C_BOLD}  ── SSL/TLS 診断 ──────────────────────────────────${C_RESET}"

    # openssl が使えるか確認
    if ! command -v openssl &>/dev/null; then
        check_warn "SSL/TLS" "openssl コマンドが見つかりません（スキップ）"
        return
    fi

    local port=443
    local conn_result
    conn_result=$(echo | openssl s_client -connect "${TARGET_HOST}:${port}" \
        -servername "$TARGET_HOST" 2>/dev/null || echo "CONNECTION_FAILED")

    if echo "$conn_result" | grep -q "CONNECTION_FAILED\|connect:errno"; then
        check_warn "SSL接続" "ポート443へ接続できませんでした"
        return
    fi

    # 証明書有効期限
    echo -e "\n${C_BOLD}  [11] SSL証明書 有効期限${C_RESET}"
    local expiry_str
    expiry_str=$(echo "$conn_result" | openssl x509 -noout -enddate 2>/dev/null \
        | sed 's/notAfter=//' || echo "")
    if [[ -n "$expiry_str" ]]; then
        local expiry_epoch today_epoch days_left
        expiry_epoch=$(date -d "$expiry_str" +%s 2>/dev/null || echo "0")
        today_epoch=$(date +%s)
        days_left=$(( (expiry_epoch - today_epoch) / 86400 ))

        if [[ $days_left -le 0 ]]; then
            check_fail "証明書有効期限" 15 "証明書が失効しています！ (${expiry_str})"
        elif [[ $days_left -le 30 ]]; then
            check_warn "証明書有効期限" "あと ${days_left} 日で失効 (${expiry_str})"
        else
            check_pass "証明書有効期限" 15 "あと ${days_left} 日 (${expiry_str})"
        fi
    fi

    # 証明書のCN/SANとホスト名の一致確認
    echo -e "\n${C_BOLD}  [12] 証明書ホスト名一致${C_RESET}"
    local cn
    cn=$(echo "$conn_result" | openssl x509 -noout -subject 2>/dev/null \
        | grep -oP 'CN\s*=\s*\K[^,/]+' || echo "")
    local san
    san=$(echo "$conn_result" | openssl x509 -noout -text 2>/dev/null \
        | grep -A1 'Subject Alternative Name' | tail -1 || echo "")

    if echo "$cn $san" | grep -q "$TARGET_HOST"; then
        check_pass "証明書ホスト名" 10 "CN/SAN にホスト名が含まれています"
    else
        check_fail "証明書ホスト名" 10 "証明書のホスト名が一致しません (CN: ${cn})"
    fi

    # TLS 1.0 / 1.1 の無効化確認
    echo -e "\n${C_BOLD}  [13] 旧TLSバージョン (1.0/1.1) の無効化${C_RESET}"
    local tls10_open=false tls11_open=false
    echo | openssl s_client -connect "${TARGET_HOST}:${port}" \
        -servername "$TARGET_HOST" -tls1 2>&1 | grep -q "Cipher\|CONNECTED" \
        && tls10_open=true || true
    echo | openssl s_client -connect "${TARGET_HOST}:${port}" \
        -servername "$TARGET_HOST" -tls1_1 2>&1 | grep -q "Cipher\|CONNECTED" \
        && tls11_open=true || true

    if $tls10_open; then
        check_fail "TLS 1.0" 10 "TLS 1.0 が有効です（脆弱なバージョン）"
    else
        check_pass "TLS 1.0 無効" 10 "TLS 1.0 は無効化されています"
    fi
    if $tls11_open; then
        check_fail "TLS 1.1" 5 "TLS 1.1 が有効です（非推奨バージョン）"
    else
        check_pass "TLS 1.1 無効" 5 "TLS 1.1 は無効化されています"
    fi
}

# ===== 追加チェック =====

check_additional() {
    echo -e "\n${C_BOLD}  ── 追加診断 ──────────────────────────────────────${C_RESET}"

    # security.txt の存在確認
    echo -e "\n${C_BOLD}  [14] security.txt${C_RESET}"
    local sec_url="${TARGET_URL%/}/.well-known/security.txt"
    local status
    status=$(curl -s -o /dev/null -w "%{http_code}" -m "$CURL_TIMEOUT" "$sec_url" 2>/dev/null || echo "000")
    if [[ "$status" == "200" ]]; then
        check_pass "security.txt" 5 "/.well-known/security.txt が存在します"
    else
        check_warn "security.txt" "/.well-known/security.txt がありません (HTTP ${status})"
    fi

    # robots.txt 確認（ステルス情報漏洩）
    echo -e "\n${C_BOLD}  [15] robots.txt 内のパス漏洩${C_RESET}"
    local robots_url="${TARGET_URL%/}/robots.txt"
    local robots_content
    robots_content=$(curl -s -m "$CURL_TIMEOUT" "$robots_url" 2>/dev/null || echo "")
    if echo "$robots_content" | grep -qiP '(admin|backup|config|secret|internal|api/v[0-9])'; then
        check_warn "robots.txt" "機密パスが robots.txt に記載されている可能性があります"
    else
        check_pass "robots.txt" 5 "機密パスの露出は検出されませんでした"
    fi
}

# ===== レポート生成 =====

show_report() {
    local grade
    local pct=0
    [[ $MAX_SCORE -gt 0 ]] && pct=$(( SCORE * 100 / MAX_SCORE ))

    if    [[ $pct -ge 90 ]]; then grade="A"
    elif  [[ $pct -ge 75 ]]; then grade="B"
    elif  [[ $pct -ge 60 ]]; then grade="C"
    elif  [[ $pct -ge 40 ]]; then grade="D"
    else                           grade="F"
    fi

    local grade_color="$C_RED"
    [[ "$grade" == "A" ]] && grade_color="${C_GREEN}${C_BOLD}"
    [[ "$grade" == "B" ]] && grade_color="${C_GREEN}"
    [[ "$grade" == "C" ]] && grade_color="${C_YELLOW}"

    # スコアバー（30文字幅）
    local bar_len=$(( pct * 30 / 100 ))
    local bar=""
    for (( i=0; i<bar_len; i++ ));    do bar="${bar}█"; done
    for (( i=bar_len; i<30; i++ ));   do bar="${bar}░"; done

    echo ""
    echo -e "${C_BOLD}${C_CYAN}  ╔══════════════════════════════════════════════════╗"
    echo -e "  ║           セキュリティ診断レポート               ║"
    echo -e "  ╚══════════════════════════════════════════════════╝${C_RESET}"
    echo ""
    echo -e "  対象: ${C_BOLD}${TARGET_URL}${C_RESET}"
    echo -e "  日時: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    echo -e "  スコア: ${C_BOLD}${SCORE} / ${MAX_SCORE}点${C_RESET}  (${pct}%)"
    echo -e "  ${bar} ${grade_color}${C_BOLD}[${grade}]${C_RESET}"
    echo ""

    if [[ ${#FINDINGS[@]} -gt 0 ]]; then
        echo -e "  ${C_RED}${C_BOLD}── 問題点 (${#FINDINGS[@]}件) ──────────────────────────${C_RESET}"
        for f in "${FINDINGS[@]}"; do
            echo -e "  ${C_RED}${f}${C_RESET}"
        done
        echo ""
    fi

    if [[ ${#WARNINGS[@]} -gt 0 ]]; then
        echo -e "  ${C_YELLOW}${C_BOLD}── 警告 (${#WARNINGS[@]}件) ───────────────────────────${C_RESET}"
        for w in "${WARNINGS[@]}"; do
            echo -e "  ${C_YELLOW}${w}${C_RESET}"
        done
        echo ""
    fi

    if [[ ${#PASSES[@]} -gt 0 ]]; then
        echo -e "  ${C_GREEN}${C_BOLD}── 合格 (${#PASSES[@]}件) ───────────────────────────${C_RESET}"
        for p in "${PASSES[@]}"; do
            echo -e "  ${C_GREEN}${p}${C_RESET}"
        done
        echo ""
    fi

    # ファイル出力
    if [[ -n "$REPORT_FILE" ]]; then
        {
            echo "セキュリティ診断レポート"
            echo "対象: ${TARGET_URL}"
            echo "日時: $(date '+%Y-%m-%d %H:%M:%S')"
            echo "スコア: ${SCORE} / ${MAX_SCORE}点 (${pct}%) [${grade}]"
            echo ""
            echo "=== 問題点 ==="
            for f in "${FINDINGS[@]}"; do echo "$f"; done
            echo ""
            echo "=== 警告 ==="
            for w in "${WARNINGS[@]}"; do echo "$w"; done
            echo ""
            echo "=== 合格 ==="
            for p in "${PASSES[@]}"; do echo "$p"; done
        } > "$REPORT_FILE"
        log_success "レポートを保存しました: ${REPORT_FILE}"
    fi
}

# ===== メイン =====

main() {
    parse_arguments "$@"
    confirm_authorization

    echo -e "\n${C_BOLD}${C_CYAN}  ── セキュリティ診断開始 ─────────────────────────${C_RESET}"
    echo -e "  対象: ${TARGET_URL}\n"

    # HTTPSヘッダーを取得（リダイレクト追跡あり）
    log_info "レスポンスヘッダーを取得中..."
    local headers
    headers=$(fetch_headers_follow "$TARGET_URL")

    echo -e "\n${C_BOLD}  ── HTTPセキュリティヘッダー診断 ──────────────────${C_RESET}"
    run_header_checks "$headers"

    check_ssl
    check_additional
    show_report
}

main "$@"
