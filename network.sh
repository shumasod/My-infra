#!/bin/bash

# ネットワーク接続を確認するURL
URL="www.google.com"

# ネットワーク接続が切れているかどうかを確認
if ! ping -c 1 $URL &> /dev/null
then
    echo "ネットワーク接続が切れています。再接続を試みます。"
    # ここでネットワーク再接続のコマンドを実行します。
    # この部分は、使用しているネットワーク管理ツールによります。
else
    echo "ネットワーク接続が正常です。"
fi
