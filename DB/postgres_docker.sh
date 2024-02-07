#!/bin/bash

# 環境変数の確認
if [ -z "$POSTGRES_VERSION" ]; then
  echo "環境変数 POSTGRES_VERSION が設定されていません。"
  exit 1
fi

if [ -z "$DATABASE_NAME" ]; then
  echo "環境変数 DATABASE_NAME が設定されていません。"
  exit 1
fi

if [ -z "$USERNAME" ]; then
  echo "環境変数 USERNAME が設定されていません。"
  exit 1
fi

if [ -z "$PASSWORD" ]; then
  echo "環境変数 PASSWORD が設定されていません。"
  exit 1
fi

if [ -z "$PORT" ]; then
  echo "環境変数 PORT が設定されていません。"
  exit 1
fi

# Dockerイメージのダウンロード
docker pull postgresql:${POSTGRES_VERSION}

# Dockerコンテナの作成
docker run -d --name postgresql \
  -p ${PORT}:5432 \
  -e POSTGRES_DB=${DATABASE_NAME} \
  -e POSTGRES_USER=${USERNAME} \
  -e POSTGRES_PASSWORD=${PASSWORD} \
  postgresql:${POSTGRES_VERSION}

# データベース接続の確認
echo "データベースに接続しています..."
docker exec -it postgresql psql -U ${USERNAME} -W -d ${DATABASE_NAME} -c "SELECT 1;"

echo "PostgreSQLデータベースが生成されました。"

echo "接続情報："
echo "ホスト名：localhost"
echo "ポート番号：${PORT}"
echo "データベース名：${DATABASE_NAME}"
echo "ユーザー名：${USERNAME}"
echo "パスワード：${PASSWORD}"
