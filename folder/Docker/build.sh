#!/bin/bash

# 色の定義
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}** Laravel 10 環境構築を開始します **${NC}"

# コンテナが既に起動しているか確認
if [ "$(docker ps -q -f name=app)" ]; then
    echo -e "${BLUE}既存のコンテナを停止しています...${NC}"
    docker-compose down
fi

# ビルドと起動
echo -e "${BLUE}Dockerコンテナをビルドしています...${NC}"
docker-compose build

echo -e "${BLUE}Dockerコンテナを起動しています...${NC}"
docker-compose up -d

# コンテナの起動確認
echo -e "${BLUE}コンテナの起動を確認しています...${NC}"
sleep 5

# appコンテナが起動しているか確認
if [ ! "$(docker ps -q -f name=app)" ]; then
    echo -e "\033[0;31mエラー: appコンテナが起動していません。docker-compose.ymlを確認してください。\033[0m"
    exit 1
fi

echo -e "${GREEN}** データベースの初期化 **${NC}"

# composer installの実行
echo -e "${BLUE}Composerパッケージをインストールしています...${NC}"
docker-compose exec -T app composer install

# .envファイルの存在確認
if [ ! -f .env ]; then
    echo -e "${BLUE}.envファイルが見つかりません。.env.exampleからコピーしています...${NC}"
    docker-compose exec -T app cp .env.example .env
fi

# APP_KEYの生成
echo -e "${BLUE}アプリケーションキーを生成しています...${NC}"
docker-compose exec -T app php artisan key:generate

# マイグレーションの実行
echo -e "${BLUE}データベースマイグレーションを実行しています...${NC}"
docker-compose exec -T app php artisan migrate --force

# キャッシュのクリア
echo -e "${BLUE}キャッシュをクリアしています...${NC}"
docker-compose exec -T app php artisan cache:clear
docker-compose exec -T app php artisan config:clear
docker-compose exec -T app php artisan route:clear
docker-compose exec -T app php artisan view:clear

echo -e "${GREEN}** Laravel 10 環境構築が完了しました **${NC}"

# ホストとポートの取得
DOCKER_HOST_IP=$(docker network inspect bridge -f '{{range .IPAM.Config}}{{.Gateway}}{{end}}')
PORT=$(grep -A 10 "ports" docker-compose.yml | grep -oP '(?<=- ")[^:]*(?=:)' | head -1)
if [ -z "$PORT" ]; then
    PORT=8080 # デフォルトポート
fi

echo -e "${GREEN}** ブラウザで http://localhost:${PORT} を開いてください **${NC}"
echo -e "${BLUE}または以下のコマンドでログを確認できます:${NC}"
echo -e "docker-compose logs -f app"