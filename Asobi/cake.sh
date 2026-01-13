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

# ケーキを描画
draw_cake() {
    clear
    echo ""
    echo -e "${YELLOW}     Happy Birthday!${NC}"
    echo ""
    echo -e "       ${WHITE}|${NC} ${WHITE}|${NC} ${WHITE}|${NC}"
    echo -e "       ${YELLOW}*${NC} ${YELLOW}*${NC} ${YELLOW}*${NC}"
    echo -e "${PINK}    ~~~~~~~~~~~~~~~~${NC}"
    echo -e "${PINK}  ~~~~~~~~~~~~~~~~~~${NC}"
    echo -e "${CYAN}  ====================${NC}"
    echo -e "${WHITE}  ####################${NC}"
    echo -e "${PINK}  ====================${NC}"
    echo -e "${WHITE}  ▽▽▽▽▽▽▽▽▽▽${NC}"
    echo -e "${CYAN}    =================${NC}"
    echo -e "${CYAN}      ==============${NC}"
    echo ""
}

# メイン処理
echo "🎂 バースデーケーキを作ります!"
sleep 1

# 材料を表示
materials=("小麦粉" "バター" "砂糖" "卵" "ベーキングパウダー" "バニラエッセンス" "生クリーム" "フルーツ")
echo -e "\n📝 必要な材料："
for item in "${materials[@]}"; do
    echo "・$item を準備中..."
    sleep 0.3
done

echo -e "\n🔥 オーブンを180℃に予熱します..."
sleep 1

echo "🥣 生地を混ぜています..."
sleep 1

echo "🎂 生地をケーキ型に流し込みます..."
sleep 1

echo -e "\n⏰ オーブンで焼いています..."
for i in {1..3}; do
    echo -n "."
    sleep 0.5
done
echo

echo "🧁 生クリームを塗っています..."
sleep 1

echo -e "🍓 デコレーションを施しています..."
sleep 1

# ケーキを表示
draw_cake

echo -e "\n${GREEN}🎉 ケーキが完成しました！${NC}"
echo "お好きなキーを押して終了..."
read -n 1

clear
exit 0
