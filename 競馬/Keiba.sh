#!/bin/bash

#==============================================================================
# 競馬ゲームスクリプト（改善版）
# 説明: ユーザーが馬を選んでレースを観戦するゲーム
#==============================================================================

#------------------------------------------------------------------------------
# 定数定義
#------------------------------------------------------------------------------
declare -r FINISH_LINE=50
declare -r MAX_HORSES=5
declare -r MAX_SPEED=3
declare -r ANIMATION_DELAY=0.2

#------------------------------------------------------------------------------
# 色の定義
#------------------------------------------------------------------------------
declare -r RED='\033[0;31m'
declare -r GREEN='\033[0;32m'
declare -r YELLOW='\033[0;33m'
declare -r BLUE='\033[0;34m'
declare -r PURPLE='\033[0;35m'
declare -r CYAN='\033[0;36m'
declare -r NC='\033[0m'  # No Color

#------------------------------------------------------------------------------
# 馬のリストと色の対応
#------------------------------------------------------------------------------
declare -a horses=("ムゲン号" "キラメキ号" "スピード号" "ダッシュ号" "パワー号")
declare -a horse_colors=("${RED}" "${GREEN}" "${YELLOW}" "${BLUE}" "${PURPLE}")

#------------------------------------------------------------------------------
# グローバル変数
#------------------------------------------------------------------------------
declare -A horse_positions
declare winner=""

#------------------------------------------------------------------------------
# ユーティリティ関数
#------------------------------------------------------------------------------

# ランダムな数値を生成（1からN）
get_random() {
    local max=$1
    echo $((RANDOM % max + 1))
}

# 画面をクリアして見出しを表示
clear_and_show_header() {
    clear
    echo "=============================="
    echo "      競馬レースゲーム"
    echo "=============================="
    echo
}

# 区切り線を表示
show_separator() {
    echo "------------------------------"
}

# エラーメッセージを表示
show_error() {
    local message="$1"
    echo -e "${RED}エラー: ${message}${NC}" >&2
}

# 成功メッセージを表示
show_success() {
    local message="$1"
    echo -e "${GREEN}${message}${NC}"
}

# 警告メッセージを表示
show_warning() {
    local message="$1"
    echo -e "${YELLOW}${message}${NC}"
}

#------------------------------------------------------------------------------
# 入力検証関数
#------------------------------------------------------------------------------

# 馬の選択が有効かチェック
validate_horse_choice() {
    local choice="$1"
    if [[ "$choice" =~ ^[1-5]$ ]]; then
        return 0
    else
        return 1
    fi
}

# yes/no の入力が有効かチェック
validate_yes_no() {
    local input="$1"
    if [[ "$input" =~ ^[yYnN]$ ]]; then
        return 0
    else
        return 1
    fi
}

#------------------------------------------------------------------------------
# 表示関数
#------------------------------------------------------------------------------

# 馬の一覧を表示
show_horse_list() {
    echo "以下の馬から1頭選んでください："
    for i in "${!horses[@]}"; do
        local color="${horse_colors[$i]}"
        echo -e "$((i+1)). ${color}${horses[$i]}${NC}"
    done
    echo
}

# レースの進行状況を表示
show_race_progress() {
    clear_and_show_header
    echo "レース進行中..."
    show_separator
    
    for i in "${!horses[@]}"; do
        local horse="${horses[$i]}"
        local color="${horse_colors[$i]}"
        local position="${horse_positions[$horse]}"
        
        printf "${color}%-12s${NC}: " "$horse"
        
        # 進行バーを表示
        for ((j=0; j<position; j++)); do
            printf "="
        done
        printf ">\n"
        
        # ゴールラインを表示（最初の馬の時のみ）
        if [ $i -eq 0 ]; then
            printf "ゴール      : "
            for ((j=0; j<FINISH_LINE; j++)); do
                if [ $((j % 10)) -eq 0 ]; then
                    printf "|"
                else
                    printf " "
                fi
            done
            printf "|\n"
        fi
    done
    
    show_separator
}

