#!/bin/bash
echo "あなたの気分をオノマトペで表現！"
onomato=("ワクワク" "ドキドキ" "モグモグ" "ゴロゴロ" "パタパタ")
echo "今日の気分は: ${onomato[$RANDOM % ${#onomato[@]}]}"
