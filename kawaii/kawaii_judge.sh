#!/bin/bash
set -euo pipefail

#
# 最上級かわいい判定スクリプト
# 作成日: 2024
# バージョン: 1.0
#
# 概要:
#   入力された対象が「最上級にかわいい」かどうかを判定します
#   独自のかわいさアルゴリズムで厳正に審査します
#
# 使用例:
#   ./kawaii_judge.sh                    # インタラクティブモード
#   ./kawaii_judge.sh "猫"               # 対象を指定
#   ./kawaii_judge.sh --strict "子犬"    # 厳格モード
#

# ===== 共通ライブラリ読み込み =====
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/../lib/common.sh" ]]; then
    # shellcheck source=../lib/common.sh
    source "${SCRIPT_DIR}/../lib/common.sh"
else
    # フォールバック: 共通ライブラリがない場合の最小定義
    C_RESET='\033[0m'
    C_BOLD='\033[1m'
    C_RED='\033[1;31m'
    C_GREEN='\033[1;32m'
    C_YELLOW='\033[1;33m'
    C_MAGENTA='\033[1;35m'
    C_CYAN='\033[1;36m'
    C_WHITE='\033[1;37m'
    C_BG_MAGENTA='\033[45m'
fi

# ===== 設定（定数） =====
readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

# かわいさレベル定義
readonly -a KAWAII_LEVELS=(
    "かわいくない..."
    "ちょっとかわいい"
    "かわいい！"
    "とてもかわいい！！"
    "超かわいい！！！"
    "最上級にかわいい！！！！"
    "∞かわいい（測定不能）"
)

# かわいいキーワード（ボーナスポイント）
readonly -a KAWAII_KEYWORDS=(
    "猫" "ねこ" "ネコ" "cat" "にゃん"
    "犬" "いぬ" "イヌ" "dog" "わんこ"
    "うさぎ" "ウサギ" "rabbit" "bunny"
    "ハムスター" "hamster"
    "パンダ" "panda"
    "ペンギン" "penguin"
    "子" "赤ちゃん" "baby"
    "ふわふわ" "もふもふ" "ぷにぷに"
    "きらきら" "キラキラ"
    "天使" "angel"
    "姫" "princess"
    "妖精" "fairy"
)

# 最上級確定キーワード
readonly -a SUPREME_KEYWORDS=(
    "推し" "最推し"
    "嫁" "俺の嫁"
    "天使" "女神"
    "尊い" "てぇてぇ"
    "ママ" "パパ"
)

# 顔文字コレクション
readonly -a KAOMOJI=(
    "(｡◕‿◕｡)"
    "(◕‿◕✿)"
    "(*≧ω≦*)"
    "(๑>ᴗ<๑)"
    "( ´ ▽ \` )ﾉ"
    "(ノ´ヮ\`)ノ*:・゚✧"
    "♡(ӦｖӦ｡)"
    "(◠‿◠)"
    "(*´▽\`*)"
    "(〃ω〃)"
    "(*ﾟ▽ﾟ*)"
    "(≧◡≦)"
)

# ===== グローバル変数 =====
declare target=""
declare -i strict_mode=0
declare -i debug_mode=0

# ===== ヘルパー関数 =====

# ランダムな顔文字を取得
get_random_kaomoji() {
    echo "${KAOMOJI[$((RANDOM % ${#KAOMOJI[@]}))]}"
}

show_usage() {
    local random_kaomoji
    random_kaomoji=$(get_random_kaomoji)
    cat <<EOF
${C_MAGENTA}✨ 最上級かわいい判定スクリプト ✨${C_RESET} v${VERSION}

使用方法: $PROG_NAME [オプション] [対象]

オプション:
  -h, --help      このヘルプを表示
  -v, --version   バージョン情報を表示
  -s, --strict    厳格モード（判定が厳しくなります）
  -d, --debug     デバッグモード（スコア詳細を表示）

例:
  $PROG_NAME                    # インタラクティブモード
  $PROG_NAME "子猫"             # 子猫のかわいさを判定
  $PROG_NAME --strict "柴犬"    # 厳格モードで判定
  $PROG_NAME "推しの写真"       # 最上級確定

${C_YELLOW}注意:${C_RESET}
  このスクリプトの判定結果は絶対です。
  異議申し立ては受け付けておりません。 ${random_kaomoji}
EOF
}

