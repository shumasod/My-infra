#!/bin/bash

# Check if the terminal supports color
if [ -t 1 ] && [[ "$(tput colors)" -ge 8 ]]; then
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    RED='\033[0;31m'
    NC='\033[0m'    # No Color
else
    GREEN=''
    YELLOW=''
    RED=''
    NC=''
fi

RESET='\033[H'  # Move cursor to top-left

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
    echo "     ${GREEN}〜〜〜${NC}"
}

# Main execution
main() {
    # Clear the screen
    clear || echo "Failed to clear screen"

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
        sleep 1 || echo "Sleep command failed" >&2
        echo -e "\n    ${GREEN}${message}${NC}"
    done

    echo -e "\n蛇「${YELLOW}今年は私の年です！${NC}」"
}

# Run main function
main