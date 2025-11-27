#!/bin/bash
# 使用法: ./tcp_client.sh <ホスト名/IP> <ポート番号>
read -p "送信するメッセージを入力してください: " message
echo "$message" | nc $1 $2
echo "メッセージを $1:$2 に送信しました。"
