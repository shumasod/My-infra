#!/bin/bash
read -p "確認するホスト名またはIPアドレスを入力してください: " host
read -p "確認するポート番号を入力してください: " port
nc -zvw3 $host $port
