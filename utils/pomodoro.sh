#!/bin/bash
set -euo pipefail

#
# ポモドーロタイマー
# バージョン: 1.0
#
# ポモドーロテクニックに基づいた作業タイマーツール
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"
readonly STATE_FILE="${HOME}/.pomodoro_state"
readonly LOG_FILE="${HOME}/.pomodoro_log"

declare -i work_min=25
declare -i short_break_min=5
declare -i long_break_min=15
declare -i pomodoros_until_long=4
declare notify_cmd=""
declare task_name="作業"
declare mode="start"

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション] [コマンド]

ポモドーロタイマー

コマンド:
  start             タイマー開始 (デフォルト)
  status            現在の状態確認
  skip              現在のフェーズをスキップ
  reset             カウンターリセット
  log               今日のログ表示
  stats             統計情報表示

オプション:
  -h, --help              このヘルプを表示
  -v, --version           バージョン情報を表示
  -w, --work MIN          作業時間(分) [デフォルト: 25]
  -s, --short-break MIN   短い休憩(分) [デフォルト: 5]
  -l, --long-break MIN    長い休憩(分) [デフォルト: 15]
  -p, --pomodoros NUM     長い休憩までのポモドーロ数 [デフォルト: 4]
  -n, --notify CMD        通知コマンド
  -t, --task NAME         タスク名

例:
  $PROG_NAME
  $PROG_NAME -w 50 -s 10 -l 30
  $PROG_NAME -t "レポート作成"
  $PROG_NAME -n "notify-send 'ポモドーロ' '\$MSG'"
  $PROG_NAME status
  $PROG_NAME log

EOF
}

load_state() {
    if [[ -f "$STATE_FILE" ]]; then
        source "$STATE_FILE"
    else
        POMODORO_COUNT=0
        TOTAL_WORK_MIN=0
        SESSION_START=$(date +%s)
    fi
}

save_state() {
    cat > "$STATE_FILE" <<EOF
POMODORO_COUNT=${POMODORO_COUNT:-0}
TOTAL_WORK_MIN=${TOTAL_WORK_MIN:-0}
SESSION_START=${SESSION_START:-$(date +%s)}
EOF
}

log_event() {
    local event="$1"
    local duration="${2:-0}"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp}|${event}|${duration}|${task_name}" >> "$LOG_FILE"
}

send_notify() {
    local msg="$1"
    if [[ -n "$notify_cmd" ]]; then
        MSG="$msg" eval "$notify_cmd" 2>/dev/null || true
    fi

    # ターミナルベル
    printf '\a'
}

show_countdown() {
    local phase="$1"
    local total_sec="$2"
    local color="${3:-$C_CYAN}"

    load_state
    local pom_count="${POMODORO_COUNT:-0}"

    local elapsed=0
    while (( elapsed < total_sec )); do
        local remaining=$(( total_sec - elapsed ))
        local mm=$(( remaining / 60 ))
        local ss=$(( remaining % 60 ))
        local progress=$(( elapsed * 100 / total_sec ))

        clear_screen

        # ヘッダー
        print_center "🍅  ポモドーロタイマー  🍅" 1 "$C_RED"
        draw_separator 2

        # フェーズ表示
        move_cursor 4 2
        print_center "$phase" 4 "$color"

        # タスク名
        [[ -n "$task_name" ]] && {
            move_cursor 5 2
            printf "  タスク: ${C_BOLD}%s${C_RESET}\n" "$task_name"
        }

        # 大きな時計表示
        move_cursor 7 2
        printf "  "
        printf "${color}${C_BOLD}"
        printf "  ┌─────────────────┐\n"
        move_cursor 8 2
        printf "  │  %02d : %02d  │\n" "$mm" "$ss"
        move_cursor 9 2
        printf "  └─────────────────┘"
        printf "${C_RESET}\n"

        # プログレスバー
        move_cursor 11 2
        draw_progress_bar "$elapsed" "$total_sec" 40
        printf "  %d%%\n" "$progress"

        # ポモドーロ数
        move_cursor 13 2
        printf "  ポモドーロ: "
        local i
        for (( i=1; i<=pomodoros_until_long; i++ )); do
            if (( i <= pom_count % pomodoros_until_long || (pom_count % pomodoros_until_long == 0 && pom_count > 0) )); then
                printf "${C_RED}🍅${C_RESET}"
            else
                printf "⬜"
            fi
        done
        printf "  (合計: %d回)\n" "$pom_count"

        move_cursor 15 2
        printf "${C_DIM}[q]=中断  [s]=スキップ${C_RESET}"

        # キー入力チェック (non-blocking)
        local key=""
        IFS= read -r -s -n1 -t 1 key 2>/dev/null && true || true
        case "${key:-}" in
            q|Q) return 1 ;;
            s|S) return 2 ;;
        esac

        (( elapsed++ )) || true
    done
    return 0
}

