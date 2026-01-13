#!/usr/bin/env bash
# 鴨葱うどん 〜禁断の深夜R-18アスキーアート版〜

set -euo pipefail

RED='\e[38;5;196m'
PINK='\e[38;5;213m'
HOT='\e[38;5;202m'
STEAM='\e[38;5;226m'
BOLD='\e[1m'
BLINK='\e[5m'
RESET='\e[0m'

show_kamonegi_R18() {
    clear
    sleep 0.5

    echo -e "${PINK}${BOLD}"
    cat << 'EOF'

               ＿＿＿_
            ／　　　　　　　＼
          /　　　●　　　●　　　\\
        ／　　　　　　　　　　　　　＼
       /　　　　　　　　　　　　　　　＼
      |　　　　●　　　　●　　　　　　|
      |　　　　　　　　　　　　　　　　|
      |　　　　　　∩　∩　　　　　　|
      |　　　　　（●）（●）　　　　　|    ← 鴨の瞳で見つめられて…
      |　　　　　　/　|　|　＼　　　　|
      |　　　　　　ｕ　ｕ　　　　　　|
      |　　　　　　　　　　　　　　　　|
      |　　　　　　∩　∩　　　　　　|    ← 九条ネギが絡みついて…
      |　　　　　（●）（●）　　　　　|
      |　　　　　　/　|　|　＼　　　　|
      |　　　　　　ｕ　ｕ　　　　　　|
      |　　　　　　　　　　　　　　　　|
      |　　　　　　∩　∩　　　　　　|    ← 最後の一滴まで…
      |　　　　　（●）（●）　　　　　|
      |　　　　　　/　|　|　＼　　　　|
      |　　　　　　ｕ　ｕ　　　　　　|
      |　　　　　　　　　　　　　　　　|
      ＼＿＿＿＿＿＿＿＿＿＿／
                 あぁ…熱い…♡

EOF
    echo -e "${RESET}"

    echo -e "${HOT}${BOLD}          鴨葱うどん 〜夜の秘め味〜${RESET}"
    echo
    sleep 1.2

    echo -e "${PINK}【深夜のレシピ・18禁】${RESET}"
    echo
    echo -e "${STEAM}  1. だし汁を${BLINK}激しく${RESET}${STEAM}沸騰させて… もう我慢できない…${RESET}"
    sleep 1.5
    echo -e "${STEAM}  2. うどんを${BLINK}ゆっくり${RESET}${STEAM}取り出して… 袋から滑り込ませるの…♡${RESET}"
    sleep 1.8
    echo -e "${STEAM}  3. 鴨肉をそっとのせて… 脂がじゅわぁっと${BLINK}溶け出す${RESET}${STEAM}瞬間がたまらない…${RESET}"
    sleep 2
    echo -e "${STEAM}  4. 九条ネギをたっぷり${BLINK}絡めて${RESET}${STEAM}… 香りが部屋中に広がっちゃう…${RESET}"
    sleep 1.5

    echo
    echo -e "${RED}${BOLD}         ふぅ… 熱すぎる… でも止められない…${RESET}"
    echo
    echo -e "${PINK}${BOLD}                   いただきます…♡♡♡${RESET}"

    # ズルズル音でフィニッシュ
    echo -e "${HOT}"
    for i in {1..8}; do
        echo -n "ズルッ"
        sleep 0.18
        echo -n "……"
        sleep 0.25
    done
    echo -e "  あぁんっ…！${RESET}"

    echo
    echo -e "${PINK}   ……ごちそうさまでした。${RESET}"
    echo -e "${PINK}   また今夜も…来てくれるよね…？${RESET}"
}

# 実行
show_kamonegi_R18