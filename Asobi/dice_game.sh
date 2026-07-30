#!/bin/bash
set -euo pipefail

#
# サイコロゲーム集
# 作成日: 2026-07-30
# バージョン: 1.0
#
# 複数のサイコロゲームを楽しめます
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare game_mode="menu"
declare dice_count=2
declare dice_sides=6

# ASCII サイコロの各面
dice_face() {
    local n=$1
    case $n in
        1) echo -e "┌─────┐\n│     │\n│  ●  │\n│     │\n└─────┘" ;;
        2) echo -e "┌─────┐\n│ ●   │\n│     │\n│   ● │\n└─────┘" ;;
        3) echo -e "┌─────┐\n│ ●   │\n│  ●  │\n│   ● │\n└─────┘" ;;
        4) echo -e "┌─────┐\n│ ● ● │\n│     │\n│ ● ● │\n└─────┘" ;;
        5) echo -e "┌─────┐\n│ ● ● │\n│  ●  │\n│ ● ● │\n└─────┘" ;;
        6) echo -e "┌─────┐\n│ ● ● │\n│ ● ● │\n│ ● ● │\n└─────┘" ;;
        *) echo -e "┌─────┐\n│     │\n│  ?  │\n│     │\n└─────┘" ;;
    esac
}

roll_animation() {
    local faces=(1 2 3 4 5 6 1 3 5 2 4 6)
    printf "\033[?25l"
    for f in "${faces[@]}"; do
        printf "\r\033[5A"
        dice_face "$f" | while IFS= read -r line; do
            printf "  %s\n" "$line"
        done
        sleep 0.08
    done
    printf "\033[?25h"
}

roll_dice() {
    local sides=${1:-6}
    echo $(( RANDOM % sides + 1 ))
}

game_simple() {
    echo ""
    printf "${C_BOLD}${C_CYAN}=== シンプルサイコロ ===${C_RESET}\n"
    echo ""
    printf "サイコロ数: ${C_YELLOW}%d個${C_RESET}  面数: ${C_YELLOW}%d面${C_RESET}\n" "$dice_count" "$dice_sides"
    echo ""

    local total=0
    local -a results=()

    for (( i=1; i<=dice_count; i++ )); do
        printf "サイコロ%d を振っています...\n" "$i"
        if [[ $dice_sides -eq 6 ]]; then
            echo ""
            dice_face 1 | while IFS= read -r line; do printf "  %s\n" "$line"; done
            roll_animation
            local val
            val=$(roll_dice "$dice_sides")
            printf "\r\033[5A"
            dice_face "$val" | while IFS= read -r line; do printf "  %s\n" "$line"; done
            echo ""
            results+=("$val")
            total=$(( total + val ))
        else
            local val
            val=$(roll_dice "$dice_sides")
            results+=("$val")
            total=$(( total + val ))
            printf "  結果: ${C_GREEN}%d${C_RESET}\n" "$val"
        fi
    done

    echo ""
    printf "  結果: ${C_CYAN}"
    printf "%d " "${results[@]}"
    printf "${C_RESET}\n"
    printf "  合計: ${C_BOLD}${C_GREEN}%d${C_RESET}\n" "$total"

    if [[ $dice_count -eq 2 && $dice_sides -eq 6 ]]; then
        echo ""
        case $total in
            2)  printf "  ${C_RED}ゾロ目(1)！ヘビ🐍${C_RESET}\n" ;;
            12) printf "  ${C_GREEN}ゾロ目(6)！最高！🎉${C_RESET}\n" ;;
            7)  printf "  ${C_YELLOW}ラッキーセブン！🍀${C_RESET}\n" ;;
            *)
                [[ "${results[0]}" == "${results[1]}" ]] && printf "  ${C_CYAN}ゾロ目！🎲${C_RESET}\n"
                ;;
        esac
    fi
    echo ""
}

