#!/bin/bash

# エラー処理の設定
set -euo pipefail
trap 'echo -e "\n${RED}エラーが発生しました${NC}"; exit 1' ERR

# ANSIカラーコードの定義
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# 顔文字の配列
declare -a KAOMOJI=(
    "( ´ ▽ ` )ﾉ"
    "(｡◕‿◕｡)"
    "(｀・ω・´)"
    "(´･ω･\`)"
    "ヽ(^o^)丿"
    "(◕‿◕✿)"
    "٩(◕‿◕｡)۶"
    "(｡♥‿♥｡)"
    "(✿ ♥‿♥)"
    "ヽ(♡‿♡)ノ"
    "(・∀・)"
    "(｡･ω･｡)"
    "(〃￣ω￣〃)"
    "(*´∀｀*)"
    "(๑•̀ㅂ•́)و✧"
    "ヽ(＾Д＾)ﾉ"
    "(´｡• ω •｡\`)"
    "(●'◡'●)"
    "(◕ᴗ◕✿)"
    "＼(^o^)／"
    "(≧◡≦)"
    "(◠‿◠)"
    "(✯◡✯)"
    "(≧∇≦)/"
)

# ルーレットアニメーション用の関数
roulette_animation() {
    local duration=$1
    local interval=0.1
    local elapsed=0
    local index=0
    
    # カーソルを非表示
    tput civis
    
    # アニメーション
    while [ $(echo "$elapsed < $duration" | bc) -eq 1 ]; do
        clear
        echo -e "${CYAN}=== 顔文字ルーレット ===${NC}\n"
        echo -e "${YELLOW}ルーレット回転中...${NC}\n"
        
        # 現在の顔文字を表示
        echo -e "${GREEN}${KAOMOJI[$index]}${NC}"
        
        # インデックスを更新
        index=$(( (index + 1) % ${#KAOMOJI[@]} ))
        
        sleep $interval
        elapsed=$(echo "$elapsed + $interval" | bc)
        
        # 回転速度を徐々に遅くする
        if [ $(echo "$elapsed > $duration / 2" | bc) -eq 1 ]; then
            interval=$(echo "$interval + 0.02" | bc)
        fi
    done
    
    # カーソルを表示
    tput cnorm
    
    # 最終的な顔文字をランダムに選択
    local final_index=$((RANDOM % ${#KAOMOJI[@]}))
    clear
    echo -e "${CYAN}=== 顔文字ルーレット ===${NC}\n"
    echo -e "${GREEN}選ばれた顔文字:${NC}\n"
    echo -e "${YELLOW}${KAOMOJI[$final_index]}${NC}\n"
    
    # クリップボードにコピー（利用可能な場合）
    if command -v xclip > /dev/null; then
        echo -n "${KAOMOJI[$final_index]}" | xclip -selection clipboard
        echo -e "${PURPLE}顔文字をクリップボードにコピーしました！${NC}"
    elif command -v pbcopy > /dev/null; then
        echo -n "${KAOMOJI[$final_index]}" | pbcopy
        echo -e "${PURPLE}顔文字をクリップボードにコピーしました！${NC}"
    fi
}

# メイン処理
main() {
    while true; do
        clear
        echo -e "${CYAN}=== 顔文字ルーレット ===${NC}\n"
        echo -e "1) ルーレットを回す"
        echo -e "2) 終了\n"
        
        read -p "選択してください (1-2): " choice
        
        case $choice in
            1)
                roulette_animation 3
                echo -e "\n${GREEN}もう一度回しますか？ (y/n)${NC}"
                read -n 1 -r answer
                echo
                if [[ ! $answer =~ ^[Yy]$ ]]; then
                    echo -e "\n${YELLOW}またね！(｡･ω･)ﾉﾞ${NC}"
                    exit 0
                fi
                ;;
            2)
                echo -e "\n${YELLOW}またね！(｡･ω･)ﾉﾞ${NC}"
                exit 0
                ;;
            *)
                echo -e "\n${RED}無効な選択です。${NC}"
                sleep 1
                ;;
        esac
    done
}

# スクリプトを開始
main
