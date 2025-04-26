#!/bin/bash
# 顔文字ルーレットスクリプトの変更履歴を分析するための手順

# ステップ1: 初期スクリプトの保存
cat > kaomoji_roulette_v1.sh << 'EOF'
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
EOF

chmod +x kaomoji_roulette_v1.sh

# ステップ2: 初期バックアップを作成
./diff_backup.sh . ./roulette_backup

# ステップ3: スクリプトの修正版（v2）の作成 - カテゴリの追加と設定ファイルのサポート
cat > kaomoji_roulette_v2.sh << 'EOF'
#!/bin/bash
# バージョン情報
VERSION="2.0.0"

# エラー処理の設定
set -euo pipefail
trap 'echo -e "\n${RED}エラーが発生しました${NC}"; exit 1' ERR

# 設定ファイルのパス
CONFIG_DIR="$HOME/.config/kaomoji_roulette"
CONFIG_FILE="$CONFIG_DIR/config.sh"
FAVORITES_FILE="$CONFIG_DIR/favorites.txt"

# ANSIカラーコードの定義
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly ORANGE='\033[0;33m'
readonly NC='\033[0m'

# 設定のデフォルト値
DEFAULT_DURATION=3
DEFAULT_INITIAL_INTERVAL=0.1
DEFAULT_SLOW_DOWN_RATE=0.02

# カテゴリ別顔文字の定義
declare -A KAOMOJI_CATEGORIES
KAOMOJI_CATEGORIES["happy"]=(
    "( ´ ▽ ` )ﾉ"
    "(｡◕‿◕｡)"
    "(・∀・)"
    "(*´∀｀*)"
    "ヽ(＾Д＾)ﾉ"
    "(●'◡'●)"
    "(◠‿◠)"
    "(✯◡✯)"
    "(≧∇≦)/"
)

KAOMOJI_CATEGORIES["love"]=(
    "(｡♥‿♥｡)"
    "(✿ ♥‿♥)"
    "ヽ(♡‿♡)ノ"
    "(◕‿◕✿)"
    "٩(◕‿◕｡)۶"
)

KAOMOJI_CATEGORIES["serious"]=(
    "(｀・ω・´)"
    "(´･ω･\`)"
    "ヽ(^o^)丿"
    "(｡･ω･｡)"
    "(〃￣ω￣〃)"
    "(๑•̀ㅂ•́)و✧"
    "(´｡• ω •｡\`)"
    "(◕ᴗ◕✿)"
    "＼(^o^)／"
    "(≧◡≦)"
)

# 設定ディレクトリの初期化
init_config() {
    if [[ ! -d "$CONFIG_DIR" ]]; then
        mkdir -p "$CONFIG_DIR"
    fi
    
    # 設定ファイルが存在しない場合は作成
    if [[ ! -f "$CONFIG_FILE" ]]; then
        cat > "$CONFIG_FILE" << EOL
# 顔文字ルーレット設定
DURATION=$DEFAULT_DURATION
INITIAL_INTERVAL=$DEFAULT_INITIAL_INTERVAL
SLOW_DOWN_RATE=$DEFAULT_SLOW_DOWN_RATE
LAST_CATEGORY="all"
EOL
    fi
    
    # お気に入りファイルの作成
    if [[ ! -f "$FAVORITES_FILE" ]]; then
        touch "$FAVORITES_FILE"
    fi
    
    # 設定の読み込み
    source "$CONFIG_FILE"
}

# ヘルプの表示
show_help() {
    cat << EOL
${CYAN}=== 顔文字ルーレット v${VERSION} ヘルプ ===${NC}

使用方法: $0 [オプション]

オプション:
  -h, --help     このヘルプメッセージを表示
  -v, --version  バージョン情報を表示
  -c CATEGORY    指定したカテゴリでルーレットを実行 (happy, love, serious, all, favorites)
  -d DURATION    ルーレットの実行時間を設定 (秒)
  -s             設定を表示
  -a "KAOMOJI"   カスタム顔文字をお気に入りに追加

例:
  $0 -c happy    幸せ系の顔文字でルーレットを実行
  $0 -d 5        5秒間ルーレットを回す
  $0 -a "( ^_^ )" カスタム顔文字をお気に入りに追加
EOL
}

