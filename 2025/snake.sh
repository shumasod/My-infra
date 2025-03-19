#!/bin/bash

# Check if the terminal supports color
if [ -t 1 ] && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    RED='\033[0;31m'
    NC='\033[0m'    
else
    GREEN=''
    YELLOW=''
    RED=''
    NC=''
fi

# Function to draw New Year decoration
draw_decoration() {
    echo -e "${RED}    ❀ 迎春 ❀${NC}"
    echo "   ==========="
}

# Function to draw snake
draw_snake() {
    echo -e "${GREEN}
  ⠀　　＿＿
　　／・・＼
　　|_＿　　|
　　　／ 　 /
　　　￣|　/
　　 　 │ (_ノ|
　 　 　 ヽ＿ノ
${NC}"
    echo -e "     ${YELLOW}・${NC}  ${YELLOW}・${NC}"
    echo "      ╲⎺╱"
    echo -e "     ${GREEN}〜〜〜${NC}"
}

# Main execution
main() {
    # Clear the screen
    clear 2>/dev/null || printf "\033c"

    # Display New Year decoration and snake
    draw_decoration
    echo ""
    draw_snake

    # New Year's greetings animation
    messages=(
        "2025年 巳年"
        "明けまして"
        "おめでとうございます"
        "本年も宜しく"
        "お願いいたします"
    )

    for message in "${messages[@]}"; do
        sleep 1 2>/dev/null || sleep 0.1
        echo -e "\n    ${GREEN}${message}${NC}"
    done

    echo -e "\n蛇「${YELLOW}今年は私の年です！${NC}」"
}

# Run main function
main