#!/bin/bash
set -euo pipefail

#
# メモリ最適化・分析ツール
# 作成日: 2026-07-31
# バージョン: 1.0
#
# システムのメモリ使用状況を分析し、最適化の提案・実行を行います
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare command_name="analyze"
declare top_n=15
declare watch_interval=5
declare threshold_mb=100

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション]

メモリ使用状況の分析・最適化ツールです。

コマンド:
  analyze                メモリ使用状況を分析 (デフォルト)
  procs                  プロセス別メモリランキング
  watch                  リアルタイム監視
  leaks                  メモリリーク疑いプロセス検出
  optimize               メモリ最適化を実行 (要root)
  report                 詳細レポートを生成

オプション:
  -h, --help             このヘルプを表示
  -v, --version          バージョン情報を表示
  -n, --top <数>         上位表示件数 [デフォルト: 15]
  -i, --interval <秒>    監視間隔 [デフォルト: 5]
  -t, --threshold <MB>   警告閾値MB [デフォルト: 100]

例:
  $PROG_NAME
  $PROG_NAME procs -n 20
  $PROG_NAME watch -i 3
  $PROG_NAME leaks -t 500
EOF
}

get_mem_info() {
    awk '
        /MemTotal/     {total=$2}
        /MemFree/      {free=$2}
        /MemAvailable/ {available=$2}
        /Buffers/      {buffers=$2}
        /^Cached/      {cached=$2}
        /SwapTotal/    {swap_total=$2}
        /SwapFree/     {swap_free=$2}
        END {
            used = total - free - buffers - cached
            swap_used = swap_total - swap_free
            pct = total > 0 ? used * 100 / total : 0
            printf "%d %d %d %d %d %d %d %.1f\n",
                total, used, free, buffers, cached, available, swap_total-swap_free, pct
        }
    ' /proc/meminfo
}

mini_bar() {
    local pct=${1%.*}
    local width=30
    local filled=$(( pct * width / 100 ))
    local color="$C_GREEN"
    (( pct >= 70 )) && color="$C_YELLOW"
    (( pct >= 90 )) && color="$C_RED"
    printf "${color}"
    printf '%0.s█' $(seq 1 $filled 2>/dev/null) || true
    printf "${C_RESET}"
    printf '%0.s░' $(seq 1 $(( width - filled )) 2>/dev/null) || true
}

to_mb() { echo $(( $1 / 1024 )); }

cmd_analyze() {
    read -r total used free buffers cached available swap_used pct <<< "$(get_mem_info)"

    local total_mb used_mb free_mb buf_mb cache_mb avail_mb swap_mb
    total_mb=$(to_mb $total)
    used_mb=$(to_mb $used)
    free_mb=$(to_mb $free)
    buf_mb=$(to_mb $buffers)
    cache_mb=$(to_mb $cached)
    avail_mb=$(to_mb $available)
    swap_mb=$(to_mb $swap_used)
    local pct_int=${pct%.*}

    echo ""
    printf "${C_BOLD}${C_CYAN}=== メモリ分析レポート ===${C_RESET}\n\n"
    printf "  ${C_BOLD}合計RAM${C_RESET}    : %d MB\n" "$total_mb"
    printf "  ${C_BOLD}使用中${C_RESET}     : "
    mini_bar "$pct_int"
    printf " ${C_BOLD}%.1f%%${C_RESET} (%d MB)\n" "$pct" "$used_mb"
    printf "  ${C_BOLD}利用可能${C_RESET}   : ${C_GREEN}%d MB${C_RESET}\n" "$avail_mb"
    printf "  ${C_BOLD}バッファ${C_RESET}   : ${C_DIM}%d MB${C_RESET}\n" "$buf_mb"
    printf "  ${C_BOLD}キャッシュ${C_RESET} : ${C_DIM}%d MB${C_RESET}\n" "$cache_mb"
    printf "  ${C_BOLD}スワップ${C_RESET}   : "
    if [[ $swap_mb -gt 0 ]]; then
        printf "${C_YELLOW}%d MB 使用中${C_RESET}\n" "$swap_mb"
    else
        printf "${C_GREEN}未使用${C_RESET}\n"
    fi

    echo ""
    printf "${C_BOLD}【診断】${C_RESET}\n"
    if (( pct_int >= 90 )); then
        log_error "メモリ使用率が危険レベルです (${pct}%)"
        printf "  推奨: 不要なプロセスの終了またはメモリ増設\n"
    elif (( pct_int >= 70 )); then
        log_warning "メモリ使用率が高めです (${pct}%)"
        printf "  推奨: 使用量の多いプロセスを確認してください\n"
    else
        log_success "メモリ使用率は正常です (${pct}%)"
    fi

    if [[ $swap_mb -gt 0 ]]; then
        echo ""
        log_warning "スワップが使用されています (${swap_mb}MB)"
        printf "  推奨: メモリ不足の可能性があります\n"
    fi
    echo ""
}