# 利用可能なカテゴリの表示
show_categories() {
    echo -e "${CYAN}利用可能なカテゴリ:${NC}\n"
    echo -e "${GREEN}1) すべて${NC}"
    echo -e "${YELLOW}2) 幸せ系${NC}"
    echo -e "${RED}3) 恋愛系${NC}"
    echo -e "${BLUE}4) まじめ系${NC}"
    echo -e "${PURPLE}5) お気に入り${NC}"
    echo -e "${ORANGE}6) ランダムカテゴリ${NC}"
}

# 顔文字の取得（カテゴリ別）
get_kaomoji_by_category() {
    local category=$1
    local result=()
    
    case $category in
        "all")
            # すべてのカテゴリから顔文字を集める
            for cat in "${!KAOMOJI_CATEGORIES[@]}"; do
                result+=("${KAOMOJI_CATEGORIES[$cat][@]}")
            done
            ;;
        "favorites")
            # お気に入りから読み込み
            if [[ -s "$FAVORITES_FILE" ]]; then
                while IFS= read -r line; do
                    result+=("$line")
                done < "$FAVORITES_FILE"
            else
                echo -e "${YELLOW}お気に入りがありません。まずお気に入りを追加してください。${NC}"
                sleep 2
                return 1
            fi
            ;;
        *)
            # 特定のカテゴリ
            if [[ -v KAOMOJI_CATEGORIES[$category] ]]; then
                result=("${KAOMOJI_CATEGORIES[$category][@]}")
            else
                echo -e "${RED}無効なカテゴリです: $category${NC}"
                sleep 2
                return 1
            fi
            ;;
    esac
    
    # 結果が空でないことを確認
    if [[ ${#result[@]} -eq 0 ]]; then
        echo -e "${RED}選択したカテゴリに顔文字がありません。${NC}"
        sleep 2
        return 1
    fi
    
    # グローバル変数に結果を設定
    CURRENT_KAOMOJI=("${result[@]}")
    return 0
}

# 設定の保存
save_settings() {
    cat > "$CONFIG_FILE" << EOL
# 顔文字ルーレット設定
DURATION=$DURATION
INITIAL_INTERVAL=$INITIAL_INTERVAL
SLOW_DOWN_RATE=$SLOW_DOWN_RATE
LAST_CATEGORY="$CATEGORY"
EOL
}

# お気に入りに追加
add_to_favorites() {
    local kaomoji=$1
    
    # すでに存在するか確認
    if grep -q "^$kaomoji$" "$FAVORITES_FILE"; then
        echo -e "${YELLOW}この顔文字はすでにお気に入りに登録されています。${NC}"
        sleep 2
        return
    fi
    
    # お気に入りに追加
    echo "$kaomoji" >> "$FAVORITES_FILE"
    echo -e "${GREEN}顔文字をお気に入りに追加しました！${NC}"
    sleep 2
}

# ルーレットアニメーション用の関数（改良版）
roulette_animation() {
    local duration=${1:-$DURATION}
    local interval=${INITIAL_INTERVAL}
    local elapsed=0
    local index=0
    
    # カーソルを非表示
    tput civis
    
    # アニメーション
    while [ $(echo "$elapsed < $duration" | bc) -eq 1 ]; do
        clear
        echo -e "${CYAN}=== 顔文字ルーレット v${VERSION} ===${NC}\n"
        echo -e "${YELLOW}ルーレット回転中... カテゴリ: ${PURPLE}$CATEGORY${NC}\n"
        
        # 現在の顔文字を表示
        echo -e "${GREEN}${CURRENT_KAOMOJI[$index]}${NC}"
        
        # インデックスを更新
        index=$(( (index + 1) % ${#CURRENT_KAOMOJI[@]} ))
        
        sleep $interval
        elapsed=$(echo "$elapsed + $interval" | bc)
        
        # 回転速度を徐々に遅くする
        if [ $(echo "$elapsed > $duration / 2" | bc) -eq 1 ]; then
            interval=$(echo "$interval + $SLOW_DOWN_RATE" | bc)
        fi
    done
    
    # カーソルを表示
    tput cnorm
    
    # 最終的な顔文字をランダムに選択
    local final_index=$((RANDOM % ${#CURRENT_KAOMOJI[@]}))
    clear
    echo -e "${CYAN}=== 顔文字ルーレット v${VERSION} ===${NC}\n"
    echo -e "${GREEN}選ばれた顔文字:${NC}\n"
    echo -e "${YELLOW}${CURRENT_KAOMOJI[$final_index]}${NC}\n"
    
    # クリップボードにコピー（利用可能な場合）
    if command -v xclip > /dev/null; then
        echo -n "${CURRENT_KAOMOJI[$final_index]}" | xclip -selection clipboard
        echo -e "${PURPLE}顔文字をクリップボードにコピーしました！${NC}"
    elif command -v pbcopy > /dev/null; then
        echo -n "${CURRENT_KAOMOJI[$final_index]}" | pbcopy
        echo -e "${PURPLE}顔文字をクリップボードにコピーしました！${NC}"
    else
        echo -e "${YELLOW}クリップボードユーティリティが見つかりません。${NC}"
    fi
    
    # お気に入りに追加するオプション
    echo -e "\n${CYAN}この顔文字をお気に入りに追加しますか？ (y/n)${NC}"
    read -n 1 -r answer
    echo
    if [[ $answer =~ ^[Yy]$ ]]; then
        add_to_favorites "${CURRENT_KAOMOJI[$final_index]}"
    fi
}

# 設定メニュー
show_settings() {
    clear
    echo -e "${CYAN}=== 顔文字ルーレット 設定 ===${NC}\n"
    echo -e "1) アニメーション時間: ${GREEN}$DURATION秒${NC}"
    echo -e "2) 初期回転速度: ${GREEN}$INITIAL_INTERVAL秒${NC}"
    echo -e "3) 減速率: ${GREEN}$SLOW_DOWN_RATE${NC}"
    echo -e "4) デフォルト設定に戻す"
    echo -e "5) 戻る\n"
    
    read -p "設定を選択 (1-5): " setting_choice
    
    case $setting_choice in
        1)
            read -p "アニメーション時間を入力 (秒): " new_duration
            if [[ $new_duration =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                DURATION=$new_duration
                save_settings
                echo -e "${GREEN}設定を保存しました${NC}"
                sleep 1
            else
                echo -e "${RED}無効な値です${NC}"
                sleep 1
            fi
            show_settings
            ;;
        2)
            read -p "初期回転速度を入力 (秒): " new_interval
            if [[ $new_interval =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                INITIAL_INTERVAL=$new_interval
                save_settings
                echo -e "${GREEN}設定を保存しました${NC}"
                sleep 1
            else
                echo -e "${RED}無効な値です${NC}"
                sleep 1
            fi
            show_settings
            ;;
        3)
            read -p "減速率を入力: " new_rate
            if [[ $new_rate =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                SLOW_DOWN_RATE=$new_rate
                save_settings
                echo -e "${GREEN}設定を保存しました${NC}"
                sleep 1
            else
                echo -e "${RED}無効な値です${NC}"
                sleep 1
            fi
            show_settings
            ;;
        4)
            DURATION=$DEFAULT_DURATION
            INITIAL_INTERVAL=$DEFAULT_INITIAL_INTERVAL
            SLOW_DOWN_RATE=$DEFAULT_SLOW_DOWN_RATE
            save_settings
            echo -e "${GREEN}デフォルト設定に戻しました${NC}"
            sleep 1
            show_settings
            ;;
        5)
            return
            ;;
        *)
            echo -e "${RED}無効な選択です${NC}"
            sleep 1
            show_settings
            ;;
    esac
}

# カスタム顔文字の追加
add_custom_kaomoji() {
    read -p "追加する顔文字を入力: " custom
    if [[ -n "$custom" ]]; then
        add_to_favorites "$custom"
    else
        echo -e "${RED}顔文字が入力されていません${NC}"
        sleep 1
    fi
}

# メイン処理
main() {
    # 初期化
    init_config
    
    # コマンドライン引数の処理
    while getopts ":hvc:d:sa:" opt; do
        case ${opt} in
            h )
                show_help
                exit 0
                ;;
            v )
                echo -e "${CYAN}顔文字ルーレット v${VERSION}${NC}"
                exit 0
                ;;
            c )
                CATEGORY=$OPTARG
                get_kaomoji_by_category "$CATEGORY" || exit 1
                roulette_animation
                exit 0
                ;;
            d )
                if [[ $OPTARG =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                    DURATION=$OPTARG
                    save_settings
                else
                    echo -e "${RED}無効な時間です: $OPTARG${NC}"
                    exit 1
                fi
                ;;
            s )
                show_settings
                exit 0
                ;;
            a )
                add_to_favorites "$OPTARG"
                echo -e "${GREEN}顔文字「$OPTARG」をお気に入りに追加しました！${NC}"
                exit 0
                ;;
            \? )
                echo -e "${RED}無効なオプション: -$OPTARG${NC}" >&2
                show_help
                exit 1
                ;;
            : )
                echo -e "${RED}オプション -$OPTARG には引数が必要です${NC}" >&2
                show_help
                exit 1
                ;;
        esac
    done
    
    # メインメニューループ
    while true; do
        clear
        echo -e "${CYAN}=== 顔文字ルーレット v${VERSION} ===${NC}\n"
        echo -e "1) ルーレットを回す"
        echo -e "2) カテゴリを選択"
        echo -e "3) 設定"
        echo -e "4) カスタム顔文字を追加"
        echo -e "5) ヘルプ"
        echo -e "6) 終了\n"
        
        read -p "選択してください (1-6): " choice
        
        case $choice in
            1)
                # カテゴリが選択されていない場合はデフォルトを使用
                if [[ -z ${CATEGORY:-} || $CATEGORY == "random" ]]; then
                    CATEGORY="all"
                fi
                
                # 現在のカテゴリから顔文字を取得
                get_kaomoji_by_category "$CATEGORY" || continue
                
                # ルーレットを実行
                roulette_animation
                
                echo -e "\n${GREEN}もう一度回しますか？ (y/n)${NC}"
                read -n 1 -r answer
                echo
                if [[ ! $answer =~ ^[Yy]$ ]]; then
                    echo -e "\n${YELLOW}またね！(｡･ω･)ﾉﾞ${NC}"
                    exit 0
                fi
                ;;
            2)
                clear
                show_categories
                echo
                read -p "カテゴリを選択 (1-6): " cat_choice
                
                case $cat_choice in
                    1) CATEGORY="all" ;;
                    2) CATEGORY="happy" ;;
                    3) CATEGORY="love" ;;
                    4) CATEGORY="serious" ;;
                    5) CATEGORY="favorites" ;;
                    6) CATEGORY=$(printf "happy\nlove\nserious\nall" | shuf -n 1) ;;
                    *)
                        echo -e "${RED}無効な選択です${NC}"
                        sleep 1
                        continue
                        ;;
                esac
                
                save_settings
                echo -e "${GREEN}カテゴリを「$CATEGORY」に設定しました${NC}"
                sleep 1
                ;;
            3)
                show_settings
                ;;
            4)
                add_custom_kaomoji
                ;;
            5)
                clear
                show_help
                echo -e "\n${YELLOW}続けるには何かキーを押してください...${NC}"
                read -n 1
                ;;
            6)
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
main "$@"
EOF

