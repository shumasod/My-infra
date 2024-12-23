#!/bin/bash
fortune=("大吉" "中吉" "小吉" "凶" "大凶")
echo "今日の運勢: ${fortune[$RANDOM % ${#fortune[@]}]}"
