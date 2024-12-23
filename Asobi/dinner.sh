#!/bin/bash

# ANSIカラーコードの定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# カテゴリー別のメニュー配列
declare -A menu_categories

menu_categories["和食"]=(
    "寿司 (1000円程度)"
    "天ぷら (800円程度)"
    "うどん (600円程度)"
    "そば (600円程度)"
    "親子丼 (800円程度)"
    "カツ丼 (900円程度)"
    "すき焼き (1500円程度)"
    "しゃぶしゃぶ (1500円程度)"
)

menu_categories["中華"]=(
    "ラーメン (800円程度)"
    "餃子セット (700円程度)"
    "麻婆豆腐定食 (800円程度)"
    "チャーハン (700円程度)"
    "八宝菜定食 (900円程度)"
    "担々麺 (900円程度)"
    "春巻き定食 (800円程度)"
    "酢豚定食 (900円程度)"
)

menu_categories["洋食"]=(
    "ハンバーグ定食 (900円程度)"
    "オムライス (800円程度)"
    "ナポリタン (700円程度)"
    "カルボナーラ (900円程度)"
    "ビーフシチュー (1000円程度)"
    "グラタン (800円程度)"
    "ピザ (1000円程度)"
    "エビフライ定食 (900円程度)"
)

menu_categories["その他"]=(
    "カレーライス (700円程度)"
    "焼肉定食 (1200円程度)"
    "タイ風グリーンカレー (900円程度)"
    "ビビンバ (900円程度)"
    "ケバブライス (800円程度)"
    "ガパオライス (900円程度)"
    "ナシゴレン (800円程度)"
    "タコライス (800円程度)"
)

# 予算の配列
budgets=(
    "〜500円"
    "501円〜800円"
    "801円〜1000円"
    "1001円〜1500円"
    "1501円〜"
)

# メイン関数
main() {
    clear
    echo -e "${BLUE}===== 今日の晩ごはんサジェスター =====${NC}\n"
    
    # 予算の確認
    echo -e "${GREEN}予算を教えてください：${NC}"
    select budget in "${budgets[@]}" "予算は気にしない"; do
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
    echo -e "6) 終了\n"
    
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
            echo -e "\n${YELLOW}またご利用ください！良い食事を！${NC}"
            exit 0 
            ;;
        *) 
            echo -e "\n${RED}無効な選択です。もう一度試してください。${NC}"
            sleep 2
            main 
            ;;
    esac
    
    # 選択されたカテゴリーからランダムにメニューを選択
    selected_array=("${menu_categories[$category][@]}")
    random_menu=${selected_array[$RANDOM % ${#selected_array[@]}]}
    
    # 結果を表示
    echo -e "\n${PURPLE}【提案メニュー】${NC}"
    echo -e "${YELLOW}ジャンル: $category${NC}"
    echo -e "${YELLOW}メニュー: $random_menu${NC}"
    if [ "$budget" != "予算は気にしない" ]; then
        echo -e "${YELLOW}予算: $budget${NC}"
    fi
    
    # メニューの評価オプション
    echo -e "\n${GREEN}このメニューはいかがですか？${NC}"
    echo "1) 良いね！これにする！"
    echo "2) 別のを見てみたい"
    echo "3) 気分が変わった"
    read -p "評価を選んでください (1-3): " rating
    
    case $rating in
        1) 
            echo -e "${GREEN}素敵な選択ですね！良い食事を！${NC}"
            sleep 2
            exit 0
            ;;
        2) 
            echo -e "${YELLOW}では、別のメニューを提案します！${NC}"
            sleep 2
            main
            ;;
        3) 
            echo -e "${RED}では、最初からやり直しましょう！${NC}"
            sleep 2
            main
            ;;
    esac
}

# スクリプトを開始
main
