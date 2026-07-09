#!/bin/bash
set -euo pipefail

#
# システム情報ダッシュボード
# 作成日: 2026-07-04
# バージョン: 1.0
#
# CPU・メモリ・ディスク・ネットワーク・プロセス情報を一画面で表示する
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション]

システムリソースの使用状況を一画面に表示します。

オプション:
  -h, --help       このヘルプを表示
  -v, --version    バージョン情報を表示
  -w, --watch N    N 秒ごとに自動更新（Ctrl+C で終了）
  -o, --output F   スナップショットをファイルに保存
  -j, --json       JSON形式で出力
EOF
}

get_cpu_usage() {
    if command -v top &>/dev/null; then
        top -bn1 2>/dev/null | grep "Cpu(s)" | awk '{print int($2)}' || echo "0"
    else
        echo "N/A"
    fi
}

get_load_avg() {
    if [ -f /proc/loadavg ]; then
        awk '{print $1, $2, $3}' /proc/loadavg
    else
        uptime 2>/dev/null | awk -F'load average:' '{print $2}' | tr -d ' ' || echo "N/A"
    fi
}

get_memory_info() {
    if [ -f /proc/meminfo ]; then
        local total used free buffers cached available
        total=$(awk '/MemTotal/{print $2}' /proc/meminfo)
        free=$(awk '/MemFree/{print $2}' /proc/meminfo)
        buffers=$(awk '/^Buffers/{print $2}' /proc/meminfo)
        cached=$(awk '/^Cached/{print $2}' /proc/meminfo)
        available=$(awk '/MemAvailable/{print $2}' /proc/meminfo)
        used=$(( total - available ))
        echo "$total $used $free $available"
    else
        echo "0 0 0 0"
    fi
}

kb_to_human() {
    local kb="$1"
    if [ "$kb" -ge 1048576 ]; then
        awk "BEGIN{printf \"%.1fGB\", $kb/1048576}"
    elif [ "$kb" -ge 1024 ]; then
        awk "BEGIN{printf \"%.1fMB\", $kb/1024}"
    else
        echo "${kb}KB"
    fi
}

get_disk_summary() {
    df -h 2>/dev/null | grep -vE "^tmpfs|^devtmpfs|^udev|^Filesystem" | \
    awk '{print $1, $2, $3, $4, $5, $6}' | head -5
}

get_network_info() {
    if command -v ip &>/dev/null; then
        ip -4 addr show 2>/dev/null | grep "inet " | grep -v "127.0.0.1" | \
        awk '{print $NF, $2}' | head -3
    fi
}

get_top_processes() {
    ps aux --sort=-%cpu 2>/dev/null | awk 'NR>1{printf "%s %s %s\n", $3, $4, $11}' | \
    head -5
}

