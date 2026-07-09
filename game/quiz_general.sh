#!/bin/bash
set -euo pipefail

#
# 一般知識クイズゲーム
# 作成日: 2026-07-04
# バージョン: 1.0
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

# フォーマット: "問題|正解|不正解1|不正解2|不正解3|解説"
readonly -a QUESTIONS=(
    "日本の首都はどこですか？|東京|大阪|京都|名古屋|東京は1869年に日本の首都となりました"
    "世界で最も高い山はどれですか？|エベレスト|K2|マッキンリー|モンブラン|エベレストは標高8849mで世界最高峰です"
    "水の化学式は何ですか？|H₂O|CO₂|O₂|NaCl|水素2原子と酸素1原子で構成されます"
    "太陽系で最大の惑星はどれですか？|木星|土星|天王星|海王星|木星の直径は地球の約11倍です"
    "日本の国花はどれですか？|桜|菊|梅|蓮|桜は日本の国花として親しまれています"
    "シェイクスピアの作品はどれですか？|ハムレット|神曲|ドン・キホーテ|戦争と平和|ハムレットはシェイクスピアの四大悲劇の一つです"
    "光の速度（真空中）は？|約30万km/s|約3万km/s|約3億km/s|約300km/s|光は1秒間に約299,792kmを進みます"
    "元素記号Feは何の元素ですか？|鉄|金|銀|銅|Feはラテン語のFerrumに由来します"
    "日本で最も長い川はどれですか？|信濃川|利根川|石狩川|最上川|信濃川の全長は367kmです"
    "ピタゴラスの定理はどれですか？|a²+b²=c²|a+b=c|a×b=c²|a²-b²=c|直角三角形の3辺の関係を示す定理です"
    "インターネットのWWWを発明したのは誰ですか？|ティム・バーナーズ＝リー|ビル・ゲイツ|スティーブ・ジョブズ|マーク・ザッカーバーグ|1989年にCERNで提案されました"
    "DNAの塩基でないものはどれですか？|ウラシル|アデニン|グアニン|シトシン|ウラシルはRNAに含まれます（DNAはチミン）"
    "世界で最も人口の多い国はどこですか？|インド|中国|アメリカ|インドネシア|2023年にインドが中国を抜きました"
    "円周率πの近似値は？|3.14159...|2.71828...|1.41421...|1.73205...|無限に続く無理数です"
    "日本語のひらがなは何文字ありますか？|46文字|48文字|50文字|52文字|現代仮名遣いでは46文字（清音）です"
)

declare -i score=0
declare -i total_answered=0

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション]

一般知識クイズに挑戦！

オプション:
  -h, --help       このヘルプを表示
  -v, --version    バージョン情報を表示
  -n, --count N    出題数（デフォルト: 10）
EOF
}

shuffle_options() {
    local correct="$1"
    local w1="$2" w2="$3" w3="$4"
    local -a opts=("$correct" "$w1" "$w2" "$w3")

    local i j tmp
    for (( i = 3; i > 0; i-- )); do
        j=$(( RANDOM % (i + 1) ))
        tmp="${opts[$i]}"
        opts[$i]="${opts[$j]}"
        opts[$j]="$tmp"
    done

    local correct_pos=0
    local k
    for (( k = 0; k < 4; k++ )); do
        [ "${opts[$k]}" == "$correct" ] && correct_pos=$k
    done

    printf "%d\n" "$correct_pos"
    printf "%s\n" "${opts[@]}"
}

