#!/bin/bash
menu=("カレー" "寿司" "ラーメン" "焼肉" "パスタ")
echo "今日の晩ごはんは... ${menu[$RANDOM % ${#menu[@]}]}！"
