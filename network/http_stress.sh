#!/bin/bash
set -euo pipefail

#
# HTTPストレステストツール
# バージョン: 1.0
#
# WebサーバーへのHTTPリクエストを並列送信してパフォーマンスを計測するツール
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare target_url=""
declare -i total_requests=100
declare -i concurrent=10
declare http_method="GET"
declare request_body=""
declare -a headers=()
declare -i timeout_sec=30
declare output_format="summary"
declare output_file=""
declare dry_run=false

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション] URL

HTTPストレステストツール

引数:
  URL               テスト対象のURL

オプション:
  -h, --help              このヘルプを表示
  -v, --version           バージョン情報を表示
  -n, --requests NUM      総リクエスト数 [デフォルト: 100]
  -c, --concurrent NUM    並列リクエスト数 [デフォルト: 10]
  -m, --method METHOD     HTTPメソッド (GET|POST|PUT|DELETE) [デフォルト: GET]
  -d, --data BODY         リクエストボディ
  -H, --header HEADER     HTTPヘッダー (複数可)
  -t, --timeout SEC       タイムアウト秒数 [デフォルト: 30]
  -f, --format FMT        出力形式 (summary|detail|csv) [デフォルト: summary]
  -o, --output FILE       結果出力ファイル
  --dry-run               実際にリクエストを送らずテスト設定を確認

例:
  $PROG_NAME http://localhost
  $PROG_NAME -n 200 -c 20 http://localhost/api
  $PROG_NAME -m POST -d '{"key":"val"}' -H "Content-Type: application/json" http://localhost/api
  $PROG_NAME -n 1000 -c 50 -f csv -o result.csv http://example.com

EOF
}

send_request() {
    local url="$1"
    local method="$2"
    local timeout="$3"
    local body="${4:-}"
    local -a extra_headers=("${@:5}")

    local curl_opts=(-s -o /dev/null -w "%{http_code}|%{time_total}|%{time_connect}|%{size_download}"
        -X "$method"
        --max-time "$timeout"
        --connect-timeout 5)

    for h in "${extra_headers[@]}"; do
        curl_opts+=(-H "$h")
    done

    [[ -n "$body" ]] && curl_opts+=(--data "$body")

    local start end result
    result=$(curl "${curl_opts[@]}" "$url" 2>/dev/null || echo "000|0|0|0")
    echo "$result"
}

