#!/bin/bash
set -euo pipefail

#
# ワードル風ゲーム（5文字英単語当て）
# 作成日: 2026-07-04
# バージョン: 1.0
#
# 6回の試行で5文字の英単語を当てるゲーム
# 🟩=正解位置 🟨=文字はあるが位置違い ⬛=含まれない
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"
readonly WORD_LENGTH=5
readonly MAX_TRIES=6

readonly -a WORD_LIST=(
    "apple" "brave" "cloud" "dream" "eagle" "flame" "grace" "house"
    "image" "jewel" "knife" "lemon" "magic" "night" "ocean" "plant"
    "queen" "river" "stone" "tower" "ultra" "voice" "water" "xenon"
    "youth" "zebra" "angel" "beach" "crisp" "drive" "elect" "frost"
    "grant" "heart" "inbox" "joker" "kings" "light" "march" "nurse"
    "orbit" "pearl" "quest" "round" "sleep" "trust" "union" "vivid"
    "witch" "extra" "yield" "zones" "blast" "chess" "delta" "enemy"
    "false" "globe" "haste" "irony" "judge" "koala" "lance" "major"
)

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション]

5文字の英単語を6回以内に当てるゲームです。

ルール:
  🟩 (緑) = 正しい位置に正しい文字
  🟨 (黄) = 単語に含まれるが位置が違う
  ⬛ (黒) = 単語に含まれない

オプション:
  -h, --help     このヘルプを表示
  -v, --version  バージョン情報を表示
EOF
}

check_guess() {
    local guess="$1"
    local answer="$2"
    local result=""

    local -a ans_chars=()
    local -a gue_chars=()
    local i
    for (( i = 0; i < WORD_LENGTH; i++ )); do
        ans_chars[$i]="${answer:$i:1}"
        gue_chars[$i]="${guess:$i:1}"
    done

    local -a used=()
    for (( i = 0; i < WORD_LENGTH; i++ )); do
        used[$i]=0
    done

    local -a color=()
    for (( i = 0; i < WORD_LENGTH; i++ )); do
        if [ "${gue_chars[$i]}" == "${ans_chars[$i]}" ]; then
            color[$i]="green"
            used[$i]=1
        else
            color[$i]="black"
        fi
    done

    for (( i = 0; i < WORD_LENGTH; i++ )); do
        if [ "${color[$i]}" == "green" ]; then continue; fi
        local j
        for (( j = 0; j < WORD_LENGTH; j++ )); do
            if [ "${used[$j]}" -eq 0 ] && [ "${gue_chars[$i]}" == "${ans_chars[$j]}" ]; then
                color[$i]="yellow"
                used[$j]=1
                break
            fi
        done
    done

    for (( i = 0; i < WORD_LENGTH; i++ )); do
        echo -n "${color[$i]}:${gue_chars[$i]} "
    done
    echo ""
}

render_row() {
    local row_data="$1"
    local -a cells=()
    read -ra cells <<< "$row_data"

    printf "  "
    local cell
    for cell in "${cells[@]}"; do
        local color="${cell%%:*}"
        local char="${cell#*:}"
        char="${char^^}"
        case "$color" in
            green)  printf "${C_BG_GREEN}${C_BLACK} %s ${C_RESET}" "$char" ;;
            yellow) printf "${C_BG_YELLOW}${C_BLACK} %s ${C_RESET}" "$char" ;;
            black)  printf "${C_BG_GRAY}${C_WHITE} %s ${C_RESET}" "$char" ;;
        esac
    done
    echo ""
}

render_empty_row() {
    printf "  "
    local i
    for (( i = 0; i < WORD_LENGTH; i++ )); do
        printf "${C_DIM}[ _ ]${C_RESET}"
    done
    echo ""
}

show_keyboard() {
    local -n used_ref="$1"
    echo ""
    echo -e "  ${C_DIM}Q W E R T Y U I O P${C_RESET}"
    echo -e "  ${C_DIM}A S D F G H J K L${C_RESET}"
    echo -e "  ${C_DIM}Z X C V B N M${C_RESET}"
    # TODO: Color used keys
    echo ""
}

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            *) error_exit "不明なオプション: $1" ;;
        esac
    done

    local answer="${WORD_LIST[$(( RANDOM % ${#WORD_LIST[@]} ))]}"
    local -a history=()
    local -i attempt=0
    local won=false

    while [ "$attempt" -lt "$MAX_TRIES" ] && ! "$won"; do
        clear_screen
        print_center "WORDLE" 0 "${C_BOLD}${C_GREEN}"
        print_center "5文字の英単語を当てろ！(${attempt}/${MAX_TRIES})" 0 "$C_DIM"
        echo ""

        local i
        for (( i = 0; i < ${#history[@]}; i++ )); do
            render_row "${history[$i]}"
        done

        local remaining=$(( MAX_TRIES - attempt ))
        for (( i = 0; i < remaining; i++ )); do
            render_empty_row
        done

        echo ""
        printf "  ${C_BOLD}入力 (5文字):${C_RESET} "
        local guess
        read -r guess
        guess="${guess,,}"

        if [ "${#guess}" -ne "$WORD_LENGTH" ]; then
            log_warning "5文字で入力してください"
            sleep 1
            continue
        fi

        if ! [[ "$guess" =~ ^[a-z]+$ ]]; then
            log_warning "アルファベットのみ使用できます"
            sleep 1
            continue
        fi

        local row_data
        row_data=$(check_guess "$guess" "$answer")
        history+=("$row_data")
        attempt=$(( attempt + 1 ))

        if [ "$guess" == "$answer" ]; then
            won=true
        fi
    done

    clear_screen
    print_center "WORDLE" 0 "${C_BOLD}${C_GREEN}"
    echo ""
    local i
    for (( i = 0; i < ${#history[@]}; i++ )); do
        render_row "${history[$i]}"
    done
    echo ""

    if "$won"; then
        local msgs=("天才！" "素晴らしい！" "良い！" "まずまず" "惜しい！" "ギリギリ！")
        local msg_idx=$(( attempt - 1 ))
        print_center "${msgs[$msg_idx]}" 0 "${C_BOLD}${C_GREEN}"
        print_center "${attempt}回で正解！答え: ${answer^^}" 0 "$C_GREEN"
    else
        print_center "残念！答えは ${answer^^} でした" 0 "$C_RED"
    fi
    echo ""
}

main "$@"
