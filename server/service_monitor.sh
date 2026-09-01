#!/bin/bash
set -euo pipefail

#
# サービス監視ツール
# 作成日: 2026-09-01
# バージョン: 1.0
#
# systemdサービスの状態監視・自動復旧・アラート通知を行います
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare command_name="status"
declare watch_interval=30
declare auto_restart=0
declare notify_cmd=""
declare output_format="text"

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション] [サービス名...]

systemdサービスの監視・管理ツールです。

コマンド:
  status [サービス...]  サービス状態確認 (デフォルト)
  watch [サービス...]   リアルタイム監視
  restart <サービス>    サービスを再起動
  enable <サービス>     自動起動を有効化
  disable <サービス>    自動起動を無効化
  logs <サービス>       ジャーナルログを表示
  failed               障害サービス一覧
  top                  リソース使用量TOP

オプション:
  -h, --help           このヘルプを表示
  -v, --version        バージョン情報を表示
  -i, --interval <秒>  監視間隔 [デフォルト: 30]
  -a, --auto-restart   障害時に自動再起動
  -n, --notify <コマンド> アラート通知コマンド
  -f, --format <形式>  出力形式 (text|json) [デフォルト: text]

例:
  $PROG_NAME status nginx mysql sshd
  $PROG_NAME watch nginx -i 10
  $PROG_NAME failed
  $PROG_NAME top
  $PROG_NAME logs nginx
EOF
}

get_service_state() {
    systemctl is-active "$1" 2>/dev/null || echo "unknown"
}

get_service_enabled() {
    systemctl is-enabled "$1" 2>/dev/null || echo "unknown"
}

get_service_memory() {
    systemctl show "$1" --property=MemoryCurrent --value 2>/dev/null | grep -v "^$\|18446744" || echo "0"
}

get_service_cpu() {
    local pid
    pid=$(systemctl show "$1" --property=MainPID --value 2>/dev/null | tr -d ' ')
    if [[ -n "$pid" && "$pid" != "0" ]]; then
        ps -p "$pid" -o %cpu= 2>/dev/null | tr -d ' ' || echo "0"
    else
        echo "0"
    fi
}

format_bytes() {
    local b="${1:-0}"
    if (( b >= 1073741824 )); then printf "%.1f GB" "$(echo "scale=1; $b/1073741824" | bc)"
    elif (( b >= 1048576 ));  then printf "%.1f MB" "$(echo "scale=1; $b/1048576" | bc)"
    elif (( b >= 1024 ));     then printf "%.1f KB" "$(echo "scale=1; $b/1024" | bc)"
    else printf "%d B" "$b"
    fi
}

print_service_row() {
    local svc="$1"
    local state enabled memory cpu uptime_str

    state=$(get_service_state "$svc")
    enabled=$(get_service_enabled "$svc")
    memory=$(get_service_memory "$svc")
    cpu=$(get_service_cpu "$svc")

    local since
    since=$(systemctl show "$svc" --property=ActiveEnterTimestamp --value 2>/dev/null | grep -v "^$" || echo "")
    if [[ -n "$since" ]]; then
        local since_epoch
        since_epoch=$(date -d "$since" +%s 2>/dev/null || echo 0)
        local now
        now=$(date +%s)
        local diff=$(( now - since_epoch ))
        if (( diff > 86400 )); then
            uptime_str="${diff}d"
        elif (( diff > 3600 )); then
            uptime_str="$(( diff / 3600 ))h"
        else
            uptime_str="$(( diff / 60 ))m"
        fi
    else
        uptime_str="-"
    fi

    local state_color="$C_RED"
    [[ "$state" == "active"   ]] && state_color="$C_GREEN"
    [[ "$state" == "inactive" ]] && state_color="$C_YELLOW"

    local en_color="$C_DIM"
    [[ "$enabled" == "enabled" ]] && en_color="$C_GREEN"

    local mem_str
    mem_str=$(format_bytes "${memory:-0}")

    printf "  %-25s ${state_color}%-10s${C_RESET} ${en_color}%-10s${C_RESET} %8s %6s%% %s\n" \
        "${svc:0:25}" "$state" "$enabled" "$mem_str" "${cpu:-0}" "$uptime_str"
}

