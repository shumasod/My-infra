#!/bin/bash

# 端末の色サポートを確認
if [ -t 1 ] && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    PURPLE='\033[0;35m'
    CYAN='\033[0;36m'
    NC='\033[0m'    # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    PURPLE=''
    CYAN=''
    NC=''
fi

# カテゴリー別のメニュー配列
declare -A menu_categories

menu_categories["和食"]=(
    "寿司:1000"
    "天ぷら:800"
    "うどん:600"
    "そば:600"
    "親子丼:800"
    "カツ丼:900"
    "すき焼き:1500"
    "しゃぶしゃぶ:1500"
    "牛丼:500"
    "唐揚げ定食:850"
    "焼き魚定食:900"
    "お好み焼き:750"
)

menu_categories["中華"]=(
    "ラーメン:800"
    "餃子セット:700"
    "麻婆豆腐定食:800"
    "チャーハン:700"
    "八宝菜定食:900"
    "担々麺:900"
    "春巻き定食:800"
    "酢豚定食:900"
    "回鍋肉定食:850"
    "天津飯:700"
    "中華丼:800"
    "エビチリ定食:950"
)

menu_categories["洋食"]=(
    "ハンバーグ定食:900"
    "オムライス:800"
    "ナポリタン:700"
    "カルボナーラ:900"
    "ビーフシチュー:1000"
    "グラタン:800"
    "ピザ:1000"
    "エビフライ定食:900"
    "ハヤシライス:850"
    "コロッケ定食:800"
    "ミートソーススパゲティ:750"
    "ドリア:850"
)

menu_categories["その他"]=(
    "カレーライス:700"
    "焼肉定食:1200"
    "タイ風グリーンカレー:900"
    "ビビンバ:900"
    "ケバブライス:800"
    "ガパオライス:900"
    "ナシゴレン:800"
    "タコライス:800"
    "フォー:850"
    "トムヤムクン:950"
    "タンドリーチキン:900"
    "サムゲタン:1100"
)

# ランダムなコメント配列
positive_comments=(
    "美味しそう！良い選択です！"
    "これは間違いない選択です！"
    "食欲をそそりますね！"
    "とても人気のある料理です！"
    "季節にぴったりの選択です！"
    "栄養バランスも良さそうですね！"
    "これで決まりですね！"
    "私も食べたくなりました！"
)

# 予算の配列と範囲
declare -A budget_ranges
budget_ranges["〜500円"]=500
budget_ranges["501円〜800円"]=800
budget_ranges["801円〜1000円"]=1000
budget_ranges["1001円〜1500円"]=1500
budget_ranges["1501円〜"]=9999

# 予算内のメニューをフィルタリングする関数
filter_by_budget() {
    local category="$1"
    local max_price="$2"
    local filtered_menu=()
    
    for item in "${menu_categories[$category][@]}"; do
        local name="${item%%:*}"
        local price="${item##*:}"
        
        if [ "$price" -le "$max_price" ]; then
            filtered_menu+=("$item")
        fi
    done
    
    # 予算内のメニューがない場合は空の配列を返す
    echo "${filtered_menu[@]}"
}

# メニュー表示関数
display_menu() {
    local item="$1"
    local name="${item%%:*}"
    local price="${item##*:}"
    
    echo -e "${YELLOW}[$name] ${CYAN}${price}円${NC}"
}

# ランダムコメント生成関数
get_random_comment() {
    local comments=("${positive_comments[@]}")
    echo "${comments[$RANDOM % ${#comments[@]}]}"
}

# 履歴記録関数
save_history() {
    local category="$1"
    local menu="$2"
    local price="$3"
    local date=$(date "+%Y-%m-%d %H:%M:%S")
    
    mkdir -p "$HOME/.dinner_history" 2>/dev/null
    echo "$date,$category,$menu,$price円" >> "$HOME/.dinner_history/history.csv"
}

