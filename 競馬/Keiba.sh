#!/bin/bash

# 馬のリスト
horses=("ムゲン号" "キラメキ号" "スピード号" "ダッシュ号" "パワー号")

# 色の定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# ランダムな数を生成する関数
get_random() {
    echo $((RANDOM % $1 + 1))
}

# レースをシミュレートする関数
simulate_race() {
    clear
    echo "レースが始まります！"
    echo "---------------------"
    
    # 各馬の位置を初期化
    declare -A positions
    for horse in "${horses[@]}"; do
        positions[$horse]=0
    done
    
    # レースのシミュレーション
    finish_line=50
    winner=""
    while [ -z "$winner" ]; do
        for horse in "${horses[@]}"; do
            positions[$horse]=$((positions[$horse] + $(get_random 3)))
            printf "${!horse}: "
            for ((i=0; i<${positions[$horse]}; i++)); do
                printf "="
            done
            printf ">\n"
            if [ ${positions[$horse]} -ge $finish_line ]; then
                winner=$horse
                break
            fi
        done
        echo "---------------------"
        sleep 0.2
        clear
    done
    
    echo "レース終了！"
    echo "優勝馬は ${winner} です！"
}

# メイン処理
main() {
    while true; do
        echo "競馬ゲームへようこそ！"
        echo "以下の馬から1頭選んでください："
        for i in "${!horses[@]}"; do
            echo "$((i+1)). ${horses[$i]}"
        done
        
        read -p "馬の番号を入力してください（1-5）: " choice
        if ! [[ "$choice" =~ ^[1-5]$ ]]; then
            echo "無効な選択です。1から5の数字を入力してください。"
            continue
        fi
        
        selected_horse=${horses[$((choice-1))]}
        echo "あなたは ${selected_horse} を選びました。"
        
        read -p "レースを開始しますか？ (y/n): " start_race
        if [ "$start_race" = "y" ]; then
            simulate_race
            if [ "$winner" = "$selected_horse" ]; then
                echo "${GREEN}おめでとうございます！あなたの馬が勝ちました！${NC}"
            else
                echo "${RED}残念！あなたの馬は勝てませんでした。${NC}"
            fi
        else
            echo "レースをキャンセルしました。"
        fi
        
        read -p "もう一度プレイしますか？ (y/n): " play_again
        if [ "$play_again" != "y" ]; then
            echo "ゲームを終了します。お疲れ様でした！"
            break
        fi
    done
}

# ゲームの開始
main
