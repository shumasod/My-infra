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
    ["ORANGE"]="\033[38;5;208m"
    ["RESET"]="\033[0m"
)

# アニメーション設定
DELAY=0.3
ANIMATION_CYCLES=0
MAX_CYCLES=100

# 画面制御関数
clear_screen() {
    printf "\033[2J\033[H"
}

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
    printf "${colors[GREEN]}アニメーションを終了しました。${colors[RESET]}\n"
    exit 0
}

# シグナルハンドリング
trap cleanup SIGINT SIGTERM EXIT

# やくざキャラクターの顔
draw_face() {
    local offset=$1
    printf "%${offset}s${colors[BROWN]}" ""
    cat << 'EOF'
    ╭─────────╮
   ╱  ● ●  ╲
  ╱  ┌─────┐  ╲
 ╱   │ ━━━ │   ╲
╱    └─┬─┬─┘    ╲
╲      ╰─╯      ╱
 ╲             ╱
  ╲___________╱
EOF
    printf "${colors[RESET]}"
}

# やくざキャラクターの体
draw_body() {
    local offset=$1
    printf "%${offset}s${colors[BLUE]}" ""
    cat << 'EOF'
      ┌─────┐
      │ 龍 │
      │ 王 │
   ╭──┴─────┴──╮
  ╱             ╲
 ╱  ┌─────────┐  ╲
╱   │         │   ╲
│   │  極道  │   │
│   │         │   │
╲   └─────────┘   ╱
 ╲               ╱
  ╲─────────────╱
EOF
    printf "${colors[RESET]}"
}

# やくざキャラクターの腕（アニメーション対応）
draw_arms() {
    local offset=$1
    local frame=$2
    printf "%${offset}s${colors[PURPLE]}" ""
    
    case $frame in
        0)
            cat << 'EOF'
 ╱─╲         ╱─╲
╱   ╲       ╱   ╲
│ ═══╪═════╪═══ │
╲   ╱       ╲   ╱
 ╲─╱         ╲─╱
EOF
            ;;
        1)
            cat << 'EOF'
   ╱─╲     ╱─╲
  ╱   ╲   ╱   ╲
 │ ═══╪═╪═╪═══ │
  ╲   ╱   ╲   ╱
   ╲─╱     ╲─╱
EOF
            ;;
        2)
            cat << 'EOF'
     ╱─╲ ╱─╲
    ╱   ╳   ╲
   │ ═══╪═══ │
    ╲   ╳   ╱
     ╲─╱ ╲─╱
EOF
            ;;
    esac
    printf "${colors[RESET]}"
}

# やくざキャラクターの脚（アニメーション対応）
draw_legs() {
    local offset=$1
    local frame=$2
    printf "%${offset}s${colors[GREEN]}" ""
    
    case $frame in
        0)
            cat << 'EOF'
     ╱│╲   ╱│╲
    ╱ │ ╲ ╱ │ ╲
   ╱  │  ╳  │  ╲
  ╱   │ ╱ ╲ │   ╲
 ╱    │╱   ╲│    ╲
└─────┘     └─────┘
EOF
            ;;
        1)
            cat << 'EOF'
   ╱│╲     ╱│╲
  ╱ │ ╲   ╱ │ ╲
 ╱  │  ╲ ╱  │  ╲
╱   │   ╳   │   ╲
│   │  ╱ ╲  │   │
└───┘─╱   ╲─└───┘
EOF
            ;;
        2)
            cat << 'EOF'
 ╱│╲       ╱│╲
╱ │ ╲     ╱ │ ╲
│ │  ╲   ╱  │ │
│ │   ╲ ╱   │ │
│ │    ╳    │ │
└─┘─╱─╱ ╲─╲─└─┘
EOF
            ;;
    esac
    printf "${colors[RESET]}"
}

# 背景エフェクト
draw_background() {
    local offset=$1
    local frame=$2
    printf "%${offset}s${colors[YELLOW]}" ""
    
    case $((frame % 4)) in
        0) printf "✦ ･ﾟ: *✦ ･ﾟ:* 極道の世界 *: ･ﾟ✦*: ･ﾟ✦\n" ;;
        1) printf "✧ ･ﾟ: *✧ ･ﾟ:* 極道の世界 *: ･ﾟ✧*: ･ﾟ✧\n" ;;
        2) printf "✨ ･ﾟ: *✨ ･ﾟ:* 極道の世界 *: ･ﾟ✨*: ･ﾟ✨\n" ;;
        3) printf "⭐ ･ﾟ: *⭐ ･ﾟ:* 極道の世界 *: ･ﾟ⭐*: ･ﾟ⭐\n" ;;
    esac
    printf "${colors[RESET]}"
}

# メッセージ表示
show_message() {
    local offset=$1
    local frame=$2
    printf "%${offset}s" ""
    
    local messages=(
        "${colors[RED]}「義理と人情の世界...」${colors[RESET]}"
        "${colors[CYAN]}「男の道を歩むぜ...」${colors[RESET]}"
        "${colors[PURPLE]}「おめぇ、覚悟はできてるか？」${colors[RESET]}"
        "${colors[ORANGE]}「この世界に足を踏み入れたな...」${colors[RESET]}"
    )
    
    local msg_index=$((frame / 3 % ${#messages[@]}))
    printf "%s\n" "${messages[$msg_index]}"
}

# アニメーション実行
animate_yakuza() {
    local frame=0
    local offset=5
    
    hide_cursor
    
    while [[ $ANIMATION_CYCLES -lt $MAX_CYCLES ]] || [[ $MAX_CYCLES -eq 0 ]]; do
        clear_screen
        
        # 背景とタイトル
        printf "\n"
        draw_background $offset $frame
        printf "\n"
        
        # キャラクター描画
