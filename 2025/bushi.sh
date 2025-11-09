#!/bin/bash

# === カラー設定 ===
if [ -t 1 ] && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    CYAN='\033[0;36m'
    NC='\033[0m'
else
    GREEN=''
    YELLOW=''
    CYAN=''
    NC=''
fi

# === 蛇のパターン（くねくね用） ===
frames=(
"🐍~~~~~~~"
"~🐍~~~~~~"
"~~🐍~~~~~"
"~~~🐍~~~~"
"~~~~🐍~~~"
"~~~~~🐍~~"
"~~~~~~🐍~"
"~~~~~~~🐍"
"~~~~~~🐍~"
"~~~~~🐍~~"
"~~~~🐍~~~"
"~~~🐍~~~~"
"~~🐍~~~~~"
"~🐍~~~~~~"
)

# === タイトル ===
draw_decoration() {
    echo -e "${YELLOW}     ❀ 迎春 ❀${NC}"
    echo "    ================="
    echo ""
}

# === メイン処理 ===
main() {
    clear
    draw_decoration
    echo -e "${CYAN}2025年 巳年 — 動く蛇🐍${NC}"
    echo ""

    # 無限ループ（Ctrl+Cで止める）
    while true; do
        for frame in "${frames[@]}"; do
            echo -ne "\r${GREEN}${frame}${NC}"
            sleep 0.08
        done
    done
}

main