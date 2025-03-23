#!/bin/bash

########################
# サイコロバトルゲーム
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

# サイコロの目を表示する関数
show_dice() {
  local num=$1
  local color=$2
  
  case $num in
    1)
      echo -e "${color}┌─────────┐${NC}"
      echo -e "${color}│         │${NC}"
      echo -e "${color}│    ●    │${NC}"
      echo -e "${color}│         │${NC}"
      echo -e "${color}└─────────┘${NC}"
      ;;
    2)
      echo -e "${color}┌─────────┐${NC}"
      echo -e "${color}│ ●       │${NC}"
      echo -e "${color}│         │${NC}"
      echo -e "${color}│       ● │${NC}"
      echo -e "${color}└─────────┘${NC}"
      ;;
    3)
      echo -e "${color}┌─────────┐${NC}"
      echo -e "${color}│ ●       │${NC}"
      echo -e "${color}│    ●    │${NC}"
      echo -e "${color}│       ● │${NC}"
      echo -e "${color}└─────────┘${NC}"
      ;;
    4)
      echo -e "${color}┌─────────┐${NC}"
      echo -e "${color}│ ●     ● │${NC}"
      echo -e "${color}│         │${NC}"
      echo -e "${color}│ ●     ● │${NC}"
      echo -e "${color}└─────────┘${NC}"
      ;;
    5)
      echo -e "${color}┌─────────┐${NC}"
      echo -e "${color}│ ●     ● │${NC}"
      echo -e "${color}│    ●    │${NC}"
      echo -e "${color}│ ●     ● │${NC}"
      echo -e "${color}└─────────┘${NC}"
      ;;
    6)
      echo -e "${color}┌─────────┐${NC}"
      echo -e "${color}│ ●     ● │${NC}"
      echo -e "${color}│ ●     ● │${NC}"
      echo -e "${color}│ ●     ● │${NC}"
      echo -e "${color}└─────────┘${NC}"
      ;;
  esac
}

# ゲーム画面の初期化
game_init() {
  clear
  printf "${YELLOW}╔═══════════════════════════════════╗${NC}\n"
  printf "${YELLOW}║       ${WHITE}サイコロバトルゲーム${YELLOW}       ║${NC}\n"
  printf "${YELLOW}╚═══════════════════════════════════╝${NC}\n\n"
  printf "${CYAN}あなたとコンピュータがサイコロを振り、数字が大きい方が勝ちです！${NC}\n\n"
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

# サイコロを振る
roll_dice() {
  echo $((RANDOM % 6 + 1))
}

# 勝敗判定
judge_game() {
  local player=$1
  local computer=$2
  
  if [[ $player -gt $computer ]]; then
    printf "${GREEN}おめでとう！あなたの勝ちです！${NC}\n"
    ((wins++))
  elif [[ $player -lt $computer ]]; then
    printf "${RED}残念！コンピュータの勝ちです！${NC}\n"
  else
    printf "${YELLOW}引き分けです！${NC}\n"
    ((draws++))
  fi
}

# サイコロゲームの処理
play_dice_game() {
  game_init
  printf "${YELLOW}サイコロを振ります。準備はいいですか？${NC}\n"
  read -n 1 -s -r -p "何かキーを押すとあなたのサイコロを振ります..."
  echo
  
  # プレイヤーのサイコロ
  player_dice=$(roll_dice)
  printf "${BLUE}あなたのサイコロ:${NC}\n"
  show_dice $player_dice $BLUE
  echo
  
  read -n 1 -s -r -p "何かキーを押すとコンピュータのサイコロを振ります..."
  echo
  
  # コンピュータのサイコロ
  computer_dice=$(roll_dice)
  printf "${RED}コンピュータのサイコロ:${NC}\n"
  show_dice $computer_dice $RED
  echo
  
  # 勝敗判定
  judge_game $player_dice $computer_dice
}

# 統計表示
show_stats() {
  clear
  printf "${YELLOW}╔═══════════════════════════════════╗${NC}\n"
  printf "${YELLOW}║           ${WHITE}ゲーム統計${YELLOW}             ║${NC}\n"
  printf "${YELLOW}╚═══════════════════════════════════╝${NC}\n\n"
  printf "${CYAN}総プレイ回数: ${WHITE}%d${NC}\n" $plays
  printf "${CYAN}勝利回数: ${WHITE}%d${NC}\n" $wins
  printf "${CYAN}引き分け: ${WHITE}%d${NC}\n" $draws
  printf "${CYAN}勝率: ${WHITE}%.2f%%${NC}\n" $(echo "scale=2; $wins/$plays*100" | bc)
  read -n 1 -s -r -p "何かキーを押して終了..."
}

# メイン処理
main() {
  plays=0
  wins=0
  draws=0
  
  while :
  do
    play_dice_game
    ((plays++))
    
    echo
    game_start_end "${YELLOW}もう一度プレイしますか？ [y/n]: ${NC}" || break
  done
  
  show_stats
}

main
