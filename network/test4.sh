#!/bin/bash
read -p "コンテンツを取得するURLを入力してください (例: https://www.example.com): " url
curl $url