run_stress_test() {
    local url="$1"
    local tmpdir
    tmpdir=$(mktemp -d)

    cleanup_stress() {
        rm -rf "$tmpdir"
    }
    trap cleanup_stress EXIT

    log_info "HTTPストレステスト開始"
    echo ""
    printf "  %-20s %s\n" "URL:" "$url"
    printf "  %-20s %d\n" "総リクエスト数:" "$total_requests"
    printf "  %-20s %d\n" "並列数:" "$concurrent"
    printf "  %-20s %s\n" "メソッド:" "$http_method"
    printf "  %-20s %d秒\n" "タイムアウト:" "$timeout_sec"
    echo ""

    if $dry_run; then
        log_info "[DRY RUN] テスト設定を確認しました。実際のリクエストは送信しません"
        return 0
    fi

    log_info "テスト実行中..."
    echo ""

    local -i completed=0
    local -i success=0
    local -i failed=0
    local start_time
    start_time=$(date +%s%N)

    local result_file="${tmpdir}/results.txt"
    touch "$result_file"

    local -i batch_start=1
    while (( batch_start <= total_requests )); do
        local -i batch_end=$(( batch_start + concurrent - 1 ))
        (( batch_end > total_requests )) && batch_end=$total_requests

        local -a pids=()
        for (( i=batch_start; i<=batch_end; i++ )); do
            local req_result_file="${tmpdir}/req_${i}.txt"
            (
                local result
                result=$(send_request "$url" "$http_method" "$timeout_sec" \
                    "$request_body" "${headers[@]}" 2>/dev/null || echo "000|0|0|0")
                echo "$result" > "$req_result_file"
            ) &
            pids+=($!)
        done

        for pid in "${pids[@]}"; do
            wait "$pid" 2>/dev/null || true
        done

        for (( i=batch_start; i<=batch_end; i++ )); do
            local req_result_file="${tmpdir}/req_${i}.txt"
            if [[ -f "$req_result_file" ]]; then
                local result
                result=$(cat "$req_result_file")
                echo "$result" >> "$result_file"
                local code="${result%%|*}"
                if (( code >= 200 && code < 400 )); then
                    (( success++ )) || true
                else
                    (( failed++ )) || true
                fi
            fi
            (( completed++ )) || true
        done

        # プログレス表示
        local pct=$(( completed * 100 / total_requests ))
        printf "\r  "
        draw_progress_bar "$completed" "$total_requests" 30
        printf " %d%% (%d/%d) 成功:%d 失敗:%d" \
            "$pct" "$completed" "$total_requests" "$success" "$failed"

        (( batch_start += concurrent )) || true
    done

    local end_time
    end_time=$(date +%s%N)
    local elapsed_ms=$(( (end_time - start_time) / 1000000 ))
    local elapsed_sec
    elapsed_sec=$(echo "scale=2; $elapsed_ms / 1000" | bc 2>/dev/null || echo "$elapsed_ms")

    echo ""
    echo ""

    # 統計計算
    local -a times=()
    while IFS='|' read -r code time_total time_connect size; do
        [[ -z "$code" ]] && continue
        local ms
        ms=$(echo "scale=0; $time_total * 1000 / 1" | bc 2>/dev/null || echo 0)
        times+=("$ms")
    done < "$result_file"

    local min_t=999999 max_t=0 sum_t=0 count_t=${#times[@]}
    for t in "${times[@]}"; do
        (( t < min_t )) && min_t=$t
        (( t > max_t )) && max_t=$t
        (( sum_t += t )) || true
    done
    local avg_t=0
    (( count_t > 0 )) && avg_t=$(( sum_t / count_t )) || true

    # パーセンタイル計算
    local -a sorted_times
    mapfile -t sorted_times < <(printf '%s\n' "${times[@]}" | sort -n)
    local p50_idx=$(( count_t * 50 / 100 ))
    local p95_idx=$(( count_t * 95 / 100 ))
    local p99_idx=$(( count_t * 99 / 100 ))
    local p50="${sorted_times[$p50_idx]:-0}"
    local p95="${sorted_times[$p95_idx]:-0}"
    local p99="${sorted_times[$p99_idx]:-0}"

    local rps=0
    (( elapsed_ms > 0 )) && rps=$(( completed * 1000 / elapsed_ms )) || true

    log_success "テスト完了"
    echo ""
    printf "  ${C_BOLD}%-25s${C_RESET} %s\n" "総リクエスト数:" "$completed"
    printf "  ${C_BOLD}%-25s${C_RESET} ${C_GREEN}%d${C_RESET}\n" "成功:" "$success"
    printf "  ${C_BOLD}%-25s${C_RESET} ${C_RED}%d${C_RESET}\n" "失敗:" "$failed"
    printf "  ${C_BOLD}%-25s${C_RESET} %.1f秒\n" "所要時間:" "$elapsed_sec"
    printf "  ${C_BOLD}%-25s${C_RESET} ${C_CYAN}%d req/s${C_RESET}\n" "スループット:" "$rps"
    echo ""
    printf "  ${C_BOLD}レイテンシ統計:${C_RESET}\n"
    printf "  %-25s %dms\n" "最小:" "$min_t"
    printf "  %-25s %dms\n" "最大:" "$max_t"
    printf "  %-25s %dms\n" "平均:" "$avg_t"
    printf "  %-25s %dms\n" "P50 (中央値):" "$p50"
    printf "  %-25s %dms\n" "P95:" "$p95"
    printf "  %-25s %dms\n" "P99:" "$p99"
    echo ""

    # ステータスコード集計
    log_info "HTTPステータスコード分布:"
    awk -F'|' '{print $1}' "$result_file" | sort | uniq -c | sort -rn | \
    while read -r count code; do
        local color="$C_RESET"
        case "${code:0:1}" in
            2) color="$C_GREEN" ;;
            3) color="$C_CYAN" ;;
            4) color="$C_YELLOW" ;;
            5) color="$C_RED" ;;
        esac
        printf "  ${color}HTTP %-5s %d件${C_RESET}\n" "$code" "$count"
    done

    echo ""

    if [[ -n "$output_file" ]]; then
        {
            echo "URL,${url}"
            echo "総リクエスト数,${completed}"
            echo "成功,${success}"
            echo "失敗,${failed}"
            echo "所要時間,${elapsed_sec}秒"
            echo "スループット,${rps}req/s"
            echo "最小レイテンシ,${min_t}ms"
            echo "最大レイテンシ,${max_t}ms"
            echo "平均レイテンシ,${avg_t}ms"
            echo "P50,${p50}ms"
            echo "P95,${p95}ms"
            echo "P99,${p99}ms"
        } > "$output_file"
        log_success "結果を保存しました: $output_file"
    fi
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -n|--requests)   [[ $# -lt 2 ]] && error_exit "-n には値が必要です"; total_requests="$2"; shift 2 ;;
            -c|--concurrent) [[ $# -lt 2 ]] && error_exit "-c には値が必要です"; concurrent="$2"; shift 2 ;;
            -m|--method)     [[ $# -lt 2 ]] && error_exit "-m には値が必要です"; http_method="$2"; shift 2 ;;
            -d|--data)       [[ $# -lt 2 ]] && error_exit "-d には値が必要です"; request_body="$2"; shift 2 ;;
            -H|--header)     [[ $# -lt 2 ]] && error_exit "-H には値が必要です"; headers+=("$2"); shift 2 ;;
            -t|--timeout)    [[ $# -lt 2 ]] && error_exit "-t には値が必要です"; timeout_sec="$2"; shift 2 ;;
            -f|--format)     [[ $# -lt 2 ]] && error_exit "-f には値が必要です"; output_format="$2"; shift 2 ;;
            -o|--output)     [[ $# -lt 2 ]] && error_exit "-o には値が必要です"; output_file="$2"; shift 2 ;;
            --dry-run) dry_run=true; shift ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  target_url="$1"; shift ;;
        esac
    done
}

main() {
    parse_arguments "$@"
    [[ -z "$target_url" ]] && error_exit "URLを指定してください"
    run_stress_test "$target_url"
}

main "$@"
