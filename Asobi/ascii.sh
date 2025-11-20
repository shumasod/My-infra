#!/bin/bash

# ============================================================================
# 顔文字ジェネレーター - Kaomoji Generator
# Version: 1.2.0
# ============================================================================

# エラー処理の改善
set -euo pipefail
trap 'echo -e "\n${RED}エラーが発生しました。プログラムを終了します。${NC}"; exit 1' ERR

# バージョン情報
readonly VERSION="1.2.0"
readonly SCRIPT_NAME="$(basename "$0")"

# 定数定義
readonly CONFIG_DIR="$HOME/.config/kaomoji"
readonly CONFIG_FILE="$CONFIG_DIR/config.sh"
readonly CACHE_FILE="$CONFIG_DIR/cache"
readonly MAX_HISTORY=10

# ANSI カラーコードの定義
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# ============================================================================
# 初期化関数
# ============================================================================

# 設定ディレクトリの作成
init_config() {
    if [[ ! -d "$CONFIG_DIR" ]]; then
        mkdir -p "$CONFIG_DIR"
        echo -e "${GREEN}設定ディレクトリを作成しました: $CONFIG_DIR${NC}"
    fi
    
    # キャッシュファイルの初期化
    if [[ ! -f "$CACHE_FILE" ]]; then
        touch "$CACHE_FILE"
    fi
}

# 顔文字データの定義とキャッシュ
init_kaomoji() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo -e "${YELLOW}初回起動を検出しました。設定を作成しています...${NC}"
        
        declare -A kaomoji
        
        # 嬉しい
        kaomoji["happy"]="(* ^ ω ^)|(´ ∀ \` *)|⊂(・▽・⊂)|＼(≧▽≦)／|(/≧▽≦)/|٩(◕‿◕｡)۶|(｡♥‿♥｡)|ヽ(>∀<☆)ノ|(*´▽｀*)|ヾ(＠⌒ー⌒＠)ノ"
        
        # 悲しい
        kaomoji["sad"]="(´；ω；\`)|(╥﹏╥)|( ͒˃̩̩⌂˂̩̩ ͒)|(っ- ‸ - ς)|( ˃̣̣̥⌓˂̣̣̥)|(｡•́︿•̀｡)|(╯︵╰,)|(⌯˃̶᷄ ﹏ ˂̶᷄⌯)"
        
        # 驚き
        kaomoji["surprise"]="（＊〇□〇）……！|(((( ;°Д°))))|(○口○ )|┌(° ~~͜ʖ ͡°)┘|( ꒪Д꒪)ノ|Σ(°△°|||)|w(°ｏ°)w|(◉Д◉ )"
        
        # 恋愛
        kaomoji["love"]="(♡´▽\`♡)|( ´ ▽ \` ).。ｏ♡|(づ￣ ³￣)づ|(≧◡≦) ♡|(*♡∀♡)|(´♡‿♡\`)|♥(ˆ⌣ˆԅ)|(灬º‿º灬)♡"
        
        # 怒り
        kaomoji["angry"]="(╬ಠ益ಠ)|(\`ω´)|(≧σ≦)|ヽ(≧Д≦)ノ|(╯°□°）╯︵ ┻━┻|(ಠ_ಠ)|(￣ヘ￣)|ಠ╭╮ಠ"
        
        # かわいい
        kaomoji["cute"]="(◕‿◕)|ʕ•ᴥ•ʔ|(＾• ω •＾)|(ᵔᴥᵔ)|ฅ^•ﻌ•^ฅ|(=^･ω･^=)|U ´ᴥ\` U|ʕ ꈍᴥꈍʔ"
        
        # 設定をファイルに保存
        declare -p kaomoji > "$CONFIG_FILE"
        echo -e "${GREEN}設定ファイルを作成しました${NC}"
    fi
    
    # 設定を読み込み
    source "$CONFIG_FILE"
}

# ============================================================================
# UI関数
# ============================================================================

# メニュー表示
show_menu() {
    clear
    cat << EOF
${CYAN}╔════════════════════════════════════════╗
║    顔文字ジェネレーター v${VERSION}         ║
╚════════════════════════════════════════╝${NC}

${GREEN}今日の気分を教えてください：${NC}

  ${BLUE}1)${NC} 😊 嬉しい
  ${BLUE}2)${NC} 😢 悲しい
  ${BLUE}3)${NC} 😲 驚き
  ${BLUE}4)${NC} 💕 恋愛
  ${BLUE}5)${NC} 😠 怒り
  ${BLUE}6)${NC} 🐱 かわいい
  ${BLUE}7)${NC} 🎲 ランダム
  ${BLUE}8)${NC} 📜 履歴表示
  ${BLUE}9)${NC} ❌ 終了

EOF
}

# 履歴表示
show_history() {
    echo -e "\n${CYAN}=== 最近使用した顔文字 ===${NC}"
    if [[ -s "$CACHE_FILE" ]]; then
        nl -b a "$CACHE_FILE" | head -n "$MAX_HISTORY"
    else
        echo -e "${YELLOW}履歴がありません${NC}"
    fi
    echo
    read -p "Enterキーを押してメニューに戻る..."
}

# ============================================================================
# 処理関数
# ============================================================================

# 入力検証
validate_input() {
    local input=$1
    if [[ ! $input =~ ^[1-9]$ ]]; then
        echo -e "\n${RED}無効な選択です。1-9の数字を入力してください。${NC}"
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
        5) echo "angry" ;;
        6) echo "cute" ;;
        7) 
            local moods=("happy" "sad" "surprise" "love" "angry" "cute")
            echo "${moods[$RANDOM % ${#moods[@]}]}"
            ;;
        8) echo "history" ;;
        9) echo "exit" ;;
    esac
}

