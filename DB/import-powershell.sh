#!/bin/bash

# MySQL接続情報
MYSQL_HOST="localhost"
MYSQL_USER="your_username"
MYSQL_PASSWORD="your_password"
MYSQL_DATABASE="your_database"
MYSQL_TABLE="your_table"

# CSVファイルのパス
CSV_FILE_PATH=""

# MySQLコマンドラインクライアントのパス
MYSQL_EXE="mysql"

# SQLクエリの作成
SQL_QUERY="LOAD DATA LOCAL INFILE '$CSV_FILE_PATH'
INTO TABLE $MYSQL_TABLE
FIELDS TERMINATED BY ','
ENCLOSED BY '\"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;"

# MySQLコマンドの実行
$MYSQL_EXE -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" --local-infile=1 -e "$SQL_QUERY"

# インポートされたレコード数の確認
COUNT_QUERY="SELECT COUNT(*) AS imported_records FROM $MYSQL_TABLE;"
RESULT=$($MYSQL_EXE -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" -e "$COUNT_QUERY" -s)

echo "インポートが完了しました。インポートされたレコード数: $RESULT"