do_start() {
    load_state

    local cleanup_called=false
    cleanup_pomo() {
        $cleanup_called && return
        cleanup_called=true
        show_cursor
        clear_screen
        echo ""
        log_info "ポモドーロタイマーを終了しました"
        echo "  完了ポモドーロ: ${POMODORO_COUNT:-0} 回"
        echo "  総作業時間: ${TOTAL_WORK_MIN:-0} 分"
        echo ""
    }
    trap cleanup_pomo EXIT INT TERM
    hide_cursor

    while true; do
        # 作業フェーズ
        log_info "作業フェーズ開始 (${work_min}分)"
        local work_sec=$(( work_min * 60 ))

        local result=0
        show_countdown "🔴 作業中 - 集中してください" "$work_sec" "$C_RED" || result=$?

        if (( result == 1 )); then
            break
        fi

        (( POMODORO_COUNT++ )) || true
        (( TOTAL_WORK_MIN += work_min )) || true
        save_state
        log_event "WORK_COMPLETE" "$work_min"
        send_notify "作業完了！休憩してください"

        # 休憩フェーズ判定
        local break_min
        if (( POMODORO_COUNT % pomodoros_until_long == 0 )); then
            break_min="$long_break_min"
            log_info "長い休憩 (${break_min}分)"
        else
            break_min="$short_break_min"
            log_info "短い休憩 (${break_min}分)"
        fi

        local break_sec=$(( break_min * 60 ))
        result=0
        show_countdown "💚 休憩中 - リラックスしてください" "$break_sec" "$C_GREEN" || result=$?

        if (( result == 1 )); then
            break
        fi

        log_event "BREAK_COMPLETE" "$break_min"
        send_notify "休憩終了！作業を再開してください"
    done
}

do_status() {
    load_state
    log_info "ポモドーロ状態"
    echo ""
    printf "  %-20s %d 回\n" "完了ポモドーロ:" "${POMODORO_COUNT:-0}"
    printf "  %-20s %d 分\n" "総作業時間:" "${TOTAL_WORK_MIN:-0}"

    local next_long=$(( pomodoros_until_long - (POMODORO_COUNT % pomodoros_until_long) ))
    printf "  %-20s %d 回後\n" "次の長い休憩:" "$next_long"

    printf "  %-20s " "ポモドーロ:"
    local i
    for (( i=1; i<=pomodoros_until_long; i++ )); do
        if (( i <= POMODORO_COUNT % pomodoros_until_long )); then
            printf "🍅"
        else
            printf "⬜"
        fi
    done
    echo ""
    echo ""
}

do_log() {
    [[ ! -f "$LOG_FILE" ]] && { log_warning "ログがありません"; return 0; }

    local today
    today=$(date '+%Y-%m-%d')
    log_info "本日のログ ($today)"
    echo ""

    grep "^${today}" "$LOG_FILE" 2>/dev/null | while IFS='|' read -r ts event dur task; do
        local event_str
        case "$event" in
            WORK_COMPLETE)  event_str="${C_RED}作業完了${C_RESET}" ;;
            BREAK_COMPLETE) event_str="${C_GREEN}休憩完了${C_RESET}" ;;
            *)              event_str="$event" ;;
        esac
        printf "  %s %b (%d分) %s\n" "$ts" "$event_str" "$dur" "$task"
    done || log_warning "本日のログはありません"
    echo ""
}

do_reset() {
    confirm "カウンターをリセットしますか?" "n" || { log_info "キャンセル"; return 0; }
    rm -f "$STATE_FILE"
    log_success "リセットしました"
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -w|--work)    [[ $# -lt 2 ]] && error_exit "-w には値が必要です"; work_min="$2"; shift 2 ;;
            -s|--short-break) [[ $# -lt 2 ]] && error_exit "-s には値が必要です"; short_break_min="$2"; shift 2 ;;
            -l|--long-break)  [[ $# -lt 2 ]] && error_exit "-l には値が必要です"; long_break_min="$2"; shift 2 ;;
            -p|--pomodoros)   [[ $# -lt 2 ]] && error_exit "-p には値が必要です"; pomodoros_until_long="$2"; shift 2 ;;
            -n|--notify)  [[ $# -lt 2 ]] && error_exit "-n には値が必要です"; notify_cmd="$2"; shift 2 ;;
            -t|--task)    [[ $# -lt 2 ]] && error_exit "-t には値が必要です"; task_name="$2"; shift 2 ;;
            start|status|skip|reset|log|stats) mode="$1"; shift ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  shift ;;
        esac
    done
}

main() {
    parse_arguments "$@"

    case "$mode" in
        start)  do_start ;;
        status) do_status ;;
        reset)  do_reset ;;
        log)    do_log ;;
        *)      error_exit "不明なコマンド: $mode" ;;
    esac
}

main "$@"
