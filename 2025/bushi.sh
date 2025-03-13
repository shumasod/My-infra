#!/bin/bash

# 端末の色サポートを確認
if [ -t 1 ] && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
    BLACK='\033[0;30m'
    RED='\033[0;31m'
    BLUE='\033[0;34m'
    GRAY='\033[1;30m'
    NC='\033[0m'    # No Color
else
    BLACK=''
    RED=''
    BLUE=''
    GRAY=''
    NC=''
fi

CLEAR='\033[2J'
RESET='\033[H'

# 侍の立ち姿 (修正版)
samurai_standing() {
    cat << "EOF"
        △ △
       (｀へ´)
     ξ ノ Ｙ ヽ
    ξ  | |   |
      ／\| |  ｜
     ｜  | |  ｜
    ／＼ | |  ｜
   ｜  ｜| |／｜
   ｜  ｜L/ ＼|
   ｜  ｜ \  ｜
   ｜  ｜  \ ｜
   し  し   ＼)
EOF
}

# 侍の抜刀姿 (修正版)
samurai_battle() {
    cat << "EOF"
      △ △    
     (｀_´)ノ
    ξ/⌒Y⌒\⚔
   ξ  | |   |
     ／\| |  ｜
    ｜  | |  ｜
   ／＼ | |  ｜
  ｜  ｜| |／｜
  ｜  ｜L/ ＼|
  ｜  ｜ \  ｜
  ｜  ｜  \ ｜
  し  し   ＼)
EOF
}

# 侍の切りかかる姿 (新規追加)
samurai_attack() {
    cat << "EOF"
       △ △    
      (｀皿´)   
     ξ/   \⚔≡≡≡
    ξ    |   |
      ／\  |  ｜
     ｜    |  ｜
    ／＼   |  ｜
   ｜  ｜ |／｜
   ｜  ｜L/ ＼|
   ｜  ｜ \  ｜
   ｜  ｜  \ ｜
   し  し   ＼)
EOF
}

# メッセージ表示関数
show_message() {
    echo -e "\n    ${1}"
}

# メイン処理
clear 2>/dev/null || printf "\033c"

echo -e "${BLUE}=============================${NC}"
echo -e "${BLUE}        侍、参上！        ${NC}"
echo -e "${BLUE}=============================${NC}"

# アニメーション
for i in {1..3}; do
    # 画面をクリア
    echo -e "${CLEAR}${RESET}"
    
    # 立ち姿
    echo -e "${GRAY}"
    samurai_standing
    echo -e "${NC}"
    show_message "見参！"
    sleep 0.7 2>/dev/null || sleep 0.1
    
    # 抜刀姿
    echo -e "${CLEAR}${RESET}"
    echo -e "${BLUE}"
    samurai_battle
    echo -e "${NC}"
    show_message "覚悟！"
    sleep 0.7 2>/dev/null || sleep 0.1
    
    # 切りかかる姿
    echo -e "${CLEAR}${RESET}"
    echo -e "${RED}"
    samurai_attack
    echo -e "${NC}"
    show_message "や〜！"
    sleep 0.7 2>/dev/null || sleep 0.1
done

echo -e "\n${BLUE}=============================${NC}"
echo -e "\n侍「拙者、${RED}弐千弐拾伍年${NC}の守護を仰せつかりました」"
echo -e "侍「${BLUE}貴殿のご多幸${NC}を祈っておる」"