# 履歴表示関数
show_history() {
    if [ -f "$HOME/.dinner_history/history.csv" ]; then
        echo -e "${BLUE}===== 最近の選択履歴 =====${NC}\n"
        echo -e "${CYAN}日時\t\t\tカテゴリー\tメニュー\t価格${NC}"
        
        # 最新の5件を表示
        tail -n 5 "$HOME/.dinner_history/history.csv" | while IFS=, read -r date category menu price; do
            echo -e "${date}\t${category}\t${menu}\t${price}"
        done
    else
        echo -e "${YELLOW}履歴はまだありません。${NC}"
    fi
    
    echo ""
    read -p "Enterキーを押して続行..." dummy
}

# メイン関数
main() {
    clear 2>/dev/null || printf "\033c"
    echo -e "${BLUE}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
    echo -e "${BLUE}┃       今日の晩ごはんサジェスター       ┃${NC}"
    echo -e "${BLUE}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}\n"
    
    # メインメニュー
    echo -e "${GREEN}何をしますか？${NC}"
    echo -e "1) 晩ごはんを提案してもらう"
    echo -e "2) 履歴を確認する"
    echo -e "3) 終了\n"
    
    read -p "選択してください (1-3): " main_choice
    
    case $main_choice in
        1) suggest_dinner ;;
        2) 
            show_history
            main
            ;;
        3) 
            echo -e "\n${YELLOW}またご利用ください！良い食事を！${NC}"
            exit 0 
            ;;
        *) 
            echo -e "\n${RED}無効な選択です。もう一度試してください。${NC}"
            sleep 1
            main 
            ;;
    esac
}

