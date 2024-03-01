#!/bin/bash

echo "** Laravel 10 環境構築を開始します **"

docker-compose build
docker-compose up -d

echo "** データベースの初期化 **"

docker exec -it app composer install
docker exec -it app php artisan key:generate
docker exec -it app php artisan migrate

echo "** Laravel 10 環境構築が完了しました **"

echo "** ブラウザで http://localhost:8080 を開いてください **"