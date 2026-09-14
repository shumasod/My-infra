#!/bin/bash
set -euo pipefail

#
# ブラックジャック
# 作成日: 2026-07-04
# バージョン: 1.0
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

readonly -a SUITS=("♠" "♥" "♦" "♣")
readonly -a RANKS=("A" "2" "3" "4" "5" "6" "7" "8" "9" "10" "J" "Q" "K")

declare -a DECK=()
declare -a PLAYER_HAND=()
declare -a DEALER_HAND=()
declare -i player_chips=100

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション]

ディーラー相手のブラックジャック。

オプション:
  -h, --help        このヘルプを表示
  -v, --version     バージョン情報を表示
  -c, --chips N     初期チップ数（デフォルト: 100）
EOF
}

card_value() {
    local rank="${1%%_*}"
    case "$rank" in
        A)  echo 11 ;;
        J|Q|K) echo 10 ;;
        *)  echo "$rank" ;;
    esac
}

hand_total() {
    local -n hand_ref="$1"
    local total=0
    local aces=0
    local card
    for card in "${hand_ref[@]}"; do
        local v
        v=$(card_value "$card")
        total=$(( total + v ))
        [[ "${card%%_*}" == "A" ]] && aces=$(( aces + 1 ))
    done
    while [ "$total" -gt 21 ] && [ "$aces" -gt 0 ]; do
        total=$(( total - 10 ))
        aces=$(( aces - 1 ))
    done
    echo "$total"
}

init_deck() {
    DECK=()
    local suit rank
    for suit in "${SUITS[@]}"; do
        for rank in "${RANKS[@]}"; do
            DECK+=("${rank}_${suit}")
        done
    done
    local i j tmp
    for (( i = ${#DECK[@]} - 1; i > 0; i-- )); do
        j=$(( RANDOM % (i + 1) ))
        tmp="${DECK[$i]}"
        DECK[$i]="${DECK[$j]}"
        DECK[$j]="$tmp"
    done
}

deal_card() {
    local -n target_ref="$1"
    local card="${DECK[0]}"
    DECK=("${DECK[@]:1}")
    target_ref+=("$card")
}

display_card() {
    local card="$1"
    local rank="${card%%_*}"
    local suit="${card#*_}"
    local color="$C_WHITE"
    [[ "$suit" == "♥" || "$suit" == "♦" ]] && color="$C_RED"
    printf "${color}[%2s%s]${C_RESET}" "$rank" "$suit"
}

show_hands() {
    local hide_dealer="${1:-false}"

    echo ""
    printf "  ${C_BOLD}ディーラー:${C_RESET} "
    if "$hide_dealer"; then
        display_card "${DEALER_HAND[0]}"
        printf " ${C_DIM}[??]${C_RESET}"
        printf "  ${C_DIM}(?)${C_RESET}"
    else
        local card
        for card in "${DEALER_HAND[@]}"; do display_card "$card"; done
        local dtotal
        dtotal=$(hand_total DEALER_HAND)
        printf "  ${C_CYAN}(%d)${C_RESET}" "$dtotal"
    fi
    echo ""

    printf "  ${C_BOLD}あなた:${C_RESET}     "
    local card
    for card in "${PLAYER_HAND[@]}"; do display_card "$card"; done
    local ptotal
    ptotal=$(hand_total PLAYER_HAND)
    local pcolor="$C_GREEN"
    [ "$ptotal" -gt 21 ] && pcolor="$C_RED"
    [ "$ptotal" -eq 21 ] && pcolor="${C_BOLD}$C_YELLOW"
    printf "  ${pcolor}(%d)${C_RESET}" "$ptotal"
    echo ""
    echo ""
}

player_turn() {
    while true; do
        local ptotal
        ptotal=$(hand_total PLAYER_HAND)
        [ "$ptotal" -ge 21 ] && break

        show_hands true
        echo -e "  ${C_YELLOW}[H]${C_RESET} ヒット  ${C_YELLOW}[S]${C_RESET} スタンド"
        printf "  選択 > "
        local choice
        read -r choice
        case "$choice" in
            h|H) deal_card PLAYER_HAND ;;
            s|S) break ;;
            *) log_warning "H か S を入力してください" ;;
        esac
    done
}

