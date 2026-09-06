#!/bin/bash
set -euo pipefail

#
# URLチェッカー
# 作成日: 2026-07-14
# バージョン: 1.0
#
# 複数URLのHTTPステータスコード・レスポンスタイムを一括チェックする
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare -i TIMEOUT=10
declare -i PARALLEL=5
declare OUTPUT_FILE=""
declare -i VERBOSE=0

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション] [URL...]

URLのHTTPステータスと応答時間を確認します。

引数:
  [URL...]           チェックするURL（複数可）

オプション:
  -h, --help         このヘルプを表示
  -v, --version      バージョン情報を表示
  -f, --file FILE    URLリストファイルを読み込む
  -t, --timeout N    タイムアウト秒（デフォルト: 10）
  -o, --output FILE  結果をCSVで保存
  --verbose          詳細情報を表示

例:
  $PROG_NAME https://example.com https://google.com
  $PROG_NAME -f urls.txt -o result.csv
  $PROG_NAME --timeout 5 https://example.com
EOF
}

check_url() {
    local url="$1"
    local start_ts end_ts elapsed status size redirect

    start_ts=$(date +%s%N 2>/dev/null || date +%s)

    local curl_out
    curl_out=$(curl -s -o /dev/null \
        --max-time "$TIMEOUT" \
        --connect-timeout 5 \
        -w "%{http_code}|%{size_download}|%{redirect_url}" \
        "$url" 2>/dev/null) || curl_out="000||"

    end_ts=$(date +%s%N 2>/dev/null || date +%s)

    IFS='|' read -r status size redirect <<< "$curl_out"
    status="${status:-000}"
    size="${size:-0}"

    if [[ "$end_ts" =~ [0-9]{10,} ]]; then
        elapsed=$(( (end_ts - start_ts) / 1000000 ))
    else
        elapsed=$(( (end_ts - start_ts) * 1000 ))
    fi

    echo "${url}|${status}|${elapsed}|${size}|${redirect}"
}

status_color() {
    local status="$1"
    local code="${status:0:1}"
    case "$code" in
        2) echo "$C_GREEN" ;;
        3) echo "$C_CYAN" ;;
        4) echo "$C_YELLOW" ;;
        5) echo "$C_RED" ;;
        *) echo "$C_DIM" ;;
    esac
}

status_label() {
    local status="$1"
    case "$status" in
        200) echo "OK" ;;
        201) echo "Created" ;;
        301) echo "Moved" ;;
        302) echo "Found" ;;
        400) echo "Bad Req" ;;
        401) echo "Unauth" ;;
        403) echo "Forbidden" ;;
        404) echo "Not Found" ;;
        500) echo "Server Err" ;;
        502) echo "Bad Gateway" ;;
        503) echo "Unavailable" ;;
        000) echo "Timeout" ;;
        *)   echo "HTTP ${status}" ;;
    esac
}

format_size() {
    local bytes="$1"
    if (( bytes >= 1048576 )); then
        echo "$(( bytes / 1048576 ))MB"
    elif (( bytes >= 1024 )); then
        echo "$(( bytes / 1024 ))KB"
    else
        echo "${bytes}B"
    fi
}

format_time() {
    local ms="$1"
    if (( ms >= 1000 )); then
        printf "%.1fs" "$(echo "scale=1; $ms / 1000" | bc)"
    else
        echo "${ms}ms"
    fi
}

