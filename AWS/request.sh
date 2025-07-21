#!/bin/bash

# リクエスト数計測・負荷テストスクリプト
# Usage: ./request_counter.sh [options] <URL>

set -euo pipefail

# 設定変数
SCRIPT_NAME=$(basename "$0")
URL=""
TOTAL_REQUESTS=100
CONCURRENT_REQUESTS=10
DELAY=0
TIMEOUT=30
METHOD="GET"
USER_AGENT="RequestCounter/1.0"
OUTPUT_DIR="./test_results"
REPORT_FILE=""
CSV_OUTPUT=false
JSON_OUTPUT=false
VERBOSE=false
QUIET=false
SHOW_PROGRESS=true
CUSTOM_HEADERS=""
POST_DATA=""
CONTENT_TYPE="application/json"

# 統計変数
TOTAL_SENT=0
TOTAL_SUCCESS=0
TOTAL_FAILED=0
TOTAL_TIME=0
MIN_TIME=999999
MAX_TIME=0
START_TIME=""
END_TIME=""
declare -a RESPONSE_TIMES=()
declare -A STATUS_CODES=()

# 色設定
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# 一時ファイル
TEMP_DIR=$(mktemp -d)
RESULTS_FILE="$TEMP_DIR/results.txt"
PIDS_FILE="$TEMP_DIR/pids.txt"

# クリーンアップ関数
cleanup() {
    if [ -f "$PIDS_FILE" ]; then
        while read -r pid; do
            kill "$pid" 2>/dev/null || true
        done < "$PIDS_FILE"
    fi
    rm -rf "$TEMP_DIR"
}

# シグナルハンドラー
trap cleanup EXIT INT TERM

# ログ関数
log_info() {
    if [ "$QUIET" = false ]; then
        echo -e "${BLUE}[INFO]${NC} $1" >&2
    fi
}

log_success() {
    if [ "$QUIET" = false ]; then
        echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
    fi
}

log_warning() {
    if [ "$QUIET" = false ]; then
        echo -e "${YELLOW}[WARNING]${NC} $1" >&2
    fi
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_verbose() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${CYAN}[DEBUG]${NC} $1" >&2
    fi
}

# ヘルプ表示
show_help() {
    cat << EOF
$SCRIPT_NAME - HTTPリクエスト数計測・負荷テストツール

使用方法:
    $SCRIPT_NAME [オプション] <URL>

オプション:
    -h, --help                このヘルプを表示
    -n, --requests NUM        総リクエスト数 (デフォルト: $TOTAL_REQUESTS)
    -c, --concurrent NUM      同時リクエスト数 (デフォルト: $CONCURRENT_REQUESTS)
    -d, --delay SECONDS       リクエスト間の遅延 (デフォルト: $DELAY秒)
    -t, --timeout SECONDS     タイムアウト時間 (デフォルト: $TIMEOUT秒)
    -m, --method METHOD       HTTPメソッド (GET|POST|PUT|DELETE) (デフォルト: $METHOD)
    -u, --user-agent STRING   カスタムUser-Agent
    -o, --output DIR          出力ディレクトリ (デフォルト: $OUTPUT_DIR)
    -r, --report FILE         レポートファイル名
    --csv                     CSV形式で結果を出力
    --json                    JSON形式で結果を出力
    -v, --verbose             詳細出力を有効にする
    -q, --quiet               静寂モード（エラーのみ表示）
    --no-progress             進捗表示を無効にする
    --header "Name: Value"    カスタムHTTPヘッダーを追加
    --data STRING             POSTデータ (POST/PUTの場合)
    --content-type TYPE       Content-Type (デフォルト: $CONTENT_TYPE)

例:
    $SCRIPT_NAME -n 1000 -c 20 https://example.com
    $SCRIPT_NAME -m POST --data '{"test":"data"}' https://api.example.com
    $SCRIPT_NAME --csv --json -v -n 500 https://example.com
    $SCRIPT_NAME --header "Authorization: Bearer token" https://secure.example.com
EOF
}

# 依存関係チェック
check_dependencies() {
    local missing_deps=()
    
    for cmd in curl bc jq; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "以下の依存関係が不足しています: ${missing_deps[*]}"
        log_info "インストール方法:"
        echo "  Ubuntu/Debian: sudo apt-get install curl bc jq"
        echo "  CentOS/RHEL: sudo yum install curl bc jq"
        echo "  macOS: brew install curl bc jq"
        exit 1
    fi
}

# 出力ディレクトリ準備
setup_output_dir() {
    if [ ! -d "$OUTPUT_DIR" ]; then
        mkdir -p "$OUTPUT_DIR"
        log_info "出力ディレクトリを作成しました: $OUTPUT_DIR"
    fi
}

