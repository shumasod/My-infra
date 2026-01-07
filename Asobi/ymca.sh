#!/usr/bin/env bash
# ymca.sh
# Terminal Dance: YMCA風のパフォーマンススクリプト
# -------------------------------------------
# 保存: chmod +x ymca.sh && ./ymca.sh
# -------------------------------------------

# ANSIカラー設定
RED="\033[31m"
YELLOW="\033[33m"
BLUE="\033[34m"
GREEN="\033[32m"
RESET="\033[0m"
BOLD="\033[1m"

# ビート間隔
BEAT=0.4

# カラフルなYMCAアニメーション
function dance(){
  clear
  echo -e "${BLUE}${BOLD}🕺 Y!${RESET}"
  sleep $BEAT
  clear
  echo -e "${YELLOW}${BOLD}🕺  M!${RESET}"
  sleep $BEAT
  clear
  echo -e "${GREEN}${BOLD}🕺   C!${RESET}"
  sleep $BEAT
  clear
  echo -