# 晩ごはん提案関数
suggest_dinner() {
    clear 2>/dev/null || printf "\033c"
    echo -e "${BLUE}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
    echo -e "${BLUE}┃       今日の晩ごはんサジェスター       ┃${NC}"
    echo -e "${BLUE}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}\n"
    
    # 予算の確認
    echo -e "${GREEN}予算を教えてください：${NC}"
    select budget in "〜500円" "501円〜800円" "801円〜1000円" "1001円〜1500円" "1501円〜" "予算は気にしない"; do
        if [ -n "$budget" ]; then
            break
        fi
        echo "正しい番号を選んでください"
    done
    
    # メニューカテゴリーの表示
    echo -e "\n${GREEN}食べたい料理のジャンルを選んでください：${NC}"
    echo "1) 和食"
    echo "2) 中華"
    echo "3) 洋食"
    echo "4) その他"
    echo "5) おまかせ"
    echo -e "6) 戻る\n"
    
    read -p "選択してください (1-6): " choice
    
    case $choice in
        1) category="和食" ;;
        2) category="中華" ;;
        3) category="洋食" ;;
        4) category="その他" ;;
        5) 
            categories=("和食" "中華" "洋食" "その他")
            category=${categories[$RANDOM % ${#categories[@]}]}
            ;;
        6) 
            main
            return
            ;;
        *) 
            echo -e "\n${RED}無効な選択です。もう一度試してください。${NC}"
            sleep 1
            suggest_dinner
            return
            ;;
    esac
    
    # 予算でフィルタリング
    if [ "$budget" != "予算は気にしない" ]; then
        max_price=${budget_ranges["$budget"]}
        filtered_menu=($(filter_by_budget "$category" "$max_price"))
        
        # 予算内のメニューがない場合
        if [ ${#filtered_menu[@]} -eq 0 ]; then
            echo -e "\n${RED}申し訳ありません。その予算内の${category}メニューがありません。${NC}"
            sleep 2
            suggest_dinner
            return
        fi
        
        # 選択されたカテゴリーと予算からランダムにメニューを選択
        random_item=${filtered_menu[$RANDOM % ${#filtered_menu[@]}]}
    else
        # 予算を気にしない場合は全メニューから選択
        selected_array=("${menu_categories[$category][@]}")
        random_item=${selected_array[$RANDOM % ${#selected_array[@]}]}
    fi
    
    # メニュー情報を分解
    menu_name="${random_item%%:*}"
    menu_price="${random_item##*:}"
    
    # 結果を表示
    clear 2>/dev/null || printf "\033c"
    echo -e "${BLUE}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
    echo -e "${BLUE}┃           あなたの晩ごはん           ┃${NC}"
    echo -e "${BLUE}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}\n"
    
    echo -e "${PURPLE}【提案メニュー】${NC}"
    echo -e "${YELLOW}ジャンル: $category${NC}"
    display_menu "$random_item"
    
    # ランダムコメントの表示
    echo -e "\n${GREEN}$(get_random_comment)${NC}\n"
    
    # メニューの評価オプション
    echo -e "${GREEN}このメニューはいかがですか？${NC}"
    echo "1) 良いね！これにする！"
    echo "2) 別のを見てみたい"
    echo "3) カテゴリーを変更する"
    echo "4) メインメニューに戻る"
    read -p "評価を選んでください (1-4): " rating
    
    case $rating in
        1) 
            # 履歴に保存
            save_history "$category" "$menu_name" "$menu_price"
            
            echo -e "\n${GREEN}素敵な選択ですね！良い食事を！${NC}"
            sleep 2
            exit 0
            ;;
        2) 
            echo -e "${YELLOW}では、別のメニューを提案します！${NC}"
            sleep 1
            # 同じカテゴリーで再提案
            suggest_dinner_same_category "$category" "$budget"
            ;;
        3) 
            echo -e "${YELLOW}カテゴリーを変更します。${NC}"
            sleep 1
            suggest_dinner
            ;;
        4)
            main
            ;;
    esac
}

# 同じカテゴリーで再提案
suggest_dinner_same_category() {
    local category="$1"
    local budget="$2"
    
    clear 2>/dev/null || printf "\033c"
    echo -e "${BLUE}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
    echo -e "${BLUE}┃       今日の晩ごはんサジェスター       ┃${NC}"
    echo -e "${BLUE}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}\n"
    
    # 予算でフィルタリング
    if [ "$budget" != "予算は気にしない" ]; then
        max_price=${budget_ranges["$budget"]}
        filtered_menu=($(filter_by_budget "$category" "$max_price"))
        
        # 予算内のメニューがない場合（これは通常起こらないはず）
        if [ ${#filtered_menu[@]} -eq 0 ]; then
            echo -e "\n${RED}申し訳ありません。その予算内の${category}メニューがありません。${NC}"
            sleep 2
            suggest_dinner
            return
        fi
        
        # 選択されたカテゴリーと予算からランダムにメニューを選択
        random_item=${filtered_menu[$RANDOM % ${#filtered_menu[@]}]}
    else
        # 予算を気にしない場合は全メニューから選択
        selected_array=("${menu_categories[$category][@]}")
        random_item=${selected_array[$RANDOM % ${#selected_array[@]}]}
    fi
    
    # メニュー情報を分解
    menu_name="${random_item%%:*}"
    menu_price="${random_item##*:}"
    
    # 結果を表示
    echo -e "${PURPLE}【新しい提案メニュー】${NC}"
    echo -e "${YELLOW}ジャンル: $category${NC}"
    display_menu "$random_item"
    
    # ランダムコメントの表示
    echo -e "\n${GREEN}$(get_random_comment)${NC}\n"
    
    # メニューの評価オプション
    echo -e "${GREEN}このメニューはいかがですか？${NC}"
    echo "1) 良いね！これにする！"
    echo "2) 別のを見てみたい"
    echo "3) カテゴリーを変更する"
    echo "4) メインメニューに戻る"
    read -p "評価を選んでください (1-4): " rating
    
    case $rating in
        1) 
            # 履歴に保存
            save_history "$category" "$menu_name" "$menu_price"
            
            echo -e "\n${GREEN}素敵な選択ですね！良い食事を！${NC}"
            sleep 2
            exit 0
            ;;
        2) 
            echo -e "${YELLOW}では、別のメニューを提案します！${NC}"
            sleep 1
            suggest_dinner_same_category "$category" "$budget"
            ;;
        3) 
            echo -e "${YELLOW}カテゴリーを変更します。${NC}"
            sleep 1
            suggest_dinner
            ;;
        4)
            main
            ;;
    esac
}

# スクリプトを開始
main