#!/bin/bash
set -euo pipefail

#
# スネークゲーム
# 作成日: 2026-07-04
# バージョン: 1.0
#
# W/A/S/D または矢印キーで操作
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"
readonly FIELD_W=40
readonly FIELD_H=20
readonly TICK=0.12

declare -a SNAKE_X=()
declare -a SNAKE_Y=()
declare -i FOOD_X=0
declare -i FOOD_Y=0
declare -i DIR_X=1
declare -i DIR_Y=0
declare -i SCORE=0
declare -i HIGH_SCORE=0
declare running=true

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション]

ターミナルでスネークゲームを遊びます。

操作:
  W / ↑   上
  S / ↓   下
  A / ←   左
  D / →   右
  Q        終了

オプション:
  -h, --help     このヘルプを表示
  -v, --version  バージョン情報を表示
EOF
}

cleanup() {
    show_cursor
    tput rmcup 2>/dev/null || true
    stty echo 2>/dev/null || true
    echo ""
}
trap cleanup EXIT INT TERM

place_food() {
    while true; do
        FOOD_X=$(( RANDOM % (FIELD_W - 2) + 1 ))
        FOOD_Y=$(( RANDOM % (FIELD_H - 2) + 1 ))
        local occupied=false
        local i
        for (( i = 0; i < ${#SNAKE_X[@]}; i++ )); do
            if [ "${SNAKE_X[$i]}" -eq "$FOOD_X" ] && [ "${SNAKE_Y[$i]}" -eq "$FOOD_Y" ]; then
                occupied=true
                break
            fi
        done
        "$occupied" || break
    done
}

check_collision() {
    local hx="${SNAKE_X[0]}"
    local hy="${SNAKE_Y[0]}"

    [ "$hx" -le 0 ] || [ "$hx" -ge $(( FIELD_W - 1 )) ] && return 0
    [ "$hy" -le 0 ] || [ "$hy" -ge $(( FIELD_H - 1 )) ] && return 0

    local i
    for (( i = 1; i < ${#SNAKE_X[@]}; i++ )); do
        [ "${SNAKE_X[$i]}" -eq "$hx" ] && [ "${SNAKE_Y[$i]}" -eq "$hy" ] && return 0
    done
    return 1
}

draw_frame() {
    local -a field=()
    local i
    for (( i = 0; i < FIELD_H; i++ )); do
        field[$i]=""
    done

    for (( i = 0; i < FIELD_W; i++ )); do
        field[0]+="${C_WHITE}═${C_RESET}"
        field[$(( FIELD_H - 1 ))]+="${C_WHITE}═${C_RESET}"
    done
    for (( i = 1; i < FIELD_H - 1; i++ )); do
        local row="${C_WHITE}║${C_RESET}"
        local j
        for (( j = 1; j < FIELD_W - 1; j++ )); do
            local cell=" "
            if [ "$j" -eq "${SNAKE_X[0]}" ] && [ "$i" -eq "${SNAKE_Y[0]}" ]; then
                cell="${C_GREEN}●${C_RESET}"
            elif [ "$j" -eq "$FOOD_X" ] && [ "$i" -eq "$FOOD_Y" ]; then
                cell="${C_RED}★${C_RESET}"
            else
                local k
                for (( k = 1; k < ${#SNAKE_X[@]}; k++ )); do
                    if [ "${SNAKE_X[$k]}" -eq "$j" ] && [ "${SNAKE_Y[$k]}" -eq "$i" ]; then
                        cell="${C_GREEN}○${C_RESET}"
                        break
                    fi
                done
            fi
            row+="$cell"
        done
        row+="${C_WHITE}║${C_RESET}"
        field[$i]="$row"
    done

    tput cup 0 0
    printf "${C_BOLD}${C_CYAN}スネークゲーム${C_RESET}  スコア:${C_YELLOW}%d${C_RESET}  最高:${C_GREEN}%d${C_RESET}  長さ:%d\n" \
        "$SCORE" "$HIGH_SCORE" "${#SNAKE_X[@]}"
    printf "${C_DIM}W/A/S/D で操作  Q で終了${C_RESET}\n"

    for (( i = 0; i < FIELD_H; i++ )); do
        printf "%s\n" "${field[$i]}"
    done
}

read_key() {
    local key
    IFS= read -rsn1 -t "$TICK" key 2>/dev/null || key=""

    if [ "$key" == $'\x1b' ]; then
        local seq
        IFS= read -rsn2 -t 0.05 seq 2>/dev/null || seq=""
        key="${key}${seq}"
    fi

    case "$key" in
        w|W|$'\x1b[A') [ "$DIR_Y" -ne 1  ] && { DIR_X=0;  DIR_Y=-1; } ;;
        s|S|$'\x1b[B') [ "$DIR_Y" -ne -1 ] && { DIR_X=0;  DIR_Y=1;  } ;;
        a|A|$'\x1b[D') [ "$DIR_X" -ne 1  ] && { DIR_X=-1; DIR_Y=0;  } ;;
        d|D|$'\x1b[C') [ "$DIR_X" -ne -1 ] && { DIR_X=1;  DIR_Y=0;  } ;;
        q|Q) running=false ;;
    esac
}

move_snake() {
    local new_x=$(( SNAKE_X[0] + DIR_X ))
    local new_y=$(( SNAKE_Y[0] + DIR_Y ))

    local ate=false
    if [ "$new_x" -eq "$FOOD_X" ] && [ "$new_y" -eq "$FOOD_Y" ]; then
        ate=true
        SCORE=$(( SCORE + 10 ))
    fi

    SNAKE_X=("$new_x" "${SNAKE_X[@]}")
    SNAKE_Y=("$new_y" "${SNAKE_Y[@]}")

    if ! "$ate"; then
        SNAKE_X=("${SNAKE_X[@]:0:${#SNAKE_X[@]}-1}")
        SNAKE_Y=("${SNAKE_Y[@]:0:${#SNAKE_Y[@]}-1}")
    else
        place_food
    fi
}

game_over_screen() {
    local mid_y=$(( FIELD_H / 2 + 2 ))
    tput cup "$mid_y" 10
    printf "${C_BOLD}${C_RED}GAME OVER!${C_RESET}"
    tput cup $(( mid_y + 1 )) 8
    printf "スコア: ${C_YELLOW}%d${C_RESET}" "$SCORE"
    tput cup $(( mid_y + 2 )) 6
    printf "${C_DIM}Enterで再挑戦 / Qで終了${C_RESET}"
    local k
    IFS= read -rsn1 k
    [[ "$k" == "q" || "$k" == "Q" ]] && return 1
    return 0
}

init_game() {
    SNAKE_X=(10 9 8)
    SNAKE_Y=(10 10 10)
    DIR_X=1
    DIR_Y=0
    SCORE=0
    running=true
    place_food
}

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            *) error_exit "不明なオプション: $1" ;;
        esac
    done

    tput smcup 2>/dev/null || true
    hide_cursor
    stty -echo 2>/dev/null || true

    while true; do
        init_game
        tput clear

        while "$running"; do
            draw_frame
            read_key
            move_snake

            if check_collision; then
                [ "$SCORE" -gt "$HIGH_SCORE" ] && HIGH_SCORE="$SCORE"
                draw_frame
                game_over_screen || break
                init_game
                tput clear
            fi
        done

        "$running" || break
    done
}

main "$@"
