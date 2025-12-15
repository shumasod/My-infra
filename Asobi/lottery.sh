#!/bin/bash

# ------------------------------------
# 🎰 宝くじシミュレーター v2.0
# ------------------------------------

# ANSIカラー定義
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
RESET='\033[0m'

draw_lottery() {
    echo -e "${CYAN}=============================="
    echo -e "        🎰 宝くじ抽選会 🎰"
    echo -e "==============================${RESET}"
    echo

    # エントリーナンバー生成
    your_number=$((RANDOM % 100))
    winning_number=$((RANDOM % 100))

    echo -e "あなたの番号を抽選中..."
    sleep 1
    echo -e "あなたの番号: ${YELLOW}$your_number${RESET}"

    echo -e "当たり番号を発表します..."
    sleep 1
    for i in {1..3}; do
        echo -n "."
        sleep 0.5
    done
    echo
    echo -e "当たり番号: ${GREEN}$winning_number${RESET}"
    echo

    # 結果判定
    if [ "$your_number" -eq "$winning_number" ]; then
        echo -e "${GREEN}🎉 おめでとうございます！ジャックポット！！ 🎉${RESET}"
    else
        diff=$((your_number - winning_number))
        [ "$diff" -lt 0 ] && diff=$(( -diff ))
        echo -e "${RED}残念！あと${diff}違いでした！${RESET}"
    fi
    echo
}

# メインループ
while true; do
    clear
    draw_lottery

    echo -e "${CYAN}もう一度挑戦しますか？ (y/n)${RESET}"
    read -r answer
    if [[ ! "$answer" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}また挑戦してね！👋${RESET}"
        break
    fi
done
