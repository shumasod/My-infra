#!/bin/bash
set -euo pipefail

#
# バースデーケーキ生成スクリプト
# 作成日: 2026-07-04
# バージョン: 2.0
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="2.0"

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション]

バースデーケーキをアニメーション付きで表示します。

オプション:
  -h, --help       このヘルプを表示
  -v, --version    バージョン情報を表示
  -n, --name NAME  お祝いする人の名前
  --fast           アニメーションをスキップ
EOF
}

draw_cake() {
    local name="${1:-}"
    echo ""
    if [ -n "$name" ]; then
        print_center "Happy Birthday, ${name}!" 0 "${C_BOLD}${C_YELLOW}"
    else
        print_center "Happy Birthday!" 0 "${C_BOLD}${C_YELLOW}"
    fi
    echo ""
    print_center "   ${C_WHITE}|${C_RESET} ${C_WHITE}|${C_RESET} ${C_WHITE}|${C_RESET}" 0 ""
    print_center "   ${C_YELLOW}*${C_RESET} ${C_YELLOW}*${C_RESET} ${C_YELLOW}*${C_RESET}" 0 ""
    print_center "${C_MAGENTA}~~~~~~~~~~~~~~~~${C_RESET}" 0 ""
    print_center "${C_MAGENTA}~~~~~~~~~~~~~~~~~~${C_RESET}" 0 ""
    print_center "${C_CYAN}====================${C_RESET}" 0 ""
    print_center "${C_WHITE}####################${C_RESET}" 0 ""
    print_center "${C_MAGENTA}====================${C_RESET}" 0 ""
    print_center "${C_WHITE}▽▽▽▽▽▽▽▽▽▽${C_RESET}" 0 ""
    print_center "${C_CYAN}=================${C_RESET}" 0 ""
    print_center "${C_CYAN}==============${C_RESET}" 0 ""
    echo ""
}

main() {
    local name=""
    local fast=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -n|--name)
                [[ $# -lt 2 ]] && error_exit "--name には名前が必要です"
                name="$2"; shift 2 ;;
            --fast) fast=true; shift ;;
            *) error_exit "不明なオプション: $1" ;;
        esac
    done

    clear_screen
    log_info "バースデーケーキを作ります！"

    local delay=0.3
    "$fast" && delay=0

    local -a materials=("小麦粉" "バター" "砂糖" "卵" "ベーキングパウダー" "バニラエッセンス" "生クリーム" "フルーツ")
    echo ""
    echo -e "  ${C_BOLD}必要な材料:${C_RESET}"
    local item
    for item in "${materials[@]}"; do
        echo -e "  ${C_DIM}・${item} を準備中...${C_RESET}"
        sleep "$delay"
    done

    echo ""
    echo -e "  ${C_YELLOW}オーブンを180℃に予熱します...${C_RESET}"
    sleep "$delay"
    echo -e "  ${C_YELLOW}生地を混ぜています...${C_RESET}"
    sleep "$delay"
    echo -e "  ${C_YELLOW}ケーキ型に流し込みます...${C_RESET}"
    sleep "$delay"

    if ! "$fast"; then
        printf "  ${C_DIM}オーブンで焼いています"
        local i
        for (( i = 0; i < 5; i++ )); do printf "."; sleep 0.4; done
        echo -e "${C_RESET}"
    fi

    echo -e "  ${C_MAGENTA}生クリームを塗っています...${C_RESET}"
    sleep "$delay"
    echo -e "  ${C_RED}デコレーションを施しています...${C_RESET}"
    sleep "$delay"

    clear_screen
    draw_cake "$name"
    log_success "ケーキが完成しました！"
    echo ""
    echo -e "  ${C_DIM}何かキーを押して終了...${C_RESET}"
    read -rn1
    clear_screen
}

main "$@"
