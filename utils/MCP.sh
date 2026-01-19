#!/bin/bash
set -euo pipefail

# MCPをASCIIアートで表示するシェルスクリプト

# 定数定義
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly RESET='\033[0m'
readonly DELAY=0.05

# ASCIIアートデータ
readonly -a ASCII_ART=(
    "${RED}  ##     ##  ${GREEN} ######  ${BLUE} ########  ${RESET}"
    "${RED}  ###   ###  ${GREEN} ##   ##  ${BLUE} ##     ##  ${RESET}"
    "${RED}  #### ####  ${GREEN} ##       ${BLUE} ##     ##  ${RESET}"
    "${RED}  ## ### ##  ${GREEN} ##       ${BLUE} ########  ${RESET}"
    "${RED}  ##     ##  ${GREEN} ##       ${BLUE} ##        ${RESET}"
    "${RED}  ##     ##  ${GREEN} ##   ##  ${BLUE} ##        ${RESET}"
    "${RED}  ##     ##  ${GREEN} ######  ${BLUE} ##        ${RESET}"
)

# アニメーション速度を引数で制御可能に
get_delay() {
    local speed="${1:-normal}"
    case "$speed" in
        fast)   echo "0.02" ;;
        normal) echo "0.05" ;;
        slow)   echo "0.1" ;;
        *)      echo "0.05" ;;
    esac
}

# アニメーション効果付きでテキストを表示
animate_text() {
    local text="$1"
    local delay="${2:-$DELAY}"
    
    echo -e "$text"
    sleep "$delay"
}

# ASCIIアートを表示
display_ascii_art() {
    local delay="$1"
    
    echo ""
    for line in "${ASCII_ART[@]}"; do
        animate_text "$line" "$delay"
    done
    echo ""
}

# タイトルとフッターを表示
display_info() {
    animate_text "${GREEN}Master Control Program${RESET}" "$DELAY"
    echo ""
    echo "=========================================="
    echo "This script displays MCP ASCII art"
    echo "Created on: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "=========================================="
}

# ヘルプメッセージ
show_help() {
    cat << EOF
使用方法: $(basename "$0") [OPTIONS]

MCPのASCIIアートをアニメーション効果付きで表示します。

OPTIONS:
    -s, --speed SPEED    アニメーション速度 (fast/normal/slow)
    -n, --no-animation   アニメーションなしで表示
    -h, --help           このヘルプを表示

EXAMPLES:
    $(basename "$0")              # 通常速度で表示
    $(basename "$0") -s fast      # 高速で表示
    $(basename "$0") -n           # アニメーションなし
EOF
}

# メイン処理
main() {
    local speed="normal"
    local no_animation=false
    
    # 引数解析
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -s|--speed)
                speed="${2:-normal}"
                shift 2
                ;;
            -n|--no-animation)
                no_animation=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo "不明なオプション: $1" >&2
                show_help
                exit 1
                ;;
        esac
    done
    
    local delay
    if [[ "$no_animation" == true ]]; then
        delay=0
    else
        delay=$(get_delay "$speed")
    fi
    
    clear
    display_ascii_art "$delay"
    display_info
}

main "$@"
