#!/bin/bash
weather=("晴れ" "雨" "曇り" "雪")
echo "今日の天気モード: ${weather[$RANDOM % ${#weather[@]}]}"
