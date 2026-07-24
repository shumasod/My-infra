#!/bin/bash
set -euo pipefail

#
# REST APIテストツール
# バージョン: 1.0
#
# REST APIエンドポイントへのリクエスト送信・レスポンス検証ツール
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare url=""
declare method="GET"
declare -a headers=()
declare data=""
declare data_file=""
declare -i timeout=30
declare output_mode="pretty"
declare -i expected_status=200
declare bearer_token=""
declare verbose=false
declare test_file=""

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション] <URL>
         $PROG_NAME --test-file <テストファイル>

REST API テストツール

引数:
  URL                   リクエスト先URL

オプション:
  -h, --help            このヘルプを表示
  -v, --version         バージョン情報を表示
  -X, --method METHOD   HTTPメソッド [デフォルト: GET]
  -H, --header KEY:VAL  ヘッダー追加 (複数可)
  -d, --data JSON       リクエストボディ
  -D, --data-file FILE  ボディをファイルから読み込む
  -t, --timeout SEC     タイムアウト秒 [デフォルト: 30]
  -T, --token TOKEN     Bearer認証トークン
  -e, --expect CODE     期待するHTTPステータスコード [デフォルト: 200]
  -o, --output MODE     出力形式 (pretty|raw|headers) [デフォルト: pretty]
  --test-file FILE      テストケースファイルを実行
  --verbose             詳細出力

例:
  $PROG_NAME https://api.example.com/users
  $PROG_NAME -X POST -d '{"name":"test"}' https://api.example.com/users
  $PROG_NAME -T mytoken -e 201 -X POST -d @body.json https://api.example.com/items

EOF
}

build_curl_args() {
    local -a args=(-s -w "\n%{http_code}\n%{time_total}\n%{size_download}")
    args+=(-X "$method")
    args+=(--max-time "$timeout")

    args+=(-H "Accept: application/json")
    if [[ -n "$bearer_token" ]]; then
        args+=(-H "Authorization: Bearer $bearer_token")
    fi

    for h in "${headers[@]}"; do
        args+=(-H "$h")
    done

    if [[ -n "$data" ]]; then
        args+=(-H "Content-Type: application/json")
        args+=(-d "$data")
    elif [[ -n "$data_file" ]]; then
        args+=(-H "Content-Type: application/json")
        args+=(-d "@${data_file}")
    fi

    [[ "$verbose" == true ]] && args+=(-v)

    echo "${args[@]}"
}

do_request() {
    local req_url="$1"

    local curl_args
    read -ra curl_args <<< "$(build_curl_args)"

    log_info "${method} ${req_url}"
    echo ""

    local response http_code time_total size
    local tmpfile
    tmpfile=$(mktemp)

    curl "${curl_args[@]}" "$req_url" > "$tmpfile" 2>/dev/null || {
        log_error "接続失敗: $req_url"
        rm -f "$tmpfile"
        return 1
    }

    local line_count
    line_count=$(wc -l < "$tmpfile")
    http_code=$(tail -3 "$tmpfile" | head -1 | tr -d '\r\n')
    time_total=$(tail -2 "$tmpfile" | head -1 | tr -d '\r\n')
    size=$(tail -1 "$tmpfile" | tr -d '\r\n')
    response=$(head -n $(( line_count - 3 )) "$tmpfile")
    rm -f "$tmpfile"

    local status_color
    if   [[ "$http_code" =~ ^2 ]]; then status_color="$C_GREEN"
    elif [[ "$http_code" =~ ^3 ]]; then status_color="$C_YELLOW"
    elif [[ "$http_code" =~ ^4 ]]; then status_color="$C_RED"
    else                                  status_color="$C_RED"
    fi

    printf "  ステータス: %b%s%b  時間: %ss  サイズ: %s bytes\n" \
        "$status_color" "$http_code" "$C_RESET" "$time_total" "$size"

    local pass=false
    [[ "$http_code" == "$expected_status" ]] && pass=true

    if [[ "$pass" == true ]]; then
        log_success "テスト PASS (期待: $expected_status)"
    else
        log_error "テスト FAIL (期待: $expected_status, 実際: $http_code)"
    fi

    echo ""
    case "$output_mode" in
        pretty)
            if command -v jq &>/dev/null && echo "$response" | jq . &>/dev/null 2>&1; then
                echo "$response" | jq .
            else
                echo "$response"
            fi
            ;;
        raw)     echo "$response" ;;
        headers) ;;
    esac

    [[ "$pass" == true ]]
}

run_test_file() {
    [[ ! -f "$test_file" ]] && error_exit "テストファイルが見つかりません: $test_file"

    log_info "テストスイート実行: $test_file"
    echo ""

    local -i pass_count=0
    local -i fail_count=0
    local -i test_num=0

    while IFS= read -r line; do
        [[ -z "$line" || "$line" == \#* ]] && continue
        (( test_num++ )) || true

        local req_method req_url req_expect req_data
        req_method=$(echo "$line" | awk '{print $1}')
        req_url=$(echo "$line" | awk '{print $2}')
        req_expect=$(echo "$line" | awk '{print $3}')
        req_data=$(echo "$line" | cut -d' ' -f4-)

        method="$req_method"
        expected_status="${req_expect:-200}"
        data="${req_data:-}"

        printf "  [%d] %s %s (期待: %s)\n" "$test_num" "$req_method" "$req_url" "$expected_status"
        if do_request "$req_url" 2>/dev/null; then
            (( pass_count++ )) || true
        else
            (( fail_count++ )) || true
        fi
    done < "$test_file"

    echo ""
    echo -e "${C_CYAN}テスト結果: ${C_GREEN}PASS ${pass_count}${C_RESET} / ${C_RED}FAIL ${fail_count}${C_RESET} (計 ${test_num})"
    echo ""
    [[ $fail_count -eq 0 ]]
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -X|--method)  [[ $# -lt 2 ]] && error_exit "--method には値が必要です"; method="${2^^}"; shift 2 ;;
            -H|--header)  [[ $# -lt 2 ]] && error_exit "--header には値が必要です"; headers+=("$2"); shift 2 ;;
            -d|--data)    [[ $# -lt 2 ]] && error_exit "--data には値が必要です"; data="$2"; shift 2 ;;
            -D|--data-file) [[ $# -lt 2 ]] && error_exit "--data-file には値が必要です"; data_file="$2"; shift 2 ;;
            -t|--timeout) [[ $# -lt 2 ]] && error_exit "--timeout には数値が必要です"; timeout="$2"; shift 2 ;;
            -T|--token)   [[ $# -lt 2 ]] && error_exit "--token には値が必要です"; bearer_token="$2"; shift 2 ;;
            -e|--expect)  [[ $# -lt 2 ]] && error_exit "--expect には数値が必要です"; expected_status="$2"; shift 2 ;;
            -o|--output)  [[ $# -lt 2 ]] && error_exit "--output には値が必要です"; output_mode="$2"; shift 2 ;;
            --test-file)  [[ $# -lt 2 ]] && error_exit "--test-file には値が必要です"; test_file="$2"; shift 2 ;;
            --verbose)    verbose=true; shift ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  url="$1"; shift ;;
        esac
    done
}

main() {
    parse_arguments "$@"

    if [[ -n "$test_file" ]]; then
        run_test_file
    elif [[ -n "$url" ]]; then
        do_request "$url"
    else
        error_exit "URLまたは --test-file を指定してください"
    fi
}

main "$@"