# レース結果を表示
show_race_result() {
    echo
    echo "🏆 レース終了！ 🏆"
    echo "================="
    
    # 順位を計算して表示
    local -a sorted_horses=()
    local -a sorted_positions=()
    
    # 馬の位置でソート
    for horse in "${horses[@]}"; do
        sorted_horses+=("$horse")
        sorted_positions+=("${horse_positions[$horse]}")
    done
    
    # バブルソートで順位付け
    for ((i=0; i<${#sorted_horses[@]}; i++)); do
        for ((j=i+1; j<${#sorted_horses[@]}; j++)); do
            if [ "${sorted_positions[$i]}" -lt "${sorted_positions[$j]}" ]; then
                # 位置を交換
                local temp_pos="${sorted_positions[$i]}"
                sorted_positions[$i]="${sorted_positions[$j]}"
                sorted_positions[$j]="$temp_pos"
                
                # 馬を交換
                local temp_horse="${sorted_horses[$i]}"
                sorted_horses[$i]="${sorted_horses[$j]}"
                sorted_horses[$j]="$temp_horse"
            fi
        done
    done
    
    # 順位を表示
    for ((i=0; i<${#sorted_horses[@]}; i++)); do
        local rank=$((i+1))
        local horse="${sorted_horses[$i]}"
        local position="${sorted_positions[$i]}"
        
        if [ $rank -eq 1 ]; then
            echo -e "${GREEN}🥇 1位: ${horse} (${position}m)${NC}"
        elif [ $rank -eq 2 ]; then
            echo -e "${YELLOW}🥈 2位: ${horse} (${position}m)${NC}"
        elif [ $rank -eq 3 ]; then
            echo -e "${CYAN}🥉 3位: ${horse} (${position}m)${NC}"
        else
            echo -e "   ${rank}位: ${horse} (${position}m)"
        fi
    done
    
    echo
}

#------------------------------------------------------------------------------
# レース処理関数
#------------------------------------------------------------------------------

# 馬の位置を初期化
initialize_race() {
    winner=""
    for horse in "${horses[@]}"; do
        horse_positions[$horse]=0
    done
}

# レースを1ステップ進める
advance_race_step() {
    for horse in "${horses[@]}"; do
        local speed=$(get_random $MAX_SPEED)
        horse_positions[$horse]=$((horse_positions[$horse] + speed))
        
        # ゴールに到達したかチェック
        if [ ${horse_positions[$horse]} -ge $FINISH_LINE ] && [ -z "$winner" ]; then
            winner="$horse"
        fi
    done
}

# レースのシミュレーション
simulate_race() {
    initialize_race
    
    echo "レースが始まります！"
    echo "3..."
    sleep 1
    echo "2..."
    sleep 1
    echo "1..."
    sleep 1
    echo "スタート！"
    sleep 0.5
    
    # レースループ
    while [ -z "$winner" ]; do
        advance_race_step
        show_race_progress
        sleep $ANIMATION_DELAY
    done
    
    show_race_result
}

#------------------------------------------------------------------------------
# ユーザーインタラクション関数
#------------------------------------------------------------------------------

# 馬を選択
select_horse() {
    local choice
    local selected_horse
    
    while true; do
        show_horse_list
        read -p "馬の番号を入力してください（1-${MAX_HORSES}）: " choice
        
        if validate_horse_choice "$choice"; then
            selected_horse="${horses[$((choice-1))]}"
            local color="${horse_colors[$((choice-1))]}"
            echo -e "あなたは ${color}${selected_horse}${NC} を選びました。"
            echo "$selected_horse"
            return 0
        else
            show_error "無効な選択です。1から${MAX_HORSES}の数字を入力してください。"
            echo
        fi
    done
}

# レース開始の確認
confirm_race_start() {
    local input
    
    while true; do
        read -p "レースを開始しますか？ (y/n): " input
        
        if validate_yes_no "$input"; then
            if [[ "$input" =~ ^[yY]$ ]]; then
                return 0
            else
                return 1
            fi
        else
            show_error "y または n を入力してください。"
        fi
    done
}

# 再プレイの確認
confirm_replay() {
    local input
    
    while true; do
        read -p "もう一度プレイしますか？ (y/n): " input
        
        if validate_yes_no "$input"; then
            if [[ "$input" =~ ^[yY]$ ]]; then
                return 0
            else
                return 1
            fi
        else
            show_error "y または n を入力してください。"
        fi
    done
}

# ゲーム結果の表示
show_game_result() {
    local selected_horse="$1"
    
    echo
    if [ "$winner" = "$selected_horse" ]; then
        show_success "🎉 おめでとうございます！あなたの馬が勝ちました！ 🎉"
    else
        show_warning "😔 残念！あなたの馬は勝てませんでした。"
        echo -e "優勝馬は ${GREEN}${winner}${NC} でした。"
    fi
    echo
}

#------------------------------------------------------------------------------
# メイン処理
#------------------------------------------------------------------------------

# ゲームの初期化
initialize_game() {
    clear_and_show_header
    echo "競馬ゲームへようこそ！"
    echo "馬を選んでレースの行方を見守りましょう。"
    echo
}

# メインゲームループ
main() {
    initialize_game
    
    while true; do
        # 馬の選択
        local selected_horse
        selected_horse=$(select_horse)
        echo
        
        # レース開始の確認
        if confirm_race_start; then
            echo
            simulate_race
            show_game_result "$selected_horse"
        else
            show_warning "レースをキャンセルしました。"
            echo
        fi
        
        # 再プレイの確認
        if confirm_replay; then
            clear_and_show_header
            continue
        else
            show_success "ゲームを終了します。お疲れ様でした！"
            break
        fi
    done
}

#------------------------------------------------------------------------------
# エラーハンドリング
#------------------------------------------------------------------------------

# シグナルハンドラー
cleanup() {
    echo
    echo "ゲームが中断されました。"
    exit 0
}

# シグナルをトラップ
trap cleanup SIGINT SIGTERM

#------------------------------------------------------------------------------
# ゲーム開始
#------------------------------------------------------------------------------

# 実行権限のチェック
if [ ! -x "$0" ]; then
    show_error "スクリプトに実行権限がありません。"
    echo "chmod +x $0 を実行してください。"
    exit 1
fi

# メイン処理の実行
main
