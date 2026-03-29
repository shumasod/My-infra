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
