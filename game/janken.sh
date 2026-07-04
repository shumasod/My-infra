#!/bin/bash
set -euo pipefail

#
# じゃんけんゲーム（対CPU）
# 作成日: 2026-07-04
# バージョン: 1.0
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

readonly -a HANDS=("グー" "チョキ" "パー")
readonly -a HAND_ART=(
'
  ___
 /   \
|     |
 \___/
  グー '
'
  /\  /\
 /  \/  \
|  /\/\  |
 \/    \/
  チョキ '
'
 _______
|       |
|       |
|_______|
   パー  '
)

declare -i player_wins=0
declare -i cpu_wins=0
declare -i draws=0

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション]

CPU相手にじゃんけんで対決するゲームです。

オプション:
  -h, --help       このヘルプを表示
  -v, --version    バージョン情報を表示
  -r, --rounds N   対戦ラウンド数 (デフォルト: 5)
EOF
}

draw_hand() {
    local idx="$1"
    local color="$2"
    echo -e "${color}${HAND_ART[$idx]}${C_RESET}"
}

get_cpu_hand() {
    echo $(( RANDOM % 3 ))
}

judge() {
    local player="$1"
    local cpu="$2"
    if [ "$player" -eq "$cpu" ]; then
        echo "draw"
    elif { [ "$player" -eq 0 ] && [ "$cpu" -eq 1 ]; } || \
         { [ "$player" -eq 1 ] && [ "$cpu" -eq 2 ]; } || \
         { [ "$player" -eq 2 ] && [ "$cpu" -eq 0 ]; }; then
        echo "win"
    else
        echo "lose"
    fi
}

show_score() {
    echo ""
    echo -e "${C_BOLD}=== スコア ===${C_RESET}"
    echo -e "  あなた: ${C_GREEN}${player_wins}勝${C_RESET}  CPU: ${C_RED}${cpu_wins}勝${C_RESET}  引き分け: ${C_YELLOW}${draws}回${C_RESET}"
    echo ""
}

play_round() {
    local round="$1"
    local total="$2"

    echo ""
    echo -e "${C_CYAN}${C_BOLD}── ラウンド ${round}/${total} ──${C_RESET}"
    echo ""
    echo -e "手を選んでください:"
    echo -e "  ${C_GREEN}1${C_RESET}) グー"
    echo -e "  ${C_YELLOW}2${C_RESET}) チョキ"
    echo -e "  ${C_MAGENTA}3${C_RESET}) パー"
    echo -e "  ${C_DIM}q${C_RESET}) 終了"
    echo ""
    printf "選択 > "

    local choice
    read -r choice

    case "$choice" in
        q|Q) return 1 ;;
        1) local player_idx=0 ;;
        2) local player_idx=1 ;;
        3) local player_idx=2 ;;
        *) log_warning "1, 2, 3 のいずれかを入力してください"; return 0 ;;
    esac

    local cpu_idx
    cpu_idx=$(get_cpu_hand)

    echo ""
    echo -e "${C_BOLD}  あなた          CPU${C_RESET}"
    echo ""

    local player_color cpu_color
    local result
    result=$(judge "$player_idx" "$cpu_idx")

    case "$result" in
        win)  player_color="$C_GREEN"; cpu_color="$C_RED" ;;
        lose) player_color="$C_RED";   cpu_color="$C_GREEN" ;;
        draw) player_color="$C_YELLOW"; cpu_color="$C_YELLOW" ;;
    esac

    echo -e "${player_color}${HANDS[$player_idx]}${C_RESET}          ${cpu_color}${HANDS[$cpu_idx]}${C_RESET}"
    echo ""

    case "$result" in
        win)
            echo -e "${C_GREEN}${C_BOLD}  ★ あなたの勝ち！★${C_RESET}"
            player_wins=$(( player_wins + 1 ))
            ;;
        lose)
            echo -e "${C_RED}${C_BOLD}  ✗ CPUの勝ち...${C_RESET}"
            cpu_wins=$(( cpu_wins + 1 ))
            ;;
        draw)
            echo -e "${C_YELLOW}${C_BOLD}  △ 引き分け！もう一度！${C_RESET}"
            draws=$(( draws + 1 ))
            ;;
    esac

    return 0
}

show_final_result() {
    clear_screen
    echo ""
    print_center "═══ 最終結果 ═══" 0 "$C_CYAN"
    echo ""
    show_score

    if [ "$player_wins" -gt "$cpu_wins" ]; then
        print_center "🏆 あなたの勝利！おめでとうございます！" 0 "$C_GREEN"
    elif [ "$cpu_wins" -gt "$player_wins" ]; then
        print_center "CPU の勝利...またチャレンジしてください！" 0 "$C_RED"
    else
        print_center "引き分け！いい勝負でした！" 0 "$C_YELLOW"
    fi
    echo ""
}

main() {
    local rounds=5

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -r|--rounds)
                [[ $# -lt 2 ]] && error_exit "--rounds には数値が必要です"
                rounds="$2"
                shift 2
                ;;
            *) error_exit "不明なオプション: $1" ;;
        esac
    done

    clear_screen
    print_center "じゃんけんゲーム" 0 "$C_CYAN"
    print_center "CPU と ${rounds} ラウンド対決！" 0 "$C_DIM"
    echo ""
    echo -e "${C_DIM}Enterキーを押してスタート...${C_RESET}"
    read -r

    local round=1
    while [ "$round" -le "$rounds" ]; do
        if ! play_round "$round" "$rounds"; then
            break
        fi
        show_score
        round=$(( round + 1 ))

        if [ "$round" -le "$rounds" ]; then
            echo -e "${C_DIM}Enterキーで次のラウンドへ...${C_RESET}"
            read -r
        fi
    done

    show_final_result
}

main "$@"