# プログレスバー表示
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((current * width / total))
    local remaining=$((width - completed))
    
    printf "\r${BLUE}進捗:${NC} ["
    printf "%${completed}s" | tr ' ' '='
    printf "%${remaining}s" | tr ' ' '-'
    printf "] %d%% (%d/%d)" "$percentage" "$current" "$total"
}

# 単一リクエスト実行
make_single_request() {
    local request_id=$1
    local start_time_ns=$(date +%s%N)
    
    local curl_opts=(
        --silent
        --write-out "%{http_code}|%{time_total}|%{size_download}|%{url_effective}"
        --output /dev/null
        --connect-timeout "$TIMEOUT"
        --max-time "$TIMEOUT"
        --user-agent "$USER_AGENT"
    )
    
    # HTTPメソッド設定
    case "$METHOD" in
        POST)
            curl_opts+=("--request" "POST")
            if [ -n "$POST_DATA" ]; then
                curl_opts+=("--data" "$POST_DATA")
                curl_opts+=("--header" "Content-Type: $CONTENT_TYPE")
            fi
            ;;
        PUT)
            curl_opts+=("--request" "PUT")
            if [ -n "$POST_DATA" ]; then
                curl_opts+=("--data" "$POST_DATA")
                curl_opts+=("--header" "Content-Type: $CONTENT_TYPE")
            fi
            ;;
        DELETE)
            curl_opts+=("--request" "DELETE")
            ;;
    esac
    
    # カスタムヘッダー追加
    if [ -n "$CUSTOM_HEADERS" ]; then
        while IFS= read -r header; do
            if [ -n "$header" ]; then
                curl_opts+=("--header" "$header")
            fi
        done <<< "$CUSTOM_HEADERS"
    fi
    
    local response
    if response=$(curl "${curl_opts[@]}" "$URL" 2>/dev/null); then
        local end_time_ns=$(date +%s%N)
        local duration_ms=$(( (end_time_ns - start_time_ns) / 1000000 ))
        
        IFS='|' read -r http_code time_total size_download effective_url <<< "$response"
        
        echo "$request_id|$http_code|$duration_ms|$size_download|$effective_url" >> "$RESULTS_FILE"
        
        log_verbose "リクエスト $request_id: HTTP $http_code, ${duration_ms}ms, ${size_download}bytes"
    else
        local end_time_ns=$(date +%s%N)
        local duration_ms=$(( (end_time_ns - start_time_ns) / 1000000 ))
        echo "$request_id|ERROR|$duration_ms|0|$URL" >> "$RESULTS_FILE"
        log_verbose "リクエスト $request_id: エラー, ${duration_ms}ms"
    fi
}

# 並列リクエスト実行
run_concurrent_requests() {
    local batch_start=$1
    local batch_end=$2
    
    for ((i=batch_start; i<=batch_end; i++)); do
        make_single_request "$i" &
        echo $! >> "$PIDS_FILE"
        
        if [ "$DELAY" -gt 0 ]; then
            sleep "$DELAY"
        fi
    done
    
    # 全プロセス完了を待機
    wait
    
    # PIDファイルをクリア
    > "$PIDS_FILE"
}

# 結果解析
analyze_results() {
    if [ ! -f "$RESULTS_FILE" ]; then
        log_error "結果ファイルが見つかりません"
        return 1
    fi
    
    log_info "結果を解析中..."
    
    TOTAL_SENT=0
    TOTAL_SUCCESS=0
    TOTAL_FAILED=0
    TOTAL_TIME=0
    MIN_TIME=999999
    MAX_TIME=0
    RESPONSE_TIMES=()
    declare -A STATUS_CODES=()
    
    while IFS='|' read -r request_id http_code duration_ms size_download effective_url; do
        TOTAL_SENT=$((TOTAL_SENT + 1))
        
        if [ "$http_code" = "ERROR" ]; then
            TOTAL_FAILED=$((TOTAL_FAILED + 1))
        elif [ "$http_code" -ge 200 ] && [ "$http_code" -lt 400 ]; then
            TOTAL_SUCCESS=$((TOTAL_SUCCESS + 1))
        else
            TOTAL_FAILED=$((TOTAL_FAILED + 1))
        fi
        
        # レスポンス時間統計
        RESPONSE_TIMES+=("$duration_ms")
        TOTAL_TIME=$((TOTAL_TIME + duration_ms))
        
        if [ "$duration_ms" -lt "$MIN_TIME" ]; then
            MIN_TIME="$duration_ms"
        fi
        
        if [ "$duration_ms" -gt "$MAX_TIME" ]; then
            MAX_TIME="$duration_ms"
        fi
        
        # ステータスコード集計
        if [ -n "${STATUS_CODES[$http_code]:-}" ]; then
            STATUS_CODES[$http_code]=$((STATUS_CODES[$http_code] + 1))
        else
            STATUS_CODES[$http_code]=1
        fi
        
    done < "$RESULTS_FILE"
}

