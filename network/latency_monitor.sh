#!/bin/bash
set -euo pipefail

#
# ネットワークレイテンシ監視ツール
# バージョン: 1.0
#
# 複数ホストへのPing/HTTP応答時間を継続監視・記録するツール
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"
readonly LOG_DIR="${HOME}/.latency_monitor"

declare mode="monitor"
declare -a target_hosts=()
declare -i interval=5
declare -i count=0
declare -i warn_threshold=100
declare -i crit_threshold=500
declare -i timeout_ms=3000
declare check_type="ping"
declare output_file=""
declare output_format="table"
declare alert_cmd=""

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション] ホスト [ホスト...]

ネットワークレイテンシ監視ツール

引数:
  ホスト              監視対象のIPアドレスまたはホスト名

モード:
  monitor             リアルタイム監視 (デフォルト)
  report              保存ログからレポート生成
  check               1回だけチェック

オプション:
  -h, --help              このヘルプを表示
  -v, --version           バージョン情報を表示
  -m, --mode MODE         動作モード (monitor|report|check)
  -i, --interval SEC      監視間隔秒数 [デフォルト: 5]
  -n, --count NUM         チェック回数 (0=無限) [デフォルト: 0]
  -t, --type TYPE         チェック種別 (ping|http|tcp) [デフォルト: ping]
  -w, --warn MS           警告閾値(ms) [デフォルト: 100]
  -c, --crit MS           致命的閾値(ms) [デフォルト: 500]
  --timeout MS            タイムアウト(ms) [デフォルト: 3000]
  -a, --alert CMD         アラートコマンド
  -o, --output FILE       ログ出力ファイル
  -f, --format FMT        出力形式 (table|csv)

例:
  $PROG_NAME 8.8.8.8 1.1.1.1
  $PROG_NAME -t http -i 10 -w 200 -c 1000 https://example.com
  $PROG_NAME -n 100 -f csv -o latency.csv 192.168.1.1
  $PROG_NAME -m report -o latency.csv

EOF
}

ping_host() {
    local host="$1"
    local timeout_s=$(( timeout_ms / 1000 ))

    local result
    result=$(ping -c 1 -W "$timeout_s" "$host" 2>/dev/null | grep 'time=' | \
        grep -oE 'time=[0-9.]+' | cut -d= -f2 || echo "")

    if [[ -z "$result" ]]; then
        echo "-1"
    else
        printf "%.0f" "$result"
    fi
}

http_check() {
    local url="$1"
    local timeout_s=$(( timeout_ms / 1000 ))

    local result
    result=$(curl -s -o /dev/null -w "%{time_total}" \
        --max-time "$timeout_s" \
        --connect-timeout "$timeout_s" \
        "$url" 2>/dev/null || echo "")

    if [[ -z "$result" ]]; then
        echo "-1"
    else
        printf "%.0f" "$(echo "$result * 1000" | bc -l 2>/dev/null || echo -1)"
    fi
}

tcp_check() {
    local host="${1%%:*}"
    local port="${1##*:}"
    [[ "$port" == "$host" ]] && port=80

    local timeout_s=$(( timeout_ms / 1000 ))
    local start end

    start=$(date +%s%N)
    if timeout "$timeout_s" bash -c "echo >/dev/tcp/${host}/${port}" 2>/dev/null; then
        end=$(date +%s%N)
        echo $(( (end - start) / 1000000 ))
    else
        echo "-1"
    fi
}

measure_latency() {
    local host="$1"
    case "$check_type" in
        ping) ping_host "$host" ;;
        http) http_check "$host" ;;
        tcp)  tcp_check "$host" ;;
    esac
}

latency_color() {
    local ms="$1"
    if (( ms < 0 )); then
        echo "$C_RED"
    elif (( ms >= crit_threshold )); then
        echo "$C_RED"
    elif (( ms >= warn_threshold )); then
        echo "$C_YELLOW"
    else
        echo "$C_GREEN"
    fi
}

