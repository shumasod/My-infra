#!/bin/bash
set -euo pipefail

#
# システムダッシュボード
# 作成日: 2026-09-01
# バージョン: 1.0
#
# CPU・メモリ・ディスク・ネットワークをリアルタイムで一画面表示します
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare refresh_interval=2
declare compact_mode=0

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション]

システム総合ダッシュボードです。

オプション:
  -h, --help           このヘルプを表示
  -v, --version        バージョン情報を表示
  -i, --interval <秒>  更新間隔 [デフォルト: 2]
  -c, --compact        コンパクト表示

キーバインド:
  q / Q     終了
  r         即時更新
  +/-       更新間隔を増減
EOF
}

get_cpu_usage() {
    local cpu1 cpu2
    cpu1=$(grep "^cpu " /proc/stat)
    sleep 0.5
    cpu2=$(grep "^cpu " /proc/stat)
    python3 - "$cpu1" "$cpu2" <<'PYEOF'
import sys
def parse(line):
    vals = list(map(int, line.split()[1:]))
    idle = vals[3] + (vals[4] if len(vals) > 4 else 0)
    return idle, sum(vals)
idle1, tot1 = parse(sys.argv[1])
idle2, tot2 = parse(sys.argv[2])
d_idle = idle2 - idle1
d_tot  = tot2  - tot1
pct = 100.0 * (d_tot - d_idle) / d_tot if d_tot > 0 else 0
print(f"{pct:.1f}")
PYEOF
}

get_load() {
    awk '{print $1, $2, $3}' /proc/loadavg
}

get_mem_info() {
    awk '
    /^MemTotal:/    { total=$2 }
    /^MemAvailable:/{ avail=$2 }
    /^SwapTotal:/   { stotal=$2 }
    /^SwapFree:/    { sfree=$2 }
    END {
        used=total-avail
        pct=int(used*100/total)
        spct=(stotal>0)?int((stotal-sfree)*100/stotal):0
        printf "%d %d %d %d %d %d\n", total, used, pct, stotal, stotal-sfree, spct
    }' /proc/meminfo
}

get_disk_usage() {
    df -h --output=target,pcent,used,avail 2>/dev/null | \
        grep -v "^tmpfs\|^devtmpfs\|^udev\|Target" | head -5
}

get_net_speed() {
    local iface="${1:-eth0}"
    local r1 t1 r2 t2
    r1=$(cat "/sys/class/net/${iface}/statistics/rx_bytes" 2>/dev/null || echo 0)
    t1=$(cat "/sys/class/net/${iface}/statistics/tx_bytes" 2>/dev/null || echo 0)
    sleep 0.5
    r2=$(cat "/sys/class/net/${iface}/statistics/rx_bytes" 2>/dev/null || echo 0)
    t2=$(cat "/sys/class/net/${iface}/statistics/tx_bytes" 2>/dev/null || echo 0)
    local rx=$(( (r2 - r1) * 2 ))
    local tx=$(( (t2 - t1) * 2 ))
    echo "$rx $tx"
}

format_net() {
    local b="$1"
    if (( b >= 1048576 )); then printf "%.1f MB/s" "$(echo "scale=1; $b/1048576" | bc)"
    elif (( b >= 1024 )); then printf "%.1f KB/s" "$(echo "scale=1; $b/1024" | bc)"
    else printf "%d B/s" "$b"
    fi
}

make_bar() {
    local pct="$1" width="${2:-30}"
    local filled=$(( pct * width / 100 ))
    local color="$C_GREEN"
    (( pct >= 70 )) && color="$C_YELLOW"
    (( pct >= 90 )) && color="$C_RED"
    printf "${color}"
    local i
    for (( i=0; i<filled; i++ )); do printf "█"; done
    printf "${C_RESET}"
    for (( i=filled; i<width; i++ )); do printf "░"; done
}

get_top_procs() {
    ps aux --sort=-%cpu 2>/dev/null | tail -n +2 | head -5 | \
        awk '{printf "%s %s %s %s\n", $1, $3, $4, $11}'
}

get_net_iface() {
    ip route show default 2>/dev/null | awk '{print $5}' | head -1 || echo "eth0"
}

