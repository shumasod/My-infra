#!/bin/bash
set -euo pipefail

#
# 算数クイズゲーム
# バージョン: 1.0
#
# 四則演算・暗算トレーニングゲーム
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"
readonly DEFAULT_ROUNDS=10

declare -i rounds=$DEFAULT_ROUNDS
declare difficulty="normal"
declare -i correct=0
declare -i total=0
declare -i total_time=0

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション]

算数クイズゲーム - 暗算トレーニング

オプション:
  -h, --help            このヘルプを表示
  -v, --version         バージョン情報を表示
  -r, --rounds NUM      出題数 [デフォルト: 10]
  -d, --difficulty LVL  難易度 (easy|normal|hard) [デフォルト: normal]

難易度:
  easy    1桁の加算・減算
  normal  2桁の四則演算
  hard    3桁・分数・パーセント計算

例:
  $PROG_NAME
  $PROG_NAME -r 20 -d hard

EOF
}

generate_question_easy() {
    local a=$(( RANDOM % 9 + 1 ))
    local b=$(( RANDOM % 9 + 1 ))
    local op_idx=$(( RANDOM % 2 ))
    local ops=("+" "-")
    local op="${ops[$op_idx]}"

    if [[ "$op" == "-" && $a -lt $b ]]; then
        local tmp=$a; a=$b; b=$tmp
    fi

    local answer
    case "$op" in
        "+") answer=$(( a + b )) ;;
        "-") answer=$(( a - b )) ;;
    esac

    echo "$a $op $b = ?"
    echo "$answer"
}

generate_question_normal() {
    local op_idx=$(( RANDOM % 4 ))
    local ops=("+" "-" "×" "÷")
    local op="${ops[$op_idx]}"
    local a b answer

    case "$op" in
        "+")
            a=$(( RANDOM % 90 + 10 ))
            b=$(( RANDOM % 90 + 10 ))
            answer=$(( a + b ))
            ;;
        "-")
            a=$(( RANDOM % 90 + 10 ))
            b=$(( RANDOM % (a - 1) + 1 ))
            answer=$(( a - b ))
            ;;
        "×")
            a=$(( RANDOM % 12 + 2 ))
            b=$(( RANDOM % 12 + 2 ))
            answer=$(( a * b ))
            ;;
        "÷")
            b=$(( RANDOM % 9 + 2 ))
            answer=$(( RANDOM % 12 + 1 ))
            a=$(( b * answer ))
            ;;
    esac

    echo "$a $op $b = ?"
    echo "$answer"
}

generate_question_hard() {
    local type=$(( RANDOM % 3 ))
    local a b answer

    case $type in
        0)  # 3桁の加減算
            a=$(( RANDOM % 900 + 100 ))
            b=$(( RANDOM % 900 + 100 ))
            if (( RANDOM % 2 )); then
                answer=$(( a + b ))
                echo "$a + $b = ?"
            else
                if (( a < b )); then local tmp=$a; a=$b; b=$tmp; fi
                answer=$(( a - b ))
                echo "$a - $b = ?"
            fi
            ;;
        1)  # パーセント計算
            local base=$(( (RANDOM % 9 + 1) * 100 ))
            local pct_idx=$(( RANDOM % 4 ))
            local pcts=(10 20 25 50)
            local pct="${pcts[$pct_idx]}"
            answer=$(( base * pct / 100 ))
            echo "${base}の${pct}%は?"
            ;;
        2)  # 二乗
            a=$(( RANDOM % 12 + 2 ))
            answer=$(( a * a ))
            echo "${a}の二乗は?"
            ;;
    esac

    echo "$answer"
}

generate_question() {
    case "$difficulty" in
        easy)   generate_question_easy ;;
        normal) generate_question_normal ;;
        hard)   generate_question_hard ;;
    esac
}

play_round() {
    local round_num="$1"
    local question answer

    local output
    output=$(generate_question)
    question=$(echo "$output" | head -1)
    answer=$(echo "$output" | tail -1)

    printf "\n${C_CYAN}問題 %d/%d${C_RESET}  %s\n" "$round_num" "$rounds" "$question"

    local start_time
    start_time=$(date +%s)
    printf "${C_YELLOW}答え: ${C_RESET}"
    local user_input
    read -r user_input

    if ! [[ "$user_input" =~ ^-?[0-9]+$ ]]; then
        log_warning "数値を入力してください"
        (( total++ )) || true
        return
    fi

    local end_time elapsed
    end_time=$(date +%s)
    elapsed=$(( end_time - start_time ))
    total_time=$(( total_time + elapsed ))

    if [[ "$user_input" == "$answer" ]]; then
        printf "${C_GREEN}正解！${C_RESET} (%d秒)\n" "$elapsed"
        (( correct++ )) || true
    else
        printf "${C_RED}不正解${C_RESET} 正解は ${C_BOLD}%s${C_RESET} (%d秒)\n" "$answer" "$elapsed"
    fi
    (( total++ )) || true
}

show_result() {
    local pct=0
    if (( total > 0 )); then
        pct=$(( correct * 100 / total ))
    fi
    local avg_time=0
    if (( total > 0 )); then
        avg_time=$(( total_time / total ))
    fi

    echo ""
    echo -e "${C_CYAN}========== 結果 ==========${C_RESET}"
    printf "  正解数:   %d / %d\n" "$correct" "$total"
    printf "  正解率:   %d%%\n" "$pct"
    printf "  平均時間: %d秒/問\n" "$avg_time"
    echo ""

    local rank
    if   (( pct >= 90 )); then rank="${C_YELLOW}S${C_RESET} (算数マスター!)"
    elif (( pct >= 70 )); then rank="${C_GREEN}A${C_RESET} (得意!)"
    elif (( pct >= 50 )); then rank="${C_BLUE}B${C_RESET} (まずまず)"
    else                       rank="${C_RED}C${C_RESET} (練習が必要)"
    fi
    printf "  ランク:   %b\n" "$rank"
    echo -e "${C_CYAN}==========================${C_RESET}"
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -r|--rounds)
                [[ $# -lt 2 ]] && error_exit "--rounds には数値が必要です"
                if ! [[ "$2" =~ ^[0-9]+$ ]]; then
                    error_exit "出題数は数値で指定してください"
                fi
                rounds="$2"; shift 2 ;;
            -d|--difficulty)
                [[ $# -lt 2 ]] && error_exit "--difficulty には値が必要です"
                case "$2" in
                    easy|normal|hard) difficulty="$2" ;;
                    *) error_exit "難易度は easy/normal/hard のいずれかです" ;;
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
    echo "  ║     算数クイズゲーム     ║"
    echo "  ╚══════════════════════════╝"
    echo -e "${C_RESET}"
    printf "  難易度: ${C_BOLD}%s${C_RESET}  出題数: ${C_BOLD}%d問${C_RESET}\n\n" "$difficulty" "$rounds"
    printf "  Enterで開始..."
    read -r

    for (( i=1; i<=rounds; i++ )); do
        play_round "$i"
    done

    show_result
}

main "$@"