# パーセンタイル計算
calculate_percentile() {
    local percentile=$1
    local sorted_times=($(printf '%s\n' "${RESPONSE_TIMES[@]}" | sort -n))
    local count=${#sorted_times[@]}
    local index=$(echo "$count * $percentile / 100" | bc -l | cut -d. -f1)
    
    if [ "$index" -ge "$count" ]; then
        index=$((count - 1))
    fi
    
    echo "${sorted_times[$index]}"
}

# 結果表示
display_results() {
    local test_duration=$((END_TIME - START_TIME))
    local average_time=0
    local rps=0
    
    if [ "$TOTAL_SENT" -gt 0 ]; then
        average_time=$(echo "scale=2; $TOTAL_TIME / $TOTAL_SENT" | bc)
        rps=$(echo "scale=2; $TOTAL_SENT / $test_duration" | bc)
    fi
    
    echo ""
    echo -e "${BOLD}=== テスト結果サマリー ===${NC}"
    echo "テスト対象URL: $URL"
    echo "実行時間: ${test_duration}秒"
    echo ""
    echo -e "${BOLD}リクエスト統計:${NC}"
    echo "  総リクエスト数: $TOTAL_SENT"
    echo "  成功: $TOTAL_SUCCESS"
    echo "  失敗: $TOTAL_FAILED"
    echo "  成功率: $(echo "scale=2; $TOTAL_SUCCESS * 100 / $TOTAL_SENT" | bc)%"
    echo "  秒間リクエスト数: $rps req/s"
    echo ""
    echo -e "${BOLD}レスポンス時間統計 (ms):${NC}"
    echo "  最小: $MIN_TIME"
    echo "  最大: $MAX_TIME"
    echo "  平均: $average_time"
    echo "  50パーセンタイル: $(calculate_percentile 50)"
    echo "  90パーセンタイル: $(calculate_percentile 90)"
    echo "  95パーセンタイル: $(calculate_percentile 95)"
    echo "  99パーセンタイル: $(calculate_percentile 99)"
    echo ""
    echo -e "${BOLD}HTTPステータスコード分布:${NC}"
    for status_code in $(printf '%s\n' "${!STATUS_CODES[@]}" | sort -n); do
        local count=${STATUS_CODES[$status_code]}
        local percentage=$(echo "scale=2; $count * 100 / $TOTAL_SENT" | bc)
        echo "  $status_code: $count ($percentage%)"
    done
}

# CSV出力
output_csv() {
    local csv_file="$OUTPUT_DIR/results_$(date +%Y%m%d_%H%M%S).csv"
    
    echo "request_id,http_code,duration_ms,size_download,effective_url" > "$csv_file"
    cat "$RESULTS_FILE" | tr '|' ',' >> "$csv_file"
    
    log_success "CSV結果を出力しました: $csv_file"
}

# JSON出力
output_json() {
    local json_file="$OUTPUT_DIR/results_$(date +%Y%m%d_%H%M%S).json"
    local test_duration=$((END_TIME - START_TIME))
    local average_time=0
    local rps=0
    
    if [ "$TOTAL_SENT" -gt 0 ]; then
        average_time=$(echo "scale=2; $TOTAL_TIME / $TOTAL_SENT" | bc)
        rps=$(echo "scale=2; $TOTAL_SENT / $test_duration" | bc)
    fi
    
    # ステータスコード分布をJSON形式に変換
    local status_json="{"
    local first=true
    for status_code in "${!STATUS_CODES[@]}"; do
        if [ "$first" = false ]; then
            status_json+=","
        fi
        status_json+="\"$status_code\":${STATUS_CODES[$status_code]}"
        first=false
    done
    status_json+="}"
    
    jq -n \
        --arg url "$URL" \
        --arg test_duration "$test_duration" \
        --arg total_sent "$TOTAL_SENT" \
        --arg total_success "$TOTAL_SUCCESS" \
        --arg total_failed "$TOTAL_FAILED" \
        --arg rps "$rps" \
        --arg min_time "$MIN_TIME" \
        --arg max_time "$MAX_TIME" \
        --arg avg_time "$average_time" \
        --arg p50 "$(calculate_percentile 50)" \
        --arg p90 "$(calculate_percentile 90)" \
        --arg p95 "$(calculate_percentile 95)" \
        --arg p99 "$(calculate_percentile 99)" \
        --argjson status_codes "$status_json" \
        '{
            url: $url,
            test_duration_seconds: ($test_duration | tonumber),
            requests: {
                total: ($total_sent | tonumber),
                successful: ($total_success | tonumber),
                failed: ($total_failed | tonumber),
                success_rate: (($total_success | tonumber) * 100 / ($total_sent | tonumber))
            },
            performance: {
                requests_per_second: ($rps | tonumber),
                response_time_ms: {
                    min: ($min_time | tonumber),
                    max: ($max_time | tonumber),
                    average: ($avg_time | tonumber),
                    percentiles: {
                        p50: ($p50 | tonumber),
                        p90: ($p90 | tonumber),
                        p95: ($p95 | tonumber),
                        p99: ($p99 | tonumber)
                    }
                }
            },
            status_codes: $status_codes,
            timestamp: now
        }' > "$json_file"
    
    log_success "JSON結果を出力しました: $json_file"
}