cmd_procs() {
    log_info "プロセス別メモリランキングを取得中..."
    echo ""

    printf "${C_BOLD}%8s %-25s %10s %10s %6s${C_RESET}\n" \
        "PID" "プロセス名" "RSS(MB)" "VSZ(MB)" "共有(MB)"
    printf "%s\n" "$(printf '%.0s─' {1..65})"

    ps aux --sort=-%mem 2>/dev/null | tail -n +2 | head -"$top_n" | \
    awk '{printf "%8s %-25s %10.1f %10.1f %6.1f\n", $2, substr($11,1,25), $6/1024, $5/1024, $6/1024*0.3}' | \
    while IFS= read -r line; do
        local mem
        mem=$(echo "$line" | awk '{print $3}')
        local mem_int=${mem%.*}
        local color=""
        (( mem_int >= 500 )) && color="$C_YELLOW"
        (( mem_int >= 1000 )) && color="$C_RED"
        printf "  ${color}%s${C_RESET}\n" "$line"
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
        print_center "メモリ監視ダッシュボード" 1 "$C_CYAN"
        draw_separator 2
        move_cursor 3 2
        printf "${C_DIM}更新: $(get_timestamp)  間隔: ${watch_interval}s  q=終了${C_RESET}"

        read -r total used _ _ _ _ swap_used pct <<< "$(get_mem_info)"
        local pct_int=${pct%.*}
        local total_mb used_mb swap_mb
        total_mb=$(to_mb $total)
        used_mb=$(to_mb $used)
        swap_mb=$(to_mb $swap_used)

        move_cursor 5 2
        printf "${C_BOLD}RAM使用率: %d/%d MB (%.1f%%)${C_RESET}" "$used_mb" "$total_mb" "$pct"
        move_cursor 6 2
        mini_bar "$pct_int"

        if [[ $swap_mb -gt 0 ]]; then
            move_cursor 8 2
            printf "${C_YELLOW}スワップ: %d MB 使用中${C_RESET}" "$swap_mb"
        fi

        move_cursor 10 2
        printf "${C_BOLD}TOP ${top_n} プロセス (RSS):${C_RESET}"

        local row=11
        ps aux --sort=-%mem 2>/dev/null | tail -n +2 | head -"$top_n" | \
        awk '{printf "%s|%.1f|%s\n", $2, $6/1024, substr($11,1,22)}' | \
        while IFS='|' read -r pid mem name; do
            move_cursor $row 4
            printf "${C_DIM}%6s${C_RESET} %-22s ${C_YELLOW}%6.1f MB${C_RESET}" "$pid" "$name" "$mem"
            (( row++ )) || true
        done

        if read -rsn1 -t "$watch_interval" key 2>/dev/null; then
            [[ "$key" == "q" || "$key" == "Q" ]] && break
        fi
    done
}

