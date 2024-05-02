#!/bin/bash

# MariaDB接続情報
DB_HOST="localhost"
DB_PORT="3306"
DB_USER="your_username"
DB_PASS="your_password"
DB_NAME="your_database"

# 欠損したSQLファイルのパス
SQL_FILE_PATH="/path/to/missing_file.sql"

# 新しいSQLファイルのパス
NEW_SQL_FILE_PATH="/path/to/new_file.sql"

# 新しいSQLファイルを作成する関数
create_new_sql_file() {
 echo "CREATE DATABASE $DB_NAME;" > "$NEW_SQL_FILE_PATH"
 # 他の必要なSQL文をここに追加することができます
}

# 欠損したSQLファイルが存在するかチェック
if [ ! -f "$SQL_FILE_PATH" ]; then
 echo "欠損したSQLファイルが見つかりません。新しいSQLファイルを作成します。"
 create_new_sql_file
else
 echo "SQLファイルが見つかりました。処理を中止します。"
fi

# 新しいSQLファイルを実行
if [ -f "$NEW_SQL_FILE_PATH" ]; then
 echo "新しいSQLファイルを実行します。"
 mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" < "$NEW_SQL_FILE_PATH"
 rm "$NEW_SQL_FILE_PATH" # 必要ならばファイルを削除
else
 echo "新しいSQLファイルが見つかりません。処理を中止します。"
fi
