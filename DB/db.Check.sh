#!/bin/bash

# データベース接続情報
DB_USER="-uroot"  # ユーザー名を適切に設定してください
DB_PASS="-proot"  # パスワードを適切に設定してください
DB_NAME="test_db" # データベース名を適切に設定してください
DB_HOST="localhost" # ホスト名を適切に設定してください

# データベース接続テスト
echo "SHOW DATABASES;" | mysql $DB_USER $DB_PASS -D $DB_NAME -h $DB_HOST

if [ $? -gt 0 ]; then
    echo "[ERROR]データベース参照不可。シェルスクリプトを強制終了する。"
    exit 1
else
    echo "データベース接続成功"
fi