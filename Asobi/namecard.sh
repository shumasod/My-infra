#!/bin/bash
names=("たろう" "はなこ" "じろう" "さくら")
echo "今日の名前: ${names[$RANDOM % ${#names[@]}]}"
