service mysql start
mysql --defaults-extra-file=/etc/mysql/my.cnf -u root -e "drop database if exists dbname;"
mysql --defaults-extra-file=/etc/mysql/my.cnf -u root -e "create database dbname;"
mysql --defaults-extra-file=/etc/mysql/my.cnf -u root dbname < file.sql


#!/bin/bash

# MySQL接続情報
MYSQL_USER="root"
MYSQL_CONFIG_FILE="/etc/mysql/my.cnf"
DATABASE_NAME="dbname"
SQL_FILE="file.sql"

# MySQLサービスの起動
service mysql start

# MySQLに接続してデータベースを削除
echo "Dropping database ${DATABASE_NAME}..."
mysql --defaults-extra-file="${MYSQL_CONFIG_FILE}" -u "${MYSQL_USER}" -e "DROP DATABASE IF EXISTS ${DATABASE_NAME};"
if [ $? -ne 0 ]; then
    echo "Failed to drop database ${DATABASE_NAME}. Aborting."
    exit 1
fi

# 新しいデータベースを作成
echo "Creating database ${DATABASE_NAME}..."
mysql --defaults-extra-file="${MYSQL_CONFIG_FILE}" -u "${MYSQL_USER}" -e "CREATE DATABASE ${DATABASE_NAME};"
if [ $? -ne 0 ]; then
    echo "Failed to create database ${DATABASE_NAME}. Aborting."
    exit 1
fi

# SQLファイルの存在を確認
if [ ! -f "${SQL_FILE}" ]; then
    echo "Error: SQL file ${SQL_FILE} not found. Aborting."
    exit 1
fi

# SQLファイルをインポート
echo "Importing data from ${SQL_FILE} to database ${DATABASE_NAME}..."
mysql --defaults-extra-file="${MYSQL_CONFIG_FILE}" -u "${MYSQL_USER}" "${DATABASE_NAME}" < "${SQL_FILE}"
if [ $? -ne 0 ]; then
    echo "Failed to import data from ${SQL_FILE} to database ${DATABASE_NAME}. Aborting."
    exit 1
fi

echo "Database setup completed successfully."
exit 0
