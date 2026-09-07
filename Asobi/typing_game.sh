#!/bin/bash
set -euo pipefail

#
# タイピング練習ゲーム
# 作成日: 2026-07-04
# バージョン: 1.0
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

readonly -a WORDS_EASY=(
    "cat" "dog" "sun" "run" "car" "hat" "big" "fun" "red" "cup"
    "map" "key" "box" "log" "sky" "win" "top" "mix" "fox" "zip"
)
readonly -a WORDS_NORMAL=(
    "apple" "brave" "cloud" "dream" "eagle" "flame" "grace" "house"
    "image" "jelly" "knife" "lemon" "magic" "night" "ocean" "plant"
    "queen" "river" "stone" "tower" "uncle" "voice" "water" "xenon"
    "yacht" "zebra" "beach" "crisp" "drove" "elite"
)
readonly -a WORDS_HARD=(
    "abbreviate" "beneficial" "catastrophe" "demonstration" "elasticsearch"
    "fundamental" "grandmother" "hypothetical" "infrastructure" "jurisdiction"
    "kaleidoscope" "laboratory" "magnificent" "nevertheless" "orchestration"
    "perpendicular" "qualification" "revolutionary" "sophisticated" "thunderstorm"
)

declare -i score=0
declare -i total_chars=0
declare -i correct_chars=0
declare -i total_words=0
declare -i correct_words=0
declare -i start_epoch=0

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション]

英単語タイピング練習ゲーム。

オプション:
  -h, --help          このヘルプを表示
  -v, --version       バージョン情報を表示
  -d, --difficulty N  難易度 1=簡単 2=普通 3=難しい（デフォルト: 2）
  -n, --words N       出題単語数（デフォルト: 10）
EOF
}

get_word() {
    local difficulty="$1"
    local -n word_array_ref
    case "$difficulty" in
        1) word_array_ref=WORDS_EASY ;;
        3) word_array_ref=WORDS_HARD ;;
        *) word_array_ref=WORDS_NORMAL ;;
    esac
    local idx=$(( RANDOM % ${#word_array_ref[@]} ))
    echo "${word_array_ref[$idx]}"
}

show_header() {
    local word_num="$1"
    local total="$2"
    local difficulty="$3"

    local diff_str
    case "$difficulty" in
        1) diff_str="${C_GREEN}かんたん${C_RESET}" ;;
        3) diff_str="${C_RED}むずかしい${C_RESET}" ;;
        *) diff_str="${C_YELLOW}ふつう${C_RESET}" ;;
    esac

    clear_screen
    print_center "タイピング練習" 0 "${C_BOLD}${C_CYAN}"
    echo ""
    printf "  問題: ${C_BOLD}%d / %d${C_RESET}   難易度: %b   スコア: ${C_GREEN}%d${C_RESET}\n" \
        "$word_num" "$total" "$diff_str" "$score"
    echo ""
}

play_word() {
    local word="$1"
    local word_num="$2"
    local total="$3"
    local difficulty="$4"

    show_header "$word_num" "$total" "$difficulty"

    print_center "次の単語を入力してください:" 0 "$C_DIM"
    echo ""
    print_center "${C_BOLD}${C_WHITE}${word}${C_RESET}" 0 ""
    echo ""

    local start_ms end_ms
    start_ms=$(date +%s%N)
    printf "  > "
    local input
    read -r input
    end_ms=$(date +%s%N)

    local elapsed_ms=$(( (end_ms - start_ms) / 1000000 ))
    local elapsed_s
    elapsed_s=$(awk "BEGIN {printf \"%.1f\", $elapsed_ms / 1000}")

    total_words=$(( total_words + 1 ))
    total_chars=$(( total_chars + ${#word} ))

    if [ "$input" == "$word" ]; then
        local pts=10
        if [ "$elapsed_ms" -lt 2000 ]; then
            pts=20
        elif [ "$elapsed_ms" -lt 4000 ]; then
            pts=15
        fi
        [ "$difficulty" -eq 3 ] && pts=$(( pts * 2 ))

        score=$(( score + pts ))
        correct_words=$(( correct_words + 1 ))
        correct_chars=$(( correct_chars + ${#word} ))

        echo ""
        echo -e "  ${C_GREEN}${C_BOLD}✓ 正解！${C_RESET}  +${pts}点  (${elapsed_s}秒)"
    else
        echo ""
        echo -e "  ${C_RED}✗ 不正解${C_RESET}  正解: ${C_YELLOW}${word}${C_RESET}  あなた: ${C_DIM}${input}${C_RESET}"
    fi

    sleep 0.8
}

show_result() {
    local total_time="$1"
    local accuracy=0
    local wpm=0

    [ "$total_chars" -gt 0 ] && accuracy=$(( correct_chars * 100 / total_chars ))
    [ "$total_time" -gt 0 ] && wpm=$(( correct_words * 60 / total_time ))

    clear_screen
    echo ""
    print_center "═══ 結果 ═══" 0 "${C_BOLD}${C_CYAN}"
    echo ""
    printf "  ${C_BOLD}スコア:${C_RESET}     ${C_BOLD}${C_YELLOW}%d点${C_RESET}\n" "$score"
    printf "  ${C_BOLD}正答率:${C_RESET}     ${C_GREEN}%d%%${C_RESET}\n" "$accuracy"
    printf "  ${C_BOLD}正解数:${C_RESET}     %d / %d\n" "$correct_words" "$total_words"
    printf "  ${C_BOLD}WPM:${C_RESET}        %d words/min\n" "$wpm"
    printf "  ${C_BOLD}所要時間:${C_RESET}   %d秒\n" "$total_time"
    echo ""

    local grade
    if [ "$accuracy" -ge 95 ] && [ "$wpm" -ge 40 ]; then
        grade="${C_BOLD}${C_YELLOW}S ランク — 完璧！${C_RESET}"
    elif [ "$accuracy" -ge 90 ]; then
        grade="${C_BOLD}${C_GREEN}A ランク — 素晴らしい！${C_RESET}"
    elif [ "$accuracy" -ge 75 ]; then
        grade="${C_BOLD}${C_CYAN}B ランク — 良いです！${C_RESET}"
    elif [ "$accuracy" -ge 60 ]; then
        grade="${C_YELLOW}C ランク — まずまず${C_RESET}"
    else
        grade="${C_DIM}D ランク — もっと練習しましょう${C_RESET}"
    fi
    print_center "$grade" 0 ""
    echo ""
}

main() {
    local difficulty=2
    local word_count=10

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -d|--difficulty)
                [[ $# -lt 2 ]] && error_exit "--difficulty には 1/2/3 が必要です"
                difficulty="$2"; shift 2 ;;
            -n|--words)
                [[ $# -lt 2 ]] && error_exit "--words には数値が必要です"
                word_count="$2"; shift 2 ;;
            *) error_exit "不明なオプション: $1" ;;
        esac
    done

    clear_screen
    print_center "タイピング練習ゲーム" 0 "${C_BOLD}${C_CYAN}"
    echo ""
    echo -e "  ${C_DIM}Enterキーで開始...${C_RESET}"
    read -r

    local game_start
    game_start=$(date +%s)

    local i
    for (( i = 1; i <= word_count; i++ )); do
        local word
        word=$(get_word "$difficulty")
        play_word "$word" "$i" "$word_count" "$difficulty"
    done

    local game_end
    game_end=$(date +%s)
    local elapsed=$(( game_end - game_start ))

    show_result "$elapsed"
}

main "$@"