play_question() {
    local question_data="$1"
    local q_num="$2"
    local total="$3"

    IFS='|' read -r question correct wrong1 wrong2 wrong3 explanation <<< "$question_data"

    local shuffle_result
    local correct_pos opts=()
    mapfile -t shuffle_result < <(shuffle_options "$correct" "$wrong1" "$wrong2" "$wrong3")
    correct_pos="${shuffle_result[0]}"
    opts=("${shuffle_result[@]:1}")

    clear_screen
    print_center "一般知識クイズ" 0 "${C_BOLD}${C_CYAN}"
    printf "  問題 ${C_BOLD}%d / %d${C_RESET}   スコア: ${C_GREEN}%d点${C_RESET}\n" "$q_num" "$total" "$score"
    echo ""
    print_center "─────────────────────────────────" 0 "$C_DIM"
    echo ""
    printf "  ${C_BOLD}Q. %s${C_RESET}\n" "$question"
    echo ""

    local i
    for (( i = 0; i < 4; i++ )); do
        local label
        case $i in
            0) label="A" ;; 1) label="B" ;; 2) label="C" ;; 3) label="D" ;;
        esac
        printf "  ${C_YELLOW}%s)${C_RESET} %s\n" "$label" "${opts[$i]}"
    done

    echo ""
    printf "  答えを選んでください (A/B/C/D): "
    local answer
    read -r answer
    answer="${answer^^}"

    local answer_idx
    case "$answer" in
        A) answer_idx=0 ;;
        B) answer_idx=1 ;;
        C) answer_idx=2 ;;
        D) answer_idx=3 ;;
        *) answer_idx=-1 ;;
    esac

    total_answered=$(( total_answered + 1 ))

    echo ""
    if [ "$answer_idx" -eq "$correct_pos" ]; then
        echo -e "  ${C_GREEN}${C_BOLD}✓ 正解！${C_RESET}"
        score=$(( score + 10 ))
    else
        local correct_label
        case $correct_pos in
            0) correct_label="A" ;; 1) correct_label="B" ;; 2) correct_label="C" ;; 3) correct_label="D" ;;
        esac
        echo -e "  ${C_RED}✗ 不正解${C_RESET}  正解: ${C_GREEN}${correct_label}) ${correct}${C_RESET}"
    fi

    echo ""
    echo -e "  ${C_DIM}解説: ${explanation}${C_RESET}"
    echo ""
    echo -e "${C_DIM}  Enterキーで次の問題へ...${C_RESET}"
    read -r
}

show_result() {
    local total="$1"
    clear_screen
    echo ""
    print_center "═══ クイズ結果 ═══" 0 "${C_BOLD}${C_CYAN}"
    echo ""
    printf "  ${C_BOLD}スコア:${C_RESET}  ${C_BOLD}${C_YELLOW}%d点 / %d点${C_RESET}\n" \
        "$score" $(( total * 10 ))
    printf "  ${C_BOLD}正答数:${C_RESET}  %d / %d\n" $(( score / 10 )) "$total"
    local pct=0
    [ "$total" -gt 0 ] && pct=$(( score * 100 / (total * 10) ))
    printf "  ${C_BOLD}正答率:${C_RESET}  %d%%\n" "$pct"
    echo ""

    local grade
    if [ "$pct" -ge 90 ]; then
        grade="${C_BOLD}${C_YELLOW}S ランク — 天才！全問制覇に挑戦してみよう${C_RESET}"
    elif [ "$pct" -ge 70 ]; then
        grade="${C_BOLD}${C_GREEN}A ランク — 素晴らしい知識です！${C_RESET}"
    elif [ "$pct" -ge 50 ]; then
        grade="${C_CYAN}B ランク — 良い成績です${C_RESET}"
    elif [ "$pct" -ge 30 ]; then
        grade="${C_YELLOW}C ランク — まだまだ伸びしろあり！${C_RESET}"
    else
        grade="${C_DIM}D ランク — もっと勉強しましょう${C_RESET}"
    fi
    print_center "$grade" 0 ""
    echo ""
}

main() {
    local count=10

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -n|--count)
                [[ $# -lt 2 ]] && error_exit "--count には数値が必要です"
                count="$2"; shift 2 ;;
            *) error_exit "不明なオプション: $1" ;;
        esac
    done

    [ "$count" -gt "${#QUESTIONS[@]}" ] && count="${#QUESTIONS[@]}"

    local -a indices=()
    local i
    for (( i = 0; i < ${#QUESTIONS[@]}; i++ )); do
        indices+=("$i")
    done
    for (( i = ${#indices[@]} - 1; i > 0; i-- )); do
        local j=$(( RANDOM % (i + 1) ))
        local tmp="${indices[$i]}"
        indices[$i]="${indices[$j]}"
        indices[$j]="$tmp"
    done

    clear_screen
    print_center "一般知識クイズ" 0 "${C_BOLD}${C_CYAN}"
    print_center "${count}問に挑戦しましょう！" 0 "$C_DIM"
    echo ""
    echo -e "  ${C_DIM}Enterキーでスタート...${C_RESET}"
    read -r

    for (( i = 0; i < count; i++ )); do
        play_question "${QUESTIONS[${indices[$i]}]}" $(( i + 1 )) "$count"
    done

    show_result "$count"
}

main "$@"
