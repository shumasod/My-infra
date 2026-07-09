#!/bin/bash
set -euo pipefail

#
# カウントダウンタイマー
# 作成日: 2026-07-04
# バージョン: 1.0
#
# 指定時間をカウントダウンし、終了時にベルと通知を表示する
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション] <時間>

指定した時間からカウントダウンします。

引数:
  <時間>  カウントダウン時間。形式:
          整数のみ → 秒として扱う
          MM:SS    → 分:秒
          HH:MM:SS → 時:分:秒

オプション:
  -h, --help         このヘルプを表示
  -v, --version      バージョン情報を表示
  -m, --message MSG  終了時に表示するメッセージ
  -r, --repeat N     N 回繰り返す（デフォルト: 1）
  --no-bell          終了時のベル音を無効化

例:
  $PROG_NAME 30
  $PROG_NAME 5:00
  $PROG_NAME 1:30:00
  $PROG_NAME -m "会議の時間です！" 10:00
  $PROG_NAME -r 3 25:00
EOF
}

parse_time() {
    local input="$1"
    if [[ "$input" =~ ^[0-9]+$ ]]; then
        echo "$input"
    elif [[ "$input" =~ ^([0-9]+):([0-9]{2})$ ]]; then
        local m="${BASH_REMATCH[1]}"
        local s="${BASH_REMATCH[2]}"
        echo $(( m * 60 + s ))
    elif [[ "$input" =~ ^([0-9]+):([0-9]{2}):([0-9]{2})$ ]]; then
        local h="${BASH_REMATCH[1]}"
        local m="${BASH_REMATCH[2]}"
        local s="${BASH_REMATCH[3]}"
        echo $(( h * 3600 + m * 60 + s ))
    else
        error_exit "時間の形式が正しくありません: $input (例: 30, 5:00, 1:30:00)"
    fi
}

format_time_hms() {
    local secs="$1"
    local h=$(( secs / 3600 ))
    local m=$(( (secs % 3600) / 60 ))
    local s=$(( secs % 60 ))
    if [ "$h" -gt 0 ]; then
        printf "%d:%02d:%02d" "$h" "$m" "$s"
    else
        printf "%02d:%02d" "$m" "$s"
    fi
}

cleanup() {
    show_cursor
    echo ""
}
trap cleanup EXIT INT TERM

draw_countdown() {
    local remaining="$1"
    local total="$2"
    local msg="$3"
    local round="$4"
    local total_rounds="$5"

    clear_screen
    update_terminal_size

    local mid=$(( TERM_ROWS / 2 - 4 ))
    [ "$mid" -lt 1 ] && mid=1

    move_cursor "$mid" 1
    if [ "$total_rounds" -gt 1 ]; then
        print_center "カウントダウン  (${round}/${total_rounds}回目)" 0 "${C_BOLD}${C_CYAN}"
    else
        print_center "カウントダウン" 0 "${C_BOLD}${C_CYAN}"
    fi

    local time_str
    time_str=$(format_time_hms "$remaining")
    local color="$C_GREEN"
    local pct=$(( (total - remaining) * 100 / (total > 0 ? total : 1) ))
    [ "$remaining" -le 60 ] && color="$C_YELLOW"
    [ "$remaining" -le 10 ] && color="$C_RED"

    move_cursor $(( mid + 2 )) 1
    print_center "${C_BOLD}${color}${time_str}${C_RESET}" 0 ""

    local bar
    bar=$(draw_progress_bar $(( total - remaining )) "$total" 30)
    move_cursor $(( mid + 4 )) 1
    print_center "$bar  ${pct}%" 0 "$color"

    if [ -n "$msg" ]; then
        move_cursor $(( mid + 6 )) 1
        print_center "$msg" 0 "$C_DIM"
    fi

    move_cursor $(( mid + 7 )) 1
    print_center "Ctrl+C で中断" 0 "$C_DIM"
}

ring_alert() {
    local i
    for (( i = 0; i < 3; i++ )); do
        printf "\a"
        sleep 0.4
    done
}

run_countdown() {
    local total="$1"
    local msg="$2"
    local use_bell="$3"
    local round="$4"
    local total_rounds="$5"

    hide_cursor
    local remaining="$total"
    while [ "$remaining" -ge 0 ]; do
        draw_countdown "$remaining" "$total" "$msg" "$round" "$total_rounds"
        [ "$remaining" -eq 0 ] && break
        sleep 1
        remaining=$(( remaining - 1 ))
    done
    show_cursor

    clear_screen
    echo ""
    print_center "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" 0 "$C_GREEN"
    print_center "⏰  時間です！" 0 "${C_BOLD}${C_GREEN}"
    if [ -n "$msg" ]; then
        print_center "$msg" 0 "${C_BOLD}${C_YELLOW}"
    fi
    print_center "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" 0 "$C_GREEN"
    echo ""

    "$use_bell" && ring_alert
}

main() {
    local time_input=""
    local message=""
    local repeat=1
    local use_bell=true

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -m|--message)
                [[ $# -lt 2 ]] && error_exit "--message にはテキストが必要です"
                message="$2"; shift 2 ;;
            -r|--repeat)
                [[ $# -lt 2 ]] && error_exit "--repeat には数値が必要です"
                repeat="$2"; shift 2 ;;
            --no-bell) use_bell=false; shift ;;
            -*)          error_exit "不明なオプション: $1" ;;
            *)
                [ -z "$time_input" ] && time_input="$1" || error_exit "引数が多すぎます"
                shift ;;
        esac
    done

    [ -z "$time_input" ] && error_exit "時間を指定してください\n使用方法: $PROG_NAME --help"

    local total_secs
    total_secs=$(parse_time "$time_input")
    [ "$total_secs" -le 0 ] && error_exit "0より大きい時間を指定してください"

    local i
    for (( i = 1; i <= repeat; i++ )); do
        run_countdown "$total_secs" "$message" "$use_bell" "$i" "$repeat"
        if [ "$i" -lt "$repeat" ]; then
            echo -e "${C_DIM}  Enterキーで次のセッションへ... (q で終了)${C_RESET}"
            local inp
            read -r inp
            [[ "$inp" == "q" || "$inp" == "Q" ]] && break
        fi
    done
}

main "$@"
