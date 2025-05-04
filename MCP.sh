#!/bin/bash

# MCPをASCIIアートで表示するシェルスクリプト

# 色の設定
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RESET='\033[0m'

# アニメーション効果の遅延（秒）
DELAY=0.05

# 画面をクリア
clear

# MCPのASCIIアート
echo ""
sleep $DELAY
echo -e "${RED}  ##     ##  ${GREEN} ######  ${BLUE} ########  ${RESET}"
sleep $DELAY
echo -e "${RED}  ###   ###  ${GREEN} ##   ##  ${BLUE} ##     ##  ${RESET}"
sleep $DELAY
echo -e "${RED}  #### ####  ${GREEN} ##       ${BLUE} ##     ##  ${RESET}"
sleep $DELAY
echo -e "${RED}  ## ### ##  ${GREEN} ##       ${BLUE} ########  ${RESET}"
sleep $DELAY
echo -e "${RED}  ##     ##  ${GREEN} ##       ${BLUE} ##        ${RESET}"
sleep $DELAY
echo -e "${RED}  ##     ##  ${GREEN} ##   ##  ${BLUE} ##        ${RESET}"
sleep $DELAY
echo -e "${RED}  ##     ##  ${GREEN} ######  ${BLUE} ##        ${RESET}"
sleep $DELAY
echo ""
sleep $DELAY
echo -e "${GREEN}Master Control Program${RESET}"
echo ""

# 実行方法の表示
echo "=========================================="
echo "This script displays MCP ASCII art"
echo "Created on: $(date)"
echo "=========================================="
