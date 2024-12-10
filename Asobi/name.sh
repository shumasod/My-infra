#!/bin/bash
read -p "あなたの名前を入力してください: " name
result=$(( $(echo -n $name | od -An -tuC | tr -d ' ') % 5 ))
outcome=("超ラッキー！" "まあまあラッキー" "普通" "微妙..." "今日は静かに過ごそう")
echo "${name}さんの今日の運勢: ${outcome[$result]}"
