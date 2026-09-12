#!/bin/bash
set -euo pipefail

#
# じゃんけんゲーム (拡張版)
# バージョン: 1.0
#
# 通常じゃんけん + じゃんけんマン + 連勝ボーナス付き拡張ゲーム
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare mode="normal"
declare -i rounds=5
declare -i player_wins=0
declare -i cpu_wins=0
declare -i draws=0
declare -i streak=0
declare -i max_streak=0
declare -i total_score=0

declare -a HANDS_NORMAL=("グー" "チョキ" "パー")
declare -a HANDS_NORMAL_EN=("rock" "scissors" "paper")
declare -a HANDS_EXT=("グー" "チョキ" "パー" "スパーク" "ダイナマイト")
declare -a EMOJI_NORMAL=("✊" "✌️" "🖐️")
declare -a EMOJI_EXT=("✊" "✌️" "🖐️" "⚡" "💥")

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション]

じゃんけんゲーム (拡張版)

オプション:
  -h, --help            このヘルプを表示
  -v, --version         バージョン情報を表示
  -m, --mode MODE       ゲームモード (normal|extended|tournament) [デフォルト: normal]
  -r, --rounds NUM      勝負数 [デフォルト: 5]

モード:
  normal      通常じゃんけん (3択)
  extended    拡張じゃんけん (5択: グー/チョキ/パー/スパーク/ダイナマイト)
  tournament  勝ち抜き戦 (先に3勝した方が優勝)

例:
  $PROG_NAME
  $PROG_NAME -m extended
  $PROG_NAME -m tournament

EOF
}

get_cpu_choice() {
    local -n hands_ref="$1"
    echo $(( RANDOM % ${#hands_ref[@]} ))
}

judge_normal() {
    local p="$1"
    local c="$2"
    if (( p == c ));               then echo "draw"
    elif (( (p - c + 3) % 3 == 1 )); then echo "win"
    else                               echo "lose"
    fi
}

judge_extended() {
    local p="$1"
    local c="$2"
    if (( p == c )); then echo "draw"; return; fi

    declare -A win_map
    win_map["0,1"]=1  # グー > チョキ
    win_map["1,2"]=1  # チョキ > パー
    win_map["2,0"]=1  # パー > グー
    win_map["3,0"]=1  # スパーク > グー
    win_map["3,1"]=1  # スパーク > チョキ
    win_map["4,2"]=1  # ダイナマイト > パー
    win_map["4,3"]=1  # ダイナマイト > スパーク
    win_map["0,4"]=1  # グー > ダイナマイト (不発)
    win_map["2,3"]=1  # パー > スパーク (包む)

    if [[ -n "${win_map["${p},${c}"]+_}" ]]; then
        echo "win"
    else
        echo "lose"
    fi
}

show_result_msg() {
    local result="$1"
    local bonus="$2"
    case "$result" in
        win)
            local bonus_str=""
            (( bonus > 0 )) && bonus_str=" 🔥連勝ボーナス +${bonus}pt"
            echo -e "${C_GREEN}あなたの勝ち！🎉${bonus_str}${C_RESET}" ;;
        lose) echo -e "${C_RED}あなたの負け...😢${C_RESET}" ;;
        draw) echo -e "${C_YELLOW}引き分け！🤝${C_RESET}" ;;
    esac
}