# ===== かわいさ判定ロジック =====

#
# 基本スコアを計算（文字列の特性から）
#
calculate_base_score() {
    local text="$1"
    local score=0

    # 文字数による基本スコア
    local len=${#text}
    if [[ $len -le 3 ]]; then
        score=$((score + 10))  # 短いと可愛い
    elif [[ $len -le 6 ]]; then
        score=$((score + 15))
    else
        score=$((score + 5))
    fi

    # ひらがなが多いとかわいい
    local hiragana_count
    hiragana_count=$(echo "$text" | grep -o '[ぁ-ん]' | wc -l)
    score=$((score + hiragana_count * 3))

    # カタカナも少しかわいい
    local katakana_count
    katakana_count=$(echo "$text" | grep -o '[ァ-ン]' | wc -l)
    score=$((score + katakana_count * 2))

    # 「っ」「ー」があるとかわいい
    if [[ "$text" == *"っ"* ]] || [[ "$text" == *"ッ"* ]]; then
        score=$((score + 5))
    fi
    if [[ "$text" == *"ー"* ]] || [[ "$text" == *"〜"* ]]; then
        score=$((score + 5))
    fi

    echo "$score"
}

#
# キーワードボーナスを計算
#
calculate_keyword_bonus() {
    local text="$1"
    local bonus=0

    # かわいいキーワードチェック
    for keyword in "${KAWAII_KEYWORDS[@]}"; do
        if [[ "$text" == *"$keyword"* ]]; then
            bonus=$((bonus + 15))
        fi
    done

    # 最上級キーワードチェック
    for keyword in "${SUPREME_KEYWORDS[@]}"; do
        if [[ "$text" == *"$keyword"* ]]; then
            bonus=$((bonus + 50))
        fi
    done

    echo "$bonus"
}

#
# ランダム要素（運命のかわいさ）
#
calculate_destiny_bonus() {
    # 0-30のランダムボーナス
    echo $((RANDOM % 31))
}

#
# 最終スコアからレベルを決定
#
get_kawaii_level() {
    local score=$1

    if [[ $strict_mode -eq 1 ]]; then
        # 厳格モード: 基準が高い
        if [[ $score -lt 20 ]]; then
            echo 0
        elif [[ $score -lt 40 ]]; then
            echo 1
        elif [[ $score -lt 60 ]]; then
            echo 2
        elif [[ $score -lt 80 ]]; then
            echo 3
        elif [[ $score -lt 100 ]]; then
            echo 4
        elif [[ $score -lt 150 ]]; then
            echo 5
        else
            echo 6
        fi
    else
        # 通常モード: やさしめ
        if [[ $score -lt 15 ]]; then
            echo 0
        elif [[ $score -lt 30 ]]; then
            echo 1
        elif [[ $score -lt 45 ]]; then
            echo 2
        elif [[ $score -lt 60 ]]; then
            echo 3
        elif [[ $score -lt 80 ]]; then
            echo 4
        elif [[ $score -lt 120 ]]; then
            echo 5
        else
            echo 6
        fi
    fi
}

# ===== 表示関数 =====

#
# かわいいバナーを表示
#
show_kawaii_banner() {
    echo ""
    echo -e "${C_MAGENTA}╔════════════════════════════════════════════════════╗${C_RESET}"
    echo -e "${C_MAGENTA}║${C_RESET}  ${C_YELLOW}✨${C_RESET} ${C_WHITE}${C_BOLD}最上級かわいい判定システム${C_RESET} ${C_YELLOW}✨${C_RESET}              ${C_MAGENTA}║${C_RESET}"
    echo -e "${C_MAGENTA}║${C_RESET}                                                    ${C_MAGENTA}║${C_RESET}"
    echo -e "${C_MAGENTA}║${C_RESET}     ${C_CYAN}～ 世界一正確なかわいさ測定器 ～${C_RESET}            ${C_MAGENTA}║${C_RESET}"
    echo -e "${C_MAGENTA}╚════════════════════════════════════════════════════╝${C_RESET}"
    echo ""
}

#
# 判定中アニメーション
#
show_judging_animation() {
    local target="$1"

    echo -e "${C_CYAN}判定対象:${C_RESET} ${C_WHITE}${C_BOLD}「${target}」${C_RESET}"
    echo ""
    echo -ne "${C_YELLOW}かわいさを分析中${C_RESET}"

    local spinners=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local messages=(
        "もふもふ度を測定..."
        "きゅんきゅん値を算出..."
        "てぇてぇレベルを解析..."
        "尊さを数値化..."
        "かわいさの極限を探索..."
    )

    for ((i = 0; i < 15; i++)); do
        local spinner="${spinners[$((i % ${#spinners[@]}))]}"
        local msg="${messages[$((i % ${#messages[@]}))]}"
        echo -ne "\r${C_YELLOW}${spinner} ${msg}${C_RESET}                    "
        sleep 0.15
    done

    echo -ne "\r${C_GREEN}✓ 分析完了！${C_RESET}                              \n"
    echo ""
    sleep 0.3
}

#
# 結果を表示
#
show_result() {
    local level=$1
    local score=$2
    local target="$3"

    local level_text="${KAWAII_LEVELS[$level]}"
    local kaomoji
    kaomoji=$(get_random_kaomoji)

    # レベルに応じた装飾
    local decoration=""
    local color=""

    case $level in
        0)
            color="${C_WHITE}"
            decoration="..."
            ;;
        1)
            color="${C_CYAN}"
            decoration="♪"
            ;;
        2)
            color="${C_GREEN}"
            decoration="♡"
            ;;
        3)
            color="${C_YELLOW}"
            decoration="♡♡"
            ;;
        4)
            color="${C_MAGENTA}"
            decoration="✨♡✨"
            ;;
        5)
            color="${C_RED}"
            decoration="🌟✨♡✨🌟"
            ;;
        6)
            color="${C_BG_MAGENTA}${C_WHITE}"
            decoration="👑✨💖✨👑"
            ;;
    esac

    echo -e "${C_WHITE}┌─────────────────────────────────────────┐${C_RESET}"
    echo -e "${C_WHITE}│${C_RESET}            ${C_BOLD}【 判定結果 】${C_RESET}              ${C_WHITE}│${C_RESET}"
    echo -e "${C_WHITE}├─────────────────────────────────────────┤${C_RESET}"
    echo -e "${C_WHITE}│${C_RESET}                                         ${C_WHITE}│${C_RESET}"
    printf "${C_WHITE}│${C_RESET}  %-37s ${C_WHITE}│${C_RESET}\n" "「${target}」は..."
    echo -e "${C_WHITE}│${C_RESET}                                         ${C_WHITE}│${C_RESET}"
    printf "${C_WHITE}│${C_RESET}    ${color}${C_BOLD}%-30s${C_RESET}     ${C_WHITE}│${C_RESET}\n" "$level_text"
    echo -e "${C_WHITE}│${C_RESET}                                         ${C_WHITE}│${C_RESET}"
    printf "${C_WHITE}│${C_RESET}         %-28s   ${C_WHITE}│${C_RESET}\n" "$decoration"
    echo -e "${C_WHITE}│${C_RESET}                                         ${C_WHITE}│${C_RESET}"
    printf "${C_WHITE}│${C_RESET}              %-24s ${C_WHITE}│${C_RESET}\n" "$kaomoji"
    echo -e "${C_WHITE}│${C_RESET}                                         ${C_WHITE}│${C_RESET}"
    echo -e "${C_WHITE}└─────────────────────────────────────────┘${C_RESET}"

    # デバッグモード
    if [[ $debug_mode -eq 1 ]]; then
        echo ""
        echo -e "${C_CYAN}[DEBUG] スコア詳細:${C_RESET}"
        echo -e "  総合スコア: ${score}"
        echo -e "  判定レベル: ${level}/6"
        echo -e "  厳格モード: $([[ $strict_mode -eq 1 ]] && echo 'ON' || echo 'OFF')"
    fi

    # 最上級以上の場合は特別演出
    if [[ $level -ge 5 ]]; then
        echo ""
        show_celebration
    fi
}

