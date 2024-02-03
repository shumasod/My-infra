#!/bin/bash

# アクセスログのファイル名
access_log="/var/log/apache2/access.log"

# 通知先のメールアドレス
mail_to="example@example.com"

# 通知するコード
error_codes="300,400,500"

# メイン処理
while true; do
  # アクセスログを読み込む
  for line in $(cat $access_log); do

  #アクセスログを表示する
  
    # コードを取得する
    code=$(echo $line | awk '{print $9}')
    # 通知対象のコードかチェックする
    if echo $error_codes | grep -q $code; then
      # 通知する
      echo "【エラー通知】" | mail -s "Apache 内のエラーが発生しました。" $mail_to
    fi
  done
  # 1 秒待つ
  sleep 1
done
