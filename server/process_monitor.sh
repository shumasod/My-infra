#!/bin/bash
set -euo pipefail

#
# プロセス監視ツール
# 作成日: 2026-07-14
# バージョン: 1.0
#
# 指定プロセスの稼働を監視し、停止時に再起動・通知する
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare PROCESS_NAME=""
declare START_CMD=""
declare LOG_FILE=""
declare -i CHECK_INTERVAL=10
declare -i MAX_RESTARTS=5
declare -i restart_count=0
declare -i total_checks=0
declare -i total_restarts=0

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション] <プロセス名>

プロセスの稼働状況を監視します。

引数:
  <プロセス名>        監視するプロセス名（pgrep で検索）

オプション:
  -h, --help          このヘルプを表示
  -v, --version       バージョン情報を表示
  -c, --cmd CMD       プロセス停止時に実行するコマンド
  -i, --interval N    チェック間隔（秒、デフォルト: 10）
  -m, --max N         最大再起動回数（デフォルト: 5、0=無制限）
  -l, --log FILE      ログファイル

例:
  $PROG_NAME nginx
  $PROG_NAME -c "systemctl start nginx" -i 30 nginx
  $PROG_NAME -l /var/log/monitor.log -m 3 myapp
EOF
}

write_log() {
    local level="$1"
    local msg="$2"
    local ts
    ts=$(get_timestamp)

    case "$level" in
        INFO)  log_info  "[${ts}] $msg" ;;
        WARN)  log_warning "[${ts}] $msg" ;;
        ERROR) log_error "[${ts}] $msg" ;;
        OK)    log_success "[${ts}] $msg" ;;
    esac

    if [[ -n "$LOG_FILE" ]]; then
        printf "[%s] [%s] %s\n" "$ts" "$level" "$msg" >> "$LOG_FILE"
    fi
}

is_running() {
    local name="$1"
    pgrep -x "$name" &>/dev/null || pgrep -f "$name" &>/dev/null
}

get_process_info() {
    local name="$1"
    local pid cpu mem

    pid=$(pgrep -x "$name" 2>/dev/null | head -1 || pgrep -f "$name" 2>/dev/null | head -1 || echo "N/A")

    if [[ "$pid" != "N/A" ]] && [[ -f "/proc/${pid}/status" ]]; then
        cpu=$(ps -p "$pid" -o %cpu= 2>/dev/null | tr -d ' ' || echo "N/A")
        mem=$(ps -p "$pid" -o %mem= 2>/dev/null | tr -d ' ' || echo "N/A")
        echo "PID=${pid} CPU=${cpu}% MEM=${mem}%"
    else
        echo "PID=${pid}"
    fi
}

restart_process() {
    if [[ -z "$START_CMD" ]]; then
        write_log "WARN" "再起動コマンドが未設定です"
        return 1
    fi

    write_log "INFO" "再起動を試みます: $START_CMD"
    if eval "$START_CMD" &>/dev/null; then
        write_log "OK" "再起動成功"
        return 0
    else
        write_log "ERROR" "再起動失敗"
        return 1
    fi
}

show_status_header() {
    clear
    echo ""
    print_center "プロセス監視ダッシュボード" 0 "${C_BOLD}${C_CYAN}"
    print_center "$(get_timestamp)" 0 "$C_DIM"
    echo ""
    echo -e "  ${C_BOLD}監視プロセス:${C_RESET} $PROCESS_NAME"
    echo -e "  ${C_BOLD}チェック間隔:${C_RESET} ${CHECK_INTERVAL}秒"
    [[ -n "$START_CMD" ]] && echo -e "  ${C_BOLD}再起動コマンド:${C_RESET} $START_CMD"
    echo -e "  ${C_DIM}Ctrl+C で終了${C_RESET}"
    echo ""
    echo -e "  ${C_DIM}$(printf '%.0s─' {1..50})${C_RESET}"
    echo ""
}

cleanup() {
    echo ""
    echo ""
    write_log "INFO" "監視終了 - チェック回数: ${total_checks}  再起動回数: ${total_restarts}"
}
trap cleanup EXIT INT TERM

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)      show_usage; exit 0 ;;
            -v|--version)   echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -c|--cmd)
                [[ $# -lt 2 ]] && error_exit "--cmd にはコマンドが必要です"
                START_CMD="$2"; shift 2 ;;
            -i|--interval)
                [[ $# -lt 2 ]] && error_exit "--interval には秒数が必要です"
                CHECK_INTERVAL="$2"; shift 2 ;;
            -m|--max)
                [[ $# -lt 2 ]] && error_exit "--max には回数が必要です"
                MAX_RESTARTS="$2"; shift 2 ;;
            -l|--log)
                [[ $# -lt 2 ]] && error_exit "--log にはファイル名が必要です"
                LOG_FILE="$2"; shift 2 ;;
            -*)  error_exit "不明なオプション: $1" ;;
            *)   PROCESS_NAME="$1"; shift ;;
        esac
    done

    [[ -z "$PROCESS_NAME" ]] && error_exit "プロセス名を指定してください"

    write_log "INFO" "監視開始: $PROCESS_NAME"

    while true; do
        (( total_checks++ ))
        show_status_header

        printf "  ${C_BOLD}チェック回数:${C_RESET} %d\n" "$total_checks"
        printf "  ${C_BOLD}再起動回数:${C_RESET} %d" "$total_restarts"
        if (( MAX_RESTARTS > 0 )); then
            printf " / %d" "$MAX_RESTARTS"
        fi
        echo ""
        echo ""

        if is_running "$PROCESS_NAME"; then
            restart_count=0
            local info
            info=$(get_process_info "$PROCESS_NAME")
            echo -e "  ${C_GREEN}${C_BOLD}● 稼働中${C_RESET}  $info"
        else
            echo -e "  ${C_RED}${C_BOLD}● 停止中${C_RESET}"
            write_log "WARN" "プロセス停止を検知: $PROCESS_NAME"

            if [[ -n "$START_CMD" ]]; then
                if (( MAX_RESTARTS == 0 || restart_count < MAX_RESTARTS )); then
                    (( restart_count++ ))
                    (( total_restarts++ ))
                    if restart_process; then
                        echo -e "  ${C_GREEN}再起動成功 (${restart_count}回目)${C_RESET}"
                    else
                        echo -e "  ${C_RED}再起動失敗${C_RESET}"
                    fi
                else
                    write_log "ERROR" "最大再起動回数に達しました (${MAX_RESTARTS}回)"
                    echo -e "  ${C_RED}最大再起動回数に達しました。監視を終了します。${C_RESET}"
                    sleep 2
                    break
                fi
            fi
        fi

        echo ""
        draw_progress_bar "$CHECK_INTERVAL" "$CHECK_INTERVAL" 40
        echo ""

        sleep "$CHECK_INTERVAL"
    done
}

main "$@"
