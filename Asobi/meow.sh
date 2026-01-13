#!/bin/bash
# ------------------------------------
# 🐾 にゃんこ翻訳スクリプト v2.0
# ------------------------------------

# カラー設定
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RESET='\033[0m'

# 猫語語尾のバリエーション
nyan_endings=("にゃん！" "にゃ〜" "だにゃ" "だにゃん" "なのにゃ" "みゃ〜" "にゃあ")

# 猫っぽい前置き
greetings=("にゃ？" "みゃ〜ん" "ごろごろ…" "にゃっ！" "すりすり〜")

# ランダム選択
greet="${greetings[$RANDOM % ${#greetings[@]}]}"
nyan="${nyan_endings[$RANDOM % ${#nyan_endings[@]}]}"

# 入力を取得
read -p "🐱 猫語に翻訳したい言葉を入力してください: " input

# 猫語変換（ちょっとしたアニメーション付き）
echo -e "\n${CYAN}$greet 翻訳中${RESET}"
for i in {1..3}; do
  echo -n "にゃ"
  sleep 0.4
done
echo -e "\n"

# 結果出力
echo -e "${YELLOW}🐾 翻訳結果: ${RESET}${input}${nyan}"
echo
