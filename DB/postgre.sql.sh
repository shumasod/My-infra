#!/bin/bash

# PostgreSQLの接続情報
DB_USER="your_username"
DB_NAME="your_database_name"
DB_HOST="localhost"
DB_PORT="5432"

# バックアップファイルの保存場所とファイル名
BACKUP_DIR="/path/to/backup/directory"
BACKUP_FILE="$BACKUP_DIR/db_backup_$(date +%Y-%m-%d_%H-%M-%S).sql"

# pg_dumpを使用してデータベースをバックアップ
pg_dump -U $DB_USER -h $DB_HOST -p $DB_PORT $DB_NAME > $BACKUP_FILE

# ステータスの確認
if [ $? -eq 0 ]; then
  echo "データベースのバックアップが正常に完了しました。"
else
  echo "データベースのバックアップ中にエラーが発生しました。"
fi
