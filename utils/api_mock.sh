#!/bin/bash
set -euo pipefail

#
# シンプルAPIモックサーバー
# 作成日: 2026-07-31
# バージョン: 1.0
#
# テスト用の簡易HTTPモックサーバーをシェルスクリプトで実装します
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare command_name="start"
declare server_port=8080
declare config_file=""
declare log_file=""
declare daemon_mode=false
declare response_delay=0

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション]

テスト用シンプルAPIモックサーバーです。

コマンド:
  start                  モックサーバーを起動 (デフォルト)
  config <ファイル>      設定ファイルから起動
  generate               設定ファイルのサンプルを生成
  test <URL>             サーバーの動作確認

オプション:
  -h, --help             このヘルプを表示
  -v, --version          バージョン情報を表示
  -p, --port <ポート>    リッスンポート [デフォルト: 8080]
  -c, --config <ファイル> 設定ファイル
  -l, --log <ファイル>   ログファイル
  -d, --delay <ミリ秒>   レスポンス遅延 [デフォルト: 0]
  --daemon               バックグラウンドで起動

例:
  $PROG_NAME start -p 3000
  $PROG_NAME config mock.conf -p 8080
  $PROG_NAME generate > mock.conf
  $PROG_NAME test http://localhost:8080/api/users
EOF
}

# デフォルトのモックレスポンスマップ
declare -A mock_routes

setup_default_routes() {
    mock_routes["GET /"]='{"status":"ok","service":"mock-api","version":"1.0"}'
    mock_routes["GET /health"]='{"healthy":true,"timestamp":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'"}'
    mock_routes["GET /api/users"]='[{"id":1,"name":"Alice","email":"alice@example.com"},{"id":2,"name":"Bob","email":"bob@example.com"}]'
    mock_routes["GET /api/users/1"]='{"id":1,"name":"Alice","email":"alice@example.com","role":"admin"}'
    mock_routes["GET /api/users/2"]='{"id":2,"name":"Bob","email":"bob@example.com","role":"user"}'
    mock_routes["POST /api/users"]='{"id":3,"message":"ユーザーを作成しました","created":true}'
    mock_routes["PUT /api/users/1"]='{"id":1,"message":"ユーザーを更新しました","updated":true}'
    mock_routes["DELETE /api/users/1"]='{"message":"ユーザーを削除しました","deleted":true}'
    mock_routes["GET /api/products"]='[{"id":1,"name":"商品A","price":1000},{"id":2,"name":"商品B","price":2000}]'
    mock_routes["GET /api/error"]='{"error":"Internal Server Error","code":500}'
    mock_routes["GET /api/slow"]='{"message":"これは遅いレスポンスです","delay":"2s"}'
}

load_config() {
    local file="$1"
    [[ ! -f "$file" ]] && error_exit "設定ファイルが見つかりません: $file"

    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" || "$line" =~ ^# ]] && continue
        if [[ "$line" =~ ^([A-Z]+)[[:space:]]+(/[^[:space:]]*)[[:space:]]+(.*) ]]; then
            local method="${BASH_REMATCH[1]}"
            local path="${BASH_REMATCH[2]}"
            local response="${BASH_REMATCH[3]}"
            mock_routes["$method $path"]="$response"
        fi
    done < "$file"
}

