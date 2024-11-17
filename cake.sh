#!/bin/bash

# カラー定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PINK='\033[1;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# カーソルを特定の位置に移動
move_cursor() {
    echo -en "\033[${1};${2}H"
}

# キャンドルのアニメーション
draw_candle_flame() {
    local x=$1
    local y=$2
    while true; do
        move_cursor $y $x
        echo -en "${YELLOW}*${NC}"
        sleep 0.5
        move_cursor $y $x
        echo -en "${RED}*${NC}"
        sleep 0.5
    done
}

# ケーキを描画
draw_cake() {
    clear
    
    # Happy Birthday テキスト
    echo -e "\n\n${YELLOW}     Happy Birthday!${NC}\n"
    
    # キャンドル
    echo -e "       ${WHITE}|${NC} ${WHITE}|${NC} ${WHITE}|${NC}"
    
    # ケーキの上部
    echo -e "${PINK}    ~~~~~~~~~~~~~~~~${NC}"
    echo -e "${PINK}  ~~~~~~~~~~~~~~~~~~${NC}"
    
    # ケーキの層
    echo -e "${CYAN}  ====================${NC}"
    echo -e "${WHITE}  ####################${NC}"
    echo -e "${PINK}  ====================${NC}"
    
    # クリームの装飾
    echo -e "${WHITE}  ▽▽▽▽▽▽▽▽▽▽${NC}"
    
    # ケーキスタンド
    echo -e "${CYAN}    =================${NC}"
    echo -e "${CYAN}      ==============${NC}\n"
    
    # スプリンクルとフルーツ
    move_cursor 6 5; echo -e "${RED}○${NC}" # いちご
    move_cursor 6 8; echo -e "${BLUE}●${NC}" # ブルーベリー
    move_cursor 6 11; echo -e "${RED}○${NC}" # いちご
    move_cursor 7 7; echo -e "${CYAN}•${NC}" # スプリンクル
    move_cursor 7 10; echo -e "${PINK}•${NC}" # スプリンクル
    move_cursor 7 13; echo -e "${YELLOW}•${NC}" # スプリンクル
}

# メイン処理
echo "ケーキ作りを始めます..."
sleep 1

# 材料を表示
materials=("小麦粉" "バター" "砂糖" "卵" "ベーキングパウダー" "バニラエッセンス" "生クリーム" "フルーツ")
echo "必要な材料を確認します："
for item in "${materials[@]}"; do
    echo "・$item を準備中..."
    sleep 0.5
done

echo -e "\nオーブンを180℃に予熱します..."
sleep 2

echo "生地を混ぜています..."
sleep 2

echo "生地をケーキ型に流し込みます..."
sleep 2

echo "オーブンで焼いています..."
for i in {1..5}; do
    echo -n "."
    sleep 1
done
echo

echo "生クリームを塗っています..."
sleep 2

echo "デコレーションを施しています..."
sleep 2

# ケーキを表示
draw_cake

# キャンドルの炎をアニメーション表示（バックグラウンドで実行）
draw_candle_flame 8 4 &
draw_candle_flame 11 4 &
draw_candle_flame 14 4 &
flame_pid=$!

# メッセージを表示
echo -e "\n${GREEN}ケーキが完成しました！${NC}"
echo "エンターキーを押して終了..."

# キー入力待ち
read

# アニメーションを停止
kill $flame_pid 2>/dev/null
kill $(jobs -p) 2>/dev/null

clear
exit 0
