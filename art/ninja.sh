#!/bin/bash

# カラー設定
BLACK='\033[0;30m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 印を結ぶ忍者を描画する関数
draw_ninja() {
    cat << "EOF"
                   ⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀
               ⢀⣤⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣤⡀
            ⢀⣴⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣦⡀
          ⢀⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⡀
         ⣾⣿⣿⣿⣿⣿⡿⠿⠿⠿⠿⠿⠿⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷
        ⣸⣿⣿⣿⣿⠏⠀⠀⠀⠀⠀⠀⠀⠀⠹⣿⣿⣿⣿⣿⣿⣿⣿⣇
        ⣿⣿⣿⣿⣿⠀⠀⠀⣿⣿⣿⣶⡄⠀⠀⣿⣿⣿⣿⣿⣿⣿⣿⣿
        ⢿⣿⣿⣿⣿⣷⣤⣼⣿⣿⣿⣿⣿⣤⣾⣿⣿⣿⣿⣿⣿⣿⣿⡟    
         ⠹⣿⣿⣿⣿⣿⣿⠿⠟⠻⠿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠏     
          ⠈⢿⠿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠁
             ⠈⠉⠛⠛⠿⠿⠿⠿⠿⠛⠋⠁
                    
EOF
}

# 印のエフェクトを描画する関数
draw_effect() {
    local frame=$1
    case $frame in
        1)
            echo -e "\033[7A\033[30C○"
            ;;
        2)
            echo -e "\033[7A\033[30C◎"
            ;;
        3)
            echo -e "\033[7A\033[30C☆"
            ;;
        4)
            echo -e "\033[7A\033[30C✨"
            ;;
    esac
}

# メイン処理
clear

# アニメーションループ
for i in {1..5}; do
    for frame in {1..4}; do
        clear
        echo -e "${BLUE}"
        draw_ninja
        echo -e "${CYAN}"
        draw_effect $frame
        sleep 0.3
    done
done

# カラーリセット
echo -e "${NC}"