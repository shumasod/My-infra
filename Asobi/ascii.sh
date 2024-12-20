#!/bin/bash

# 顔文字の配列を感情カテゴリーごとに定義
declare -A kaomoji
kaomoji["happy"]=(
    "(* ^ ω ^)" 
    "(´ ∀ \` *)" 
    "⊂(・▽・⊂)" 
    "＼(≧▽≦)／" 
    "(/≧▽≦)/" 
    "٩(◕‿◕｡)۶"
    "(｡♥‿♥｡)"
    "ヽ(>∀<☆)ノ"
)

kaomoji["sad"]=(
    "(´；ω；\`)"
    "(╥﹏╥)"
    "( ͒˃̩̩⌂˂̩̩ ͒)"
    "(っ- ‸ - ς)"
    "( ˃̣̣̥⌓˂̣̣̥)"
)

kaomoji["surprise"]=(
    "（＊〇□〇）……！"
    "(((( ;°Д°))))"
    "(○口○ )"
    "┌(° ~~͜ʖ ͡°)┘"
    "( ꒪Д꒪)ノ"
)

kaomoji["love"]=(
    "(♡´▽\`♡)"
    "( ´ ▽ \` ).。ｏ♡"
    "(づ￣ ³￣)づ"
    "(≧◡≦) ♡"
    "(*♡∀♡)"
)

# ANSI カラーコードの定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# メイン関数
main() {
    clear
    echo -e "${BLUE}=== 顔文字ジェネレーター ===${NC}\n"
    
    # 気分を選択
    echo -e "${GREEN}今日の気分を教えてください：${NC}"
    echo "1) 嬉しい"
    echo "2) 悲しい"
    echo "3) 驚き"
    echo "4) 恋愛"
    echo "5) ランダム"
    echo -e "6) 終了\n"
    
    read -p "選択してください (1-6): " choice
    
    case $choice in
        1) mood="happy" ;;
        2) mood="sad" ;;
        3) mood="surprise" ;;
        4) mood="love" ;;
        5) mood=$(printf "happy\nsad\nsurprise\nlove" | shuf -n 1) ;;
        6) echo -e "\n${YELLOW}またね！(｡･ω･)ﾉﾞ${NC}" && exit 0 ;;
        *) echo -e "\n${RED}無効な選択です。もう一度試してください。${NC}" && sleep 2 && main ;;
    esac
    
    # 選択されたカテゴリーからランダムに顔文字を選択
    selected_array=("${kaomoji[$mood][@]}")
    random_kaomoji=${selected_array[$RANDOM % ${#selected_array[@]}]}
    
    # 結果を表示
    echo -e "\n${YELLOW}あなたの顔文字: $random_kaomoji${NC}"
    
    # 続行するかどうかを確認
    echo -e "\n${GREEN}もう一度試しますか？ (y/n)${NC}"
    read -n 1 -r answer
    echo
    if [[ $answer =~ ^[Yy]$ ]]; then
        main
    else
        echo -e "\n${YELLOW}またね！(｡･ω･)ﾉﾞ${NC}"
        exit 0
    fi
}

# スクリプトを開始
main
