#!/bin/bash

# 色の設定
BLACK='\033[0;30m'
RED='\033[0;31m'
BLUE='\033[0;34m'
GRAY='\033[1;30m'
NC='\033[0m'
CLEAR='\033[2J'
RESET='\033[H'

# 侍の立ち姿
samurai_standing() {
    cat << "EOF"
        △
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

# 侍の抜刀姿
samurai_battle() {
    cat << "EOF"
        △    ⚔
     (｀_´)ノ
    ξ/⌒Y⌒\
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

# メイン処理
clear

echo -e "${BLUE}侍、参上！${NC}"

# アニメーション
for i in {1..3}; do
    echo -e "${RESET}"
    echo -e "${GRAY}"
    samurai_standing
    echo -e "${NC}"
    sleep 1
    
    echo -e "${RESET}"
    echo -e "${RED}"
    samurai_battle
    echo -e "${NC}"
    echo "    や～！"
    sleep 1
done

echo ""
echo "侍「拙者、${RED}弐千弐拾伍年${NC}の守護を仰せつかりました」"
