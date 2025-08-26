#!/bin/bash
read -p "HTTPヘッダを取得するURLを入力してください (例: https://www.google.com): " url
curl -I $url
