
#!/bin/bash

# カラーコード
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
RESET='\033[0m'

# ターミナルをクリア
clear

# 名前を入力してもらう
echo -e "${CYAN}name:${RESET}"
read name

if [ -z "$name" ]; then
    name="あなた"
fi

# カウントダウンアニメーション
echo -e "\n${YELLOW}お誕生日のお祝いを準備中...${RESET}"
for i in {5..1}; do
    echo -ne "${MAGENTA}$i...${RESET}"
    sleep 1
done

# ターミナルをクリア
clear

# 誕生日メッセージを表示
echo -e "\n\n"
echo -e "${RED}★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★${RESET}"
echo -e "${YELLOW}★                                            ★${RESET}"
echo -e "${GREEN}★        お  誕  生  日  お  め  で  と  う    ★${RESET}"
echo -e "${CYAN}★                                            ★${RESET}"
echo -e "${BLUE}★             ${name}さん！             ★${RESET}"
echo -e "${MAGENTA}★                                            ★${RESET}"
echo -e "${RED}★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★${RESET}"
echo -e "\n\n"

# バースデーケーキの改良アスキーアート
echo -e "${YELLOW}     |v|v|v|v|v|v|v|v|v|v|v|v|     ${RESET}"
echo -e "${YELLOW}     '\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"'     ${RESET}"
echo -e "${YELLOW}      {                     }      ${RESET}"
echo -e "${RED}      {         TO          }      ${RESET}"
echo -e "${YELLOW}      {                     }      ${RESET}"
echo -e "${YELLOW}  <<<${CYAN}<<<<<<<<<<<<<<<<<<<<<<<<${YELLOW}>>>  ${RESET}"
echo -e "${YELLOW}  {{                           }}  ${RESET}"
echo -e "${YELLOW}  {{       ${MAGENTA}${name}さん${YELLOW}        }}  ${RESET}"
echo -e "${YELLOW}  {{                           }}  ${RESET}"
echo -e "${YELLOW}  {{   ${GREEN}\|/\  /\|/\  /\|/\  /\|/${YELLOW}   }}  ${RESET}"
echo -e "${YELLOW}  |${CYAN}:                           ${YELLOW}:|  ${RESET}"
echo -e "${YELLOW}  |${CYAN}:                           ${YELLOW}:|  ${RESET}"
echo -e "${YELLOW}  |${CYAN}:   ${RED}H  A  P  P  Y${CYAN}           ${YELLOW}:|  ${RESET}"
echo -e "${YELLOW}  |${CYAN}:                           ${YELLOW}:|  ${RESET}"
echo -e "${YELLOW}  |${CYAN}:   ${GREEN}\|/\  /\|/\  /\|/\  /\|/${CYAN}   ${YELLOW}:|  ${RESET}"
echo -e "${YELLOW}  |${CYAN}:                           ${YELLOW}:|  ${RESET}"
echo -e "${YELLOW}  |${CYAN}O${RED}=O${GREEN}=O${BLUE}=O${MAGENTA}=O${CYAN}=O${YELLOW}=O${RED}=O${GREEN}=O${BLUE}=O${MAGENTA}=O${CYAN}=O${YELLOW}=O${RED}=O${GREEN}=O${BLUE}=O${MAGENTA}=O${YELLOW}:|  ${RESET}"
echo -e "${YELLOW}  |${CYAN}O${RED}=O${GREEN}=O${BLUE}=O${MAGENTA}=O${CYAN}=O${YELLOW}=O${RED}=O${GREEN}=O${BLUE}=O${MAGENTA}=O${CYAN}=O${YELLOW}=O${RED}=O${GREEN}=O${BLUE}=O${MAGENTA}=O${YELLOW}:|  ${RESET}"
echo -e "${YELLOW}  {{                           }}  ${RESET}"
echo -e "${YELLOW}  {{    ${RED}B I R T H D A Y${YELLOW}      }}  ${RESET}"
echo -e "${YELLOW}  {{                           }}  ${RESET}"
echo -e "${YELLOW}  \"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"  ${RESET}"

