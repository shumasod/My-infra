#!/bin/bash
set -euo pipefail

#
# ANSIカラーピッカー
# 作成日: 2026-07-14
# バージョン: 1.0
#
# ターミナルで使えるANSIカラーコードを一覧表示・選択するツール
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション]

ANSIカラーコードを一覧表示・解説します。

オプション:
  -h, --help        このヘルプを表示
  -v, --version     バージョン情報を表示
  -s, --standard    標準16色を表示
  -2, --256         256色パレットを表示
  -r, --rgb         RGB形式で検索
  -c, --code CODE   指定コードのプレビュー
  --shell           シェルスクリプト用コード出力

例:
  $PROG_NAME --standard
  $PROG_NAME --256
  $PROG_NAME --code 196
  $PROG_NAME --shell
EOF
}

show_standard_colors() {
    echo ""
    print_center "標準ANSIカラー（16色）" 0 "${C_BOLD}${C_CYAN}"
    echo ""

    echo -e "  ${C_BOLD}通常色（30-37）:${C_RESET}"
    echo -n "  "
    local names=("黒" "赤" "緑" "黄" "青" "紫" "水" "白")
    for i in {0..7}; do
        printf "\033[%dm  ■ %s(3%d)  \033[0m" "$((30+i))" "${names[$i]}" "$i"
    done
    echo ""
    echo ""

    echo -e "  ${C_BOLD}明るい色（90-97）:${C_RESET}"
    echo -n "  "
    for i in {0..7}; do
        printf "\033[%dm  ■ %s(9%d)  \033[0m" "$((90+i))" "${names[$i]}" "$i"
    done
    echo ""
    echo ""

    echo -e "  ${C_BOLD}背景色（40-47）:${C_RESET}"
    echo -n "  "
    for i in {0..7}; do
        printf "\033[%d;37m  □%d  \033[0m" "$((40+i))" "$i"
    done
    echo ""
    echo ""

    echo -e "  ${C_BOLD}テキスト装飾:${C_RESET}"
    printf "  \033[1m太字(1)\033[0m  "
    printf "  \033[3mイタリック(3)\033[0m  "
    printf "  \033[4m下線(4)\033[0m  "
    printf "  \033[7m反転(7)\033[0m  "
    printf "  \033[9m取消線(9)\033[0m  "
    echo ""
    echo ""
}

show_256_palette() {
    echo ""
    print_center "256色パレット" 0 "${C_BOLD}${C_CYAN}"
    echo ""

    echo -e "  ${C_BOLD}システムカラー（0-15）:${C_RESET}"
    echo -n "  "
    for i in {0..15}; do
        printf "\033[48;5;%dm  %3d  \033[0m" "$i" "$i"
        if (( (i+1) % 8 == 0 )); then
            echo ""
            echo -n "  "
        fi
    done
    echo ""

    echo -e "  ${C_BOLD}カラーキューブ（16-231）:${C_RESET}"
    local row=0
    for i in $(seq 16 231); do
        if (( row == 0 )); then echo -n "  "; fi
        printf "\033[48;5;%dm   \033[0m" "$i"
        (( row++ ))
        if (( row == 36 )); then
            echo ""
            row=0
        fi
    done
    echo ""

    echo -e "  ${C_BOLD}グレースケール（232-255）:${C_RESET}"
    echo -n "  "
    for i in $(seq 232 255); do
        printf "\033[48;5;%dm   \033[0m" "$i"
        if (( (i-232+1) % 12 == 0 )); then
            echo ""
            echo -n "  "
        fi
    done
    echo ""
}

preview_color() {
    local code="$1"

    if ! [[ "$code" =~ ^[0-9]+$ ]] || (( code < 0 || code > 255 )); then
        error_exit "カラーコードは0-255の整数を指定してください"
    fi

    echo ""
    print_center "カラープレビュー: $code" 0 "${C_BOLD}${C_CYAN}"
    echo ""

    printf "  前景色: \033[38;5;%dm  ■■■ テキストサンプル ■■■  \033[0m\n" "$code"
    printf "  背景色: \033[48;5;%dm  ■■■ テキストサンプル ■■■  \033[0m\n" "$code"
    echo ""
    echo -e "  ${C_BOLD}使用方法:${C_RESET}"
    echo -e "  ${C_GREEN}前景:${C_RESET} \\033[38;5;${code}m ... \\033[0m"
    echo -e "  ${C_GREEN}背景:${C_RESET} \\033[48;5;${code}m ... \\033[0m"
    echo ""
}

show_shell_codes() {
    echo ""
    print_center "シェルスクリプト用カラー定数" 0 "${C_BOLD}${C_CYAN}"
    echo ""
    cat <<'SHELLEOF'
  # 標準カラー定数
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  MAGENTA='\033[0;35m'
  CYAN='\033[0;36m'
  WHITE='\033[1;37m'
  BOLD='\033[1m'
  DIM='\033[2m'
  RESET='\033[0m'

  # 使用例
  echo -e "${RED}エラー${RESET}: ファイルが見つかりません"
  echo -e "${GREEN}成功${RESET}: 処理が完了しました"
  echo -e "${YELLOW}警告${RESET}: ディスク使用率が高い"

  # 256色の使用例
  echo -e "\033[38;5;208m オレンジ色テキスト \033[0m"
  echo -e "\033[48;5;57m 紫背景 \033[0m"
SHELLEOF
    echo ""
    echo -e "  ${C_BOLD}lib/common.sh の C_* 定数も利用可能です:${C_RESET}"
    echo -e "  ${C_DIM}source lib/common.sh${C_RESET}"
    echo -e "  ${C_DIM}echo -e \"\${C_RED}エラー\${C_RESET}\"${C_RESET}"
    echo ""
}

main() {
    local show_standard=false
    local show_256=false
    local preview_code=""
    local show_shell=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -s|--standard) show_standard=true; shift ;;
            -2|--256)     show_256=true; shift ;;
            -c|--code)
                [[ $# -lt 2 ]] && error_exit "--code にはコード番号が必要です"
                preview_code="$2"; shift 2 ;;
            --shell)      show_shell=true; shift ;;
            *)            error_exit "不明なオプション: $1" ;;
        esac
    done

    if [[ -n "$preview_code" ]]; then
        preview_color "$preview_code"
        exit 0
    fi

    if "$show_shell"; then
        show_shell_codes
        exit 0
    fi

    if "$show_256"; then
        show_256_palette
        exit 0
    fi

    show_standard_colors

    if ! "$show_standard"; then
        echo -e "  ${C_DIM}--256 で256色パレット、--code N でコードプレビュー${C_RESET}"
        echo ""
    fi
}

main "$@"