display_dashboard() {
    update_terminal_size
    clear_screen

    local timestamp
    timestamp=$(get_timestamp)
    local hostname
    hostname=$(hostname 2>/dev/null || echo "unknown")
    local uptime_str
    uptime_str=$(uptime -p 2>/dev/null || uptime | awk -F'up' '{print $2}' | cut -d',' -f1 | xargs)
    local kernel
    kernel=$(uname -r 2>/dev/null || echo "unknown")

    print_center "システム情報ダッシュボード" 0 "${C_BOLD}${C_CYAN}"
    printf "  ${C_DIM}%s  ホスト: %s  稼働: %s${C_RESET}\n" "$timestamp" "$hostname" "$uptime_str"
    echo ""

    # CPU
    echo -e "  ${C_BOLD}${C_CYAN}[ CPU ]${C_RESET}"
    local cpu_pct
    cpu_pct=$(get_cpu_usage)
    local load_avg
    load_avg=$(get_load_avg)
    local nproc
    nproc=$(nproc 2>/dev/null || echo "?")

    local cpu_color="$C_GREEN"
    if [[ "$cpu_pct" =~ ^[0-9]+$ ]]; then
        [ "$cpu_pct" -ge 80 ] && cpu_color="$C_RED"
        [ "$cpu_pct" -ge 60 ] && [ "$cpu_pct" -lt 80 ] && cpu_color="$C_YELLOW"
        local cpu_bar
        cpu_bar=$(draw_progress_bar "$cpu_pct" 100 25)
        printf "  使用率: ${cpu_color}%3d%%${C_RESET}  %s\n" "$cpu_pct" "$cpu_bar"
    fi
    printf "  コア数: %s  ロード平均: %s\n" "$nproc" "$load_avg"
    echo ""

    # Memory
    echo -e "  ${C_BOLD}${C_CYAN}[ メモリ ]${C_RESET}"
    local mem_info
    read -r mem_total mem_used mem_free mem_avail <<< "$(get_memory_info)"
    if [ "$mem_total" -gt 0 ]; then
        local mem_pct=$(( mem_used * 100 / mem_total ))
        local mem_color="$C_GREEN"
        [ "$mem_pct" -ge 80 ] && mem_color="$C_RED"
        [ "$mem_pct" -ge 60 ] && [ "$mem_pct" -lt 80 ] && mem_color="$C_YELLOW"
        local mem_bar
        mem_bar=$(draw_progress_bar "$mem_used" "$mem_total" 25)
        printf "  使用率: ${mem_color}%3d%%${C_RESET}  %s\n" "$mem_pct" "$mem_bar"
        printf "  合計: %s  使用: %s  空き: %s\n" \
            "$(kb_to_human "$mem_total")" "$(kb_to_human "$mem_used")" "$(kb_to_human "$mem_avail")"
    fi
    echo ""

    # Disk
    echo -e "  ${C_BOLD}${C_CYAN}[ ディスク ]${C_RESET}"
    printf "  ${C_DIM}%-18s  %5s  %5s  %5s  %5s${C_RESET}\n" "マウントポイント" "サイズ" "使用済" "空き" "使用率"
    while IFS= read -r dline; do
        local dfs dsize dused davail dpct dmount
        read -r dfs dsize dused davail dpct dmount <<< "$dline"
        local dpct_num="${dpct%%%}"
        local dcolor="$C_GREEN"
        [[ "$dpct_num" =~ ^[0-9]+$ ]] && [ "$dpct_num" -ge 80 ] && dcolor="$C_RED"
        [[ "$dpct_num" =~ ^[0-9]+$ ]] && [ "$dpct_num" -ge 60 ] && [ "$dpct_num" -lt 80 ] && dcolor="$C_YELLOW"
        printf "  %-18s  %5s  %5s  %5s  ${dcolor}%5s${C_RESET}\n" \
            "${dmount:0:18}" "$dsize" "$dused" "$davail" "$dpct"
    done < <(get_disk_summary)
    echo ""

    # Network
    local net_info
    net_info=$(get_network_info)
    if [ -n "$net_info" ]; then
        echo -e "  ${C_BOLD}${C_CYAN}[ ネットワーク ]${C_RESET}"
        while IFS= read -r nline; do
            local iface addr
            read -r iface addr <<< "$nline"
            printf "  %-12s  %s\n" "$iface" "$addr"
        done <<< "$net_info"
        echo ""
    fi

    # Top Processes
    echo -e "  ${C_BOLD}${C_CYAN}[ プロセス TOP5 (CPU順) ]${C_RESET}"
    printf "  ${C_DIM}%5s  %5s  %s${C_RESET}\n" "CPU%" "MEM%" "コマンド"
    while IFS= read -r pline; do
        local pcpu pmem pcmd
        read -r pcpu pmem pcmd <<< "$pline"
        local pcolor="$C_GREEN"
        [[ "$pcpu" =~ ^[0-9] ]] && awk "BEGIN{exit ($pcpu < 50)}" 2>/dev/null && pcolor="$C_RED"
        printf "  ${pcolor}%5s${C_RESET}  %5s  %s\n" "$pcpu" "$pmem" "${pcmd:0:40}"
    done < <(get_top_processes)
    echo ""
    printf "  ${C_DIM}カーネル: %s${C_RESET}\n" "$kernel"
}

main() {
    local watch_interval=0
    local output_file=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -w|--watch)
                [[ $# -lt 2 ]] && error_exit "--watch には秒数が必要です"
                watch_interval="$2"; shift 2 ;;
            -o|--output)
                [[ $# -lt 2 ]] && error_exit "--output にはファイル名が必要です"
                output_file="$2"; shift 2 ;;
            *) error_exit "不明なオプション: $1" ;;
        esac
    done

    if [ "$watch_interval" -gt 0 ]; then
        while true; do
            display_dashboard
            echo ""
            printf "  ${C_DIM}次の更新まで %d秒... (Ctrl+C で終了)${C_RESET}\n" "$watch_interval"
            sleep "$watch_interval"
        done
    else
        display_dashboard
        if [ -n "$output_file" ]; then
            display_dashboard > "$output_file" 2>&1
            log_success "スナップショットを保存: $output_file"
        fi
    fi
}

main "$@"
