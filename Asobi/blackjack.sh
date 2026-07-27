#!/bin/bash
set -euo pipefail

#
# ブラックジャック
# バージョン: 1.0
#
# ターミナルで遊べるブラックジャックゲーム
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare -i initial_chips=1000
declare -i bet_amount=100

# カードデッキ
declare -a SUITS=("♠" "♥" "♦" "♣")
declare -a RANKS=("A" "2" "3" "4" "5" "6" "7" "8" "9" "10" "J" "Q" "K")

declare -a deck=()
declare -a player_hand=()
declare -a dealer_hand=()

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション]

ブラックジャック

オプション:
  -h, --help          このヘルプを表示
  -v, --version       バージョン情報を表示
  -c, --chips NUM     初期チップ数 [デフォルト: 1000]
  -b, --bet NUM       デフォルトベット額 [デフォルト: 100]

ルール:
  - ディーラーは17以上でスタンド
  - ブラックジャック (A+10) で 1.5倍
  - バストで負け

EOF
}

init_deck() {
    deck=()
    for suit in "${SUITS[@]}"; do
        for rank in "${RANKS[@]}"; do
            deck+=("${rank}${suit}")
        done
    done
}

shuffle_deck() {
    local n=${#deck[@]}
    for (( i=n-1; i>0; i-- )); do
        local j=$(( RANDOM % (i+1) ))
        local tmp="${deck[$i]}"
        deck[$i]="${deck[$j]}"
        deck[$j]="$tmp"
    done
}

draw_card() {
    local card="${deck[0]}"
    deck=("${deck[@]:1}")
    echo "$card"
}

card_value() {
    local card="$1"
    local rank="${card:0:-1}"
    case "$rank" in
        A)  echo "11" ;;
        J|Q|K|10) echo "10" ;;
        *)  echo "$rank" ;;
    esac
}

hand_value() {
    local -a hand=("$@")
    local total=0
    local aces=0

    for card in "${hand[@]}"; do
        local val
        val=$(card_value "$card")
        (( total += val )) || true
        [[ "${card:0:-1}" == "A" ]] && (( aces++ )) || true
    done

    while (( total > 21 && aces > 0 )); do
        (( total -= 10 )) || true
        (( aces-- )) || true
    done

    echo "$total"
}

