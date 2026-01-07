#!/bin/bash

# 色の定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# 馬のステータス
declare -A horse_stats
horse_name=""
horse_stats[speed]=50
horse_stats[stamina]=50
horse_stats[power]=50

# ランダムな数を生成する関数
get_random() {
    echo $((RANDOM % $1 + 1))
}

# 馬の名前を決める
choose_horse_name() {
    echo "あなたの馬の名前を決めてください："
    read horse_name
    echo "${GREEN}${horse_name}が生まれました！${NC}"
}

# 馬の能力を表示
show_horse_stats() {
    echo "${YELLOW}${horse_name}のステータス${NC}"
    echo "スピード: ${horse_stats[speed]}"
    echo "スタミナ: ${horse_stats[stamina]}"
    echo "パワー: ${horse_stats[power]}"
}

# 馬を育成する
train_horse() {
    echo "どの能力を鍛えますか？"
    echo "1. スピード"
    echo "2. スタミナ"
    echo "3. パワー"
    read -p "選択してください (1-3): " choice

    case $choice in
        1) horse_stats[speed]=$((horse_stats[speed] + $(get_random 5))) ;;
        2) horse_stats[stamina]=$((horse_stats[stamina] + $(get_random 5))) ;;
        3) horse_stats[power]=$((horse_stats[power] + $(get_random 5))) ;;
        *) echo "無効な選択です。" ; return ;;
    esac

    echo "${GREEN}トレーニングが完了しました！${NC}"
    show_horse_stats
}

# レースをシミュレートする関数
simulate_race() {
    clear
    echo "レースが始まります！"
    echo "---------------------"
    
    # 競争馬のリスト（プレイヤーの馬を含む）
    local horses=("${horse_name}" "ライバル1号" "ライバル2号" "ライバル3号")
    
    # 各馬の位置を初期化
    declare -A positions
    for horse in "${horses[@]}"; do
        positions[$horse]=0
    done
    
    # レースのシミュレーション
    local finish_line=50
    local winner=""
    while [ -z "$winner" ]; do
        for horse in "${horses[@]}"; do
            local move=$(($(get_random 3) + (horse == "${horse_name}" ? (horse_stats[speed] / 20) : 0)))
            positions[$horse]=$((positions[$horse] + move))
            printf "${horse}: "
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
    
    if [ "$winner" = "${horse_name}" ]; then
        echo "${GREEN}おめでとうございます！あなたの馬が勝ちました！${NC}"
    else
        echo "${RED}残念！あなたの馬は勝てませんでした。${NC}"
    fi
}

# メイン処理
main() {
    choose_horse_name
    
    while true; do
        echo ""
        echo "1. 馬の能力を確認する"
        echo "2. 馬を育成する"
        echo "3. レースに参加する"
        echo "4. ゲームを終了する"
        read -p "選択してください (1-4): " choice

        case $choice in
            1) show_horse_stats ;;
            2) train_horse ;;
            3) simulate_race ;;
            4) echo "ゲームを終了します。お疲れ様でした！" ; break ;;
            *) echo "無効な選択です。" ;;
        esac
    done
}

# ゲームの開始
main
