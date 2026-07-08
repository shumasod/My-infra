#!/bin/bash
set -euo pipefail

#
# ポモドーロタイマー
# 作成日: 2026-07-04
# バージョン: 1.0
#
# 25分作業 → 5分休憩 のサイクルで集中力を管理
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

readonly DEFAULT_WORK=25
readonly DEFAULT_SHORT_BREAK=5
readonly DEFAULT_LONG_BREAK=15
readonly DEFAULT_CYCLES=4

declare -i work_min=$DEFAULT_WORK
declare -i short_break_min=$DEFAULT_SHORT_BREAK
declare -i long_break_min=$DEFAULT_LONG_BREAK
declare -i cycles=$DEFAULT_CYCLES
declare -i completed_pomodoros=0

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション]

ポモドーロタイマーで集中作業をサポートします。

オプション:
  -h, --help           このヘルプを表示
  -v, --version        バージョン情報を表示
  -w, --work N         作業時間（分）  デフォルト: ${DEFAULT_WORK}
  -s, --short N        短い休憩（分）  デフォルト: ${DEFAULT_SHORT_BREAK}
  -l, --long N         長い休憩（分）  デフォルト: ${DEFAULT_LONG_BREAK}
  -c, --cycles N       長休憩までのサイクル数  デフォルト: ${DEFAULT_CYCLES}
EOF
}

cleanup() {
    show_cursor
    tput cnorm 2>/dev/null || true
    echo ""
}
trap cleanup EXIT INT TERM

ring_bell() {
    printf "\a"
}

draw_timer() {
    local label="$1"
    local elapsed="$2"
    local total="$3"
    local color="$4"

    local remaining=$(( total - elapsed ))
    local min=$(( remaining / 60 ))
    local sec=$(( remaining % 60 ))

    clear_screen
    update_terminal_size

    local mid=$(( TERM_ROWS / 2 - 4 ))
    [ "$mid" -lt 1 ] && mid=1

    move_cursor "$mid" 1
    print_center "🍅 ポモドーロタイマー 🍅" 0 "${C_BOLD}${C_RED}"

    move_cursor $(( mid + 2 )) 1
    print_center "$label" 0 "${C_BOLD}${color}"

    move_cursor $(( mid + 4 )) 1
    print_center "$(printf '%02d:%02d' "$min" "$sec")" 0 "${C_BOLD}${color}"

    local bar
    bar=$(draw_progress_bar "$elapsed" "$total" 30)
    move_cursor $(( mid + 6 )) 1
    print_center "$bar" 0 "$color"

    move_cursor $(( mid + 8 )) 1
    print_center "完了ポモドーロ: ${completed_pomodoros} / ${cycles}" 0 "$C_DIM"

    move_cursor $(( mid + 9 )) 1
    print_center "Ctrl+C で中断" 0 "$C_DIM"
}

run_timer() {
    local label="$1"
    local minutes="$2"
    local color="$3"
    local total_sec=$(( minutes * 60 ))
    local elapsed=0

    hide_cursor
    while [ "$elapsed" -le "$total_sec" ]; do
        draw_timer "$label" "$elapsed" "$total_sec" "$color"
        sleep 1
        elapsed=$(( elapsed + 1 ))
    done
    show_cursor

    ring_bell
    sleep 0.3
    ring_bell
}

confirm_next() {
    local msg="$1"
    echo ""
    print_center "$msg" 0 "${C_BOLD}${C_YELLOW}"
    echo ""
    print_center "Enterキーで開始  q で終了" 0 "$C_DIM"
    printf "\n  > "
    local input
    read -r input
    [[ "$input" == "q" || "$input" == "Q" ]] && return 1
    return 0
}

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -w|--work)
                [[ $# -lt 2 ]] && error_exit "--work には数値が必要です"
                work_min="$2"; shift 2 ;;
            -s|--short)
                [[ $# -lt 2 ]] && error_exit "--short には数値が必要です"
                short_break_min="$2"; shift 2 ;;
            -l|--long)
                [[ $# -lt 2 ]] && error_exit "--long には数値が必要です"
                long_break_min="$2"; shift 2 ;;
            -c|--cycles)
                [[ $# -lt 2 ]] && error_exit "--cycles には数値が必要です"
                cycles="$2"; shift 2 ;;
            *) error_exit "不明なオプション: $1" ;;
        esac
    done

    clear_screen
    print_center "🍅 ポモドーロタイマー" 0 "${C_BOLD}${C_RED}"
    echo ""
    echo -e "  ${C_BOLD}作業時間:${C_RESET}   ${work_min}分"
    echo -e "  ${C_BOLD}短い休憩:${C_RESET}   ${short_break_min}分"
    echo -e "  ${C_BOLD}長い休憩:${C_RESET}   ${long_break_min}分"
    echo -e "  ${C_BOLD}サイクル数:${C_RESET} ${cycles}回で長休憩"
    echo ""

    confirm_next "準備ができたら開始してください" || exit 0

    while true; do
        run_timer "作業中 🔴" "$work_min" "$C_RED"
        completed_pomodoros=$(( completed_pomodoros + 1 ))

        if [ $(( completed_pomodoros % cycles )) -eq 0 ]; then
            confirm_next "🎉 ${cycles}ポモドーロ達成！長い休憩 (${long_break_min}分)" || break
            run_timer "長い休憩 ☕" "$long_break_min" "$C_BLUE"
        else
            local remaining_in_cycle=$(( cycles - completed_pomodoros % cycles ))
            confirm_next "短い休憩 (${short_break_min}分) — あと${remaining_in_cycle}ポモドーロで長休憩" || break
            run_timer "短い休憩 🌿" "$short_break_min" "$C_GREEN"
        fi

        confirm_next "次の作業セッションを開始しますか？" || break
    done

    clear_screen
    echo ""
    print_center "お疲れ様でした！" 0 "${C_BOLD}${C_GREEN}"
    echo ""
    echo -e "  完了ポモドーロ数: ${C_BOLD}${C_YELLOW}${completed_pomodoros}${C_RESET}"
    echo -e "  集中時間:         ${C_BOLD}${C_CYAN}$(( completed_pomodoros * work_min ))分${C_RESET}"
    echo ""
}

main "$@"
