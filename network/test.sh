#!/bin/bash
read -p "Ping疎通を確認するホスト名またはIPアドレスを入力してください: " host
ping -c 4 $host
