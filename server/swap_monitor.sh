#!/bin/bash
set -euo pipefail

#
# スワップ使用量監視ツール
# 作成日: 2026-07-30
# バージョン: 1.0
#
# システムのスワップ使用量を監視し、プロセス別に表示します
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare command_name="status"
declare warn_threshold=50
declare critical_threshold=80
declare watch_interval=5
declare top_n=10
declare alert_cmd=""

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション]

スワップ使用量の監視ツールです。

コマンド:
  status                 スワップ状態を表示 (デフォルト)
  procs                  プロセス別スワップ使用量
  watch                  リアルタイム監視
  history                使用量の推移を記録
  clear                  スワップをクリア (要root)

オプション:
  -h, --help             このヘルプを表示
  -v, --version          バージョン情報を表示
  -n, --top <数>         上位表示件数 [デフォルト: 10]
  -w, --warn <数>        警告閾値% [デフォルト: 50]
  -c, --critical <数>    危険閾値% [デフォルト: 80]
  -i, --interval <秒>    監視間隔秒 [デフォルト: 5]
  --alert <コマンド>     アラート時に実行するコマンド

例:
  $PROG_NAME
  $PROG_NAME procs -n 20
  $PROG_NAME watch -i 3 -w 40 -c 70
  $PROG_NAME clear
EOF
}

get_swap_info() {
    awk '/SwapTotal/ {total=$2} /SwapFree/ {free=$2} END {
        used = total - free
        pct  = total > 0 ? used * 100 / total : 0
        printf "%d %d %d %.1f\n", total, used, free, pct
    }' /proc/meminfo
}

draw_swap_bar() {
    local pct=$1
    local width=40
    local filled=$(( pct * width / 100 ))
    local color="$C_GREEN"
    (( pct >= warn_threshold ))     && color="$C_YELLOW"
    (( pct >= critical_threshold )) && color="$C_RED"

    printf "${color}"
    printf '%0.s█' $(seq 1 $filled 2>/dev/null) || true
    printf "${C_RESET}"
    printf '%0.s░' $(seq 1 $(( width - filled )) 2>/dev/null) || true
}

cmd_status() {
    read -r total used free pct <<< "$(get_swap_info)"

    local total_mb=$(( total / 1024 ))
    local used_mb=$(( used / 1024 ))
    local free_mb=$(( free / 1024 ))
    local pct_int=${pct%.*}

    echo ""
    printf "${C_BOLD}=== スワップ使用状況 ===${C_RESET}\n"
    echo ""
    printf "  合計  : %d MB\n" "$total_mb"
    printf "  使用中: ${C_YELLOW}%d MB${C_RESET}\n" "$used_mb"
    printf "  空き  : ${C_GREEN}%d MB${C_RESET}\n" "$free_mb"
    echo ""
    printf "  使用率: "
    draw_swap_bar "${pct_int:-0}"
    printf " ${C_BOLD}%.1f%%${C_RESET}\n" "$pct"
    echo ""

    if (( pct_int >= critical_threshold )); then
        log_error "スワップ使用率が危険レベルです: ${pct}%"
        [[ -n "$alert_cmd" ]] && eval "$alert_cmd" || true
    elif (( pct_int >= warn_threshold )); then
        log_warning "スワップ使用率が警告レベルです: ${pct}%"
    else
        log_success "スワップ使用率は正常範囲です: ${pct}%"
    fi
    echo ""

    # メモリ情報も表示
    printf "${C_BOLD}【メモリ情報】${C_RESET}\n"
    local mem_total mem_free mem_available mem_used mem_pct
    mem_total=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
    mem_available=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
    mem_used=$(( mem_total - mem_available ))
    mem_pct=$(( mem_used * 100 / (mem_total > 0 ? mem_total : 1) ))
    printf "  RAM使用率: "
    draw_swap_bar "$mem_pct"
    printf " ${C_BOLD}%d%%${C_RESET} (%d/%d MB)\n" "$mem_pct" "$(( mem_used / 1024 ))" "$(( mem_total / 1024 ))"
    echo ""
}

cmd_procs() {
    if [[ ! -r /proc/1/status ]]; then
        error_exit "/proc へのアクセス権限がありません"
    fi

    log_info "プロセス別スワップ使用量を集計中..."
    echo ""

    printf "${C_BOLD}%8s %-25s %10s %10s${C_RESET}\n" "PID" "プロセス名" "スワップ(KB)" "RSS(KB)"
    printf "%s\n" "$(printf '%.0s─' {1..60})"

    local count=0
    for pid_dir in /proc/[0-9]*/; do
        local pid="${pid_dir%/}"
        pid="${pid##*/proc/}"
        local status_file="/proc/$pid/status"
        [[ ! -r "$status_file" ]] && continue

        local swap_kb rss name
        swap_kb=$(awk '/VmSwap/ {print $2}' "$status_file" 2>/dev/null || echo 0)
        rss=$(awk '/VmRSS/ {print $2}' "$status_file" 2>/dev/null || echo 0)
        name=$(awk '/^Name/ {print $2}' "$status_file" 2>/dev/null || echo "?")

        [[ "${swap_kb:-0}" -eq 0 ]] && continue
        echo "${swap_kb:-0} $pid $name ${rss:-0}"
    done | sort -rn | head -"$top_n" | while read -r swap_kb pid name rss; do
        local color="$C_GREEN"
        (( swap_kb > 102400 )) && color="$C_YELLOW"
        (( swap_kb > 512000 )) && color="$C_RED"
        printf "  ${C_DIM}%6s${C_RESET} %-25s ${color}%10d${C_RESET} %10d\n" \
            "$pid" "${name:0:25}" "$swap_kb" "${rss:-0}"
    done
    echo ""
}