#
# 最上級演出
#
show_celebration() {
    echo -e "${C_YELLOW}✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨${C_RESET}"
    echo ""
    echo -e "  ${C_MAGENTA}${C_BOLD}おめでとうございます！${C_RESET}"
    echo -e "  ${C_WHITE}あなたの判定対象は${C_RESET}"
    echo -e "  ${C_RED}${C_BOLD}最上級のかわいさ${C_RESET}${C_WHITE}を持っています！${C_RESET}"
    echo ""

    # ランダムなコメント
    local comments=(
        "この世に生まれてきてくれてありがとう..."
        "尊い...尊すぎる..."
        "かわいいは正義！"
        "推せる...推せるぞ..."
        "天使かな？天使だね。"
        "世界が平和になった気がする"
        "永遠にかわいい"
    )
    local comment="${comments[$((RANDOM % ${#comments[@]}))]}"

    echo -e "  ${C_CYAN}「${comment}」${C_RESET}"
    echo ""
    echo -e "${C_YELLOW}✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨${C_RESET}"
}

# ===== メイン処理 =====

#
# かわいさを判定
#
judge_kawaii() {
    local target="$1"

    show_kawaii_banner
    show_judging_animation "$target"

    # スコア計算
    local base_score
    base_score=$(calculate_base_score "$target")

    local keyword_bonus
    keyword_bonus=$(calculate_keyword_bonus "$target")

    local destiny_bonus
    destiny_bonus=$(calculate_destiny_bonus)

    local total_score=$((base_score + keyword_bonus + destiny_bonus))

    # レベル決定
    local level
    level=$(get_kawaii_level "$total_score")

    # 結果表示
    show_result "$level" "$total_score" "$target"
}

