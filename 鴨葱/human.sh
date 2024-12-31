#!/bin/bash

# カラー定義
declare -A colors=(
    ["RED"]="\033[0;31m"
    ["GREEN"]="\033[0;32m"
    ["BLUE"]="\033[0;34m"
    ["PURPLE"]="\033[0;35m"
    ["CYAN"]="\033[0;36m"
    ["BROWN"]="\033[0;33m"
    ["WHITE"]="\033[1;37m"
    ["BLACK"]="\033[0;30m"
    ["YELLOW"]="\033[1;33m"
    ["RESET"]="\033[0m"
)

# アニメーションの遅延時間（秒）
DELAY=0.1

# 画面クリア関数
clear_screen() {
    printf "\033c"
}

# カーソル制御
hide_cursor() {
    printf "\033[?25l"
}

show_cursor() {
    printf "\033[?25h"
}

# 終了時の処理
cleanup() {
    show_cursor
    clear_screen
    exit 0
}

trap cleanup SIGINT SIGTERM

# やくざのキャラクター定義
yakuza_face() {
    local offset=$1
    printf "%${offset}s${colors[BROWN]}" ""
    cat << "EOF"
      ,------.
     /  ..    \
    |  (__)   |
     \   ^   /
      '-----'
EOF
    printf "${colors[RESET]}"
}

yakuza_body() {
    local offset=$1
    printf "%${offset}s${colors[PURPLE]}" ""
    cat << "EOF"
     ,-'''''-,
    /  _   _  \
   |  (o) (o) |
    \    ^    /
     '-.....-'
      /|||||\
     //||||\\
    ///|||\\\ 
EOF
    printf "${colors[RESET]}"
}

yakuza_arms() {
    local offset=$1
    local frame=$2
    printf "%${offset}s${colors[BLUE]}" ""
    case $frame in
        0)
            cat << "EOF"
    o==[]=::::::::>
      \__/
     /    \
    /      \
EOF
            ;;
        1)
            cat << "EOF"
      o==[]==>
     /\__/\
    /      \
   /        \
EOF
            ;;
    esac
    printf "${colors[RESET]}"
}

yakuza_legs() {
    local offset=$1
    local frame=$2
    printf "%${offset}s${colors[GREEN]}" ""
    case $frame in
        0)
            cat << "EOF"
       /\  /\
      /  \/  \
     /        \
    /          \
EOF
            ;;
        1)
            cat << "EOF"
      /\    /\
     /  \  /  \
    /    \/    \
   /            \
EOF
            ;;
    esac
    printf "${colors[RESET]}"
}

# アニメーション関数
animate_yakuza() {
    local frame=0
    local offset=10
    hide_cursor
    
    while true; do
        clear_screen
        
        # タイトル表示
        printf "\n%${offset}s${colors[RED]}━━━ やくざのアニメーション ━━━${colors[RESET]}\n\n"
        
        # キャラクター表示
        yakuza_face $offset
        yakuza_body $offset
        yakuza_arms $offset $frame
        yakuza_legs $offset $frame
        
        # フレーム切り替え
        frame=$(( (frame + 1) % 2 ))
        
        # 待機
        sleep $DELAY
    done
}

# メイン処理
main() {
    # 開始メッセージ
    clear_screen
    printf "${colors[YELLOW]}アニメーションを開始します...${colors[RESET]}\n"
    sleep 1

    # アニメーション実行
    animate_yakuza
}

# プログラム実行
main