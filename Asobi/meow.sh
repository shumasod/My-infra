#!/bin/bash
set -euo pipefail

#
# にゃんこ翻訳スクリプト
# 作成日: 2026-07-04
# バージョン: 3.0
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="3.0"

readonly -a NYAN_ENDINGS=("にゃん！" "にゃ〜" "だにゃ" "だにゃん" "なのにゃ" "みゃ〜" "にゃあ" "ぬぁ〜")
readonly -a GREETINGS=("にゃ？" "みゃ〜ん" "ごろごろ…" "にゃっ！" "すりすり〜" "くるるる〜")
readonly -a CAT_FACES=("(=^･ω･^=)" "(ฅ^•ﻌ•^ฅ)" "ヾ(=^･ω･^=)ﾉ" "(=｀ェ´=)" "ε（・ω・｀）з")

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション] [テキスト]

入力した言葉を猫語に翻訳します。

引数:
  テキスト   翻訳するテキスト（省略時はインタラクティブ入力）

オプション:
  -h, --help       このヘルプを表示
  -v, --version    バージョン情報を表示
  -l, --loop       ループモード（連続入力）
  --no-animation   翻訳アニメーションをスキップ
EOF
}

translate_to_nyan() {
    local input="$1"
    local animate="${2:-true}"

    local greet="${GREETINGS[$(( RANDOM % ${#GREETINGS[@]} ))]}"
    local nyan="${NYAN_ENDINGS[$(( RANDOM % ${#NYAN_ENDINGS[@]} ))]}"
    local face="${CAT_FACES[$(( RANDOM % ${#CAT_FACES[@]} ))]}"

    echo ""
    echo -e "  ${C_CYAN}${greet} 翻訳中...${C_RESET}"

    if "$animate"; then
        printf "  "
        local i
        for (( i = 0; i < 5; i++ )); do
            printf "${C_YELLOW}にゃ${C_RESET}"
            sleep 0.2
        done
        echo ""
    fi

    echo ""
    echo -e "  ${C_BOLD}${C_MAGENTA}${face}${C_RESET}"
    echo -e "  ${C_YELLOW}翻訳結果:${C_RESET} ${C_BOLD}${input}${nyan}${C_RESET}"
    echo ""
}

main() {
    local loop_mode=false
    local animate=true
    local text=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)      show_usage; exit 0 ;;
            -v|--version)   echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -l|--loop)      loop_mode=true; shift ;;
            --no-animation) animate=false; shift ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  text="$1"; shift ;;
        esac
    done

    clear_screen
    print_center "にゃんこ翻訳スクリプト v${VERSION}" 0 "${C_BOLD}${C_CYAN}"
    print_center "${CAT_FACES[$(( RANDOM % ${#CAT_FACES[@]} ))]}" 0 "$C_YELLOW"
    echo ""

    if [ -n "$text" ]; then
        translate_to_nyan "$text" "$animate"
        return
    fi

    if "$loop_mode"; then
        while true; do
            printf "  ${C_CYAN}猫語に翻訳する言葉 (q=終了): ${C_RESET}"
            local input
            read -r input
            [[ "$input" == "q" || "$input" == "Q" ]] && break
            [ -z "$input" ] && continue
            translate_to_nyan "$input" "$animate"
        done
        clear_screen
        log_success "またにゃ〜！"
    else
        printf "  ${C_CYAN}猫語に翻訳したい言葉を入力してください: ${C_RESET}"
        local input
        read -r input
        [ -n "$input" ] && translate_to_nyan "$input" "$animate"
    fi
}

main "$@"
