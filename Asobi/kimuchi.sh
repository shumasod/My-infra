#!/bin/bash

# kimchi.sh
# キムチ製造シミュレーター（疑似）

set -e

echo "🌶️ キムチ製造シェルスクリプト 🌶️"
echo "-------------------------------"

sleep 1
echo "🥬 白菜を収穫しています..."
sleep 1
echo "🧂 塩漬け中..."
sleep 1
echo "💧 水分を抜いています..."
sleep 1

echo ""
echo "🌶️ ヤンニョムを作成中..."
sleep 1
echo "  - 唐辛子"
sleep 0.5
echo "  - にんにく"
sleep 0.5
echo "  - 生姜"
sleep 0.5
echo "  - 魚醤"
sleep 0.5

echo ""
echo "🥣 白菜とヤンニョムを混ぜています..."
sleep 1

echo ""
echo "⏳ 発酵開始..."
for day in {1..7}; do
  sleep 1
  echo "  Day $day: 乳酸菌レベル ↑  酸味 +$day"
done

echo ""
echo "🥢 味見しています..."
sleep 1

echo ""
echo "🎉 キムチ完成！"
echo "辛さレベル: 🌶️🌶️🌶️"
echo "発酵度: 中"
echo "香り: 最強"
echo ""
echo "※このキムチはターミナル内でのみ存在します。"