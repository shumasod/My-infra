#!/bin/bash

# ANSIカラーコードの定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# カテゴリー別のダジャレ配列
declare -A dajare_categories

dajare_categories["食べ物"]=(
    "カレーは辛れー"
    "寿司を食べたらスシーンとした"
    "おにぎりの具がむにぎりと出てきた"
    "天ぷらを見てテンプレート"
    "餃子を見てギョーザムライ"
)

dajare_categories["動物"]=(
    "カエルが帰る"
    "イカれたイカ"
    "トラブルになったトラ"
    "パンダが派手"
    "ネコがねっころがった"
)

dajare_categories["日常"]=(
    "時計は時々止まる"
    "傘を差すのがさすが"
    "布団が吹っ飛んだ"
    "進むのが親むけ"
    "電話に出んわ"
)

dajare_categories["季節"]=(
    "春が着るのは春着"
    "夏が来たのを夏っと見た"
    "秋の空を飽きのかない"
    "冬を踏んだ"
    "梅雨が愛むよう"
)

# メイン関数
main() {
    clear
    echo -e "${BLUE}===== ダジャレジェネレーター =====${NC}\n"
    
    # メニューの表示
    echo -e "${GREEN}カテゴリーを選んでください：${NC}"
    echo "1) 食べ物ダジャレ"
    echo "2) 動物ダジャレ"
    echo "3) 日常ダジャレ"
    echo "4) 季節ダジャレ"
    echo "5) 全てのカテゴリーからランダム"
    echo -e "6) 終了\n"
    
    read -p "選択してください (1-6): " choice
    
    case $choice in
        1) category="食べ物" ;;
        2) category="動物" ;;
        3) category="日常" ;;
        4) category="季節" ;;
        5) 
            categories=("食べ物" "動物" "日常" "季節")
            category=${categories[$RANDOM % ${#categories[@]}]}
            ;;
        6) 
            echo -e "\n${YELLOW}また来てね！ダジャレでまた会いましょう！${NC}"
            exit 0 
            ;;
        *) 
            echo -e "\n${RED}無効な選択です。もう一度試してください。${NC}"
            sleep 2
            main 
            ;;
    esac
    
    # 選択されたカテゴリーからランダムにダジャレを選択
    selected_array=("${dajare_categories[$category][@]}")
    random_dajare=${selected_array[$RANDOM % ${#selected_array[@]}]}
    
    # 結果を表示
    echo -e "\n${PURPLE}カテゴリー: $category${NC}"
    echo -e "${YELLOW}ダジャレ: $random_dajare${NC}"
    
    # ダジャレの評価オプション
    echo -e "\n${GREEN}このダジャレはどうでしたか？${NC}"
    echo "1) 面白い！"
    echo "2) まあまあ"
    echo "3) うーん..."
    read -p "評価を選んでください (1-3): " rating
    
    case $rating in
        1) echo -e "${GREEN}ありがとうございます！${NC}" ;;
        2) echo -e "${YELLOW}次はもっと面白いのが出るかも！${NC}" ;;
        3) echo -e "${RED}申し訳ありません...次は良いのが出るはず！${NC}" ;;
    esac
    
    # 続行するかどうかを確認
    echo -e "\n${GREEN}もう一度ダジャレを見ますか？ (y/n)${NC}"
    read -n 1 -r answer
    echo
    if [[ $answer =~ ^[Yy]$ ]]; then
        main
    else
        echo -e "\n${YELLOW}また来てね！ダジャレでまた会いましょう！${NC}"
        exit 0
    fi
}

# スクリプトを開始
main