game_yahtzee_like() {
    printf "${C_BOLD}${C_CYAN}=== ヤッツィー風ゲーム ===${C_RESET}\n"
    echo ""

    local -a dice=()
    local -a kept=()
    for (( i=0; i<5; i++ )); do
        dice+=( $(roll_dice 6) )
        kept+=(false)
    done

    local rounds=3
    for (( round=1; round<=rounds; round++ )); do
        printf "${C_BOLD}ラウンド %d/%d${C_RESET}\n" "$round" "$rounds"
        echo ""
        printf "  サイコロ: "
        for (( i=0; i<5; i++ )); do
            if [[ "${kept[$i]}" == "true" ]]; then
                printf "${C_DIM}[%d]${C_RESET} " "${dice[$i]}"
            else
                printf "${C_GREEN}%d${C_RESET} " "${dice[$i]}"
            fi
        done
        echo ""
        echo ""

        if [[ $round -lt $rounds ]]; then
            printf "  キープする番号を入力 (1-5、複数可、例:135) [Enter=全振り]: "
            local keep_input
            read -r keep_input

            # 全てfalseにリセット
            for (( i=0; i<5; i++ )); do kept[$i]=false; done

            # 指定番号をキープ
            for (( i=0; i<${#keep_input}; i++ )); do
                local idx=$(( ${keep_input:$i:1} - 1 ))
                if [[ $idx -ge 0 && $idx -lt 5 ]]; then
                    kept[$idx]=true
                fi
            done

            # キープしない分を振り直し
            for (( i=0; i<5; i++ )); do
                [[ "${kept[$i]}" == "false" ]] && dice[$i]=$(roll_dice 6)
            done
        fi
    done

    # スコア計算
    echo ""
    printf "${C_BOLD}最終結果: ${C_RESET}"
    local -A counts=()
    for d in "${dice[@]}"; do
        counts[$d]=$(( ${counts[$d]:-0} + 1 ))
    done

    printf "${C_CYAN}"
    printf "%d " "${dice[@]}"
    printf "${C_RESET}\n\n"

    local sorted_counts
    sorted_counts=$(for k in "${!counts[@]}"; do echo "${counts[$k]} $k"; done | sort -rn)

    local top1 top2
    top1=$(echo "$sorted_counts" | head -1 | awk '{print $1}')
    top2=$(echo "$sorted_counts" | sed -n '2p' | awk '{print $1}')

    local score_name=""
    if [[ $top1 -eq 5 ]]; then
        score_name="ファイブオブアカインド"
    elif [[ $top1 -eq 4 ]]; then
        score_name="フォーオブアカインド"
    elif [[ $top1 -eq 3 && $top2 -eq 2 ]]; then
        score_name="フルハウス"
    elif [[ $top1 -eq 3 ]]; then
        score_name="スリーオブアカインド"
    elif [[ $top1 -eq 2 && $top2 -eq 2 ]]; then
        score_name="ツーペア"
    elif [[ $top1 -eq 2 ]]; then
        score_name="ワンペア"
    else
        score_name="ノーペア"
    fi

    printf "  役: ${C_BOLD}${C_YELLOW}%s${C_RESET}\n\n" "$score_name"
}

game_high_low() {
    printf "${C_BOLD}${C_CYAN}=== ハイロー賭けゲーム ===${C_RESET}\n"
    echo ""

    local chips=100
    local rounds=5

    for (( round=1; round<=rounds; round++ )); do
        printf "${C_BOLD}ラウンド %d/%d${C_RESET}  チップ: ${C_YELLOW}%d${C_RESET}\n" "$round" "$rounds" "$chips"

        printf "  賭けチップ数 (所持: %d): " "$chips"
        local bet
        read -r bet
        if ! [[ "$bet" =~ ^[0-9]+$ ]] || [[ $bet -gt $chips || $bet -le 0 ]]; then
            printf "  ${C_RED}無効な賭け額です${C_RESET}\n"
            continue
        fi

        printf "  予想 [h=高い(4-6)/l=低い(1-3)]: "
        local guess
        read -r guess

        local val
        val=$(roll_dice 6)
        printf "  サイコロ: ${C_BOLD}${C_CYAN}%d${C_RESET}\n" "$val"

        local win=false
        if [[ "$guess" == "h" && $val -ge 4 ]]; then win=true; fi
        if [[ "$guess" == "l" && $val -le 3 ]]; then win=true; fi

        if $win; then
            chips=$(( chips + bet ))
            printf "  ${C_GREEN}当たり！ +%d チップ${C_RESET}\n\n" "$bet"
        else
            chips=$(( chips - bet ))
            printf "  ${C_RED}はずれ！ -%d チップ${C_RESET}\n\n" "$bet"
        fi

        [[ $chips -le 0 ]] && { printf "  ${C_RED}破産しました！${C_RESET}\n\n"; break; }
    done

    echo ""
    printf "  最終チップ: ${C_BOLD}"
    if [[ $chips -gt 100 ]]; then
        printf "${C_GREEN}%d (+%d)${C_RESET}" "$chips" "$(( chips - 100 ))"
    elif [[ $chips -lt 100 ]]; then
        printf "${C_RED}%d (%d)${C_RESET}" "$chips" "$(( chips - 100 ))"
    else
        printf "${C_YELLOW}%d (±0)${C_RESET}" "$chips"
    fi
    echo ""
    echo ""
}

show_menu() {
    while true; do
        clear_screen 2>/dev/null || printf "\033[2J\033[H"
        printf "${C_BOLD}${C_CYAN}"
        printf "  ██████╗ ██╗ ██████╗███████╗\n"
        printf "  ██╔══██╗██║██╔════╝██╔════╝\n"
        printf "  ██║  ██║██║██║     █████╗  \n"
        printf "  ██║  ██║██║██║     ██╔══╝  \n"
        printf "  ██████╔╝██║╚██████╗███████╗\n"
        printf "  ╚═════╝ ╚═╝ ╚═════╝╚══════╝\n"
        printf "${C_RESET}\n"
        printf "  ${C_BOLD}サイコロゲーム集${C_RESET}\n\n"
        printf "  [1] シンプルサイコロ\n"
        printf "  [2] ヤッツィー風\n"
        printf "  [3] ハイロー賭けゲーム\n"
        printf "  [q] 終了\n"
        echo ""
        printf "  選択: "
        local choice
        read -r choice
        echo ""

        case "$choice" in
            1) game_simple ;;
            2) game_yahtzee_like ;;
            3) game_high_low ;;
            q|Q) break ;;
            *) log_warning "無効な選択です" ;;
        esac

        printf "  Enterキーでメニューに戻る..."
        read -r
    done
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    cat <<EOF
使用方法: $PROG_NAME [オプション]
  -h, --help        このヘルプを表示
  -v, --version     バージョン情報を表示
  -n, --count <数>  サイコロの数 [デフォルト: 2]
  -s, --sides <数>  面数 [デフォルト: 6]
  --simple          シンプルモードで起動
EOF
                exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -n|--count)
                [[ $# -lt 2 ]] && error_exit "--count には値が必要です"
                dice_count="$2"; shift 2 ;;
            -s|--sides)
                [[ $# -lt 2 ]] && error_exit "--sides には値が必要です"
                dice_sides="$2"; shift 2 ;;
            --simple) game_mode="simple"; shift ;;
            *) error_exit "不明なオプション: $1" ;;
        esac
    done
}

main() {
    parse_arguments "$@"
    case "$game_mode" in
        simple) game_simple ;;
        menu)   show_menu ;;
    esac
}

main "$@"