handle_request() {
    local request="$1"
    local method path http_ver
    read -r method path http_ver <<< "$request"

    local key="$method $path"
    local response_body status_code content_type

    # ルートマッチング
    if [[ -n "${mock_routes[$key]:-}" ]]; then
        response_body="${mock_routes[$key]}"
        status_code="200 OK"
        content_type="application/json"
    elif [[ "$path" =~ ^/api/ ]]; then
        response_body='{"error":"Not Found","path":"'"$path"'"}'
        status_code="404 Not Found"
        content_type="application/json"
    elif [[ "$method" == "GET" && "$path" == "/" ]]; then
        response_body='{"status":"ok"}'
        status_code="200 OK"
        content_type="application/json"
    else
        response_body='{"error":"Not Found"}'
        status_code="404 Not Found"
        content_type="application/json"
    fi

    # エラーエンドポイント
    [[ "$path" == "/api/error" ]] && status_code="500 Internal Server Error"

    # 遅延
    if [[ $response_delay -gt 0 ]]; then
        sleep "$(echo "scale=3; $response_delay/1000" | bc 2>/dev/null || echo 0)"
    elif [[ "$path" == "/api/slow" ]]; then
        sleep 2
    fi

    local body_len=${#response_body}
    local timestamp
    timestamp=$(date -u +"%a, %d %b %Y %H:%M:%S GMT")

    printf "HTTP/1.1 %s\r\n" "$status_code"
    printf "Content-Type: %s; charset=utf-8\r\n" "$content_type"
    printf "Content-Length: %d\r\n" "$body_len"
    printf "Access-Control-Allow-Origin: *\r\n"
    printf "Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS\r\n"
    printf "Access-Control-Allow-Headers: Content-Type, Authorization\r\n"
    printf "Date: %s\r\n" "$timestamp"
    printf "X-Mock-Server: %s v%s\r\n" "$PROG_NAME" "$VERSION"
    printf "\r\n"
    printf "%s" "$response_body"

    local log_line
    log_line="$(date '+%Y-%m-%d %H:%M:%S') $method $path -> $status_code (${body_len}B)"
    echo "$log_line" >&2
    if [[ -n "$log_file" ]]; then
        echo "$log_line" >> "$log_file"
    fi
}

cmd_start() {
    setup_default_routes
    [[ -n "$config_file" ]] && load_config "$config_file"

    log_success "APIモックサーバーを起動しました"
    printf "  ポート  : ${C_CYAN}%d${C_RESET}\n" "$server_port"
    printf "  URL     : ${C_CYAN}http://localhost:%d${C_RESET}\n" "$server_port"
    printf "  ルート数: ${C_GREEN}%d${C_RESET}\n" "${#mock_routes[@]}"
    echo ""
    printf "${C_BOLD}【登録済みルート】${C_RESET}\n"
    for route in $(echo "${!mock_routes[@]}" | tr ' ' '\n' | sort); do
        printf "  ${C_DIM}%s${C_RESET}\n" "$route"
    done
    echo ""
    log_info "Ctrl+C で停止します"
    echo ""

    # ポートチェック
    if command -v nc &>/dev/null; then
        while true; do
            nc -l -p "$server_port" 2>/dev/null | {
                local request_line=""
                while IFS= read -r line; do
                    line="${line%$'\r'}"
                    [[ -z "$line" ]] && break
                    [[ -z "$request_line" ]] && request_line="$line"
                done
                [[ -n "$request_line" ]] && handle_request "$request_line"
            }
        done
    elif command -v socat &>/dev/null; then
        log_info "socat を使用してサーバーを起動..."
        socat TCP-LISTEN:${server_port},reuseaddr,fork EXEC:"bash -c 'source \"${BASH_SOURCE[0]}\"; handle_request'" 2>/dev/null || \
        error_exit "socat でのサーバー起動に失敗しました"
    else
        error_exit "nc または socat が必要です: apt install netcat または apt install socat"
    fi
}

cmd_generate() {
    cat <<'EOF'
# APIモック設定ファイル
# 書式: <メソッド> <パス> <JSONレスポンス>

# ヘルスチェック
GET /health {"status":"healthy","version":"1.0"}

# ユーザーAPI
GET /api/v1/users [{"id":1,"name":"Alice"},{"id":2,"name":"Bob"}]
GET /api/v1/users/1 {"id":1,"name":"Alice","email":"alice@example.com"}
POST /api/v1/users {"id":3,"created":true,"message":"作成しました"}
PUT /api/v1/users/1 {"id":1,"updated":true,"message":"更新しました"}
DELETE /api/v1/users/1 {"deleted":true,"message":"削除しました"}

# 商品API
GET /api/v1/products [{"id":1,"name":"商品A","price":1000},{"id":2,"name":"商品B","price":2500}]
GET /api/v1/products/1 {"id":1,"name":"商品A","price":1000,"stock":50}

# エラーレスポンス例
GET /api/v1/error {"error":"Internal Server Error","code":500}
EOF
}

cmd_test() {
    local url="${ARGS[0]:-http://localhost:$server_port}"

    log_info "モックサーバーのテスト: $url"
    echo ""

    local endpoints=("/" "/health" "/api/users" "/api/users/1" "/api/products")

    for ep in "${endpoints[@]}"; do
        local full_url="${url%/}${ep}"
        local status body
        if command -v curl &>/dev/null; then
            status=$(curl -s -o /tmp/mock_test_$$ -w "%{http_code}" "$full_url" 2>/dev/null || echo "000")
            body=$(cat /tmp/mock_test_$$ 2>/dev/null || echo "")
            rm -f /tmp/mock_test_$$
        else
            status="N/A"
            body=""
        fi

        local color="$C_GREEN"
        [[ "${status:-000}" != "200" ]] && color="$C_YELLOW"
        [[ "${status:-000}" == "000" ]] && color="$C_RED"

        printf "  ${color}%s${C_RESET} GET %s" "$status" "$ep"
        [[ -n "$body" ]] && printf " ${C_DIM}→ %s${C_RESET}" "${body:0:60}"
        echo ""
    done
    echo ""
}

declare -a ARGS=()

parse_arguments() {
    [[ $# -eq 0 ]] && return 0
    case "$1" in
        start|config|generate|test)
            command_name="$1"; shift ;;
    esac

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -p|--port)    [[ $# -lt 2 ]] && error_exit "--port には値が必要です"; server_port="$2"; shift 2 ;;
            -c|--config)  [[ $# -lt 2 ]] && error_exit "--config には値が必要です"; config_file="$2"; shift 2 ;;
            -l|--log)     [[ $# -lt 2 ]] && error_exit "--log には値が必要です"; log_file="$2"; shift 2 ;;
            -d|--delay)   [[ $# -lt 2 ]] && error_exit "--delay には値が必要です"; response_delay="$2"; shift 2 ;;
            --daemon)     daemon_mode=true; shift ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  ARGS+=("$1"); shift ;;
        esac
    done
}

main() {
    parse_arguments "$@"
    case "$command_name" in
        start)    cmd_start ;;
        config)
            config_file="${ARGS[0]:-}"
            [[ -z "$config_file" ]] && error_exit "設定ファイルを指定してください"
            cmd_start ;;
        generate) cmd_generate ;;
        test)     cmd_test ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
