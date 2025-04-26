#!/bin/bash

########################
# 数字当てゲーム
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

# アニメーション表示
show_animation() {
  local symbol="?"
  local colors=("$RED" "$GREEN" "$YELLOW" "$BLUE" "$MAGENTA" "$CYAN")
  
  for i in {1..10}; do
    clear
    game_header
    
    color_index=$((i % 6))
    color=${colors[$color_index]}
    
    echo -e "\n\n"
    echo -e "            ${color}  ???  ${NC}"
    echo -e "            ${color} ?   ? ${NC}"
    echo -e "            ${color}?     ?${NC}"
    echo -e "            ${color}?     ?${NC}"
    echo -e "            ${color} ?   ? ${NC}"
    echo -e "            ${color}  ???  ${NC}"
    echo -e "\n\n"
    
    sleep 0.2
  done
}

# ゲームヘッダー表示
game_header() {
  printf "${YELLOW}╔═══════════════════════════════════╗${NC}\n"
  printf "${YELLOW}║        ${WHITE}数字当てゲーム${YELLOW}          ║${NC}\n"
  printf "${YELLOW}╚═══════════════════════════════════╝${NC}\n"
}

# ゲーム画面の初期化
game_init() {
  clear
  game_header
  printf "\n${CYAN}1から100までの数字を当ててください！${NC}\n"
  printf "${CYAN}%d回以内に当てられるでしょうか？${NC}\n\n" $MAX_TRIES
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

# 数字の当て方のヒントを表示
show_hint() {
  local guess=$1
  local target=$2
  local diff=$((guess - target))
  
  if [[ $diff -lt 0 ]]; then
    diff=$((diff * -1))
  fi
  
  if [[ $diff -ge 50 ]]; then
    printf "${RED}まったく違います！${NC}"
  elif [[ $diff -ge 25 ]]; then
    printf "${RED}かなり離れています${NC}"
  elif [[ $diff -ge 10 ]]; then
    printf "${YELLOW}まだ離れています${NC}"
  elif [[ $diff -ge 5 ]]; then
    printf "${YELLOW}近づいてきました${NC}"
  elif [[ $diff -ge 2 ]]; then
    printf "${GREEN}とても近いです！${NC}"
  elif [[ $diff -eq 1 ]]; then
    printf "${GREEN}惜しい！もう少し！${NC}"
  fi
  
  if [[ $guess -lt $target ]]; then
    printf " ${BLUE}(もっと大きい数字です)${NC}\n"
  elif [[ $guess -gt $target ]]; then
    printf " ${BLUE}(もっと小さい数字です)${NC}\n"
  fi
}

# 数字当てゲームの処理
play_number_game() {
  # 1-100のランダムな数字を生成
  local target=$((RANDOM % 100 + 1))
  local tries=0
  local guess
  local is_win=0
  
  game_init
  
  # ヒントを出しながらプレイヤーに数字を当ててもらう
  while [[ $tries -lt $MAX_TRIES ]]; do
    ((tries++))
    
    printf "${YELLOW}残り回数: %d/${MAX_TRIES}${NC}\n" $((MAX_TRIES - tries + 1))
    read -p "数字を入力してください (1-100): " guess
    
    # 入力チェック
    if ! [[ "$guess" =~ ^[0-9]+$ ]] || [[ $guess -lt 1 ]] || [[ $guess -gt 100 ]]; then
      printf "${RED}1から100までの数字を入力してください！${NC}\n"
      ((tries--))
      continue
    fi
    
    # 当たりの場合
    if [[ $guess -eq $target ]]; then
      clear
      game_header
      printf "\n${GREEN}正解です！おめでとう！${NC}\n"
      printf "${GREEN}%d回目で当てることができました！${NC}\n" $tries
      is_win=1
      ((total_tries += tries))
      ((total_wins++))
      break
    else
      # ヒントを表示
      show_hint $guess $target
    fi
  done
  
  # 負けの場合
  if [[ $is_win -eq 0 ]]; then
    printf "\n${RED}残念！正解は %d でした！${NC}\n" $target
  fi
}

# 統計表示
show_stats() {
  local avg_tries=0
  if [[ $total_wins -gt 0 ]]; then
    avg_tries=$(echo "scale=1; $total_tries / $total_wins" | bc)
  fi
  
  clear
  printf "${YELLOW}╔═══════════════════════════════════╗${NC}\n"
  printf "${YELLOW}║           ${WHITE}ゲーム統計${YELLOW}             ║${NC}\n"
  printf "${YELLOW}╚═══════════════════════════════════╝${NC}\n\n"
  printf "${CYAN}総プレイ回数: ${WHITE}%d${NC}\n" $plays
  printf "${CYAN}勝利回数: ${WHITE}%d${NC}\n" $total_wins
  printf "${CYAN}平均試行回数: ${WHITE}%s${NC}\n" $avg_tries
  printf "${CYAN}勝率: ${WHITE}%.2f%%${NC}\n" $(echo "scale=2; $total_wins/$plays*100" | bc)
  read -n 1 -s -r -p "何かキーを押して終了..."
}

# メイン処理
main() {
  MAX_TRIES=7  # 最大試行回数
  plays=0
  total_wins=0
  total_tries=0
  
  while :
  do
    show_animation
    play_number_game
    ((plays++))
    
    echo
    game_start_end "${YELLOW}もう一度プレイしますか？ [y/n]: ${NC}" || break
  done
  
  show_stats
}

main