dealer_turn() {
    local dtotal
    dtotal=$(hand_total DEALER_HAND)
    while [ "$dtotal" -lt 17 ]; do
        deal_card DEALER_HAND
        dtotal=$(hand_total DEALER_HAND)
    done
}

play_round() {
    local bet="$1"
    PLAYER_HAND=()
    DEALER_HAND=()
    init_deck

    deal_card PLAYER_HAND
    deal_card DEALER_HAND
    deal_card PLAYER_HAND
    deal_card DEALER_HAND

    clear_screen
    print_center "─── ブラックジャック ───" 0 "$C_CYAN"
    printf "  チップ: ${C_GREEN}%d${C_RESET}  ベット: ${C_YELLOW}%d${C_RESET}\n" "$player_chips" "$bet"

    local ptotal
    ptotal=$(hand_total PLAYER_HAND)

    if [ "$ptotal" -eq 21 ]; then
        show_hands false
        echo -e "  ${C_BOLD}${C_YELLOW}★ ブラックジャック！★${C_RESET}"
        player_chips=$(( player_chips + bet * 3 / 2 ))
        return
    fi

    player_turn

    ptotal=$(hand_total PLAYER_HAND)
    if [ "$ptotal" -gt 21 ]; then
        show_hands false
        echo -e "  ${C_RED}バスト！負けました...${C_RESET}"
        player_chips=$(( player_chips - bet ))
        return
    fi

    dealer_turn

    local dtotal
    dtotal=$(hand_total DEALER_HAND)
    show_hands false

    if [ "$dtotal" -gt 21 ]; then
        echo -e "  ${C_GREEN}ディーラーバスト！あなたの勝ち！${C_RESET}"
        player_chips=$(( player_chips + bet ))
    elif [ "$ptotal" -gt "$dtotal" ]; then
        echo -e "  ${C_GREEN}あなたの勝ち！${C_RESET}"
        player_chips=$(( player_chips + bet ))
    elif [ "$ptotal" -lt "$dtotal" ]; then
        echo -e "  ${C_RED}ディーラーの勝ち...${C_RESET}"
        player_chips=$(( player_chips - bet ))
    else
        echo -e "  ${C_YELLOW}引き分け（プッシュ）${C_RESET}"
    fi
}

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -c|--chips)
                [[ $# -lt 2 ]] && error_exit "--chips には数値が必要です"
                player_chips="$2"; shift 2 ;;
            *) error_exit "不明なオプション: $1" ;;
        esac
    done

    clear_screen
    print_center "ブラックジャック" 0 "${C_BOLD}${C_CYAN}"
    echo ""

    while [ "$player_chips" -gt 0 ]; do
        printf "  チップ: ${C_GREEN}%d${C_RESET}\n" "$player_chips"
        printf "  ベット額を入力 (1-%d, q=終了) > " "$player_chips"
        local input
        read -r input
        [[ "$input" == "q" || "$input" == "Q" ]] && break

        if ! [[ "$input" =~ ^[0-9]+$ ]] || [ "$input" -lt 1 ] || [ "$input" -gt "$player_chips" ]; then
            log_warning "1〜${player_chips} の数値を入力してください"
            sleep 1
            continue
        fi

        play_round "$input"
        echo ""
        echo -e "${C_DIM}Enterキーで続ける...${C_RESET}"
        read -r
        clear_screen
    done

    echo ""
    if [ "$player_chips" -le 0 ]; then
        log_error "チップがなくなりました。ゲームオーバー"
    else
        log_success "終了チップ: ${player_chips} 枚"
    fi
    echo ""
}

main "$@"