# ランダムな顔文字の選択（改善版）
get_random_kaomoji() {
    local mood=$1
    local IFS='|'
    read -ra emoji_array <<< "${kaomoji[$mood]}"
    local index=$((RANDOM % ${#emoji_array[@]}))
    echo "${emoji_array[$index]}"
}

# 顔文字をクリップボードにコピー
copy_to_clipboard() {
    local text=$1
    local copied=false
    
    # macOS
    if command -v pbcopy > /dev/null 2>&1; then
        echo -n "$text" | pbcopy
        copied=true
    # Linux (X11)
    elif command -v xclip > /dev/null 2>&1; then
        echo -n "$text" | xclip -selection clipboard
        copied=true
    # Linux (Wayland)
    elif command -v wl-copy > /dev/null 2>&1; then
        echo -n "$text" | wl-copy
        copied=true
    # Windows (WSL)
    elif command -v clip.exe > /dev/null 2>&1; then
        echo -n "$text" | clip.exe
        copied=true
    fi
    
    if [[ "$copied" == true ]]; then
        echo -e "${GREEN}✓ クリップボードにコピーしました！${NC}"
    else
        echo -e "${YELLOW}⚠ クリップボードツールが見つかりません${NC}"
        echo -e "${CYAN}手動でコピーしてください: $text${NC}"
    fi
}

# 履歴の保存（改善版）
save_to_history() {
    local kaomoji=$1
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # 重複チェック
    if ! grep -Fxq "$kaomoji" "$CACHE_FILE" 2>/dev/null; then
        echo "$kaomoji" >> "$CACHE_FILE"
        
        # 履歴のサイズ制限
        if [[ $(wc -l < "$CACHE_FILE") -gt $MAX_HISTORY ]]; then
            tail -n $MAX_HISTORY "$CACHE_FILE" > "${CACHE_FILE}.tmp"
            mv "${CACHE_FILE}.tmp" "$CACHE_FILE"
        fi
    fi
}

# ============================================================================
# ヘルプとバージョン
# ============================================================================

# ヘルプメッセージ
show_help() {
    cat << EOF
${CYAN}顔文字ジェネレーター${NC} - 気分に合わせた顔文字を生成

${YELLOW}使用方法:${NC}
  $SCRIPT_NAME [オプション]

${YELLOW}オプション:${NC}
  -h, --help      このヘルプメッセージを表示
  -v, --version   バージョン情報を表示
  -c, --clear     履歴をクリア
  -l, --list      利用可能な顔文字カテゴリを表示

${YELLOW}機能:${NC}
  • 6つのカテゴリから顔文字を選択
  • クリップボードへの自動コピー
  • 使用履歴の保存（最大${MAX_HISTORY}件）
  • マルチプラットフォーム対応

${YELLOW}設定ファイル:${NC}
  設定: $CONFIG_FILE
  履歴: $CACHE_FILE

${CYAN}作成者: Kaomoji Generator Team${NC}
EOF
}

# バージョン表示
show_version() {
    echo -e "${CYAN}顔文字ジェネレーター${NC} version ${GREEN}${VERSION}${NC}"
}

# カテゴリ一覧表示
show_categories() {
    echo -e "${CYAN}=== 利用可能なカテゴリ ===${NC}\n"
    for key in "${!kaomoji[@]}"; do
        echo -e "  ${GREEN}•${NC} $key"
        IFS='|' read -ra emojis <<< "${kaomoji[$key]}"
        echo -e "    例: ${emojis[0]} ${emojis[1]} ${emojis[2]}"
    done
}

# ============================================================================
# メイン処理
# ============================================================================

main() {
    # コマンドライン引数の処理
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                show_version
                exit 0
                ;;
            -c|--clear)
                > "$CACHE_FILE"
                echo -e "${GREEN}履歴をクリアしました${NC}"
                exit 0
                ;;
            -l|--list)
                init_config
                init_kaomoji
                show_categories
                exit 0
                ;;
            *)
                echo -e "${RED}不明なオプション: $1${NC}"
                echo "使用方法については '$SCRIPT_NAME --help' を参照してください"
                exit 1
                ;;
        esac
        shift
    done
    
    # 初期化
    init_config
    init_kaomoji
    
    # メインループ
    while true; do
        show_menu
        
        # プロンプト表示と入力受付
        printf "${PURPLE}選択してください (1-9): ${NC}"
        read -r choice
        
        # 入力検証
        if ! validate_input "$choice"; then
            sleep 1.5
            continue
        fi
        
        # 気分の選択
        mood=$(select_mood "$choice")
        
        # アクション実行
        case $mood in
            "exit")
                echo -e "\n${YELLOW}またね！(｡･ω･)ﾉﾞ${NC}"
                exit 0
                ;;
            "history")
                show_history
                ;;
            *)
                # 顔文字の生成と表示
                random_kaomoji=$(get_random_kaomoji "$mood")
                echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                echo -e "${YELLOW}あなたの顔文字:${NC} ${GREEN}${random_kaomoji}${NC}"
                echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                
                # クリップボードへのコピーと履歴保存
                copy_to_clipboard "$random_kaomoji"
                save_to_history "$random_kaomoji"
                
                # 続行確認
                echo -e "\n${GREEN}もう一度試しますか？ (y/n)${NC}"
                read -n 1 -r answer
                echo
                
                if [[ ! $answer =~ ^[Yy]$ ]]; then
                    echo -e "\n${YELLOW}またね！(｡･ω･)ﾉﾞ${NC}"
                    exit 0
                fi
                ;;
        esac
    done
}

# スクリプトの開始
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
