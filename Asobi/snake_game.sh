#!/bin/bash
set -euo pipefail

#
# スネークゲーム
# バージョン: 1.0
#
# ターミナルで遊べるスネークゲーム
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare difficulty="normal"
declare -i board_w=40
declare -i board_h=20

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション]

スネークゲーム

オプション:
  -h, --help          このヘルプを表示
  -v, --version       バージョン情報を表示
  -d, --difficulty D  難易度 (easy|normal|hard) [デフォルト: normal]
  --width W           ボード幅 [デフォルト: 40]
  --height H          ボード高さ [デフォルト: 20]

操作:
  WASD / 矢印キー   移動
  p                 一時停止
  q                 終了

EOF
}

get_speed() {
    case "$difficulty" in
        easy)   echo "0.15" ;;
        normal) echo "0.10" ;;
        hard)   echo "0.06" ;;
        *)      echo "0.10" ;;
    esac
}

play_snake() {
    local speed
    speed=$(get_speed)

    # ヘビの初期位置 (配列: "row,col" の順)
    local -a snake_rows=()
    local -a snake_cols=()
    local -i init_row=$(( board_h / 2 ))
    local -i init_col=$(( board_w / 2 ))

    # 初期長さ3
    snake_rows=($(( init_row )) $(( init_row )) $(( init_row )))
    snake_cols=($(( init_col )) $(( init_col - 1 )) $(( init_col - 2 )))

    local dir="RIGHT"
    local next_dir="RIGHT"
    local -i score=0
    local -i food_row food_col
    local game_over=false
    local paused=false

    # 食べ物を配置
    place_food() {
        while true; do
            food_row=$(( RANDOM % (board_h - 2) + 1 ))
            food_col=$(( RANDOM % (board_w - 2) + 1 ))
            local occupied=false
            local i
            for (( i=0; i<${#snake_rows[@]}; i++ )); do
                if (( snake_rows[$i] == food_row && snake_cols[$i] == food_col )); then
                    occupied=true
                    break
                fi
            done
            $occupied || break
        done
    }

    place_food

    draw_board() {
        clear_screen

        # ヘッダー
        move_cursor 1 2
        printf "${C_BOLD}スネークゲーム${C_RESET}  スコア: ${C_YELLOW}${C_BOLD}%d${C_RESET}  長さ: ${C_CYAN}%d${C_RESET}  難易度: %s" \
            "$score" "${#snake_rows[@]}" "$difficulty"

        # 上の壁
        move_cursor 2 2
        printf "${C_WHITE}+"
        printf '%0.s-' $(seq 1 $board_w)
        printf "+${C_RESET}"

        # 側面と内部
        local r
        for (( r=0; r<board_h; r++ )); do
            move_cursor $(( r + 3 )) 2
            printf "${C_WHITE}|${C_RESET}"

            local c
            for (( c=0; c<board_w; c++ )); do
                local cell=" "
                local color=""

                # 食べ物チェック
                if (( r == food_row && c == food_col )); then
                    cell="🍎"
                    printf "%s" "$cell"
                    continue
                fi

                # ヘビチェック
                local is_snake=false
                local is_head=false
                local i
                for (( i=0; i<${#snake_rows[@]}; i++ )); do
                    if (( snake_rows[$i] == r && snake_cols[$i] == c )); then
                        is_snake=true
                        (( i == 0 )) && is_head=true
                        break
                    fi
                done

                if $is_head; then
                    printf "${C_GREEN}${C_BOLD}@${C_RESET}"
                elif $is_snake; then
                    printf "${C_GREEN}o${C_RESET}"
                else
                    printf " "
                fi
            done

            printf "${C_WHITE}|${C_RESET}"
        done

        # 下の壁
        move_cursor $(( board_h + 3 )) 2
        printf "${C_WHITE}+"
        printf '%0.s-' $(seq 1 $board_w)
        printf "+${C_RESET}"

        # 操作説明
        move_cursor $(( board_h + 4 )) 2
        printf "${C_DIM}WASD/矢印=移動  p=一時停止  q=終了${C_RESET}"

        $paused && {
            move_cursor $(( board_h / 2 + 3 )) $(( board_w / 2 - 3 ))
            printf "${C_YELLOW}${C_BOLD} PAUSED ${C_RESET}"
        }
    }

    local cleanup_called=false
    cleanup_snake() {
        $cleanup_called && return
        cleanup_called=true
        show_cursor
        tput cnorm 2>/dev/null || true
        clear_screen
        echo ""
        log_info "ゲーム終了"
        printf "  最終スコア: ${C_YELLOW}${C_BOLD}%d${C_RESET}\n" "$score"
        printf "  最終の長さ: ${C_CYAN}%d${C_RESET}\n" "${#snake_rows[@]}"
        echo ""
    }
    trap cleanup_snake EXIT INT TERM
    hide_cursor

    while ! $game_over; do
        draw_board

        # キー入力 (ノンブロッキング)
        local key=""
        IFS= read -r -s -n1 -t "$speed" key 2>/dev/null || true

        # 矢印キー対応 (ESC[A/B/C/D)
        if [[ "$key" == $'\x1b' ]]; then
            local k2 k3
            IFS= read -r -s -n1 -t 0.05 k2 2>/dev/null || true
            IFS= read -r -s -n1 -t 0.05 k3 2>/dev/null || true
            if [[ "$k2" == "[" ]]; then
                case "$k3" in
                    A) key="w" ;;
                    B) key="s" ;;
                    C) key="d" ;;
                    D) key="a" ;;
                esac
            fi
        fi

        case "${key:-}" in
            q|Q) break ;;
            p|P) paused=!$paused; continue ;;
            w|W) [[ "$dir" != "DOWN" ]] && next_dir="UP" ;;
            s|S) [[ "$dir" != "UP" ]] && next_dir="DOWN" ;;
            a|A) [[ "$dir" != "RIGHT" ]] && next_dir="LEFT" ;;
            d|D) [[ "$dir" != "LEFT" ]] && next_dir="RIGHT" ;;
        esac

        $paused && continue

        dir="$next_dir"

        # 新しいヘッド位置
        local -i new_row="${snake_rows[0]}"
        local -i new_col="${snake_cols[0]}"

        case "$dir" in
            UP)    (( new_row-- )) || true ;;
            DOWN)  (( new_row++ )) || true ;;
            LEFT)  (( new_col-- )) || true ;;
            RIGHT) (( new_col++ )) || true ;;
        esac

        # 壁衝突チェック
        if (( new_row < 0 || new_row >= board_h || new_col < 0 || new_col >= board_w )); then
            game_over=true
            break
        fi

        # 自己衝突チェック
        local i
        for (( i=0; i<${#snake_rows[@]}; i++ )); do
            if (( snake_rows[$i] == new_row && snake_cols[$i] == new_col )); then
                game_over=true
                break
            fi
        done
        $game_over && break

        # 食べ物チェック
        local ate_food=false
        if (( new_row == food_row && new_col == food_col )); then
            ate_food=true
            (( score += 10 )) || true
            place_food
        fi

        # ヘビを移動 (先頭に追加)
        snake_rows=("$new_row" "${snake_rows[@]}")
        snake_cols=("$new_col" "${snake_cols[@]}")

        # 食べていない場合は末尾を削除
        if ! $ate_food; then
            unset 'snake_rows[-1]'
            unset 'snake_cols[-1]'
        fi
    done

    if $game_over; then
        draw_board
        move_cursor $(( board_h / 2 + 3 )) $(( board_w / 2 - 5 ))
        printf "${C_RED}${C_BOLD} GAME OVER! ${C_RESET}"
        sleep 2
    fi
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -d|--difficulty)
                [[ $# -lt 2 ]] && error_exit "-d には値が必要です"
                difficulty="$2"
                case "$difficulty" in
                    easy|normal|hard) ;;
                    *) error_exit "無効な難易度: $difficulty" ;;
                esac
                shift 2
                ;;
            --width)  [[ $# -lt 2 ]] && error_exit "--width には値が必要です"; board_w="$2"; shift 2 ;;
            --height) [[ $# -lt 2 ]] && error_exit "--height には値が必要です"; board_h="$2"; shift 2 ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  shift ;;
        esac
    done
}

main() {
    parse_arguments "$@"
    play_snake
}

main "$@"