print_result_row() {
    local url="$1" status="$2" elapsed="$3" size="$4"

    local color
    color=$(status_color "$status")
    local label
    label=$(status_label "$status")
    local size_fmt
    size_fmt=$(format_size "$size")
    local time_fmt
    time_fmt=$(format_time "$elapsed")

    local short_url="$url"
    if (( ${#url} > 50 )); then
        short_url="${url:0:47}..."
    fi

    printf "  ${color}[%3s]${C_RESET} %-12s %-8s %-50s\n" \
        "$status" "$label" "$time_fmt" "$short_url"
}

main() {
    local urls=()
    local url_file=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -f|--file)
                [[ $# -lt 2 ]] && error_exit "--file にはファイル名が必要です"
                url_file="$2"; shift 2 ;;
            -t|--timeout)
                [[ $# -lt 2 ]] && error_exit "--timeout には秒数が必要です"
                TIMEOUT="$2"; shift 2 ;;
            -o|--output)
                [[ $# -lt 2 ]] && error_exit "--output にはファイル名が必要です"
                OUTPUT_FILE="$2"; shift 2 ;;
            --verbose)    VERBOSE=1; shift ;;
            http*|ftp*)   urls+=("$1"); shift ;;
            -*)           error_exit "不明なオプション: $1" ;;
            *)            error_exit "URLはhttp://またはhttps://で始めてください: $1" ;;
        esac
    done

    if [[ -n "$url_file" ]]; then
        if [[ ! -f "$url_file" ]]; then
            error_exit "ファイルが見つかりません: $url_file"
        fi
        while IFS= read -r line; do
            line="${line%%#*}"
            line="${line#"${line%%[![:space:]]*}"}"
            line="${line%"${line##*[![:space:]]}"}"
            [[ -n "$line" ]] && urls+=("$line")
        done < "$url_file"
    fi

    if [[ ${#urls[@]} -eq 0 ]]; then
        echo -n "チェックするURLを入力（空行で終了）: "
        while IFS= read -r line; do
            [[ -z "$line" ]] && break
            urls+=("$line")
            echo -n "URL: "
        done
    fi

    [[ ${#urls[@]} -eq 0 ]] && error_exit "URLが指定されていません"

    echo ""
    print_center "URL チェッカー" 0 "${C_BOLD}${C_CYAN}"
    print_center "$(get_timestamp)  タイムアウト: ${TIMEOUT}s" 0 "$C_DIM"
    echo ""

    printf "  ${C_BOLD}%-6s %-12s %-8s %-50s${C_RESET}\n" "STATUS" "LABEL" "TIME" "URL"
    echo -e "  ${C_DIM}$(printf '%.0s─' {1..75})${C_RESET}"

    local -i ok=0 warn=0 err=0
    local csv_rows=()

    if [[ -n "$OUTPUT_FILE" ]]; then
        echo "URL,Status,Label,Time(ms),Size(bytes),Redirect" > "$OUTPUT_FILE"
    fi

    for url in "${urls[@]}"; do
        local result
        result=$(check_url "$url")
        IFS='|' read -r r_url r_status r_elapsed r_size r_redirect <<< "$result"

        print_result_row "$r_url" "$r_status" "$r_elapsed" "$r_size"

        local code="${r_status:0:1}"
        case "$code" in
            2)   (( ok++ )) ;;
            3|4) (( warn++ )) ;;
            *)   (( err++ )) ;;
        esac

        if [[ -n "$OUTPUT_FILE" ]]; then
            printf '"%s",%s,"%s",%s,%s,"%s"\n' \
                "$r_url" "$r_status" "$(status_label "$r_status")" \
                "$r_elapsed" "$r_size" "${r_redirect:-}" >> "$OUTPUT_FILE"
        fi

        if (( VERBOSE == 1 )) && [[ -n "$r_redirect" ]]; then
            echo -e "    ${C_DIM}→ リダイレクト: $r_redirect${C_RESET}"
        fi
    done

    echo ""
    echo -e "  ${C_DIM}$(printf '%.0s─' {1..50})${C_RESET}"
    echo ""
    printf "  合計: %d  ${C_GREEN}OK: %d${C_RESET}  ${C_YELLOW}警告: %d${C_RESET}  ${C_RED}エラー: %d${C_RESET}\n" \
        "${#urls[@]}" "$ok" "$warn" "$err"
    echo ""

    if [[ -n "$OUTPUT_FILE" ]]; then
        log_success "結果を保存: $OUTPUT_FILE"
    fi

    (( err == 0 )) && exit 0 || exit 1
}

main "$@"