render_dashboard() {
    update_terminal_size
    clear_screen

    local half=$(( TERM_COLS / 2 ))
    local row=1

    # ヘッダー
    printf "${C_BG_GRAY}${C_BOLD}"
    printf "%-*s" "$TERM_COLS" "  システムダッシュボード  $(get_timestamp)  [q=終了 r=更新 +/-=間隔(${refresh_interval}s)]"
    printf "${C_RESET}\n"
    (( row++ ))

    # CPU
    local cpu_pct load1 load5 load15
    cpu_pct=$(get_cpu_usage)
    read -r load1 load5 load15 <<< "$(get_load)"
    local cpu_int="${cpu_pct%.*}"

    move_cursor $((row)) 1
    printf "${C_BOLD}${C_CYAN} CPU${C_RESET}"
    move_cursor $((row+1)) 2
    printf "使用率: ${C_BOLD}%5s%%${C_RESET}  " "$cpu_pct"
    make_bar "${cpu_int:-0}" $(( half - 20 ))
    move_cursor $((row+2)) 2
    printf "ロード: ${C_DIM}%s %s %s${C_RESET} (1/5/15分)" "$load1" "$load5" "$load15"
    (( row += 4 ))

    # メモリ
    local mem_total mem_used mem_pct swap_total swap_used swap_pct
    read -r mem_total mem_used mem_pct swap_total swap_used swap_pct <<< "$(get_mem_info)"
    local mem_total_mb=$(( mem_total / 1024 ))
    local mem_used_mb=$(( mem_used / 1024 ))

    move_cursor $((row)) 1
    printf "${C_BOLD}${C_CYAN} メモリ${C_RESET}"
    move_cursor $((row+1)) 2
    printf "RAM:   ${C_BOLD}%s/${C_RESET}%s MB  " "$mem_used_mb" "$mem_total_mb"
    make_bar "${mem_pct:-0}" $(( half - 22 ))
    printf "  ${C_BOLD}%d%%${C_RESET}" "$mem_pct"

    if (( swap_total > 0 )); then
        local swap_used_mb=$(( swap_used / 1024 ))
        local swap_total_mb=$(( swap_total / 1024 ))
        move_cursor $((row+2)) 2
        printf "Swap:  %s/%s MB  " "$swap_used_mb" "$swap_total_mb"
        make_bar "${swap_pct:-0}" $(( half - 22 ))
        printf "  %d%%" "$swap_pct"
    fi
    (( row += 4 ))

    # ディスク
    move_cursor $((row)) 1
    printf "${C_BOLD}${C_CYAN} ディスク${C_RESET}"
    (( row++ ))
    while IFS= read -r line; do
        local mount pct used avail
        read -r mount pct used avail <<< "$line"
        local pct_num="${pct%\%}"
        move_cursor $((row)) 2
        printf "%-15s " "${mount:0:15}"
        make_bar "${pct_num:-0}" $(( half - 28 ))
        printf "  ${C_BOLD}%5s${C_RESET} (%s/%s)" "$pct" "$used" "$avail"
        (( row++ ))
    done < <(get_disk_usage)
    (( row++ ))

    # ネットワーク
    local iface
    iface=$(get_net_iface)
    local rx tx
    read -r rx tx <<< "$(get_net_speed "$iface")"

    move_cursor $((row)) 1
    printf "${C_BOLD}${C_CYAN} ネットワーク${C_RESET} ${C_DIM}(${iface})${C_RESET}"
    move_cursor $((row+1)) 2
    printf "受信: ${C_GREEN}%-15s${C_RESET}  送信: ${C_YELLOW}%s${C_RESET}" \
        "$(format_net "$rx")" "$(format_net "$tx")"
    (( row += 3 ))

    # トッププロセス
    move_cursor $((row)) 1
    printf "${C_BOLD}${C_CYAN} トッププロセス${C_RESET}"
    (( row++ ))
    printf "${C_DIM}  %-15s %6s %6s %s${C_RESET}\n" "ユーザー" "CPU%" "MEM%" "コマンド"
    (( row++ ))
    while IFS=' ' read -r user cpu mem cmd; do
        move_cursor $((row)) 2
        local cpu_color="$C_GREEN"
        local cpu_int="${cpu%.*}"
        (( ${cpu_int:-0} > 30 )) && cpu_color="$C_YELLOW"
        (( ${cpu_int:-0} > 70 )) && cpu_color="$C_RED"
        printf "%-15s ${cpu_color}%6s${C_RESET} %6s ${C_DIM}%s${C_RESET}" \
            "${user:0:15}" "$cpu" "$mem" "${cmd:0:$(( TERM_COLS - 35 ))}"
        (( row++ ))
    done < <(get_top_procs)

    # フッター
    move_cursor $(( TERM_ROWS )) 1
    printf "${C_BG_GRAY}${C_DIM}%-*s${C_RESET}" "$TERM_COLS" \
        "  ホスト: $(hostname)  カーネル: $(uname -r)  稼働: $(uptime -p 2>/dev/null | sed 's/up //')"
}

run_dashboard() {
    local cleanup_done=false
    cleanup() {
        $cleanup_done && return
        cleanup_done=true
        show_cursor
        printf '\033[?1049l'
        stty "$ORIG_STTY" 2>/dev/null || true
    }
    trap cleanup EXIT INT TERM

    local ORIG_STTY
    ORIG_STTY=$(stty -g)
    printf '\033[?1049h'
    hide_cursor
    stty -echo -icanon min 0 time 0

    while true; do
        render_dashboard

        local key=""
        IFS= read -r -s -n1 -t "$refresh_interval" key 2>/dev/null || true

        case "$key" in
            q|Q) break ;;
            r|R) continue ;;
            +)   (( refresh_interval < 60 )) && (( refresh_interval++ )) ;;
            -)   (( refresh_interval > 1  )) && (( refresh_interval-- )) ;;
        esac
    done
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -i|--interval) [[ $# -lt 2 ]] && error_exit "--interval には値が必要です"; refresh_interval="$2"; shift 2 ;;
            -c|--compact) compact_mode=1; shift ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  shift ;;
        esac
    done
}

main() {
    parse_arguments "$@"
    run_dashboard
}

main "$@"
