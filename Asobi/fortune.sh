#!/bin/bash
set -euo pipefail

#
# おみくじ・フォーチュンクッキー
# 作成日: 2026-07-04
# バージョン: 1.0
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

readonly -a FORTUNE_LEVELS=("大吉" "中吉" "小吉" "吉" "末吉" "凶" "大凶")
readonly -a FORTUNE_WEIGHTS=(15 20 15 25 15 8 2)
readonly -a FORTUNE_COLORS=(
    "$C_YELLOW"
    "$C_GREEN"
    "$C_BRIGHT_GREEN"
    "$C_CYAN"
    "$C_WHITE"
    "$C_RED"
    "$C_MAGENTA"
)

readonly -a FORTUNES_DAIKICHI=(
    "あなたの努力は必ず報われます。今こそ大きな一歩を踏み出す時！"
    "素晴らしい出会いが待っています。心を開いて進んでください。"
    "長年の夢が叶う予感。信じる気持ちを忘れずに。"
)
readonly -a FORTUNES_CHUKICHI=(
    "着実な進歩が期待できます。焦らずマイペースで。"
    "人間関係が豊かになる時期です。感謝の気持ちを大切に。"
    "努力が認められるでしょう。継続は力なり。"
)
readonly -a FORTUNES_SHOKICHI=(
    "小さな幸せを見つける才能を持っています。日常を大切に。"
    "穏やかな日々が続きます。平和な時間を楽しんで。"
    "周囲のサポートを受けながら前進できます。"
)
readonly -a FORTUNES_KICHI=(
    "バランスの取れた日々を送れます。無理せず自然体で。"
    "地道な努力が実を結びます。コツコツと積み上げましょう。"
    "信頼できる仲間との絆が深まります。"
)
readonly -a FORTUNES_SUEKICHI=(
    "今は準備の時期。力を蓄えて機会を待ちましょう。"
    "少し立ち止まって振り返ることで道が開けます。"
    "慎重さが功を奏します。じっくり考えて行動を。"
)
readonly -a FORTUNES_KYO=(
    "今日は慎重に行動することが大切です。無理は禁物。"
    "試練が訪れるかもしれませんが、乗り越えた先に成長があります。"
    "初心に返って基本を大切にする時期です。"
)
readonly -a FORTUNES_DAIKYO=(
    "困難な時期ですが、嵐の後には必ず晴れ間が来ます。"
    "今こそ内なる力を信じる時。どんな状況も永遠には続きません。"
    "逆境は成長のチャンス。乗り越えた後の自分を想像して。"
)

readonly -a LUCKY_NUMBERS=(7 3 8 1 5 2 9 4 6)
readonly -a LUCKY_DIRECTIONS=("北" "北東" "東" "南東" "南" "南西" "西" "北西")
readonly -a LUCKY_COLORS=("赤" "青" "緑" "黄" "白" "紫" "オレンジ" "ピンク" "金" "銀")

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション]

今日のおみくじを引きます。

オプション:
  -h, --help     このヘルプを表示
  -v, --version  バージョン情報を表示
  -s, --simple   シンプルモード（アニメーションなし）
EOF
}

draw_omikuji_box() {
    local level="$1"
    local color="$2"
    echo ""
    printf "  ${color}"
    printf "╔══════════════════════╗\n"
    printf "  ║                      ║\n"
    printf "  ║   ★ おみくじ ★     ║\n"
    printf "  ║                      ║\n"
    printf "  ║   %-8s            ║\n" "$level"
    printf "  ║                      ║\n"
    printf "  ╚══════════════════════╝"
    printf "${C_RESET}\n"
    echo ""
}

animate_draw() {
    local -a frames=("??" "？？" "　　" "？？" "??" "！！")
    local f
    for f in "${frames[@]}"; do
        printf "\r  ${C_DIM}引いています... [${C_YELLOW}%s${C_DIM}]${C_RESET}" "$f"
        sleep 0.2
    done
    printf "\r%50s\r" ""
}

weighted_random() {
    local total=0
    local w
    for w in "${FORTUNE_WEIGHTS[@]}"; do
        total=$(( total + w ))
    done

    local r=$(( RANDOM % total ))
    local cumulative=0
    local i
    for (( i = 0; i < ${#FORTUNE_WEIGHTS[@]}; i++ )); do
        cumulative=$(( cumulative + FORTUNE_WEIGHTS[$i] ))
        if [ "$r" -lt "$cumulative" ]; then
            echo "$i"
            return
        fi
    done
    echo "3"
}

get_fortune_message() {
    local level_idx="$1"
    case "$level_idx" in
        0) echo "${FORTUNES_DAIKICHI[$(( RANDOM % ${#FORTUNES_DAIKICHI[@]} ))]}" ;;
        1) echo "${FORTUNES_CHUKICHI[$(( RANDOM % ${#FORTUNES_CHUKICHI[@]} ))]}" ;;
        2) echo "${FORTUNES_SHOKICHI[$(( RANDOM % ${#FORTUNES_SHOKICHI[@]} ))]}" ;;
        3) echo "${FORTUNES_KICHI[$(( RANDOM % ${#FORTUNES_KICHI[@]} ))]}" ;;
        4) echo "${FORTUNES_SUEKICHI[$(( RANDOM % ${#FORTUNES_SUEKICHI[@]} ))]}" ;;
        5) echo "${FORTUNES_KYO[$(( RANDOM % ${#FORTUNES_KYO[@]} ))]}" ;;
        6) echo "${FORTUNES_DAIKYO[$(( RANDOM % ${#FORTUNES_DAIKYO[@]} ))]}" ;;
    esac
}

main() {
    local simple=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -s|--simple)  simple=true; shift ;;
            *) error_exit "不明なオプション: $1" ;;
        esac
    done

    clear_screen
    print_center "今日のおみくじ" 0 "${C_BOLD}${C_YELLOW}"
    print_center "$(date '+%Y年%m月%d日')" 0 "$C_DIM"
    echo ""

    if ! "$simple"; then
        printf "  ${C_DIM}Enterキーでおみくじを引く...${C_RESET}"
        read -r
        animate_draw
    fi

    local idx
    idx=$(weighted_random)
    local level="${FORTUNE_LEVELS[$idx]}"
    local color="${FORTUNE_COLORS[$idx]}"
    local message
    message=$(get_fortune_message "$idx")

    local lucky_num="${LUCKY_NUMBERS[$(( RANDOM % ${#LUCKY_NUMBERS[@]} ))]}"
    local lucky_dir="${LUCKY_DIRECTIONS[$(( RANDOM % ${#LUCKY_DIRECTIONS[@]} ))]}"
    local lucky_color="${LUCKY_COLORS[$(( RANDOM % ${#LUCKY_COLORS[@]} ))]}"

    draw_omikuji_box "$level" "$color"

    echo -e "  ${C_DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
    echo ""
    printf "  ${C_BOLD}%s${C_RESET}\n" "$message"
    echo ""
    echo -e "  ${C_DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
    echo ""
    printf "  ${C_BOLD}ラッキーナンバー:${C_RESET} ${C_YELLOW}%d${C_RESET}\n" "$lucky_num"
    printf "  ${C_BOLD}ラッキー方角:${C_RESET}     ${C_CYAN}%s${C_RESET}\n" "$lucky_dir"
    printf "  ${C_BOLD}ラッキーカラー:${C_RESET}   ${C_GREEN}%s${C_RESET}\n" "$lucky_color"
    echo ""
}

main "$@"
