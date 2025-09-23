#!/bin/bash


GREEN='\033[0;32m'
BROWN='\033[0;33m'
RED='\033[0;31m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# 門松のアスキーアート
echo -e "${GREEN}"
cat << "EOF"
⠀　　　_〆
　　 　 (∴:)
　　 （￣￣ ）
　＜(￣￣￣￣)＞
　[二▲二二▲二]
　　|▽　　▽|
　　|▲　　▲|
　　|＿ |⌒| ＿|
EOF
echo -e "${NC}"

# 新年の挨拶
echo -e "${RED}明けましておめでとうございます${NC}"
echo -e "${RED}謹んで新年のお慶びを申し上げます${NC}"

# 現在の年を取得して表示
YEAR=$(date +%Y)
# 令和の年号を計算 (2019年が令和元年)
REIWA=$((YEAR - 2018))

echo ""
echo -e "${WHITE}${YEAR}年（令和${REIWA}年）も宜しくお願いいたします${NC}"