cmd_leaks() {
    log_info "メモリリーク疑いのプロセスを検索中..."
    echo ""

    local threshold_kb=$(( threshold_mb * 1024 ))

    printf "${C_BOLD}%-8s %-25s %12s %s${C_RESET}\n" "PID" "プロセス名" "RSS(MB)" "状態"
    printf "%s\n" "$(printf '%.0s─' {1..60})"

    ps aux --sort=-%mem 2>/dev/null | tail -n +2 | \
    awk -v thr="$threshold_kb" '$6 > thr {print $2, $11, $6}' | \
    head -"$top_n" | while read -r pid name rss_kb; do
        local rss_mb=$(( rss_kb / 1024 ))
        local elapsed
        elapsed=$(ps -p "$pid" -o etime= 2>/dev/null | tr -d ' ' || echo "N/A")
        local color="$C_YELLOW"
        (( rss_mb >= 1000 )) && color="$C_RED"
        printf "  ${color}%-6s${C_RESET} %-25s ${color}%10d MB${C_RESET} 実行時間: %s\n" \
            "$pid" "${name:0:25}" "$rss_mb" "$elapsed"
    done
    echo ""
    log_info "しきい値: ${threshold_mb}MB 以上 (--threshold で変更可)"
}

cmd_optimize() {
    if [[ $EUID -ne 0 ]]; then
        error_exit "最適化にはroot権限が必要です"
    fi

    log_info "メモリ最適化を実行中..."

    # ページキャッシュのクリア
    if confirm "ページキャッシュをクリアしますか？ (I/O増加の可能性あり)" "n"; then
        sync
        echo 1 > /proc/sys/vm/drop_caches
        log_success "ページキャッシュをクリアしました"
    fi

    # dentryとinodeキャッシュのクリア
    if confirm "dentryとinodeキャッシュをクリアしますか？" "n"; then
        sync
        echo 2 > /proc/sys/vm/drop_caches
        log_success "dentryとinodeキャッシュをクリアしました"
    fi

    echo ""
    log_info "最適化後のメモリ状態:"
    cmd_analyze
}

cmd_report() {
    log_info "詳細メモリレポートを生成中..."
    echo ""

    cmd_analyze
    cmd_procs
    cmd_leaks

    # /proc/meminfo の全情報
    printf "${C_BOLD}【/proc/meminfo 詳細】${C_RESET}\n"
    cat /proc/meminfo | while IFS= read -r line; do
        local key val unit
        key=$(echo "$line" | awk '{print $1}')
        val=$(echo "$line" | awk '{print $2}')
        unit=$(echo "$line" | awk '{print $3}')
        if [[ -n "$val" && "$val" =~ ^[0-9]+$ && -n "$unit" ]]; then
            printf "  %-25s %8d %s (%d MB)\n" "$key" "$val" "$unit" "$(( val / 1024 ))"
        else
            printf "  %s\n" "$line"
        fi
    done
    echo ""
}

parse_arguments() {
    [[ $# -eq 0 ]] && return 0
    case "$1" in
        analyze|procs|watch|leaks|optimize|report)
            command_name="$1"; shift ;;
    esac

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -n|--top)     [[ $# -lt 2 ]] && error_exit "--top には値が必要です"; top_n="$2"; shift 2 ;;
            -i|--interval) [[ $# -lt 2 ]] && error_exit "--interval には値が必要です"; watch_interval="$2"; shift 2 ;;
            -t|--threshold) [[ $# -lt 2 ]] && error_exit "--threshold には値が必要です"; threshold_mb="$2"; shift 2 ;;
            *) error_exit "不明なオプション: $1" ;;
        esac
    done
}

main() {
    parse_arguments "$@"
    case "$command_name" in
        analyze)  cmd_analyze ;;
        procs)    cmd_procs ;;
        watch)    cmd_watch ;;
        leaks)    cmd_leaks ;;
        optimize) cmd_optimize ;;
        report)   cmd_report ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
