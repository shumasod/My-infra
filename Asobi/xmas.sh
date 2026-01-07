#!/bin/bash

# =============================================================================
# 🎄 Christmas Tree Animation Script
# =============================================================================
# クリスマスツリーをターミナルに表示し、オーナメントを点滅させます
# Usage: ./christmas.sh [tree_height]
# =============================================================================

set -euo pipefail

# カラー定義
readonly GREEN='\033[0;32m'
readonly BRIGHT_GREEN='\033[1;32m'
readonly RED='\033[0;31m'
readonly BRIGHT_RED='\033[1;31m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly BRIGHT_BLUE='\033[1;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly BROWN='\033[0;33m'
readonly RESET='\033[0m'
readonly BLINK='\033[5m'

# デフォルト設定
TREE_HEIGHT=${1:-15}
ANIMATION_FRAMES=0

# ターミナルサイズ取得
get_terminal_width() {
    tput cols 2>/dev/null || echo 80
}

# カーソル非表示
hide_cursor() {
    tput civis 2>/dev/null || true
}

# カーソル表示
show_cursor() {
    tput cnorm 2>/dev/null || true
}

# 画面クリア
clear_screen() {
    clear
    tput cup 0 0 2>/dev/null || true
}

# 終了時のクリーンアップ
cleanup() {
    show_cursor
    echo -e "${RESET}"
    echo ""
    echo -e "${YELLOW}🎄 Merry Christmas! 🎄${RESET}"
    exit 0
}

trap cleanup SIGINT SIGTERM

# ランダムなオーナメント色を取得
get_ornament_color() {
    local colors=("$RED" "$BRIGHT_RED" "$YELLOW" "$BLUE" "$BRIGHT_BLUE" "$MAGENTA" "$CYAN" "$WHITE")
    echo "${colors[$((RANDOM % ${#colors[@]}))]}"
}

# ランダムなオーナメント文字を取得
get_ornament() {
    local ornaments=("●" "○" "◆" "★" "✦" "❄" "♦" "◇")
    echo "${ornaments[$((RANDOM % ${#ornaments[@]}))]}"
}

# ツリーの星を描画
draw_star() {
    local width=$1
    local center=$((width / 2))
    local star_art=(
        "    ★    "
        "   ███   "
        "    █    "
    )
    
    for line in "${star_art[@]}"; do
        local padding=$(( center - ${#line} / 2 ))
        printf "%*s" "$padding" ""
        echo -e "${YELLOW}${line}${RESET}"
    done
}

# ツリー本体を描画
draw_tree() {
    local height=$1
    local width=$2
    local center=$((width / 2))
    local frame=$3
    
    for ((i = 0; i < height; i++)); do
        local row_width=$((i * 2 + 1))
        local padding=$((center - row_width / 2 - 1))
        
        printf "%*s" "$padding" ""
        
        for ((j = 0; j < row_width; j++)); do
            # オーナメントを配置する確率
            if [[ $((RANDOM % 8)) -eq 0 ]] && [[ $j -ne 0 ]] && [[ $j -ne $((row_width - 1)) ]]; then
                local color
                color=$(get_ornament_color)
                local ornament
                ornament=$(get_ornament)
                echo -ne "${color}${ornament}${RESET}"
            else
                # フレームに応じて緑の濃淡を変える
                if [[ $(( (i + j + frame) % 3 )) -eq 0 ]]; then
                    echo -ne "${BRIGHT_GREEN}*${RESET}"
                else
                    echo -ne "${GREEN}*${RESET}"
                fi
            fi
        done
        echo ""
    done
}

# 幹を描画
draw_trunk() {
    local width=$1
    local center=$((width / 2))
    local trunk_width=5
    local trunk_height=3
    
    for ((i = 0; i < trunk_height; i++)); do
        local padding=$((center - trunk_width / 2 - 1))
        printf "%*s" "$padding" ""
        echo -e "${BROWN}█████${RESET}"
    done
}

# 雪を描画
draw_snow() {
    local width=$1
    local snow_chars=("❄" "❅" "❆" "." "*" "·")
    
    printf "%*s" 0 ""
    for ((i = 0; i < width; i++)); do
        if [[ $((RANDOM % 5)) -eq 0 ]]; then
            echo -ne "${WHITE}${snow_chars[$((RANDOM % ${#snow_chars[@]}))]}${RESET}"
        else
            echo -n " "
        fi
    done
    echo ""
}

# メッセージを描画
draw_message() {
    local width=$1
    local center=$((width / 2))
    local messages=(
        "🎄 Merry Christmas! 🎄"
        "❄️  Happy Holidays!  ❄️"
        "🎅 Ho Ho Ho! 🎅"
    )
    local message="${messages[$((ANIMATION_FRAMES % ${#messages[@]}))]}"
    local msg_len=${#message}
    local padding=$((center - msg_len / 2))
    
    echo ""
    printf "%*s" "$padding" ""
    echo -e "${BRIGHT_RED}${message}${RESET}"
    echo ""
}

# プレゼントを描画
draw_presents() {
    local width=$1
    local center=$((width / 2))
    
    local present1="${RED}┌───┐${RESET}"
    local present2="${RED}│${YELLOW}♥${RED}│${RESET}"
    local present3="${RED}└───┘${RESET}"
    
    local present4="${BLUE}┌──┐${RESET}"
    local present5="${BLUE}│${WHITE}★${BLUE}│${RESET}"
    local present6="${BLUE}└──┘${RESET}"
    
    local present7="${MAGENTA}┌────┐${RESET}"
    local present8="${MAGENTA}│${CYAN}◆◆${MAGENTA}│${RESET}"
    local present9="${MAGENTA}└────┘${RESET}"
    
    local offset=$((center - 12))
    
    printf "%*s" "$offset" ""
    echo -e "  ${present1}   ${present4}   ${present7}"
    printf "%*s" "$offset" ""
    echo -e "  ${present2}   ${present5}   ${present8}"
    printf "%*s" "$offset" ""
    echo -e "  ${present3}   ${present6}   ${present9}"
}

# ASCII情報を表示
show_info() {
    echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}  ${YELLOW}🎄 Christmas Tree Animation${RESET}                           ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}  ${WHITE}Press Ctrl+C to exit${RESET}                                  ${CYAN}║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${RESET}"
    echo ""
}

# メイン描画関数
draw_frame() {
    local frame=$1
    local term_width
    term_width=$(get_terminal_width)
    
    clear_screen
    show_info
    draw_snow "$term_width"
    draw_star "$term_width"
    draw_tree "$TREE_HEIGHT" "$term_width" "$frame"
    draw_trunk "$term_width"
    echo ""
    draw_presents "$term_width"
    draw_message "$term_width"
    draw_snow "$term_width"
}

# 静的表示モード
static_display() {
    local term_width
    term_width=$(get_terminal_width)
    
    clear_screen
    show_info
    draw_snow "$term_width"
    draw_star "$term_width"
    draw_tree "$TREE_HEIGHT" "$term_width" 0
    draw_trunk "$term_width"
    echo ""
    draw_presents "$term_width"
    draw_message "$term_width"
    draw_snow "$term_width"
}

# アニメーションモード
animation_mode() {
    hide_cursor
    
    while true; do
        draw_frame "$ANIMATION_FRAMES"
        ((ANIMATION_FRAMES++))
        sleep 0.5
    done
}

# ヘルプ表示
show_help() {
    echo "Usage: $0 [OPTIONS] [tree_height]"
    echo ""
    echo "Options:"
    echo "  -h, --help     このヘルプを表示"
    echo "  -s, --static   静的表示（アニメーションなし）"
    echo "  -a, --animate  アニメーション表示（デフォルト）"
    echo ""
    echo "Arguments:"
    echo "  tree_height    ツリーの高さ（デフォルト: 15）"
    echo ""
    echo "Examples:"
    echo "  $0              デフォルト設定でアニメーション表示"
    echo "  $0 20           高さ20のツリーをアニメーション表示"
    echo "  $0 -s 10        高さ10のツリーを静的表示"
}

# メイン処理
main() {
    local mode="animate"
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -s|--static)
                mode="static"
                shift
                ;;
            -a|--animate)
                mode="animate"
                shift
                ;;
            *)
                if [[ "$1" =~ ^[0-9]+$ ]]; then
                    TREE_HEIGHT=$1
                fi
                shift
                ;;
        esac
    done
    
    # ツリーの高さの範囲チェック
    if [[ $TREE_HEIGHT -lt 5 ]]; then
        TREE_HEIGHT=5
    elif [[ $TREE_HEIGHT -gt 30 ]]; then
        TREE_HEIGHT=30
    fi
    
    if [[ "$mode" == "static" ]]; then
        static_display
    else
        animation_mode
    fi
}

main "$@"