latency_status() {
    local ms="$1"
    if (( ms < 0 ));                   then echo "TIMEOUT"
    elif (( ms >= crit_threshold ));   then echo "CRITICAL"
    elif (( ms >= warn_threshold ));   then echo "WARNING"
    else                               echo "OK"
    fi
}

do_check() {
    log_info "レイテンシチェック (${check_type})"
    echo ""

    printf "  ${C_BOLD}%-35s %8s %-10s${C_RESET}\n" "ホスト" "レイテンシ" "状態"
    printf "  %s\n" "$(printf '%.0s-' {1..55})"

    for host in "${target_hosts[@]}"; do
        local ms
        ms=$(measure_latency "$host")
        local color
        color=$(latency_color "$ms")
        local status
        status=$(latency_status "$ms")

        if (( ms < 0 )); then
            printf "  %-35s ${color}%8s${C_RESET} ${color}%-10s${C_RESET}\n" \
                "$host" "TIMEOUT" "$status"
        else
            printf "  %-35s ${color}%7dms${C_RESET} ${color}%-10s${C_RESET}\n" \
                "$host" "$ms" "$status"
        fi
    done
    echo ""
}

do_monitor() {
    mkdir -p "$LOG_DIR"

    local log_file="${output_file:-${LOG_DIR}/latency_$(date +%Y%m%d).csv}"

    if [[ ! -f "$log_file" ]]; then
        local header="timestamp"
        for host in "${target_hosts[@]}"; do
            header="${header},${host}"
        done
        echo "$header" > "$log_file"
    fi

    log_info "レイテンシ監視開始 (Ctrl+C で停止)"
    log_info "ログ: $log_file"
    echo ""

    local check_num=0

    cleanup_monitor() {
        show_cursor
        clear_screen
        echo ""
        log_info "監視を終了しました"
    }
    trap cleanup_monitor EXIT INT TERM

    hide_cursor

    while true; do
        (( count > 0 && check_num >= count )) && break
        (( check_num++ )) || true

        local timestamp
        timestamp=$(get_timestamp)
        local -a ms_values=()

        clear_screen
        print_center "ネットワークレイテンシ監視" 1 "$C_CYAN"
        move_cursor 2 2
        printf "${C_DIM}更新: %s  チェック: %d  間隔: %ds${C_RESET}" \
            "$timestamp" "$check_num" "$interval"
        draw_separator 3

        local row=5
        move_cursor $row 2
        printf "${C_BOLD}%-35s %8s %-10s %s${C_RESET}\n" \
            "ホスト" "レイテンシ" "状態" "グラフ"
        (( row++ )) || true
        move_cursor $row 2
        printf "%s\n" "$(printf '%.0s-' {1..75})"
        (( row++ )) || true

        local csv_line="$timestamp"
        local alert_triggered=false

        for host in "${target_hosts[@]}"; do
            local ms
            ms=$(measure_latency "$host")
            ms_values+=("$ms")
            csv_line="${csv_line},${ms}"

            local color
            color=$(latency_color "$ms")
            local status
            status=$(latency_status "$ms")

            local bar=""
            if (( ms >= 0 )); then
                local bar_len=$(( ms > 500 ? 30 : ms * 30 / 500 ))
                (( bar_len > 0 )) && bar=$(printf '█%.0s' $(seq 1 $bar_len))
            fi

            move_cursor $row 2
            if (( ms < 0 )); then
                printf "  %-33s ${color}%8s${C_RESET} ${color}%-10s${C_RESET}\n" \
                    "$host" "TIMEOUT" "$status"
            else
                printf "  %-33s ${color}%7dms${C_RESET} ${color}%-10s${C_RESET} ${color}%s${C_RESET}\n" \
                    "$host" "$ms" "$status" "$bar"
            fi
            (( row++ )) || true

            if [[ "$status" == "CRITICAL" || "$status" == "TIMEOUT" ]]; then
                alert_triggered=true
            fi
        done

        echo "$csv_line" >> "$log_file"

        if $alert_triggered && [[ -n "$alert_cmd" ]]; then
            eval "$alert_cmd '$timestamp'" 2>/dev/null || true
        fi

        sleep "$interval"
    done
}