# メイン処理
main() {
    # 引数解析
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -n|--requests)
                TOTAL_REQUESTS="$2"
                shift 2
                ;;
            -c|--concurrent)
                CONCURRENT_REQUESTS="$2"
                shift 2
                ;;
            -d|--delay)
                DELAY="$2"
                shift 2
                ;;
            -t|--timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            -m|--method)
                METHOD="$2"
                shift 2
                ;;
            -u|--user-agent)
                USER_AGENT="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -r|--report)
                REPORT_FILE="$2"
                shift 2
                ;;
            --csv)
                CSV_OUTPUT=true
                shift
                ;;
            --json)
                JSON_OUTPUT=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -q|--quiet)
                QUIET=true
                shift
                ;;
            --no-progress)
                SHOW_PROGRESS=false
                shift
                ;;
            --header)
                CUSTOM_HEADERS="${CUSTOM_HEADERS}${2}\n"
                shift 2
                ;;
            --data)
                POST_DATA="$2"
                shift 2
                ;;
            --content-type)
                CONTENT_TYPE="$2"
                shift 2
                ;;
            -*)
                log_error "未知のオプション: $1"
                echo "ヘルプを表示するには: $SCRIPT_NAME --help"
                exit 1
                ;;
            *)
                if [ -z "$URL" ]; then
                    URL="$1"
                else
                    log_error "複数のURLが指定されています"
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # URL必須チェック
    if [ -z "$URL" ]; then
        log_error "URLが指定されていません"
        echo "使用方法: $SCRIPT_NAME [オプション] <URL>"
        exit 1
    fi
    
    # 設定検証
    if [ "$CONCURRENT_REQUESTS" -gt "$TOTAL_REQUESTS" ]; then
        CONCURRENT_REQUESTS="$TOTAL_REQUESTS"
        log_warning "同時リクエスト数を総リクエスト数に調整しました: $CONCURRENT_REQUESTS"
    fi
    
    # 初期設定
    check_dependencies
    setup_output_dir
    
    # テスト開始
    log_info "負荷テストを開始します..."
    log_info "URL: $URL"
    log_info "総リクエスト数: $TOTAL_REQUESTS"
    log_info "同時リクエスト数: $CONCURRENT_REQUESTS"
    log_info "HTTPメソッド: $METHOD"
    
    START_TIME=$(date +%s)
    
    # バッチ処理でリクエスト実行
    local completed=0
    for ((batch_start=1; batch_start<=TOTAL_REQUESTS; batch_start+=CONCURRENT_REQUESTS)); do
        local batch_end=$((batch_start + CONCURRENT_REQUESTS - 1))
        if [ "$batch_end" -gt "$TOTAL_REQUESTS" ]; then
            batch_end="$TOTAL_REQUESTS"
        fi
        
        run_concurrent_requests "$batch_start" "$batch_end"
        
        completed="$batch_end"
        if [ "$SHOW_PROGRESS" = true ] && [ "$QUIET" = false ]; then
            show_progress "$completed" "$TOTAL_REQUESTS"
        fi
    done
    
    END_TIME=$(date +%s)
    
    if [ "$SHOW_PROGRESS" = true ] && [ "$QUIET" = false ]; then
        echo "" # 改行
    fi
    
    # 結果解析と表示
    analyze_results
    display_results
    
    # 結果出力
    if [ "$CSV_OUTPUT" = true ]; then
        output_csv
    fi
    
    if [ "$JSON_OUTPUT" = true ]; then
        output_json
    fi
    
    if [ -n "$REPORT_FILE" ]; then
        display_results > "$OUTPUT_DIR/$REPORT_FILE"
        log_success "レポートを出力しました: $OUTPUT_DIR/$REPORT_FILE"
    fi
    
    log_success "テスト完了"
}

# スクリプト実行
main "$@"
