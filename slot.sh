#!/bin/bash

########################
# スロットゲーム

########################

# カラー定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# カーソル非表示
printf "\e[?25l"

# ANSIエスケープシーケンスリセット
esc_reset() {
  printf "\e[2J\e[H\e[?25h"
  exit 0
}
trap "esc_reset" INT QUIT TERM

# 乱数生成
random_card() {
  cards=("7" "$" "?" "♠" "♥" "♦" "♣")
  echo "${cards[$((RANDOM % 7))]}"
}

# スロット画面の描画
slot_init() {
  clear
  printf "${YELLOW}╔═══════════════════════════════════╗${NC}\n"
  printf "${YELLOW}║       ${WHITE}華麗なるスロットゲーム${YELLOW}       ║${NC}\n"
  printf "${YELLOW}╚═══════════════════════════════════╝${NC}\n\n"
  slot_flame="${CYAN}╔═══════════╗${NC}"
  show_cards="${CYAN}║${NC}[${WHITE}|$(random_card)|$(random_card)|$(random_card)|${NC}]${CYAN}║${NC}"
  bottom_flame="${CYAN}╚═══════════╝${NC}"
  printf "%s\n%s\n%s\n" "${slot_flame}" "${show_cards}" "${bottom_flame}"
}

# ゲームスタート・終了の確認
game_start_end() {
  while :
  do
    read -p "$1" key
    case "$key" in
      [Yy]*) return 0 ;;
      [Nn]*) esc_reset ;;
      *) echo -e "${RED}y または n を入力してください!${NC}" ;;
    esac
  done
}

# ゲームの判定
slot_judge() {
  local c1="${GREEN}" c2="${BLUE}" ce="${NC}"
  case "$enter_count" in
    0)
      card_1=$(random_card)
      card_2=$(random_card)
      card_3=$(random_card)
      printf "\e[4;1H${CYAN}║${NC}[${WHITE}|%s|%s|%s|${NC}]${CYAN}║${NC}\e[1G" "${card_1}" "${card_2}" "${card_3}"
      ;;
    1)
      card_2=$(random_card)
      card_3=$(random_card)
      printf "\e[4;1H${CYAN}║${NC}[${WHITE}|$c1%s$ce|%s|%s|${NC}]${CYAN}║${NC}\e[1G" "${card_1}" "${card_2}" "${card_3}"
      ;;
    2)
      card_3=$(random_card)
      if [[ "$card_1" == "$card_2" ]]; then
        printf "\e[4;1H${CYAN}║${NC}[${WHITE}|$c2%s$ce|$c2%s$ce|%s|${NC}]${CYAN}║${NC}\e[1G" "${card_1}" "${card_2}" "${card_3}"
      else
        printf "\e[4;1H${CYAN}║${NC}[${WHITE}|$c1%s$ce|$c1%s$ce|%s|${NC}]${CYAN}║${NC}\e[1G" "${card_1}" "${card_2}" "${card_3}"
      fi
      ;;
    3)
      if [[ "$card_1" == "$card_2" && "$card_1" == "$card_3" ]]; then
        success_show
        return
      fi
      if [[ "$card_1" == "$card_2" ]]; then
        printf "\e[4;1H${CYAN}║${NC}[${WHITE}|$c2%s$ce|$c2%s$ce|$c1%s$ce|${NC}]${CYAN}║${NC}\e[1G" "${card_1}" "${card_2}" "${card_3}"
      elif [[ "$card_1" == "$card_3" ]]; then
        printf "\e[4;1H${CYAN}║${NC}[${WHITE}|$c2%s$ce|$c1%s$ce|$c2%s$ce|${NC}]${CYAN}║${NC}\e[1G" "${card_1}" "${card_2}" "${card_3}"
      elif [[ "$card_2" == "$card_3" ]]; then
        printf "\e[4;1H${CYAN}║${NC}[${WHITE}|$c1%s$ce|$c2%s$ce|$c2%s$ce|${NC}]${CYAN}║${NC}\e[1G" "${card_1}" "${card_2}" "${card_3}"
      else
        printf "\e[4;1H${CYAN}║${NC}[${WHITE}|$c1%s$ce|$c1%s$ce|$c1%s$ce|${NC}]${CYAN}║${NC}\e[1G" "${card_1}" "${card_2}" "${card_3}"
      fi
      printf "\e[7;1H\e[K${RED}残念でした!${NC}\n"
      return
      ;;
  esac
}

# スロットのサクセス画面（点滅表示）
display_slot() {
  local c1="${RED}" c2="${YELLOW}" ce="${NC}"
  for i in {1..8}; do
    clear
    printf "${YELLOW}╔═══════════════════════════════════╗${NC}\n"
    printf "${YELLOW}║       ${WHITE}大当たり！おめでとう！${YELLOW}       ║${NC}\n"
    printf "${YELLOW}╚═══════════════════════════════════╝${NC}\n\n"
    if ((i % 2 == 0)); then
      printf "$c1${slot_flame}$ce\n"
    else
      printf "${slot_flame}\n"
    fi
    printf "${CYAN}║${NC}[${WHITE}|$c2%s$ce|$c2%s$ce|$c2%s$ce|${NC}]${CYAN}║${NC}\n" "${card_1}" "${card_2}" "${card_3}"
    if ((i % 2 == 0)); then
      printf "$c1${bottom_flame}$ce\n"
    else
      printf "${bottom_flame}\n"
    fi
    sleep 0.2
  done
}

success_show() {
  display_slot
  printf "\e[7;1H${GREEN}おめでとうございます! 大当たりです！${NC}\n"
  ((wins++))
}

# スロットマシーン作成
slot_machine() {
  enter_count=0
  trap "((enter_count++))" USR1 USR2
  trap "slot_init" CONT
  while ((enter_count < 3)); do
    slot_judge
    sleep 0.2
  done
}

# 統計表示
show_stats() {
  clear
  printf "${YELLOW}╔═══════════════════════════════════╗${NC}\n"
  printf "${YELLOW}║           ${WHITE}ゲーム統計${YELLOW}             ║${NC}\n"
  printf "${YELLOW}╚═══════════════════════════════════╝${NC}\n\n"
  printf "${CYAN}総プレイ回数: ${WHITE}%d${NC}\n" $plays
  printf "${CYAN}勝利回数: ${WHITE}%d${NC}\n" $wins
  printf "${CYAN}勝率: ${WHITE}%.2f%%${NC}\n" $(echo "scale=2; $wins/$plays*100" | bc)
  read -n 1 -s -r -p "Press any key to continue..."
}

# メイン処理
main() {
  plays=0
  wins=0
  while :
  do
    slot_init
    printf "\e[7;1H"
    game_start_end "${YELLOW}ゲームを始めますか？ [y/n]: ${NC}"
    ((plays++))
    printf "\e[7;1H\e[J"
    slot_machine &
    local PID=$!
    for ((i=0; i<3; i++)); do
      while :
      do
        read -s -n 1 key
        if [[ -z $key && ${PID:=0} -gt 0 ]]; then
          kill -USR1 $PID
          break
        else
          printf "\e[7;1H${MAGENTA}何も入力せずに、Enterキーを押してください!${NC}"
        fi
      done
    done
    wait
    printf "\e[9;1H"
    game_start_end "${YELLOW}もう一度チャレンジしますか？ [y/n]: ${NC}" || break
  done
  show_stats
}

main