is_blackjack() {
    local -a hand=("$@")
    [[ ${#hand[@]} -eq 2 ]] || return 1
    local val
    val=$(hand_value "${hand[@]}")
    [[ "$val" -eq 21 ]]
}

card_color() {
    local card="$1"
    local suit="${card: -1}"
    case "$suit" in
        ♥|♦) echo "$C_RED" ;;
        *)    echo "$C_RESET" ;;
    esac
}

display_hand() {
    local label="$1"
    shift
    local -a hand=("$@")
    local val
    val=$(hand_value "${hand[@]}")

    printf "  ${C_BOLD}%s${C_RESET} [合計: " "$label"
    if (( val > 21 )); then
        printf "${C_RED}${C_BOLD}%d BUST${C_RESET}]  " "$val"
    elif (( val == 21 )); then
        printf "${C_YELLOW}${C_BOLD}%d${C_RESET}]  " "$val"
    else
        printf "%d]  " "$val"
    fi

    for card in "${hand[@]}"; do
        local color
        color=$(card_color "$card")
        printf "${color}[%s]${C_RESET} " "$card"
    done
    echo ""
}

play_game() {
    local -i chips="$initial_chips"
    local -i bet="$bet_amount"
    local -i wins=0 losses=0 pushes=0 bjs=0
    local -i games=0

    local cleanup_called=false
    cleanup_bj() {
        $cleanup_called && return
        cleanup_called=true
        show_cursor
        clear_screen
        echo ""
        log_info "ブラックジャック終了"
        printf "  最終チップ: ${C_YELLOW}${C_BOLD}%d${C_RESET}\n" "$chips"
        printf "  勝敗: %dW %dL %dP (BJ:%d)\n" "$wins" "$losses" "$pushes" "$bjs"
        echo ""
    }
    trap cleanup_bj EXIT INT TERM
    hide_cursor

    # デッキ初期化
    init_deck
    shuffle_deck

    while true; do
        (( games++ )) || true

        # デッキ残枚数チェック
        (( ${#deck[@]} < 15 )) && { init_deck; shuffle_deck; }

        clear_screen
        print_center "🃏  ブラックジャック  🃏" 1 "$C_CYAN"
        draw_separator 2

        move_cursor 3 2
        printf "  チップ: ${C_YELLOW}${C_BOLD}%d${C_RESET}  |  ベット: ${C_CYAN}%d${C_RESET}  |  %dW %dL %dP" \
            "$chips" "$bet" "$wins" "$losses" "$pushes"

        echo ""
        move_cursor 5 2
        printf "${C_DIM}[Enter]=ゲーム開始  [+]=ベット増  [-]=ベット減  [q]=終了${C_RESET}"
        move_cursor 6 2
        printf "> "

        if (( chips < bet )); then
            log_error "チップが不足しています"
            sleep 2
            break
        fi

        local key=""
        IFS= read -r -s -n1 key || true
        case "${key:-}" in
            q|Q) break ;;
            "+") (( bet + 50 <= chips )) && (( bet += 50 )) || true; (( games-- )) || true; continue ;;
            "-") (( bet > 50 )) && (( bet -= 50 )) || true; (( games-- )) || true; continue ;;
            "") ;;
            *) (( games-- )) || true; continue ;;
        esac

        (( chips -= bet )) || true

        # カード配布
        player_hand=()
        dealer_hand=()
        player_hand+=("$(draw_card)" "$(draw_card)")
        dealer_hand+=("$(draw_card)" "$(draw_card)")

        # ブラックジャック判定
        local player_bj=false dealer_bj=false
        is_blackjack "${player_hand[@]}" && player_bj=true
        is_blackjack "${dealer_hand[@]}" && dealer_bj=true

        clear_screen
        print_center "🃏  ブラックジャック  🃏" 1 "$C_CYAN"
        draw_separator 2

        move_cursor 3 2
        printf "  チップ: ${C_YELLOW}%d${C_RESET}  ベット: ${C_CYAN}%d${C_RESET}\n" "$chips" "$bet"

        echo ""
        move_cursor 5 2
        # ディーラーの手(1枚隠す)
        printf "  ${C_BOLD}ディーラー${C_RESET} [?]  "
        local color
        color=$(card_color "${dealer_hand[0]}")
        printf "${color}[%s]${C_RESET} [??]\n" "${dealer_hand[0]}"

        echo ""
        move_cursor 7 2
        display_hand "あなた" "${player_hand[@]}"

        local game_over=false
        local result_msg=""

        if $player_bj || $dealer_bj; then
            game_over=true
            if $player_bj && $dealer_bj; then
                result_msg="${C_CYAN}プッシュ (両者BJ)${C_RESET}"
                (( chips += bet )) || true
                (( pushes++ )) || true
            elif $player_bj; then
                local bj_win=$(( bet * 3 / 2 ))
                result_msg="${C_YELLOW}${C_BOLD}ブラックジャック!! +${bj_win}${C_RESET}"
                (( chips += bet + bj_win )) || true
                (( wins++ )) || true
                (( bjs++ )) || true
            else
                result_msg="${C_RED}ディーラーBJ... 負け${C_RESET}"
                (( losses++ )) || true
            fi
        fi

        # プレイヤーのアクション
        while ! $game_over; do
            local pval
            pval=$(hand_value "${player_hand[@]}")

            move_cursor 9 2
            printf "${C_DIM}[h]=ヒット  [s]=スタンド${C_RESET}"
            move_cursor 10 2
            printf "> "

            IFS= read -r -s -n1 key || true
            case "${key:-}" in
                h|H)
                    player_hand+=("$(draw_card)")
                    move_cursor 7 2
                    printf "%60s\r" ""
                    move_cursor 7 2
                    display_hand "あなた" "${player_hand[@]}"
                    pval=$(hand_value "${player_hand[@]}")
                    if (( pval > 21 )); then
                        result_msg="${C_RED}バスト！ 負け${C_RESET}"
                        (( losses++ )) || true
                        game_over=true
                    elif (( pval == 21 )); then
                        game_over=true
                    fi
                    ;;
                s|S)
                    game_over=true
                    ;;
                q|Q)
                    (( chips += bet )) || true
                    break 2
                    ;;
            esac
        done

        # ディーラーのアクション
        if [[ -z "$result_msg" ]]; then
            clear_screen
            print_center "🃏  ブラックジャック  🃏" 1 "$C_CYAN"
            draw_separator 2
            move_cursor 3 2
            printf "  チップ: ${C_YELLOW}%d${C_RESET}  ベット: ${C_CYAN}%d${C_RESET}\n" "$chips" "$bet"

            while true; do
                local dval
                dval=$(hand_value "${dealer_hand[@]}")
                (( dval >= 17 )) && break
                dealer_hand+=("$(draw_card)")
            done

            echo ""
            move_cursor 5 2
            display_hand "ディーラー" "${dealer_hand[@]}"
            echo ""
            move_cursor 7 2
            display_hand "あなた" "${player_hand[@]}"

            local pval dval
            pval=$(hand_value "${player_hand[@]}")
            dval=$(hand_value "${dealer_hand[@]}")

            if (( dval > 21 )); then
                result_msg="${C_GREEN}ディーラーバスト！ 勝ち +${bet}${C_RESET}"
                (( chips += bet * 2 )) || true
                (( wins++ )) || true
            elif (( pval > dval )); then
                result_msg="${C_GREEN}勝ち！ +${bet}${C_RESET}"
                (( chips += bet * 2 )) || true
                (( wins++ )) || true
            elif (( pval == dval )); then
                result_msg="${C_CYAN}プッシュ (引き分け)${C_RESET}"
                (( chips += bet )) || true
                (( pushes++ )) || true
            else
                result_msg="${C_RED}負け...${C_RESET}"
                (( losses++ )) || true
            fi
        fi

        move_cursor 10 2
        printf "  結果: %b\n" "$result_msg"
        move_cursor 11 2
        printf "  チップ: ${C_YELLOW}${C_BOLD}%d${C_RESET}\n" "$chips"
        move_cursor 13 2
        printf "${C_DIM}Enterで続ける...${C_RESET}"
        IFS= read -r -s -n1 key || true
        [[ "${key:-}" == "q" ]] && break

        (( chips <= 0 )) && {
            move_cursor 14 2
            printf "${C_RED}チップがなくなりました！${C_RESET}\n"
            sleep 2
            break
        }
    done
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -c|--chips)   [[ $# -lt 2 ]] && error_exit "-c には値が必要です"; initial_chips="$2"; shift 2 ;;
            -b|--bet)     [[ $# -lt 2 ]] && error_exit "-b には値が必要です"; bet_amount="$2"; shift 2 ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  shift ;;
        esac
    done
}

main() {
    parse_arguments "$@"
    play_game
}

main "$@"
