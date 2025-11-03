#!/bin/bash

# カラー設定（対応端末のみ）
if [ -t 1 ] && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    RED='\033[0;31m'
    CYAN='\033[0;36m'
    NC='\033[0m'
else
    GREEN=''
    YELLOW=''
    RED=''
    CYAN=''
    NC=''
fi

# 新年飾り
draw_decoration() {
    echo -e "${RED}     ❀ 迎春 ❀${NC}"
    echo "    ================="
}

# リアル風蛇（少し長く、うねり感あり）
draw_snake() {
    echo -e "${GREEN}"
    cat <<'SNAKE'
          /^\/^\ 
        _|__|  O|
\/     /~     \_/ \
 \____|__________/  \
        \_______      \
                `\     \                 \
                  |     |                  \
                 /      /                    \
                /     /                       \
              /      /                         \ \
             /     /                            \  \
           /     /             _----_            \   \
          /     /           _-~      ~-_         |   |
         (      (        _-~    _--_    ~-_     _/   |
          \      ~-____-~    _-~    ~-_    ~-_-~    /
            ~-_           _-~          ~-_       _-~
               ~--______-~                ~-___-~
SNAKE
    echo -e "${NC}"
}

# メイン処理
main() {
    clear 2>/dev/null || printf "\033c"
    draw_decoration
    echo ""
    draw_snake

    messages=(
        "2025年 巳年"
        "明けまして"
        "おめでとうございます"
        "本年も宜しく"
        "お願いいたします"
    )

    for message in "${messages[@]}"; do
        sleep 1
        echo -e "\n    ${CYAN}${message}${NC}"
    done

    echo -e "\n🐍 蛇「${YELLOW}今年は私の年、滑るように進みます！${NC}」"
}

main