do_report() {
    local log_file="${output_file:-}"

    if [[ -z "$log_file" ]]; then
        mapfile -t log_files < <(find "$LOG_DIR" -name "latency_*.csv" | sort -r)
        [[ ${#log_files[@]} -eq 0 ]] && error_exit "ログファイルが見つかりません: $LOG_DIR"
        log_file="${log_files[0]}"
    fi

    [[ ! -f "$log_file" ]] && error_exit "ファイルが見つかりません: $log_file"

    log_info "レポート: $log_file"
    echo ""

    python3 - <<PYEOF
import csv, sys
from collections import defaultdict

data = defaultdict(list)
with open('$log_file') as f:
    reader = csv.reader(f)
    headers = next(reader)
    hosts = headers[1:]
    for row in reader:
        if not row: continue
        for i, host in enumerate(hosts):
            try:
                val = int(row[i+1])
                if val >= 0:
                    data[host].append(val)
            except (ValueError, IndexError):
                pass

print(f"  {'ホスト':<35} {'件数':>6} {'最小':>8} {'最大':>8} {'平均':>8} {'中央値':>8}")
print("  " + "-"*75)
for host in hosts:
    vals = sorted(data[host])
    if not vals:
        print(f"  {host:<35} {'0':>6} {'N/A':>8} {'N/A':>8} {'N/A':>8} {'N/A':>8}")
        continue
    n = len(vals)
    avg = sum(vals) // n
    median = vals[n//2]
    print(f"  {host:<35} {n:>6} {vals[0]:>7}ms {vals[-1]:>7}ms {avg:>7}ms {median:>7}ms")
PYEOF
    echo ""
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -m|--mode)    [[ $# -lt 2 ]] && error_exit "-m には値が必要です"; mode="$2"; shift 2 ;;
            -i|--interval) [[ $# -lt 2 ]] && error_exit "-i には値が必要です"; interval="$2"; shift 2 ;;
            -n|--count)   [[ $# -lt 2 ]] && error_exit "-n には値が必要です"; count="$2"; shift 2 ;;
            -t|--type)    [[ $# -lt 2 ]] && error_exit "-t には値が必要です"; check_type="$2"; shift 2 ;;
            -w|--warn)    [[ $# -lt 2 ]] && error_exit "-w には値が必要です"; warn_threshold="$2"; shift 2 ;;
            -c|--crit)    [[ $# -lt 2 ]] && error_exit "-c には値が必要です"; crit_threshold="$2"; shift 2 ;;
            --timeout)    [[ $# -lt 2 ]] && error_exit "--timeout には値が必要です"; timeout_ms="$2"; shift 2 ;;
            -a|--alert)   [[ $# -lt 2 ]] && error_exit "-a には値が必要です"; alert_cmd="$2"; shift 2 ;;
            -o|--output)  [[ $# -lt 2 ]] && error_exit "-o には値が必要です"; output_file="$2"; shift 2 ;;
            -f|--format)  [[ $# -lt 2 ]] && error_exit "-f には値が必要です"; output_format="$2"; shift 2 ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  target_hosts+=("$1"); shift ;;
        esac
    done
}

main() {
    parse_arguments "$@"

    case "$mode" in
        monitor)
            [[ ${#target_hosts[@]} -eq 0 ]] && error_exit "監視対象ホストを指定してください"
            do_monitor
            ;;
        check)
            [[ ${#target_hosts[@]} -eq 0 ]] && error_exit "チェック対象ホストを指定してください"
            do_check
            ;;
        report) do_report ;;
        *)      error_exit "不明なモード: $mode" ;;
    esac
}

main "$@"
