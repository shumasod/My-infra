#!/bin/bash

# 色の設定
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'    # No Color
CLEAR='\033[2J' # 画面クリア
RESET='\033[H'  # カーソルを先頭に

# お正月の飾りを描画
draw_decoration() {
    echo -e "${RED}    ❀ 迎春 ❀${NC}"
    echo "   ==========="
}

# 蛇を描画する関数
draw_snake() {
    echo -e "${GREEN}"
    cat << "EOF"
  ⠀　　＿＿
　　／・・＼
　　|_＿　　|
　　　／ 　 /
　　　￣|　/
　　 　 │ (_ノ|
　 　 　 ヽ＿ノ
EOF
    echo -e "${NC}"
    echo -e "     ${YELLOW}・${NC}  ${YELLOW}・${NC}"
    echo "      ╲⎺╱"
    echo "     ${GREEN}〜〜〜${NC}"
}

# メイン処理
clear  # 画面をクリア

# お正月の飾りと蛇を表示
draw_decoration
echo ""
draw_snake

# 新年の挨拶アニメーション
messages=(
    "2025年 巳年"
    "明けまして"
    "おめでとうございます"
    "本年も宜しく"
    "お願いいたします"
)

for message in "${messages[@]}"; do
    sleep 1
    echo -e "\n    ${GREEN}${message}${NC}"
done

echo -e "\n蛇「${YELLOW}今年は私の年です！${NC}」"