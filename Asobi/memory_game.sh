#!/bin/bash
set -euo pipefail

#
# 記憶力ゲーム (神経衰弱)
# バージョン: 1.0
#
# ターミナル上で遊べる神経衰弱ゲーム
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare -i grid_size=4
declare -i pairs=0
declare -i found=0
declare -i moves=0
declare -A board
declare -A revealed
declare -i start_time=0

declare -a SYMBOLS=(
    "🍎" "🍊" "🍋" "🍇" "🍓" "🍒" "🍑" "🥝"
    "🐶" "🐱" "🐭" "🐹" "🐰" "🦊" "🐻" "🐼"
    "⚽" "🏀" "🎾" "⚾" "🏐" "🎱" "🏉" "🎯"
    "🌸" "🌺" "🌻" "🌹" "🌷" "💐" "🍀" "🌿"
)

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション]

記憶力ゲーム (神経衰弱)

オプション:
  -h, --help            このヘルプを表示
  -v, --version         バージョン情報を表示
  -s, --size NUM        グリッドサイズ (2-6の偶数) [デフォルト: 4]

例:
  $PROG_NAME
  $PROG_NAME -s 6

EOF
}

init_board() {
    pairs=$(( grid_size * grid_size / 2 ))
    local total=$(( grid_size * grid_size ))

    local -a selected_symbols=("${SYMBOLS[@]:0:$pairs}")
    local -a all_cards=()

    for sym in "${selected_symbols[@]}"; do
        all_cards+=("$sym" "$sym")
    done

    # Fisher-Yates シャッフル
    local n=${#all_cards[@]}
    for (( i=n-1; i>0; i-- )); do
        local j=$(( RANDOM % (i + 1) ))
        local tmp="${all_cards[$i]}"
        all_cards[$i]="${all_cards[$j]}"
        all_cards[$j]="$tmp"
    done

    for (( i=0; i<total; i++ )); do
        board[$i]="${all_cards[$i]}"
        revealed[$i]=0
    done
    found=0
    moves=0
    start_time=$(date +%s)
}

display_board() {
    clear_screen
    print_center "🃏 記憶力ゲーム (神経衰弱) 🃏" 1 "$C_CYAN"

    local elapsed=$(( $(date +%s) - start_time ))
    local elapsed_fmt
    elapsed_fmt=$(format_time "$elapsed")
    move_cursor 3 2
    printf "  ペア: ${C_GREEN}%d/%d${C_RESET}  手数: ${C_YELLOW}%d${C_RESET}  時間: ${C_CYAN}%s${C_RESET}" \
        "$found" "$pairs" "$moves" "$elapsed_fmt"

    local row_start=5
    for (( row=0; row<grid_size; row++ )); do
        move_cursor $(( row_start + row * 2 )) 4
        printf "  "
        for (( col=0; col<grid_size; col++ )); do
            local idx=$(( row * grid_size + col ))
            local num=$(( idx + 1 ))
            if [[ "${revealed[$idx]}" == "2" ]]; then
                printf " ${C_DIM}[  ]${C_RESET} "
            elif [[ "${revealed[$idx]}" == "1" ]]; then
                printf " ${C_GREEN}[%s]${C_RESET} " "${board[$idx]}"
            else
                if (( num < 10 )); then
                    printf " ${C_BLUE}[ %d]${C_RESET} " "$num"
                else
                    printf " ${C_BLUE}[%2d]${C_RESET} " "$num"
                fi
            fi
        done
    done
    echo ""
}

get_choice() {
    local prompt="$1"
    local max="$1"
    local -i choice=0

    while true; do
        move_cursor $(( 5 + grid_size * 2 + 2 )) 4
        printf "  %s [1-%d]: " "$prompt" "$(( grid_size * grid_size ))"
        read -r input

        if ! [[ "$input" =~ ^[0-9]+$ ]]; then
            continue
        fi
        choice=$input
        if (( choice >= 1 && choice <= grid_size * grid_size )); then
            local idx=$(( choice - 1 ))
            if [[ "${revealed[$idx]}" == "0" ]]; then
                echo "$idx"
                return
            fi
        fi
    done
}

show_result() {
    local elapsed=$(( $(date +%s) - start_time ))
    local elapsed_fmt
    elapsed_fmt=$(format_time "$elapsed")
    local avg_moves_per_pair
    avg_moves_per_pair=$(echo "scale=1; $moves / $pairs" | bc 2>/dev/null || echo "N/A")

    clear_screen
    echo ""
    echo -e "${C_YELLOW}╔══════════════════════════════╗${C_RESET}"
    echo -e "${C_YELLOW}║       ゲームクリア！🎉        ║${C_RESET}"
    echo -e "${C_YELLOW}╚══════════════════════════════╝${C_RESET}"
    echo ""
    printf "  総手数:         %d 手\n" "$moves"
    printf "  クリア時間:     %s\n" "$elapsed_fmt"
    printf "  平均手数/ペア:  %s\n" "$avg_moves_per_pair"

    local pct_wasted=$(( (moves - pairs) * 100 / moves ))
    local rank
    if   (( pct_wasted <= 20 )); then rank="${C_YELLOW}S (完璧な記憶力！)"
    elif (( pct_wasted <= 40 )); then rank="${C_GREEN}A (素晴らしい)"
    elif (( pct_wasted <= 60 )); then rank="${C_BLUE}B (良い)"
    else                              rank="${C_DIM}C (練習あるのみ)"
    fi
    printf "  ランク:         %b${C_RESET}\n\n" "$rank"
}

play_game() {
    init_board

    while (( found < pairs )); do
        display_board

        local idx1
        idx1=$(get_choice "1枚目を選んでください")
        revealed[$idx1]=1
        display_board

        local idx2
        idx2=$(get_choice "2枚目を選んでください")
        revealed[$idx2]=1
        display_board
        (( moves++ )) || true

        sleep 0.8

        if [[ "${board[$idx1]}" == "${board[$idx2]}" ]]; then
            revealed[$idx1]=2
            revealed[$idx2]=2
            (( found++ )) || true
        else
            revealed[$idx1]=0
            revealed[$idx2]=0
        fi
    done

    display_board
    show_result
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -s|--size)
                [[ $# -lt 2 ]] && error_exit "--size には数値が必要です"
                if ! [[ "$2" =~ ^[2468]$ ]]; then
                    error_exit "グリッドサイズは 2/4/6/8 のいずれかです"
                fi
                grid_size="$2"; shift 2 ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  error_exit "不明な引数: $1" ;;
        esac
    done
}

cleanup() {
    show_cursor
}
trap cleanup EXIT

main() {
    parse_arguments "$@"
    hide_cursor

    while true; do
        play_game
        printf "\nもう一度プレイしますか? [y/N]: "
        local ans; read -r ans
        [[ ! "$ans" =~ ^[yY]$ ]] && break
    done

    show_cursor
    echo -e "\n${C_GREEN}またね！${C_RESET}\n"
}

main "$@"