cmd_watch() {
    local cleanup_done=false
    cleanup() {
        $cleanup_done && return
        cleanup_done=true
        show_cursor
        printf '\033[?1049l'
    }
    trap cleanup EXIT INT TERM

    printf '\033[?1049h'
    hide_cursor

    while true; do
        clear_screen
        update_terminal_size

        print_center "スワップ監視ダッシュボード" 1 "$C_CYAN"
        draw_separator 2

        local ts
        ts=$(get_timestamp)
        move_cursor 3 2
        printf "${C_DIM}更新: %s  間隔: %ds  q=終了${C_RESET}" "$ts" "$watch_interval"

        move_cursor 5 2
        read -r total used free pct <<< "$(get_swap_info)"
        local pct_int=${pct%.*}
        local total_mb=$(( total / 1024 ))
        local used_mb=$(( used / 1024 ))

        printf "${C_BOLD}スワップ: %d/%d MB (%.1f%%)${C_RESET}" "$used_mb" "$total_mb" "$pct"
        move_cursor 6 2
        draw_swap_bar "${pct_int:-0}"

        local status_color="$C_GREEN"
        local status_msg="正常"
        if (( pct_int >= critical_threshold )); then
            status_color="$C_RED"
            status_msg="危険"
            [[ -n "$alert_cmd" ]] && eval "$alert_cmd" || true
        elif (( pct_int >= warn_threshold )); then
            status_color="$C_YELLOW"
            status_msg="警告"
        fi
        printf " ${status_color}${C_BOLD}[%s]${C_RESET}" "$status_msg"

        move_cursor 8 2
        printf "${C_BOLD}プロセス別TOP${top_n}:${C_RESET}"

        local row=9
        for pid_dir in /proc/[0-9]*/; do
            local pid="${pid_dir%/}"
            pid="${pid##*/proc/}"
            local status_file="/proc/$pid/status"
            [[ ! -r "$status_file" ]] && continue
            local swap_kb name
            swap_kb=$(awk '/VmSwap/ {print $2}' "$status_file" 2>/dev/null || echo 0)
            name=$(awk '/^Name/ {print $2}' "$status_file" 2>/dev/null || echo "?")
            [[ "${swap_kb:-0}" -eq 0 ]] && continue
            echo "${swap_kb:-0} $pid $name"
        done | sort -rn | head -"$top_n" | while read -r swap_kb pid name; do
            move_cursor $row 4
            printf "${C_DIM}%5s${C_RESET} %-20s ${C_YELLOW}%8d KB${C_RESET}" \
                "$pid" "${name:0:20}" "$swap_kb"
            (( row++ )) || true
        done

        if read -rsn1 -t "$watch_interval" key 2>/dev/null; then
            [[ "$key" == "q" || "$key" == "Q" ]] && break
        fi
    done
}

cmd_clear() {
    if [[ $EUID -ne 0 ]]; then
        error_exit "スワップのクリアにはroot権限が必要です"
    fi

    read -r _ used _ _ <<< "$(get_swap_info)"
    local used_mb=$(( used / 1024 ))

    if [[ $used_mb -eq 0 ]]; then
        log_info "スワップは使用されていません"
        return
    fi

    log_warning "スワップをクリアします (使用中: ${used_mb}MB)"
    if ! confirm "続行しますか？" "n"; then
        log_info "キャンセルしました"
        return
    fi

    log_info "スワップをオフにしています..."
    swapoff -a
    log_info "スワップをオンにしています..."
    swapon -a
    log_success "スワップをクリアしました"
}

parse_arguments() {
    [[ $# -eq 0 ]] && return 0

    case "$1" in
        status|procs|watch|history|clear)
            command_name="$1"; shift ;;
    esac

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -n|--top)
                [[ $# -lt 2 ]] && error_exit "--top には値が必要です"
                top_n="$2"; shift 2 ;;
            -w|--warn)
                [[ $# -lt 2 ]] && error_exit "--warn には値が必要です"
                warn_threshold="$2"; shift 2 ;;
            -c|--critical)
                [[ $# -lt 2 ]] && error_exit "--critical には値が必要です"
                critical_threshold="$2"; shift 2 ;;
            -i|--interval)
                [[ $# -lt 2 ]] && error_exit "--interval には値が必要です"
                watch_interval="$2"; shift 2 ;;
            --alert)
                [[ $# -lt 2 ]] && error_exit "--alert には値が必要です"
                alert_cmd="$2"; shift 2 ;;
            *) error_exit "不明なオプション: $1" ;;
        esac
    done
}

main() {
    parse_arguments "$@"
    case "$command_name" in
        status)  cmd_status ;;
        procs)   cmd_procs ;;
        watch)   cmd_watch ;;
        clear)   cmd_clear ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
