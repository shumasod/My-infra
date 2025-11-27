#!/bin/bash
read -p "接続を試行するホスト名またはIPアドレスを入力してください: " host
read -p "接続を試行するポート番号を入力してください: " port
echo "ポート $port に $host への接続を試行しています..."
for i in $(seq 1 10); do
  nc -zvw1 $host $port && { echo "接続に成功しました！"; break; } || { echo "試行 $i/10: 接続できませんでした。再試行します..."; sleep 2; }
done
