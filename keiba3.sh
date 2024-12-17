#!/bin/bash

# 色の定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# タイトル画面のアスキーアート
show_title() {
    clear
    cat << "EOF"
    ______________________________
   /    競馬育成ゲーム v1.0     \
  /______________________________)
                 ||    
         ,%%,  ||
        ,%  %;'
       %;   %;'
        ;%;,;%;,
         `;;'`;
          ||  |
          || ||
          || ||
          || ||
        ,==' '==,
EOF
    echo -e "\n${YELLOW}素晴らしい競走馬を育てましょう！${NC}\n"
}

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

# 馬のアスキーアート表示
show_horse_ascii() {
    if ((horse_stats[happiness] >= 75)); then
        cat << "EOF"
          /{{\
         (  {{
        (   )
       ( )  ((
        /\  /\
       (  \/  )
        \    /
         \  /
          \/   Happy!
EOF
    elif ((horse_stats[happiness] >= 25)); then
        cat << "EOF"
          /{{\
         (  {{
        (   )
       ( )  ((
        /\  /\
       (  ..  )
        \    /
         \  /
          \/   Normal
EOF
    else
        cat << "EOF"
          /{{\
         (  {{
        (   )
       ( )  ((
        /\  /\
       (  ;;  )
        \    /
         \  /
          \/   Tired...
EOF
    fi
}

# ステータスバーの表示
show_status_bar() {
    local stat=$1
    local max=100
    local bar_length=20
    local filled=$((stat * bar_length / max))
    local empty=$((bar_length - filled))
    
    printf "["
    for ((i=0; i<filled; i++)); do printf "#"; done
    for ((i=0; i<empty; i++)); do printf "-"; done
    printf "] %d/100" "$stat"
}

# 馬の能力を表示
show_horse_stats() {
    echo -e "${YELLOW}${horse_name}のステータス (日数: $days)${NC}"
    show_horse_ascii
    echo "スピード:  $(show_status_bar ${horse_stats[speed]})"
    echo "スタミナ:  $(show_status_bar ${horse_stats[stamina]})"
    echo "パワー:    $(show_status_bar ${horse_stats[power]})"
    echo "体調:      $(show_status_bar ${horse_stats[health]})"
    echo "幸福度:    $(show_status_bar ${horse_stats[happiness]})"
    echo -e "${GREEN}所持金: $money 円${NC}"
}

# レース画面のアスキーアート
show_race_progress() {
    local position=$1
    local max_length=$2
    local horse_char="🐎"  # UTF-8対応の場合は馬の絵文字を使用
    
    printf "["
    for ((i=0; i<max_length; i++)); do
        if [ $i -eq $position ]; then
            printf "%s" "$horse_char"
        else
            printf "-"
        fi
    done
    printf "]"
}

# レースをシミュレートする関数
simulate_race() {
    if ((horse_stats[health] < 50)); then
        echo -e "${RED}馬の体調が悪いためレースに参加できません。${NC}"
        return
    }

    local race_fee=500
    if ((money < race_fee)); then
        echo -e "${RED}レース参加費用が足りません。${NC}"
        return
    }

    money=$((money - race_fee))
    
    clear
    cat << "EOF"
    🏁 レース開始！ 🏁
    ==================
         _______
       _/       \_
      / |       | \
     /  |__   __|  \
    |__/((o| |o))\__|
    |      | |      |
    |\     |_|     /|
    | \           / |
     \| /  ___  \ |/
      \ | / _ \ | /
       \_________/
EOF
    
    # レースのシミュレーション処理（既存のコードを使用）
    local horses=("${horse_name}" "ライバル1号" "ライバル2号" "ライバル3号")
    declare -A positions
    for horse in "${horses[@]}"; do
        positions[$horse]=0
    done
    
    local finish_line=20
    local winner=""
    while [ -z "$winner" ]; do
        clear
        echo "🏁 レース実況中 🏁"
        for horse in "${horses[@]}"; do
            local move=$((RANDOM % 3 + (horse == "${horse_name}" ? (horse_stats[speed] / 20) : 1)))
            positions[$horse]=$((positions[$horse] + move))
            printf "%-10s: " "$horse"
            show_race_progress ${positions[$horse]} $finish_line
            echo
            if [ ${positions[$horse]} -ge $finish_line ]; then
                winner=$horse
                break
            fi
        done
        sleep 0.5
    done
    
    echo -e "\n${YELLOW}レース終了！${NC}"
    echo "優勝: $winner"
    
    if [ "$winner" = "${horse_name}" ]; then
        local prize=$((1000 + (horse_stats[speed] + horse_stats[stamina] + horse_stats[power]) * 10))
        money=$((money + prize))
        echo -e "${GREEN}おめでとうございます！賞金${prize}円を獲得しました！${NC}"
    else
        echo -e "${RED}残念！次回がんばりましょう。${NC}"
    fi

    horse_stats[health]=$((horse_stats[health] - 20))
    horse_stats[happiness]=$((horse_stats[happiness] - 10))
    days=$((days + 1))
    
    read -p "Enterキーを押してください..."
    show_horse_stats
}

# その他の関数は既存のコードを使用（choose_horse_name, farm_activities, train_horse）

# メイン処理
main() {
    show_title
    choose_horse_name
    
    while true; do
        echo ""
        echo "================================"
        echo "1. 馬の状態を確認する"
        echo "2. 牧場で育成する"
        echo "3. トレーニングをする"
        echo "4. レースに参加する"
        echo "5. ゲームを終了する"
        echo "================================"
        read -p "選択してください (1-5): " choice

        case $choice in
            1) show_horse_stats ;;
            2) farm_activities ;;
            3) train_horse ;;
            4) simulate_race ;;
            5) 
                cat << "EOF"
                   Thank you for playing!
                      ,%%,
                     ,%  %;'
                    %;   %;'
                     ;%;,;%;,
                      `;;'`;
                       ||  |
                       || ||
                    ~~~~~~~~~~~
EOF
                echo -e "${GREEN}ゲームを終了します。お疲れ様でした！${NC}"
                break ;;
            *) echo -e "${RED}無効な選択です。${NC}" ;;
        esac
    done
}

# ゲームの開始
main