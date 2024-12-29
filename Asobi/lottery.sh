#!/bin/bash
echo "宝くじを引きます！"
your_number=$((RANDOM % 100))
winning_number=$((RANDOM % 100))
echo "あなたの番号: $your_number"
echo "当たり番号: $winning_number"
if [ "$your_number" -eq "$winning_number" ]; then
  echo "おめでとう！ジャックポット！"
else
  echo "残念、また挑戦してください！"
fi
