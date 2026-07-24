#!/bin/bash
set -euo pipefail

#
# ハングマンゲーム (英単語当て)
# バージョン: 1.0
#
# 英単語を1文字ずつ当てるゲーム
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"
readonly MAX_WRONG=6

declare difficulty="normal"
declare -i score=0
declare -i games_played=0

declare -a WORDS_EASY=(
    "cat:ネコ" "dog:イヌ" "sun:太陽" "hat:帽子" "cup:カップ"
    "car:車" "red:赤" "sea:海" "sky:空" "map:地図"
)
declare -a WORDS_NORMAL=(
    "apple:リンゴ" "bread:パン" "chair:椅子" "dance:ダンス" "earth:地球"
    "flame:炎" "grape:ブドウ" "heart:心臓" "image:画像" "juice:ジュース"
    "knife:ナイフ" "lemon:レモン" "music:音楽" "night:夜" "ocean:海洋"
    "piano:ピアノ" "queen:女王" "river:川" "sugar:砂糖" "tiger:トラ"
)
declare -a WORDS_HARD=(
    "algorithm:アルゴリズム" "brilliant:輝かしい" "chocolate:チョコレート"
    "dynamite:ダイナマイト" "eloquent:雄弁な" "fantastic:素晴らしい"
    "gorgeous:豪華な" "heritage:遺産" "invisible:見えない" "jubilant:歓喜の"
    "kaleidoscope:万華鏡" "labyrinth:迷宮" "magnificent:壮大な"
    "nightmare:悪夢" "orchestra:オーケストラ"
)

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション]

ハングマンゲーム (英単語当て)

オプション:
  -h, --help            このヘルプを表示
  -v, --version         バージョン情報を表示
  -d, --difficulty LVL  難易度 (easy|normal|hard) [デフォルト: normal]

例:
  $PROG_NAME
  $PROG_NAME -d hard

EOF
}

draw_hangman() {
    local wrong="$1"
    local frames=(
        "  +---+\n  |   |\n      |\n      |\n      |\n      |\n========="
        "  +---+\n  |   |\n  O   |\n      |\n      |\n      |\n========="
        "  +---+\n  |   |\n  O   |\n  |   |\n      |\n      |\n========="
        "  +---+\n  |   |\n  O   |\n /|   |\n      |\n      |\n========="
        "  +---+\n  |   |\n  O   |\n /|\\  |\n      |\n      |\n========="
        "  +---+\n  |   |\n  O   |\n /|\\  |\n /    |\n      |\n========="
        "  +---+\n  |   |\n  O   |\n /|\\  |\n / \\  |\n      |\n========="
    )
    local color="$C_GREEN"
    (( wrong >= 4 )) && color="$C_YELLOW"
    (( wrong >= 6 )) && color="$C_RED"

    echo -e "${color}$(echo -e "${frames[$wrong]}")${C_RESET}"
}

pick_word() {
    local -n word_list="$1"
    local idx=$(( RANDOM % ${#word_list[@]} ))
    echo "${word_list[$idx]}"
}

display_state() {
    local word="$1"
    local -n guessed_ref="$2"
    local -i wrong="$3"
    local hint="$4"

    clear_screen
    print_center "🎯 ハングマン" 1 "$C_CYAN"

    move_cursor 3 2
    draw_hangman "$wrong" | while IFS= read -r line; do
        echo "  $line"
    done

    move_cursor 12 2
    printf "  ヒント: ${C_DIM}%s${C_RESET}\n" "$hint"
    printf "  残り試行: ${C_YELLOW}%d回${C_RESET}\n\n" "$(( MAX_WRONG - wrong ))"

    printf "  単語: "
    for (( i=0; i<${#word}; i++ )); do
        local ch="${word:$i:1}"
        if [[ -n "${guessed_ref[$ch]+_}" ]]; then
            printf "${C_GREEN}%s ${C_RESET}" "$ch"
        else
            printf "${C_DIM}_ ${C_RESET}"
        fi
    done
    echo ""
    echo ""

    local sorted_guesses
    sorted_guesses=$(echo "${!guessed_ref[@]}" | tr ' ' '\n' | sort | tr '\n' ' ')
    printf "  使用済み: ${C_YELLOW}%s${C_RESET}\n" "${sorted_guesses:-なし}"
}

is_complete() {
    local word="$1"
    local -n guessed_chk="$2"
    for (( i=0; i<${#word}; i++ )); do
        local ch="${word:$i:1}"
        [[ -z "${guessed_chk[$ch]+_}" ]] && return 1
    done
    return 0
}

play_game() {
    local word_entry
    case "$difficulty" in
        easy)   word_entry=$(pick_word WORDS_EASY) ;;
        normal) word_entry=$(pick_word WORDS_NORMAL) ;;
        hard)   word_entry=$(pick_word WORDS_HARD) ;;
    esac

    local word="${word_entry%%:*}"
    local hint="${word_entry#*:}"
    local -i wrong=0
    declare -A guessed=()

    while true; do
        display_state "$word" guessed "$wrong" "$hint"

        if is_complete "$word" guessed; then
            move_cursor 20 2
            log_success "正解！ 「${word}」(${hint})"
            (( score++ )) || true
            break
        fi

        if (( wrong >= MAX_WRONG )); then
            move_cursor 20 2
            log_error "ゲームオーバー！ 正解は「${word}」(${hint})"
            break
        fi

        move_cursor 19 2
        printf "  文字を入力してください [a-z]: "
        local input
        read -r input
        input="${input,,}"

        if ! [[ "$input" =~ ^[a-z]$ ]]; then
            continue
        fi

        if [[ -n "${guessed[$input]+_}" ]]; then
            continue
        fi

        guessed["$input"]=1

        if [[ "$word" != *"$input"* ]]; then
            (( wrong++ )) || true
        fi
    done

    (( games_played++ )) || true
    sleep 2
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
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

cleanup() { show_cursor; }
trap cleanup EXIT

main() {
    parse_arguments "$@"
    hide_cursor

    echo ""
    echo -e "${C_CYAN}"
    echo "  ╔═══════════════════════════╗"
    echo "  ║   ハングマンゲーム 🎯    ║"
    echo "  ╚═══════════════════════════╝"
    echo -e "${C_RESET}"
    printf "  難易度: ${C_BOLD}%s${C_RESET}  Enterで開始...\n" "$difficulty"
    read -r

    while true; do
        play_game
        show_cursor
        printf "\nもう一度プレイしますか? [y/N]: "
        local ans; read -r ans
        [[ ! "$ans" =~ ^[yY]$ ]] && break
        hide_cursor
    done

    echo ""
    printf "  プレイ数: %d  正解数: %d\n\n" "$games_played" "$score"
}

main "$@"
