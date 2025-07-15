#!/bin/bash
# 使用法: ./tcp_server.sh <ポート番号>
echo "TCPサーバーをポート $1 で開始します..."
while true; do
  nc -l -p $1
  echo "クライアントが接続しました。メッセージを受信しました。"
done