# 風船が浮かび上がるアニメーション
for i in {1..10}; do
    position=$((20 - i))
    clear_lines=$((20 - position))
    
    # 誕生日メッセージを再表示
    echo -e "\n\n"
    echo -e "${RED}★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★${RESET}"
    echo -e "${YELLOW}★                                            ★${RESET}"
    echo -e "${GREEN}★        お  誕  生  日  お  め  で  と  う    ★${RESET}"
    echo -e "${CYAN}★                                            ★${RESET}"
    echo -e "${BLUE}★             ${name}さん！             ★${RESET}"
    echo -e "${MAGENTA}★                                            ★${RESET}"
    echo -e "${RED}★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★${RESET}"
    echo -e "\n\n"
    
    # 改良したケーキを表示
    echo -e "${YELLOW}     |v|v|v|v|v|v|v|v|v|v|v|v|     ${RESET}"
    echo -e "${YELLOW}     '\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"'     ${RESET}"
    echo -e "${YELLOW}      {                     }      ${RESET}"
    echo -e "${RED}      {         TO          }      ${RESET}"
    echo -e "${YELLOW}      {                     }      ${RESET}"
    echo -e "${YELLOW}  <<<${CYAN}<<<<<<<<<<<<<<<<<<<<<<<<${YELLOW}>>>  ${RESET}"
    echo -e "${YELLOW}  {{                           }}  ${RESET}"
    echo -e "${YELLOW}  {{       ${MAGENTA}${name}さん${YELLOW}        }}  ${RESET}"
    echo -e "${YELLOW}  {{                           }}  ${RESET}"
    echo -e "${YELLOW}  {{   ${GREEN}\|/\  /\|/\  /\|/\  /\|/${YELLOW}   }}  ${RESET}"
    echo -e "${YELLOW}  |${CYAN}:                           ${YELLOW}:|  ${RESET}"
    echo -e "${YELLOW}  |${CYAN}:                           ${YELLOW}:|  ${RESET}"
    echo -e "${YELLOW}  |${CYAN}:   ${RED}H  A  P  P  Y${CYAN}           ${YELLOW}:|  ${RESET}"
    echo -e "${YELLOW}  |${CYAN}:                           ${YELLOW}:|  ${RESET}"
    echo -e "${YELLOW}  |${CYAN}:   ${GREEN}\|/\  /\|/\  /\|/\  /\|/${CYAN}   ${YELLOW}:|  ${RESET}"
    echo -e "${YELLOW}  |${CYAN}:                           ${YELLOW}:|  ${RESET}"
    echo -e "${YELLOW}  |${CYAN}O${RED}=O${GREEN}=O${BLUE}=O${MAGENTA}=O${CYAN}=O${YELLOW}=O${RED}=O${GREEN}=O${BLUE}=O${MAGENTA}=O${CYAN}=O${YELLOW}=O${RED}=O${GREEN}=O${BLUE}=O${MAGENTA}=O${YELLOW}:|  ${RESET}"
    echo -e "${YELLOW}  |${CYAN}O${RED}=O${GREEN}=O${BLUE}=O${MAGENTA}=O${CYAN}=O${YELLOW}=O${RED}=O${GREEN}=O${BLUE}=O${MAGENTA}=O${CYAN}=O${YELLOW}=O${RED}=O${GREEN}=O${BLUE}=O${MAGENTA}=O${YELLOW}:|  ${RESET}"
    echo -e "${YELLOW}  {{                           }}  ${RESET}"
    echo -e "${YELLOW}  {{    ${RED}B I R T H D A Y${YELLOW}      }}  ${RESET}"
    echo -e "${YELLOW}  {{                           }}  ${RESET}"
    echo -e "${YELLOW}  \"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"  ${RESET}"
    
    # 風船を表示（上昇するように位置を調整）
    for j in $(seq 1 $position); do
        echo ""
    done
    
    echo -e "${RED}   o   ${BLUE}   o   ${YELLOW}   o   ${GREEN}   o   ${RESET}"
    echo -e "${RED}  /|\\  ${BLUE}  /|\\  ${YELLOW}  /|\\  ${GREEN}  /|\\  ${RESET}"
    echo -e "${RED}   |   ${BLUE}   |   ${YELLOW}   |   ${GREEN}   |   ${RESET}"
    
    sleep 0.5
done

echo -e "\n${CYAN}素敵な一年になりますように！${RESET}\n"
