#!/bin/bash
set -euo pipefail

#
# システムヘルスダッシュボード
# バージョン: 1.0
#
# サーバーの健全性を一画面で確認できるTUIダッシュボード
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare -i refresh_sec=5
declare -a check_services=()
declare -a check_urls=()
declare -a check_ports=()
declare output_once=false

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション]

システムヘルスダッシュボード

オプション:
  -h, --help              このヘルプを表示
  -v, --version           バージョン情報を表示
  -r, --refresh SEC       更新間隔秒数 [デフォルト: 5]
  -s, --service SVC       監視するsystemdサービス (複数可)
  -u, --url URL           HTTPチェックURL (複数可)
  -p, --port HOST:PORT    TCPポートチェック (複数可)
  --once                  1回だけ表示して終了

例:
  $PROG_NAME
  $PROG_NAME -s nginx -s mysql -s redis
  $PROG_NAME -u http://localhost -u http://localhost:8080
  $PROG_NAME -p localhost:3306 -p localhost:6379
  $PROG_NAME --once

EOF
}

get_cpu_usage() {
    local idle
    idle=$(vmstat 1 2 2>/dev/null | tail -1 | awk '{print $15}' || echo 100)
    echo $(( 100 - idle ))
}

get_mem_info() {
    local total avail used pct
    total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    avail=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    used=$(( total - avail ))
    pct=$(( used * 100 / total ))
    echo "${used}|${total}|${pct}"
}

get_disk_info() {
    df -h / 2>/dev/null | tail -1 | awk '{print $3"|"$2"|"$5}' | tr -d '%'
}

get_load() {
    cat /proc/loadavg 2>/dev/null | awk '{print $1, $2, $3}'
}

check_service() {
    local svc="$1"
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
        echo "OK"
    else
        echo "FAIL"
    fi
}

check_http() {
    local url="$1"
    local code
    code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 "$url" 2>/dev/null || echo "000")
    if (( code >= 200 && code < 400 )); then
        echo "OK:$code"
    else
        echo "FAIL:$code"
    fi
}

check_tcp_port() {
    local host="${1%%:*}"
    local port="${1##*:}"
    if timeout 2 bash -c "echo >/dev/tcp/${host}/${port}" 2>/dev/null; then
        echo "OK"
    else
        echo "FAIL"
    fi
}

get_top_procs() {
    ps aux --sort=-%cpu 2>/dev/null | tail -n +2 | head -5 | \
        awk '{printf "%s|%.1f|%.1f|%s\n", $1, $3, $4, $11}'
}

