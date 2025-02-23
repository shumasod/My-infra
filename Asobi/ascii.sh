#!/bin/bash

# エラー処理の改善
set -euo pipefail
trap 'echo -e "\n${RED}エラーが発生しました。プログラムを終了します。${NC}"; exit 1' ERR

# 定数定義
readonly CONFIG_DIR="$HOME/.config/kaomoji"
readonly CONFIG_FILE="$CONFIG_DIR/config.sh"
readonly CACHE_FILE="$CONFIG_DIR/cache"

# ANSI カラーコードの定義
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# 設定ディレクトリの作成
init_config() {
    if [[ ! -d "$CONFIG_DIR" ]]; then
        mkdir -p "$CONFIG_DIR"
    fi
}

# 顔文字データの定義とキャッシュ
init_kaomoji() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
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
        
        # 設定をファイルに保存
        declare -p kaomoji > "$CONFIG_FILE"
    fi
    
    # 設定を読み込み
    source "$CONFIG_FILE"
}

# メニュー表示の最適化
show_menu() {
    clear
    cat << EOF
${BLUE}=== 顔文字ジェネレーター ===${NC}

${GREEN}今日の気分を教えてください：${NC}
1) 嬉しい
2) 悲しい
3) 驚き
4) 恋愛
5) ランダム
6) 終了

EOF
}

# 入力検証
validate_input() {
    local input=$1
    if [[ ! $input =~ ^[1-6]$ ]]; then
        echo -e "\n${RED}無効な選択です。1-6の数字を入力してください。${NC}"
        return 1
    fi
    return 0
}

# 気分の選択処理
select_mood() {
    local choice=$1
    case $choice in
        1) echo "happy" ;;
        2) echo "sad" ;;
        3) echo "surprise" ;;
        4) echo "love" ;;
        5) echo $(printf "happy\nsad\nsurprise\love" | shuf -n 1) ;;
        6) echo "exit" ;;
    esac
}

# ランダムな顔文字の選択
get_random_kaomoji() {
    local mood=$1
    local selected_array=("${kaomoji[$mood][@]}")
    echo "${selected_array[$RANDOM % ${#selected_array[@]}]}"
}

# 顔文字をクリップボードにコピー（利用可能な場合）
copy_to_clipboard() {
    local text=$1
    if command -v xclip > /dev/null; then
        echo -n "$text" | xclip -selection clipboard
        echo -e "${GREEN}顔文字をクリップボードにコピーしました！${NC}"
    elif command -v pbcopy > /dev/null; then
        echo -n "$text" | pbcopy
        echo -e "${GREEN}顔文字をクリップボードにコピーしました！${NC}"
    fi
}

# 最近使用した顔文字の保存
save_to_history() {
    local kaomoji=$1
    echo "$kaomoji" >> "$CACHE_FILE"
    tail -n 10 "$CACHE_FILE" > "$CACHE_FILE.tmp"
    mv "$CACHE_FILE.tmp" "$CACHE_FILE"
}

# メイン処理
main() {
    init_config
    init_kaomoji
    
    while true; do
        show_menu
        read -p "選択してください (1-6): " choice
        
        if ! validate_input "$choice"; then
            sleep 1
            continue
        fi
        
        mood=$(select_mood "$choice")
        
        if [[ $mood == "exit" ]]; then
            echo -e "\n${YELLOW}またね！(｡･ω･)ﾉﾞ${NC}"
            exit 0
        fi
        
        random_kaomoji=$(get_random_kaomoji "$mood")
        echo -e "\n${YELLOW}あなたの顔文字: $random_kaomoji${NC}"
        
        # クリップボードへのコピーと履歴の保存
        copy_to_clipboard "$random_kaomoji"
        save_to_history "$random_kaomoji"
        
        echo -e "\n${GREEN}もう一度試しますか？ (y/n)${NC}"
        read -n 1 -r answer
        echo
        
        if [[ ! $answer =~ ^[Yy]$ ]]; then
            echo -e "\n${YELLOW}またね！(｡･ω･)ﾉﾞ${NC}"
            exit 0
        fi
    done
}

# スクリプトを開始
main
