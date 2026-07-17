#!/bin/bash
set -euo pipefail

#
# systemdサービス管理ヘルパー
# バージョン: 1.0
#
# 複数サービスの一括管理・状態確認・ログ表示ツール
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare -a SERVICES=()
declare action=""
declare follow_log=false
declare log_lines=50
declare -i timeout=30

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME <アクション> [サービス名...]

systemdサービスの一括管理ツール

アクション:
  status    サービス状態を確認
  start     サービスを起動
  stop      サービスを停止
  restart   サービスを再起動
  enable    サービスを自動起動に設定
  disable   サービスの自動起動を解除
  log       サービスのログを表示
  list      実行中サービスを一覧表示

オプション:
  -h, --help            このヘルプを表示
  -v, --version         バージョン情報を表示
  -f, --follow          ログをリアルタイム表示 (logアクション用)
  -n, --lines NUM       表示するログ行数 [デフォルト: 50]
  -t, --timeout SEC     操作タイムアウト秒 [デフォルト: 30]

例:
  $PROG_NAME status nginx mysql
  $PROG_NAME restart nginx
  $PROG_NAME log -f nginx
  $PROG_NAME list

EOF
}

check_systemctl() {
    if ! command -v systemctl &>/dev/null; then
        error_exit "systemctlが見つかりません (systemd環境が必要です)"
    fi
}

get_service_status() {
    local svc="$1"
    local active enabled
    active=$(systemctl is-active "$svc" 2>/dev/null || echo "unknown")
    enabled=$(systemctl is-enabled "$svc" 2>/dev/null || echo "unknown")
    echo "$active $enabled"
}

print_service_status() {
    local svc="$1"
    local status_info
    status_info=$(get_service_status "$svc")
    local active="${status_info%% *}"
    local enabled="${status_info##* }"

    local active_color
    case "$active" in
        active)   active_color="$C_GREEN" ;;
        inactive) active_color="$C_YELLOW" ;;
        failed)   active_color="$C_RED" ;;
        *)        active_color="$C_DIM" ;;
    esac

    local enabled_color
    case "$enabled" in
        enabled)  enabled_color="$C_GREEN" ;;
        disabled) enabled_color="$C_YELLOW" ;;
        *)        enabled_color="$C_DIM" ;;
    esac

    printf "  %-30s  状態: %b%-10s%b  自動起動: %b%s%b\n" \
        "$svc" \
        "$active_color" "$active" "$C_RESET" \
        "$enabled_color" "$enabled" "$C_RESET"
}

do_status() {
    log_info "サービス状態確認"
    echo ""
    for svc in "${SERVICES[@]}"; do
        print_service_status "$svc"
    done
    echo ""
}

do_action() {
    local act="$1"
    local action_jp
    case "$act" in
        start)   action_jp="起動" ;;
        stop)    action_jp="停止" ;;
        restart) action_jp="再起動" ;;
        enable)  action_jp="自動起動設定" ;;
        disable) action_jp="自動起動解除" ;;
        *)       action_jp="$act" ;;
    esac

    log_info "サービス${action_jp}: ${SERVICES[*]}"
    echo ""

    for svc in "${SERVICES[@]}"; do
        printf "  %s ... " "$svc"
        if timeout "$timeout" systemctl "$act" "$svc" 2>/dev/null; then
            echo -e "${C_GREEN}完了${C_RESET}"
        else
            echo -e "${C_RED}失敗${C_RESET}"
        fi
    done

    echo ""
    log_info "操作後の状態:"
    for svc in "${SERVICES[@]}"; do
        print_service_status "$svc"
    done
}

do_log() {
    local svc="${SERVICES[0]:-}"
    [[ -z "$svc" ]] && error_exit "サービス名を指定してください"

    if [[ "$follow_log" == true ]]; then
        log_info "$svc のログ (リアルタイム表示 Ctrl+C で終了)"
        journalctl -u "$svc" -f
    else
        log_info "$svc のログ (最新${log_lines}行)"
        journalctl -u "$svc" -n "$log_lines" --no-pager
    fi
}

do_list() {
    log_info "実行中のサービス一覧"
    echo ""
    systemctl list-units --type=service --state=active --no-pager --no-legend \
        | awk '{printf "  %-45s %s %s\n", $1, $3, $4}' \
        | head -50
    echo ""
}

parse_arguments() {
    [[ $# -eq 0 ]] && { show_usage; exit 0; }

    action="$1"; shift

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -f|--follow)  follow_log=true; shift ;;
            -n|--lines)
                [[ $# -lt 2 ]] && error_exit "--lines には数値が必要です"
                log_lines="$2"; shift 2 ;;
            -t|--timeout)
                [[ $# -lt 2 ]] && error_exit "--timeout には数値が必要です"
                timeout="$2"; shift 2 ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  SERVICES+=("$1"); shift ;;
        esac
    done
}

main() {
    parse_arguments "$@"
    check_systemctl

    case "$action" in
        status)
            [[ ${#SERVICES[@]} -eq 0 ]] && error_exit "サービス名を指定してください"
            do_status ;;
        start|stop|restart|enable|disable)
            [[ ${#SERVICES[@]} -eq 0 ]] && error_exit "サービス名を指定してください"
            do_action "$action" ;;
        log)
            do_log ;;
        list)
            do_list ;;
        *)
            error_exit "不明なアクション: $action。--help を参照してください" ;;
    esac
}

main "$@"