cmd_status() {
    local services=("$@")

    if [[ ${#services[@]} -eq 0 ]]; then
        while IFS= read -r svc; do
            [[ -n "$svc" ]] && services+=("$svc")
        done < <(systemctl list-units --type=service --state=active,failed \
            --no-legend --no-pager 2>/dev/null | awk '{print $1}' | sed 's/\.service$//' | head -30)
    fi

    log_info "サービス状態確認"
    echo ""
    printf "${C_BOLD}  %-25s %-10s %-10s %8s %7s %s${C_RESET}\n" \
        "サービス" "状態" "自動起動" "メモリ" "CPU" "稼働時間"
    printf "  %s\n" "$(printf '%.0s─' {1..75})"

    for svc in "${services[@]}"; do
        print_service_row "$svc"
    done
    echo ""
}

cmd_watch() {
    local services=("$@")
    [[ ${#services[@]} -eq 0 ]] && error_exit "監視するサービスを指定してください"

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
        print_center "サービス監視ダッシュボード" 1 "$C_CYAN"
        draw_separator 2
        move_cursor 3 2
        printf "${C_DIM}更新: $(get_timestamp)  間隔: ${watch_interval}s  q=終了${C_RESET}"

        move_cursor 5 2
        printf "${C_BOLD}%-25s %-10s %-10s %8s %7s %s${C_RESET}\n" \
            "サービス" "状態" "自動起動" "メモリ" "CPU" "稼働時間"
        move_cursor 6 2
        printf "%s" "$(printf '%.0s─' {1..72})"

        local row=7
        for svc in "${services[@]}"; do
            local state
            state=$(get_service_state "$svc")
            move_cursor $row 2

            if [[ "$state" != "active" && $auto_restart -eq 1 ]]; then
                log_warning "サービスが停止しています。再起動試みます: $svc"
                systemctl restart "$svc" 2>/dev/null || true
                [[ -n "$notify_cmd" ]] && eval "$notify_cmd '$svc が停止。再起動しました'" 2>/dev/null || true
            fi

            print_service_row "$svc"
            (( row++ ))
        done

        if read -rsn1 -t "$watch_interval" key 2>/dev/null; then
            [[ "$key" == "q" || "$key" == "Q" ]] && break
        fi
    done
}

cmd_restart() {
    local svc="${1:-}"
    [[ -z "$svc" ]] && error_exit "サービス名を指定してください"

    log_info "サービスを再起動: $svc"
    if systemctl restart "$svc" 2>/dev/null; then
        log_success "再起動完了: $svc"
        sleep 1
        local state
        state=$(get_service_state "$svc")
        printf "  状態: %s\n" "$state"
    else
        log_error "再起動失敗: $svc"
        return 1
    fi
}

cmd_enable() {
    local svc="${1:-}"
    [[ -z "$svc" ]] && error_exit "サービス名を指定してください"
    systemctl enable "$svc" 2>/dev/null && log_success "自動起動を有効化: $svc" || log_error "失敗: $svc"
}

cmd_disable() {
    local svc="${1:-}"
    [[ -z "$svc" ]] && error_exit "サービス名を指定してください"
    systemctl disable "$svc" 2>/dev/null && log_success "自動起動を無効化: $svc" || log_error "失敗: $svc"
}

cmd_logs() {
    local svc="${1:-}"
    [[ -z "$svc" ]] && error_exit "サービス名を指定してください"
    log_info "ジャーナルログ: $svc"
    journalctl -u "$svc" --no-pager -n 50 2>/dev/null | while IFS= read -r line; do
        if echo "$line" | grep -qi "error\|fail\|crit"; then
            printf "${C_RED}%s${C_RESET}\n" "$line"
        elif echo "$line" | grep -qi "warn"; then
            printf "${C_YELLOW}%s${C_RESET}\n" "$line"
        else
            printf "${C_DIM}%s${C_RESET}\n" "$line"
        fi
    done
}

cmd_failed() {
    log_info "障害サービス一覧"
    echo ""
    local failed_svcs
    failed_svcs=$(systemctl list-units --type=service --state=failed \
        --no-legend --no-pager 2>/dev/null | awk '{print $1}' | sed 's/\.service$//')

    if [[ -z "$failed_svcs" ]]; then
        log_success "障害サービスはありません"
        echo ""
        return
    fi

    printf "${C_BOLD}  %-25s %-20s %s${C_RESET}\n" "サービス" "状態" "詳細"
    printf "  %s\n" "$(printf '%.0s─' {1..65})"

    while IFS= read -r svc; do
        local desc
        desc=$(systemctl show "$svc" --property=Description --value 2>/dev/null || echo "N/A")
        printf "  ${C_RED}%-25s${C_RESET} %-20s %s\n" "$svc" "failed" "${desc:0:30}"
    done <<< "$failed_svcs"
    echo ""
}

cmd_top() {
    log_info "サービスリソース使用量TOP"
    echo ""

    printf "${C_BOLD}  %-30s %12s %8s${C_RESET}\n" "サービス" "メモリ" "CPU%"
    printf "  %s\n" "$(printf '%.0s─' {1..55})"

    local tmp
    tmp=$(mktemp)
    systemctl list-units --type=service --state=active --no-legend --no-pager 2>/dev/null | \
        awk '{print $1}' | sed 's/\.service$//' | head -40 | \
    while IFS= read -r svc; do
        local mem
        mem=$(systemctl show "$svc" --property=MemoryCurrent --value 2>/dev/null | grep -v "^$\|18446744" || echo "0")
        local cpu
        cpu=$(get_service_cpu "$svc")
        printf "%s\t%s\t%s\n" "$svc" "${mem:-0}" "${cpu:-0}"
    done | sort -t$'\t' -k2 -rn | head -15 > "$tmp"

    while IFS=$'\t' read -r svc mem cpu; do
        local mem_str
        mem_str=$(format_bytes "${mem:-0}")
        local cpu_color="$C_GREEN"
        local cpu_int="${cpu%.*}"
        (( ${cpu_int:-0} > 50 )) && cpu_color="$C_YELLOW"
        (( ${cpu_int:-0} > 80 )) && cpu_color="$C_RED"
        printf "  ${C_CYAN}%-30s${C_RESET} %12s ${cpu_color}%8s%%${C_RESET}\n" \
            "${svc:0:30}" "$mem_str" "${cpu:-0}"
    done < "$tmp"
    rm -f "$tmp"
    echo ""
}

parse_arguments() {
    [[ $# -eq 0 ]] && return 0
    case "$1" in
        status|watch|restart|enable|disable|logs|failed|top)
            command_name="$1"; shift ;;
    esac

    local positional=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -i|--interval) [[ $# -lt 2 ]] && error_exit "--interval には値が必要です"; watch_interval="$2"; shift 2 ;;
            -a|--auto-restart) auto_restart=1; shift ;;
            -n|--notify)  [[ $# -lt 2 ]] && error_exit "--notify には値が必要です"; notify_cmd="$2"; shift 2 ;;
            -f|--format)  [[ $# -lt 2 ]] && error_exit "--format には値が必要です"; output_format="$2"; shift 2 ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  positional+=("$1"); shift ;;
        esac
    done
    POSITIONAL=("${positional[@]+"${positional[@]}"}")
}

declare -a POSITIONAL=()

main() {
    parse_arguments "$@"
    case "$command_name" in
        status)  cmd_status  "${POSITIONAL[@]+"${POSITIONAL[@]}"}" ;;
        watch)   cmd_watch   "${POSITIONAL[@]+"${POSITIONAL[@]}"}" ;;
        restart) cmd_restart "${POSITIONAL[0]:-}" ;;
        enable)  cmd_enable  "${POSITIONAL[0]:-}" ;;
        disable) cmd_disable "${POSITIONAL[0]:-}" ;;
        logs)    cmd_logs    "${POSITIONAL[0]:-}" ;;
        failed)  cmd_failed ;;
        top)     cmd_top ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
