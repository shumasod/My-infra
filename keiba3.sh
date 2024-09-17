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
horse_stats[health]=100
horse_stats[happiness]=50

# 日数とお金の管理
days=1
money=1000

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
    echo "${YELLOW}${horse_name}のステータス (日数: $days)${NC}"
    echo "スピード: ${horse_stats[speed]}"
    echo "スタミナ: ${horse_stats[stamina]}"
    echo "パワー: ${horse_stats[power]}"
    echo "体調: ${horse_stats[health]}"
    echo "幸福度: ${horse_stats[happiness]}"
    echo "所持金: $money 円"
}

# 牧場での育成
farm_activities() {
    while true; do
        echo ""
        echo "牧場での活動を選んでください："
        echo "1. 放牧 (体調+10, 幸福度+15, 100円)"
        echo "2. ブラッシング (体調+5, 幸福度+10, 50円)"
        echo "3. エサやり (スタミナ+3, 体調+5, 200円)"
        echo "4. 休養 (体調+20, 1日経過)"
        echo "5. 戻る"
        read -p "選択してください (1-5): " choice

        case $choice in
            1)
                if ((money >= 100)); then
                    horse_stats[health]=$((horse_stats[health] + 10))
                    horse_stats[happiness]=$((horse_stats[happiness] + 15))
                    money=$((money - 100))
                    echo "${GREEN}放牧を行いました。${horse_name}は楽しそうです。${NC}"
                else
                    echo "${RED}お金が足りません。${NC}"
                fi
                ;;
            2)
                if ((money >= 50)); then
                    horse_stats[health]=$((horse_stats[health] + 5))
                    horse_stats[happiness]=$((horse_stats[happiness] + 10))
                    money=$((money - 50))
                    echo "${GREEN}ブラッシングを行いました。${horse_name}はリラックスしています。${NC}"
                else
                    echo "${RED}お金が足りません。${NC}"
                fi
                ;;
            3)
                if ((money >= 200)); then
                    horse_stats[stamina]=$((horse_stats[stamina] + 3))
                    horse_stats[health]=$((horse_stats[health] + 5))
                    money=$((money - 200))
                    echo "${GREEN}エサやりを行いました。${horse_name}の体力が回復しました。${NC}"
                else
                    echo "${RED}お金が足りません。${NC}"
                fi
                ;;
            4)
                horse_stats[health]=$((horse_stats[health] + 20))
                days=$((days + 1))
                echo "${GREEN}${horse_name}は十分に休養しました。1日が経過しました。${NC}"
                ;;
            5) return ;;
            *) echo "${RED}無効な選択です。${NC}" ;;
        esac

        # ステータスの上限設定
        for stat in "${!horse_stats[@]}"; do
            if ((horse_stats[$stat] > 100)); then
                horse_stats[$stat]=100
            fi
        done

        show_horse_stats
    done
}

# 馬を育成する（トレーニング）
train_horse() {
    echo "どの能力を鍛えますか？"
    echo "1. スピード (200円)"
    echo "2. スタミナ (200円)"
    echo "3. パワー (200円)"
    echo "4. 戻る"
    read -p "選択してください (1-4): " choice

    if ((choice >= 1 && choice <= 3)); then
        if ((money >= 200)); then
            money=$((money - 200))
            local stat_increase=$(get_random 5)
            case $choice in
                1) horse_stats[speed]=$((horse_stats[speed] + stat_increase)) ;;
                2) horse_stats[stamina]=$((horse_stats[stamina] + stat_increase)) ;;
                3) horse_stats[power]=$((horse_stats[power] + stat_increase)) ;;
            esac
            horse_stats[health]=$((horse_stats[health] - 10))
            horse_stats[happiness]=$((horse_stats[happiness] - 5))
            days=$((days + 1))
            echo "${GREEN}トレーニングが完了しました！能力が${stat_increase}ポイント上昇しました。${NC}"
        else
            echo "${RED}お金が足りません。${NC}"
        fi
    elif ((choice == 4)); then
        return
    else
        echo "${RED}無効な選択です。${NC}"
    fi

    # ステータスの上限と下限の設定
    for stat in "${!horse_stats[@]}"; do
        if ((horse_stats[$stat] > 100)); then
            horse_stats[$stat]=100
        elif ((horse_stats[$stat] < 0)); then
            horse_stats[$stat]=0
        fi
    done

    show_horse_stats
}

# レースをシミュレートする関数
simulate_race() {
    if ((horse_stats[health] < 50)); then
        echo "${RED}馬の体調が悪いためレースに参加できません。${NC}"
        return
    fi

    local race_fee=500
    if ((money < race_fee)); then
        echo "${RED}レース参加費用が足りません。${NC}"
        return
    fi

    money=$((money - race_fee))
    
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
        local prize=$((1000 + (horse_stats[speed] + horse_stats[stamina] + horse_stats[power]) * 10))
        money=$((money + prize))
        echo "${GREEN}おめでとうございます！あなたの馬が勝ちました！賞金${prize}円を獲得しました。${NC}"
    else
        echo "${RED}残念！あなたの馬は勝てませんでした。${NC}"
    fi

    horse_stats[health]=$((horse_stats[health] - 20))
    horse_stats[happiness]=$((horse_stats[happiness] - 10))
    days=$((days + 1))
    
    show_horse_stats
}

# メイン処理
main() {
    choose_horse_name
    
    while true; do
        echo ""
        echo "1. 馬の能力を確認する"
        echo "2. 牧場で育成する"
        echo "3. トレーニングをする"
        echo "4. レースに参加する"
        echo "5. ゲームを終了する"
        read -p "選択してください (1-5): " choice

        case $choice in
            1) show_horse_stats ;;
            2) farm_activities ;;
            3) train_horse ;;
            4) simulate_race ;;
            5) echo "ゲームを終了します。お疲れ様でした！" ; break ;;
            *) echo "${RED}無効な選択です。${NC}" ;;
        esac
    done
}

# ゲームの開始
main
