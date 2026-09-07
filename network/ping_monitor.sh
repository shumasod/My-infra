#!/bin/bash
set -euo pipefail

#
# 継続的ping監視ツール
# 作成日: 2026-07-04
# バージョン: 1.0
#
# 複数ホストへのping応答をリアルタイムで監視する
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"
readonly DEFAULT_INTERVAL=5
readonly DEFAULT_TIMEOUT=3
readonly HISTORY_SIZE=20

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション] <ホスト> [ホスト...]

複数ホストへのping応答をリアルタイム監視します。

引数:
  <ホスト>  監視するホスト名またはIPアドレス（複数指定可）

オプション:
  -h, --help          このヘルプを表示
  -v, --version       バージョン情報を表示
  -i, --interval N    ping間隔（秒）デフォルト: ${DEFAULT_INTERVAL}
  -t, --timeout N     タイムアウト（秒）デフォルト: ${DEFAULT_TIMEOUT}
  -c, --count N       ping回数後に終了（0=無制限）
  -o, --output FILE   ログをファイルに保存
  -w, --warn N        遅延警告閾値（ms）デフォルト: 100

例:
  $PROG_NAME 8.8.8.8 1.1.1.1
  $PROG_NAME -i 10 -w 50 google.com yahoo.co.jp
  $PROG_NAME -c 100 -o ping_log.txt 192.168.1.1
EOF
}

declare -A HOST_STATUS=()
declare -A HOST_RTT=()
declare -A HOST_LOSS=()
declare -A HOST_SENT=()
declare -A HOST_RECV=()
declare -A HOST_MIN=()
declare -A HOST_MAX=()
declare -A HOST_HIST=()

cleanup() {
    show_cursor
    tput cnorm 2>/dev/null || true
    echo ""
    echo ""
    log_info "監視を終了しました"
}
trap cleanup EXIT INT TERM

do_ping() {
    local host="$1"
    local timeout="$2"

    local result
    result=$(ping -c 1 -W "$timeout" "$host" 2>/dev/null) || true

    if echo "$result" | grep -q "1 received"; then
        local rtt
        rtt=$(echo "$result" | grep "rtt\|round-trip" | awk -F'/' '{print $5}' | cut -d. -f1)
        [ -z "$rtt" ] && rtt=$(echo "$result" | grep "time=" | sed 's/.*time=\([0-9]*\).*/\1/')
        echo "ok:${rtt:-0}"
    else
        echo "fail:0"
    fi
}

update_stats() {
    local host="$1"
    local status="$2"
    local rtt="$3"

    HOST_SENT[$host]=$(( ${HOST_SENT[$host]:-0} + 1 ))

    if [ "$status" == "ok" ]; then
        HOST_RECV[$host]=$(( ${HOST_RECV[$host]:-0} + 1 ))
        HOST_STATUS[$host]="UP"
        HOST_RTT[$host]="$rtt"

        local min="${HOST_MIN[$host]:-9999}"
        local max="${HOST_MAX[$host]:-0}"
        [ "$rtt" -lt "$min" ] && HOST_MIN[$host]="$rtt"
        [ "$rtt" -gt "$max" ] && HOST_MAX[$host]="$rtt"
    else
        HOST_STATUS[$host]="DOWN"
        HOST_RTT[$host]="-"
    fi

    local sent="${HOST_SENT[$host]}"
    local recv="${HOST_RECV[$host]:-0}"
    HOST_LOSS[$host]=$(( (sent - recv) * 100 / sent ))

    local hist="${HOST_HIST[$host]:-}"
    if [ "$status" == "ok" ]; then
        hist+="▲"
    else
        hist+="▼"
    fi
    local hist_len="${#hist}"
    if [ "$hist_len" -gt "$HISTORY_SIZE" ]; then
        hist="${hist:$(( hist_len - HISTORY_SIZE ))}"
    fi
    HOST_HIST[$host]="$hist"
}

