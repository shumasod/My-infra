#!/bin/bash
# ------------------------------------
# 🎴 今日の運勢おみくじ v2.0
# ------------------------------------

# カラー設定
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
MAGENTA='\033[1;35m'
RESET='\033[0m'

# 運勢リスト
fortunes=("大吉" "中吉" "小吉" "凶" "大凶")

# 運勢に応じたメッセージ
messages=(
    "🌸 最高の一日になりそう！全力で楽しんで！"
    "🌞 穏やかな幸せが訪れそうです。焦らずいきましょう。"
    "🍀 小さな幸せを見逃さないで。感謝の気持ちを忘れずに。"
    "☁️ 注意深く行動を。焦らず冷静に判断を。"
    "💀 静かに過ごすのが吉。無理せず、今日は休息日かも。"
)

# ランダム選択
index=$((RANDOM % ${#fortunes[@]}))
fortune="${fortunes[$index]}"
message="${messages[$index]}"

# アニメーション
echo -e "${BLUE}🔮 おみくじを引いています..."
for i in {1..3}; do
  echo -n "・"
  sleep 0.5
done
echo -e "\n${RESET}"

# 運勢表示
case "$fortune" in
  "大吉") color=$GREEN ;;
  "中吉") color=$YELLOW ;;
  "小吉") color=$MAGENTA ;;
  "凶") color=$RED ;;
  "大凶") color=$RED ;;
esac

echo -e "今日の運勢は…… ${color}${fortune}${RESET} ✨"
echo -e "${message}"
echo