chmod +x kaomoji_roulette_v2.sh

# ステップ4: 変更後のバックアップを作成
./diff_backup.sh . ./roulette_backup

# ステップ5: 差分の分析
# 以下のコマンドで差分を確認できます
# diff -u ./roulette_backup/latest/kaomoji_roulette_v1.sh ./roulette_backup/backup_*/kaomoji_roulette_v2.sh

# 変更点の要約
cat << EOF
===== 顔文字ルーレットスクリプト変更分析 =====

変更点の概要:
1. バージョン情報の追加 (v2.0.0)
2. 設定ファイルのサポート ($HOME/.config/kaomoji_roulette/config.sh)
3. カテゴリ機能の追加 (幸せ系、恋愛系、まじめ系)
4. お気に入り機能の追加
5. コマンドライン引数のサポート (-h, -v, -c, -d, -s, -a)
6. 設定メニューの追加 (アニメーション時間、回転速度、減速率の調整)
7. カスタム顔文字の追加機能
8. エラー処理の改善
9. 全体的なUI/UXの向上

主要な構造的変更:
- 単一の顔文字配列から連想配列（カテゴリ別）への変更
- 設定保存機能の追加
- モジュール化されたコード構造（各機能が独立した関数に）
- getoptsを使用したコマンドライン引数処理

追加された機能の詳細:
1. カテゴリシステム: 顔文字をカテゴリ別に整理
2. 設定システム: ユーザー設定の保存と読み込み
3. お気に入り機能: 顔文字をお気に入りとして保存
4. コマンドラインインターフェース: スクリプトを直接実行可能
5. カスタマイズオプション: アニメーションの速度と時間を調整可能

パフォーマンス改善:
1. 設定の永続化
2. カテゴリに基づいた効率的な顔文字の取得
3. 拡張性を考慮した設計

これらの変更点は、差分バックアップスクリプトによって効果的に追跡されます。
各変更のタイムスタンプと詳細な差分はバックアップディレクトリで確認できます。
EOF
