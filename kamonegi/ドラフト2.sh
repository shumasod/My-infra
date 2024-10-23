#!/bin/bash

# 鴨葱うどんを表示する関数
function show_kamonegi() {
  # 鴨葱うどんの画像を表示
  curl -s https://www.google.com/search?q=kamonegi+udon&tbm=isch | grep -Eo '<img.*>' | head -n 1 | awk '{print $1}' | sed 's/<img\s\+//' | xargs wget -q -O - | display

  echo "**********************************"
  echo "** 鴨葱うどん **"
  echo "**********************************"

  echo "  具材："
  echo "    - うどん"
  echo "    - 鴨肉"
  echo "    - 九条ネギ"
  echo "    - だし汁"

  echo "  作り方："
  echo "  1. 鍋にだし汁を入れて
  echo  