play_round_normal() {
    local -a hands=("${HANDS_NORMAL[@]}")
    local -a emojis=("${EMOJI_NORMAL[@]}")

    echo ""
    echo -e "  ${C_CYAN}【選択してください】${C_RESET}"
    for (( i=0; i<${#hands[@]}; i++ )); do
        printf "  %d) %s %s\n" "$(( i+1 ))" "${emojis[$i]}" "${hands[$i]}"
    done
    echo ""
    printf "  選択 [1-%d]: " "${#hands[@]}"

    local input
    read -r input
    if ! [[ "$input" =~ ^[1-3]$ ]]; then
        log_warning "1〜3で入力してください"
        return 1
    fi

    local player=$(( input - 1 ))
    local cpu
    cpu=$(get_cpu_choice hands)

    echo ""
    printf "  あなた: %s %s\n" "${emojis[$player]}" "${hands[$player]}"
    printf "  CPU:    %s %s\n" "${emojis[$cpu]}" "${hands[$cpu]}"
    echo ""

    local result
    result=$(judge_normal "$player" "$cpu")

    local bonus=0
    if [[ "$result" == "win" ]]; then
        (( player_wins++ )) || true
        (( streak++ )) || true
        (( streak > max_streak )) && max_streak=$streak
        bonus=$(( (streak - 1) * 10 ))
        (( total_score += 100 + bonus )) || true
    elif [[ "$result" == "lose" ]]; then
        (( cpu_wins++ )) || true
        streak=0
    else
        (( draws++ )) || true
        streak=0
    fi

    show_result_msg "$result" "$bonus"
    [[ "$result" == "win" && $streak -gt 1 ]] && \
        printf "  ${C_YELLOW}🔥 %d連勝中！${C_RESET}\n" "$streak"
    return 0
}

play_round_extended() {
    local -a hands=("${HANDS_EXT[@]}")
    local -a emojis=("${EMOJI_EXT[@]}")

    echo ""
    echo -e "  ${C_CYAN}【選択してください (拡張モード)】${C_RESET}"
    for (( i=0; i<${#hands[@]}; i++ )); do
        printf "  %d) %s %s\n" "$(( i+1 ))" "${emojis[$i]}" "${hands[$i]}"
    done
    echo ""
    printf "  選択 [1-%d]: " "${#hands[@]}"

    local input
    read -r input
    if ! [[ "$input" =~ ^[1-5]$ ]]; then
        log_warning "1〜5で入力してください"
        return 1
    fi

    local player=$(( input - 1 ))
    local cpu
    cpu=$(get_cpu_choice hands)

    echo ""
    printf "  あなた: %s %s\n" "${emojis[$player]}" "${hands[$player]}"
    printf "  CPU:    %s %s\n" "${emojis[$cpu]}" "${hands[$cpu]}"
    echo ""

    local result
    result=$(judge_extended "$player" "$cpu")

    if [[ "$result" == "win" ]]; then
        (( player_wins++ )) || true
        (( streak++ )) || true
    elif [[ "$result" == "lose" ]]; then
        (( cpu_wins++ )) || true
        streak=0
    else
        (( draws++ )) || true
    fi

    show_result_msg "$result" 0
    return 0
}

show_final_score() {
    echo ""
    echo -e "${C_CYAN}╔══════════════════════════╗${C_RESET}"
    echo -e "${C_CYAN}║        最終結果          ║${C_RESET}"
    echo -e "${C_CYAN}╚══════════════════════════╝${C_RESET}"
    printf "  あなた: %d勝  CPU: %d勝  引分: %d\n" \
        "$player_wins" "$cpu_wins" "$draws"

    if [[ "$mode" == "normal" ]]; then
        printf "  スコア:  %dpt\n" "$total_score"
        printf "  最大連勝: %d\n" "$max_streak"
    fi

    echo ""
    if   (( player_wins > cpu_wins )); then log_success "あなたの優勝！🏆"
    elif (( player_wins < cpu_wins )); then log_error   "CPUの優勝...💀"
    else                                    log_info    "引き分け！🤝"
    fi
    echo ""
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -m|--mode)
                [[ $# -lt 2 ]] && error_exit "--mode には値が必要です"
                case "$2" in
                    normal|extended|tournament) mode="$2" ;;
                    *) error_exit "モードは normal/extended/tournament のいずれかです" ;;
                esac
                shift 2 ;;
            -r|--rounds)
                [[ $# -lt 2 ]] && error_exit "--rounds には数値が必要です"
                rounds="$2"; shift 2 ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  error_exit "不明な引数: $1" ;;
        esac
    done
}

main() {
    parse_arguments "$@"

    echo ""
    echo -e "${C_CYAN}"
    echo "  ╔══════════════════════════╗"
    echo "  ║    じゃんけんゲーム ✊   ║"
    echo "  ╚══════════════════════════╝"
    echo -e "${C_RESET}"
    printf "  モード: ${C_BOLD}%s${C_RESET}  " "$mode"

    if [[ "$mode" == "tournament" ]]; then
        echo "先に3勝した方の優勝"
        local win_target=3
        while (( player_wins < win_target && cpu_wins < win_target )); do
            printf "  [あなた %d - %d CPU]\n" "$player_wins" "$cpu_wins"
            play_round_normal || true
        done
    else
        printf "%d本勝負\n" "$rounds"
        for (( i=1; i<=rounds; i++ )); do
            printf "\n  ── 第%d戦 ──\n" "$i"
            if [[ "$mode" == "extended" ]]; then
                play_round_extended || true
            else
                play_round_normal || true
            fi
        done
    fi

    show_final_score
}

main "$@"
