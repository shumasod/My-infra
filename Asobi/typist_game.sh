#!/bin/bash
set -euo pipefail

#
# タイピングゲーム
# バージョン: 1.0
#
# 英単語タイピングの速度と精度を測定するゲーム
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare difficulty="normal"
declare -i question_count=20
declare -i time_limit=60

# 難易度別単語リスト
declare -a WORDS_EASY=(
    "cat" "dog" "run" "sun" "top" "big" "red" "hot" "cup" "bus"
    "hat" "map" "pen" "box" "key" "sky" "fly" "try" "say" "buy"
    "sit" "hit" "cut" "put" "let" "set" "get" "bit" "fit" "kit"
    "bat" "rat" "fat" "mat" "sat" "pat" "fan" "can" "man" "ban"
)

declare -a WORDS_NORMAL=(
    "apple" "brave" "cloud" "dance" "earth" "flame" "grace" "heart"
    "image" "judge" "knife" "light" "mount" "night" "ocean" "piano"
    "queen" "river" "stone" "tiger" "ultra" "value" "water" "xenon"
    "yield" "zebra" "black" "clean" "drive" "eagle" "frost" "globe"
    "happy" "index" "joker" "knock" "lemon" "magic" "never" "offer"
    "place" "quiet" "robot" "smile" "train" "under" "voice" "world"
)

declare -a WORDS_HARD=(
    "algorithm" "beautiful" "challenge" "dimension" "elaborate"
    "fantastic" "guarantee" "highlight" "illuminate" "javascript"
    "knowledge" "lightning" "mechanism" "negotiate" "operation"
    "peripheral" "quarantine" "repository" "situation" "technology"
    "understand" "vulnerable" "wavelength" "xenophobia" "yesterday"
    "achievement" "background" "comfortable" "development" "everything"
    "fundamental" "government" "hypothesis" "infrastructure" "javascript"
    "kindergarten" "limitations" "maintenance" "notification" "optimization"
)

declare -a WORDS_MASTER=(
    "authentication" "configuration" "containerization" "cryptocurrency"
    "documentation" "elasticsearch" "functionalities" "infrastructure"
    "internationalization" "microservices" "orchestration" "parallelization"
    "prioritization" "quantification" "recommendation" "systematization"
    "transformation" "virtualization" "vulnerability" "implementation"
)

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション]

英単語タイピングゲーム

オプション:
  -h, --help          このヘルプを表示
  -v, --version       バージョン情報を表示
  -d, --difficulty D  難易度 (easy|normal|hard|master) [デフォルト: normal]
  -n, --count NUM     出題数 [デフォルト: 20]
  -t, --time SEC      制限時間(秒) [デフォルト: 60]

例:
  $PROG_NAME
  $PROG_NAME -d hard -n 30
  $PROG_NAME -d easy -t 30

EOF
}

get_words() {
    case "$difficulty" in
        easy)   printf '%s\n' "${WORDS_EASY[@]}" ;;
        normal) printf '%s\n' "${WORDS_NORMAL[@]}" ;;
        hard)   printf '%s\n' "${WORDS_HARD[@]}" ;;
        master) printf '%s\n' "${WORDS_MASTER[@]}" ;;
    esac
}

