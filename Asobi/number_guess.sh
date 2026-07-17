#!/bin/bash
set -euo pipefail

#
# 数当てゲーム
# バージョン: 1.0
#
# コンピュータが考えた数を当てるゲーム (二分探索学習にも最適)
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare -i max_num=100
declare -i max_tries=7
declare -i secret=0
declare -i tries=0
declare difficulty="normal"

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション]

数当てゲーム

オプション:
  -h, --help            このヘルプを表示
  -v, --version         バージョン情報を表示
  -d, --difficulty LVL  難易度 (easy|normal|hard|extreme) [デフォルト: normal]

難易度と設定:
  easy     1〜50、試行回数10回
  normal   1〜100、試行回数7回
  hard     1〜500、試行回数9回
  extreme  1〜1000、試行回数10回

例:
  $PROG_NAME
  $PROG_NAME -d hard

EOF
}

setup_difficulty() {
    case "$difficulty" in
        easy)    max_num=50;   max_tries=10 ;;
        normal)  max_num=100;  max_tries=7  ;;
        hard)    max_num=500;  max_tries=9  ;;
        extreme) max_num=1000; max_tries=10 ;;
    esac
    secret=$(( RANDOM % max_num + 1 ))
}

show_hint() {
    local guess="$1"
    local diff=$(( secret - guess ))
    local abs_diff=${diff#-}

    local proximity
    if   (( abs_diff <= 2  )); then proximity="${C_RED}非常に熱い🔥${C_RESET}"
    elif (( abs_diff <= 10 )); then proximity="${C_YELLOW}熱い♨${C_RESET}"
    elif (( abs_diff <= 25 )); then proximity="${C_BLUE}温かい☀${C_RESET}"
    else                            proximity="${C_CYAN}冷たい❄${C_RESET}"
    fi

    if   (( guess < secret )); then printf "  %b → もっと大きい数です\n" "$proximity"
    elif (( guess > secret )); then printf "  %b → もっと小さい数です\n" "$proximity"
    fi
}

show_result_win() {
    local rating
    local remaining=$(( max_tries - tries ))

    echo ""
    echo -e "${C_GREEN}╔══════════════════════════╗${C_RESET}"
    echo -e "${C_GREEN}║        正解！ 🎉         ║${C_RESET}"
    echo -e "${C_GREEN}╚══════════════════════════╝${C_RESET}"
    printf "  答え: %d\n" "$secret"
    printf "  試行: %d回 (残り%d回)\n" "$tries" "$remaining"

    local pct=$(( remaining * 100 / max_tries ))
    if   (( pct >= 80 )); then rating="${C_YELLOW}S (完璧!)"
    elif (( pct >= 60 )); then rating="${C_GREEN}A (素晴らしい)"
    elif (( pct >= 40 )); then rating="${C_BLUE}B (良い)"
    elif (( pct >= 20 )); then rating="${C_CYAN}C (まずまず)"
    else                       rating="${C_DIM}D (ギリギリ)"
    fi
    printf "  評価: %b${C_RESET}\n\n" "$rating"
}

show_result_lose() {
    echo ""
    echo -e "${C_RED}╔══════════════════════════╗${C_RESET}"
    echo -e "${C_RED}║      残念... 💀          ║${C_RESET}"
    echo -e "${C_RED}╚══════════════════════════╝${C_RESET}"
    printf "  答えは %b%d%b でした\n\n" "$C_BOLD" "$secret" "$C_RESET"
}

play_game() {
    echo ""
    printf "${C_CYAN}1〜%dの数を当ててください (最大%d回)${C_RESET}\n\n" "$max_num" "$max_tries"

    while (( tries < max_tries )); do
        local remaining=$(( max_tries - tries ))
        printf "  [残り%d回] 予想を入力: " "$remaining"

        local input
        read -r input

        if ! [[ "$input" =~ ^[0-9]+$ ]]; then
            echo -e "  ${C_YELLOW}数値を入力してください${C_RESET}"
            continue
        fi

        local guess=$input
        if (( guess < 1 || guess > max_num )); then
            printf "  ${C_YELLOW}1〜%dの範囲で入力してください${C_RESET}\n" "$max_num"
            continue
        fi

        (( tries++ )) || true

        if (( guess == secret )); then
            show_result_win
            return 0
        fi

        show_hint "$guess"
    done

    show_result_lose
    return 0
}

play_again() {
    printf "もう一度プレイしますか? [y/N]: "
    local ans
    read -r ans
    [[ "$ans" =~ ^[yY]$ ]]
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -d|--difficulty)
                [[ $# -lt 2 ]] && error_exit "--difficulty には値が必要です"
                case "$2" in
                    easy|normal|hard|extreme) difficulty="$2" ;;
                    *) error_exit "難易度は easy/normal/hard/extreme のいずれかです" ;;
                esac
                shift 2 ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  error_exit "不明な引数: $1" ;;
        esac
    done
}

main() {
    parse_arguments "$@"

    echo -e "${C_CYAN}"
    echo "  ╔══════════════════════════╗"
    echo "  ║      数当てゲーム        ║"
    echo "  ╚══════════════════════════╝"
    echo -e "${C_RESET}"
    printf "  難易度: ${C_BOLD}%s${C_RESET}\n" "$difficulty"

    while true; do
        tries=0
        setup_difficulty
        play_game
        play_again || break
    done

    echo -e "\n${C_GREEN}またね！${C_RESET}\n"
}

main "$@"
