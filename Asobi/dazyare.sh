#!/bin/bash
echo "ランダムダジャレを生成します！"
jokes=("カレーは辛れー" "寿司を食べたらスシーンとした" "時計は時々止まる")
echo "${jokes[$RANDOM % ${#jokes[@]}]}"