render_dashboard() {
    local timestamp
    timestamp=$(get_timestamp)

    update_terminal_size

    clear_screen

    # ===== ヘッダー =====
    print_center "システムヘルスダッシュボード" 1 "$C_CYAN"
    move_cursor 2 2
    printf "${C_DIM}ホスト: $(hostname)  更新: %s  間隔: %ds  q=終了  r=手動更新${C_RESET}" \
        "$timestamp" "$refresh_sec"
    draw_separator 3

    local row=5

    # ===== CPU =====
    move_cursor $row 2
    local cpu_pct
    cpu_pct=$(get_cpu_usage)
    local cpu_color="$C_GREEN"
    (( cpu_pct >= 70 )) && cpu_color="$C_YELLOW"
    (( cpu_pct >= 90 )) && cpu_color="$C_RED"

    printf "${C_BOLD}CPU使用率${C_RESET}\n"
    (( row++ )) || true
    move_cursor $row 4
    draw_progress_bar "$cpu_pct" 100 30
    printf " ${cpu_color}%d%%${C_RESET}\n" "$cpu_pct"
    (( row += 2 )) || true

    # ===== メモリ =====
    move_cursor $row 2
    local mem_info
    mem_info=$(get_mem_info)
    local mem_used="${mem_info%%|*}"
    local mem_rest="${mem_info#*|}"
    local mem_total="${mem_rest%%|*}"
    local mem_pct="${mem_rest##*|}"
    local mem_used_mb=$(( mem_used / 1024 ))
    local mem_total_mb=$(( mem_total / 1024 ))

    local mem_color="$C_GREEN"
    (( mem_pct >= 70 )) && mem_color="$C_YELLOW"
    (( mem_pct >= 90 )) && mem_color="$C_RED"

    printf "${C_BOLD}メモリ使用率${C_RESET}\n"
    (( row++ )) || true
    move_cursor $row 4
    draw_progress_bar "$mem_pct" 100 30
    printf " ${mem_color}%d%%${C_RESET} (%d/%d MB)\n" "$mem_pct" "$mem_used_mb" "$mem_total_mb"
    (( row += 2 )) || true

    # ===== ディスク =====
    move_cursor $row 2
    local disk_info
    disk_info=$(get_disk_info)
    local disk_used="${disk_info%%|*}"
    local disk_rest="${disk_info#*|}"
    local disk_total="${disk_rest%%|*}"
    local disk_pct="${disk_rest##*|}"

    local disk_color="$C_GREEN"
    (( disk_pct >= 70 )) && disk_color="$C_YELLOW"
    (( disk_pct >= 90 )) && disk_color="$C_RED"

    printf "${C_BOLD}ディスク使用率 (/)${C_RESET}\n"
    (( row++ )) || true
    move_cursor $row 4
    draw_progress_bar "$disk_pct" 100 30
    printf " ${disk_color}%d%%${C_RESET} (%s/%s)\n" "$disk_pct" "$disk_used" "$disk_total"
    (( row += 2 )) || true

    # ===== ロードアベレージ =====
    move_cursor $row 2
    local load
    load=$(get_load)
    printf "${C_BOLD}ロードアベレージ:${C_RESET} %s\n" "$load"
    (( row += 2 )) || true

    # ===== サービス状態 =====
    if [[ ${#check_services[@]} -gt 0 ]]; then
        draw_separator $row
        (( row++ )) || true
        move_cursor $row 2
        printf "${C_BOLD}サービス状態${C_RESET}\n"
        (( row++ )) || true

        for svc in "${check_services[@]}"; do
            move_cursor $row 4
            local status
            status=$(check_service "$svc")
            if [[ "$status" == "OK" ]]; then
                printf "${C_GREEN}●${C_RESET} %-20s ${C_GREEN}稼働中${C_RESET}\n" "$svc"
            else
                printf "${C_RED}●${C_RESET} %-20s ${C_RED}停止中${C_RESET}\n" "$svc"
            fi
            (( row++ )) || true
        done
        (( row++ )) || true
    fi

    # ===== URLチェック =====
    if [[ ${#check_urls[@]} -gt 0 ]]; then
        draw_separator $row
        (( row++ )) || true
        move_cursor $row 2
        printf "${C_BOLD}HTTPチェック${C_RESET}\n"
        (( row++ )) || true

        for url in "${check_urls[@]}"; do
            move_cursor $row 4
            local http_result
            http_result=$(check_http "$url")
            local http_status="${http_result%%:*}"
            local http_code="${http_result##*:}"
            if [[ "$http_status" == "OK" ]]; then
                printf "${C_GREEN}●${C_RESET} %-35s ${C_GREEN}%s${C_RESET}\n" "${url:0:34}" "HTTP $http_code"
            else
                printf "${C_RED}●${C_RESET} %-35s ${C_RED}%s${C_RESET}\n" "${url:0:34}" "HTTP $http_code"
            fi
            (( row++ )) || true
        done
        (( row++ )) || true
    fi

    # ===== ポートチェック =====
    if [[ ${#check_ports[@]} -gt 0 ]]; then
        draw_separator $row
        (( row++ )) || true
        move_cursor $row 2
        printf "${C_BOLD}ポートチェック${C_RESET}\n"
        (( row++ )) || true

        for hostport in "${check_ports[@]}"; do
            move_cursor $row 4
            local tcp_result
            tcp_result=$(check_tcp_port "$hostport")
            if [[ "$tcp_result" == "OK" ]]; then
                printf "${C_GREEN}●${C_RESET} %-25s ${C_GREEN}接続OK${C_RESET}\n" "$hostport"
            else
                printf "${C_RED}●${C_RESET} %-25s ${C_RED}接続NG${C_RESET}\n" "$hostport"
            fi
            (( row++ )) || true
        done
        (( row++ )) || true
    fi

    # ===== Top プロセス =====
    draw_separator $row
    (( row++ )) || true
    move_cursor $row 2
    printf "${C_BOLD}CPU使用率 Top 5${C_RESET}\n"
    (( row++ )) || true
    move_cursor $row 4
    printf "${C_DIM}%-12s %6s %6s %s${C_RESET}\n" "ユーザー" "CPU%" "MEM%" "コマンド"
    (( row++ )) || true

    get_top_procs | while IFS='|' read -r user cpu mem cmd; do
        [[ $row -ge $(( TERM_ROWS - 2 )) ]] && break
        move_cursor $row 4
        printf "%-12s ${C_YELLOW}%6s${C_RESET} %6s %s\n" "${user:0:11}" "$cpu" "$mem" "${cmd:0:30}"
        (( row++ )) || true
    done
}

do_monitor() {
    local cleanup_called=false
    cleanup_dash() {
        $cleanup_called && return
        cleanup_called=true
        show_cursor
        clear_screen
        echo ""
    }
    trap cleanup_dash EXIT INT TERM
    hide_cursor

    while true; do
        render_dashboard

        if $output_once; then
            show_cursor
            break
        fi

        local key=""
        IFS= read -r -s -n1 -t "$refresh_sec" key 2>/dev/null || true
        case "${key:-}" in
            q|Q) break ;;
            r|R) continue ;;
        esac
    done
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -r|--refresh) [[ $# -lt 2 ]] && error_exit "-r には値が必要です"; refresh_sec="$2"; shift 2 ;;
            -s|--service) [[ $# -lt 2 ]] && error_exit "-s には値が必要です"; check_services+=("$2"); shift 2 ;;
            -u|--url)     [[ $# -lt 2 ]] && error_exit "-u には値が必要です"; check_urls+=("$2"); shift 2 ;;
            -p|--port)    [[ $# -lt 2 ]] && error_exit "-p には値が必要です"; check_ports+=("$2"); shift 2 ;;
            --once)       output_once=true; shift ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  shift ;;
        esac
    done
}

main() {
    parse_arguments "$@"
    do_monitor
}

main "$@"
