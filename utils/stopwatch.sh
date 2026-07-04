#!/bin/bash
set -euo pipefail

#
# ストップウォッチ
# 作成日: 2026-07-04
# バージョン: 1.0
#
# スペース: 開始/一時停止  L: ラップ記録  q: 終了
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare -a LAP_TIMES=()
declare -i start_time=0
declare -i pause_offset=0
declare -i pause_start=0
declare running=false
declare paused=false

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション]

ターミナル上で動作するストップウォッチ。

オプション:
  -h, --help     このヘルプを表示
  -v, --version  バージョン情報を表示

操作方法:
  Space / Enter  開始 / 一時停止 / 再開
  L              ラップタイム記録
  R              リセット
  Q              終了
EOF
}

cleanup() {
    show_cursor
    tput cnorm 2>/dev/null || true
    echo ""
}
trap cleanup EXIT INT TERM

get_elapsed() {
    local now
    now=$(date +%s%N)
    now=$(( now / 1000000 ))
    if "$paused"; then
        echo $(( pause_start - start_time - pause_offset ))
    else
        echo $(( now - start_time - pause_offset ))
    fi
}

format_ms() {
    local ms="$1"
    local h=$(( ms / 3600000 ))
    local m=$(( (ms % 3600000) / 60000 ))
    local s=$(( (ms % 60000) / 1000 ))
    local cs=$(( (ms % 1000) / 10 ))
    printf "%02d:%02d:%02d.%02d" "$h" "$m" "$s" "$cs"
}

draw_display() {
    local elapsed="$1"
    local time_str
    time_str=$(format_ms "$elapsed")

    clear_screen
    update_terminal_size

    local mid_row=$(( TERM_ROWS / 2 - 3 ))
    [ "$mid_row" -lt 1 ] && mid_row=1

    move_cursor "$mid_row" 1
    print_center "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" 0 "$C_DIM"

    local time_color="$C_GREEN"
    "$paused" && time_color="$C_YELLOW"
    ! "$running" && time_color="$C_DIM"

    move_cursor $(( mid_row + 1 )) 1
    print_center "${time_str}" 0 "${C_BOLD}${time_color}"

    local status_msg
    if ! "$running"; then
        status_msg="[Space] スタート  [Q] 終了"
    elif "$paused"; then
        status_msg="一時停止中  [Space] 再開  [L] ラップ  [R] リセット  [Q] 終了"
    else
        status_msg="計測中  [Space] 一時停止  [L] ラップ  [R] リセット  [Q] 終了"
    fi

    move_cursor $(( mid_row + 2 )) 1
    print_center "$status_msg" 0 "$C_DIM"

    move_cursor $(( mid_row + 3 )) 1
    print_center "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" 0 "$C_DIM"

    if [ "${#LAP_TIMES[@]}" -gt 0 ]; then
        move_cursor $(( mid_row + 5 )) 1
        print_center "ラップタイム" 0 "$C_CYAN"
        local lap_row=$(( mid_row + 6 ))
        local show_from=$(( ${#LAP_TIMES[@]} - 5 ))
        [ "$show_from" -lt 0 ] && show_from=0
        local i
        for (( i = show_from; i < ${#LAP_TIMES[@]}; i++ )); do
            move_cursor "$lap_row" 1
            print_center "#$(( i + 1 ))  ${LAP_TIMES[$i]}" 0 "$C_WHITE"
            lap_row=$(( lap_row + 1 ))
        done
    fi
}

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            *) error_exit "不明なオプション: $1" ;;
        esac
    done

    hide_cursor

    while true; do
        local elapsed=0
        "$running" && ! "$paused" && elapsed=$(get_elapsed)
        "$paused" && elapsed=$(get_elapsed)

        draw_display "$elapsed"

        local key
        read -rsn1 -t 0.05 key || key=""

        case "$key" in
            " "|"")
                if [ -z "$key" ]; then continue; fi
                local now_ms
                now_ms=$(( $(date +%s%N) / 1000000 ))
                if ! "$running"; then
                    start_time=$now_ms
                    pause_offset=0
                    LAP_TIMES=()
                    running=true
                    paused=false
                elif "$paused"; then
                    pause_offset=$(( pause_offset + now_ms - pause_start ))
                    paused=false
                else
                    pause_start=$now_ms
                    paused=true
                fi
                ;;
            l|L)
                if "$running" && ! "$paused"; then
                    local lap_ms
                    lap_ms=$(get_elapsed)
                    LAP_TIMES+=("$(format_ms "$lap_ms")")
                fi
                ;;
            r|R)
                running=false
                paused=false
                pause_offset=0
                LAP_TIMES=()
                ;;
            q|Q) break ;;
        esac
    done

    clear_screen
    echo ""
    log_info "計測終了"
    if [ "${#LAP_TIMES[@]}" -gt 0 ]; then
        echo ""
        echo -e "${C_CYAN}ラップタイム記録:${C_RESET}"
        local i
        for (( i = 0; i < ${#LAP_TIMES[@]}; i++ )); do
            echo -e "  #$(( i + 1 ))  ${LAP_TIMES[$i]}"
        done
    fi
    echo ""
}

main "$@"