shuffle_array() {
    local -a arr=("$@")
    local n=${#arr[@]}
    for (( i=n-1; i>0; i-- )); do
        local j=$(( RANDOM % (i+1) ))
        local tmp="${arr[$i]}"
        arr[$i]="${arr[$j]}"
        arr[$j]="$tmp"
    done
    printf '%s\n' "${arr[@]}"
}

get_rank() {
    local wpm="$1"
    local accuracy="$2"
    local score=$(( wpm * accuracy / 100 ))

    if (( score >= 120 )); then   echo "S (神タイパー)"
    elif (( score >= 90 )); then  echo "A (エキスパート)"
    elif (( score >= 60 )); then  echo "B (上級者)"
    elif (( score >= 40 )); then  echo "C (中級者)"
    elif (( score >= 20 )); then  echo "D (初心者)"
    else                          echo "E (練習が必要)"
    fi
}

show_progress_bar_inline() {
    local current="$1"
    local total="$2"
    local width=20
    local filled=$(( current * width / total ))
    local empty=$(( width - filled ))
    printf "["
    (( filled > 0 )) && printf '█%.0s' $(seq 1 $filled)
    (( empty > 0 )) && printf '░%.0s' $(seq 1 $empty)
    printf "] %d/%d" "$current" "$total"
}

play_game() {
    local -a all_words
    mapfile -t all_words < <(get_words)

    # シャッフルして必要数だけ取り出す
    local -a shuffled
    mapfile -t shuffled < <(shuffle_array "${all_words[@]}")

    local -a words
    for (( i=0; i<question_count && i<${#shuffled[@]}; i++ )); do
        words+=("${shuffled[$i]}")
    done

    local total="${#words[@]}"

    clear_screen
    print_center "タイピングゲーム" 2 "$C_CYAN"
    print_center "難易度: $difficulty | 出題: ${total}問 | 制限時間: ${time_limit}秒" 3 "$C_DIM"

    move_cursor 5 2
    echo "準備ができたらEnterキーを押してください..."
    read -r

    local -i correct=0 wrong=0 total_chars=0 correct_chars=0
    local start_time
    start_time=$(date +%s)
    local -i current=0

    for word in "${words[@]}"; do
        (( current++ )) || true
        local now
        now=$(date +%s)
        local elapsed=$(( now - start_time ))
        local remaining=$(( time_limit - elapsed ))

        if (( remaining <= 0 )); then
            break
        fi

        clear_screen

        # ヘッダー
        move_cursor 1 2
        printf "${C_BOLD}タイピングゲーム${C_RESET}"
        move_cursor 1 30
        printf "$(show_progress_bar_inline $current $total)"
        move_cursor 1 60

        local time_color="$C_GREEN"
        (( remaining <= 10 )) && time_color="$C_RED"
        (( remaining <= 20 && remaining > 10 )) && time_color="$C_YELLOW"
        printf "${time_color}残り %d秒${C_RESET}" "$remaining"

        # 統計
        move_cursor 2 2
        printf "正解: ${C_GREEN}%d${C_RESET}  ミス: ${C_RED}%d${C_RESET}" "$correct" "$wrong"

        # 単語表示
        draw_separator 4
        move_cursor 6 2
        printf "${C_DIM}以下の単語を入力してください:${C_RESET}"
        move_cursor 8 2
        printf "${C_BOLD}${C_CYAN}  %s${C_RESET}" "$word"
        move_cursor 10 2
        printf "> "

        local input=""
        local key=""
        local word_start
        word_start=$(date +%s%N)
        local timed_out=false

        while IFS= read -r -s -n1 -t "$remaining" key 2>/dev/null; do
            now=$(date +%s)
            remaining=$(( time_limit - (now - start_time) ))
            (( remaining <= 0 )) && { timed_out=true; break; }

            if [[ "$key" == "" ]]; then
                break
            elif [[ "$key" == $'\x7f' || "$key" == $'\b' ]]; then
                if [[ -n "$input" ]]; then
                    input="${input%?}"
                    printf "\r> %-${#word}s\r> %s" "" "$input"
                fi
            else
                input+="$key"
                printf "%s" "$key"
            fi
        done

        $timed_out && break

        echo ""
        (( total_chars += ${#word} )) || true

        if [[ "$input" == "$word" ]]; then
            (( correct++ )) || true
            (( correct_chars += ${#word} )) || true
            move_cursor 12 2
            printf "${C_GREEN}✓ 正解！${C_RESET}"
        else
            (( wrong++ )) || true
            move_cursor 12 2
            printf "${C_RED}✗ ミス！${C_RESET}  正解: ${C_CYAN}%s${C_RESET}" "$word"
        fi
        sleep 0.5
    done

    local end_time
    end_time=$(date +%s)
    local total_time=$(( end_time - start_time ))
    (( total_time == 0 )) && total_time=1

    local wpm=$(( correct * 60 / total_time ))
    local accuracy=0
    (( correct + wrong > 0 )) && accuracy=$(( correct * 100 / (correct + wrong) ))

    # 結果画面
    clear_screen
    print_center "ゲーム終了！" 2 "$C_CYAN"
    draw_separator 3

    move_cursor 5 2
    printf "  ${C_BOLD}%-20s${C_RESET} %d 問\n" "総問題数:" "$total"
    printf "  ${C_BOLD}%-20s${C_RESET} ${C_GREEN}%d 問${C_RESET}\n" "正解数:" "$correct"
    printf "  ${C_BOLD}%-20s${C_RESET} ${C_RED}%d 問${C_RESET}\n" "ミス数:" "$wrong"
    printf "  ${C_BOLD}%-20s${C_RESET} ${C_CYAN}%d%%${C_RESET}\n" "正確率:" "$accuracy"
    printf "  ${C_BOLD}%-20s${C_RESET} %d 秒\n" "プレイ時間:" "$total_time"
    printf "  ${C_BOLD}%-20s${C_RESET} ${C_YELLOW}%d WPM${C_RESET}\n" "タイピング速度:" "$wpm"

    local rank
    rank=$(get_rank "$wpm" "$accuracy")
    echo ""
    print_center "ランク: ${rank}" 13 "$C_BOLD"
    echo ""
    move_cursor 15 2
    echo "  Enterキーで終了..."
    read -r
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -d|--difficulty)
                [[ $# -lt 2 ]] && error_exit "--difficulty には値が必要です"
                difficulty="$2"
                case "$difficulty" in
                    easy|normal|hard|master) ;;
                    *) error_exit "無効な難易度: $difficulty (easy|normal|hard|master)" ;;
                esac
                shift 2
                ;;
            -n|--count)
                [[ $# -lt 2 ]] && error_exit "--count には値が必要です"
                question_count="$2"
                shift 2
                ;;
            -t|--time)
                [[ $# -lt 2 ]] && error_exit "--time には値が必要です"
                time_limit="$2"
                shift 2
                ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  shift ;;
        esac
    done
}

cleanup() {
    show_cursor
    tput cnorm 2>/dev/null || true
    echo ""
}
trap cleanup EXIT INT TERM

main() {
    parse_arguments "$@"
    hide_cursor
    play_game
}

main "$@"
