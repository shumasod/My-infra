#!/bin/bash

# makgeolli.sh
# マッコリを作った気になるシェルスクリプト（※飲めません）

set -e

echo "🍶 マッコリ醸造シミュレーター 🍶"
echo "------------------------------"

sleep 1
echo "🌾 米を洗っています..."
sleep 1
echo "💧 水を加えています..."
sleep 1
echo "🦠 麹（ヌルク）を投入..."
sleep 1

echo ""
echo "⏳ 発酵中..."
for day in {1..5}; do
  sleep 1
  echo "  Day $day: プクプク…アルコール度数 ↑"
done

echo ""
echo "🥣 かき混ぜています..."
sleep 1

echo ""
echo "🎉 マッコリ完成！"
echo "アルコール度数: 6%"
echo "味: やや甘口・微炭酸"
echo ""
echo "※このマッコリはシェル上でのみ有効です。飲めません。"