draw_dashboard() {
    local hosts=("$@")
    local timestamp
    timestamp=$(get_timestamp)

    clear_screen
    print_center "Ping 監視ダッシュボード" 0 "${C_BOLD}${C_CYAN}"
    printf "  ${C_DIM}更新: %s  Ctrl+C で終了${C_RESET}\n" "$timestamp"
    echo ""

    printf "  ${C_BOLD}%-20s  %-6s  %8s  %6s  %6s  %6s  %s${C_RESET}\n" \
        "ホスト" "状態" "RTT(ms)" "損失率" "送信" "受信" "履歴(最新→)"
    printf "  ${C_DIM}%s${C_RESET}\n" "$(printf '%0.s─' {1..85})"

    local host
    for host in "${hosts[@]}"; do
        local status="${HOST_STATUS[$host]:-INIT}"
        local rtt="${HOST_RTT[$host]:--}"
        local loss="${HOST_LOSS[$host]:-0}"
        local sent="${HOST_SENT[$host]:-0}"
        local recv="${HOST_RECV[$host]:-0}"
        local hist="${HOST_HIST[$host]:-}"

        local status_str color
        case "$status" in
            UP)
                status_str="${C_GREEN}  UP  ${C_RESET}"
                if [[ "$rtt" =~ ^[0-9]+$ ]] && [ "$rtt" -ge "${warn_ms:-100}" ]; then
                    color="$C_YELLOW"
                else
                    color="$C_GREEN"
                fi
                ;;
            DOWN)
                status_str="${C_RED} DOWN ${C_RESET}"
                color="$C_RED"
                ;;
            *)
                status_str="${C_DIM} INIT ${C_RESET}"
                color="$C_DIM"
                ;;
        esac

        local loss_color="$C_GREEN"
        [ "$loss" -ge 10 ] && loss_color="$C_YELLOW"
        [ "$loss" -ge 30 ] && loss_color="$C_RED"

        printf "  %-20s  %b  ${color}%6s${C_RESET}ms  ${loss_color}%5d%%${C_RESET}  %6d  %6d  ${C_DIM}%s${C_RESET}\n" \
            "${host:0:20}" "$status_str" "$rtt" "$loss" "$sent" "$recv" "$hist"
    done
    echo ""
}

main() {
    local interval=$DEFAULT_INTERVAL
    local timeout=$DEFAULT_TIMEOUT
    local count=0
    local output_file=""
    local warn_ms=100
    local -a hosts=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -i|--interval)
                [[ $# -lt 2 ]] && error_exit "--interval には数値が必要です"
                interval="$2"; shift 2 ;;
            -t|--timeout)
                [[ $# -lt 2 ]] && error_exit "--timeout には数値が必要です"
                timeout="$2"; shift 2 ;;
            -c|--count)
                [[ $# -lt 2 ]] && error_exit "--count には数値が必要です"
                count="$2"; shift 2 ;;
            -o|--output)
                [[ $# -lt 2 ]] && error_exit "--output にはファイル名が必要です"
                output_file="$2"; shift 2 ;;
            -w|--warn)
                [[ $# -lt 2 ]] && error_exit "--warn には数値が必要です"
                warn_ms="$2"; shift 2 ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  hosts+=("$1"); shift ;;
        esac
    done

    [ "${#hosts[@]}" -eq 0 ] && error_exit "ホストを1つ以上指定してください"

    hide_cursor

    local iteration=0
    while true; do
        for host in "${hosts[@]}"; do
            local ping_result
            ping_result=$(do_ping "$host" "$timeout")
            local status="${ping_result%%:*}"
            local rtt="${ping_result#*:}"
            update_stats "$host" "$status" "$rtt"

            if [ -n "$output_file" ]; then
                printf "%s\t%s\t%s\t%sms\n" \
                    "$(get_timestamp)" "$host" "$status" "$rtt" >> "$output_file"
            fi
        done

        draw_dashboard "${hosts[@]}"

        iteration=$(( iteration + 1 ))
        if [ "$count" -gt 0 ] && [ "$iteration" -ge "$count" ]; then
            break
        fi

        sleep "$interval"
    done
}

main "$@"