#
# インタラクティブモード
#
interactive_mode() {
    show_kawaii_banner

    echo -e "${C_CYAN}かわいさを判定したいものを入力してください:${C_RESET}"
    echo -ne "${C_WHITE}> ${C_RESET}"
    read -r target

    if [[ -z "$target" ]]; then
        echo -e "${C_RED}何も入力されませんでした${C_RESET}"
        exit 1
    fi

    echo ""
    show_judging_animation "$target"

    # スコア計算
    local base_score
    base_score=$(calculate_base_score "$target")

    local keyword_bonus
    keyword_bonus=$(calculate_keyword_bonus "$target")

    local destiny_bonus
    destiny_bonus=$(calculate_destiny_bonus)

    local total_score=$((base_score + keyword_bonus + destiny_bonus))

    # レベル決定
    local level
    level=$(get_kawaii_level "$total_score")

    # 結果表示
    show_result "$level" "$total_score" "$target"

    # 続けるか確認
    echo ""
    echo -ne "${C_CYAN}もう一度判定しますか？ [y/N]: ${C_RESET}"
    read -r again
    if [[ "$again" =~ ^[Yy] ]]; then
        echo ""
        interactive_mode
    else
        echo ""
        echo -e "${C_MAGENTA}またのご利用をお待ちしております ${C_RESET}$(get_random_kaomoji)"
    fi
}

#
# 引数解析
#
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_usage
                exit 0
                ;;
            -v|--version)
                echo "$PROG_NAME version $VERSION"
                exit 0
                ;;
            -s|--strict)
                strict_mode=1
                shift
                ;;
            -d|--debug)
                debug_mode=1
                shift
                ;;
            -*)
                echo -e "${C_RED}不明なオプション: $1${C_RESET}" >&2
                exit 1
                ;;
            *)
                target="$1"
                shift
                ;;
        esac
    done
}

#
# メイン関数
#
main() {
    parse_arguments "$@"

    if [[ -z "$target" ]]; then
        interactive_mode
    else
        judge_kawaii "$target"
    fi
}

# スクリプト実行
main "$@"
