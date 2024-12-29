#!/bin/bash
# 花札こいこいゲーム
# カラー定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# 花札の定義
declare -A HANAFUDA
HANAFUDA=(
  ["1,1"]="松の光" ["1,2"]="松の赤短" ["1,3"]="松のタン" ["1,4"]="松のカス"
  ["2,1"]="梅の鴬" ["2,2"]="梅の赤短" ["2,3"]="梅のタン" ["2,4"]="梅のカス"
  ["3,1"]="桜の幕" ["3,2"]="桜の赤短" ["3,3"]="桜のタン" ["3,4"]="桜のカス"
  ["4,1"]="藤の幕" ["4,2"]="藤のタン" ["4,3"]="藤のカス" ["4,4"]="藤のカス"
  ["5,1"]="菖蒲の八橋" ["5,2"]="菖蒲のタン" ["5,3"]="菖蒲のカス" ["5,4"]="菖蒲のカス"
  ["6,1"]="牡丹の蝶" ["6,2"]="牡丹のタン" ["6,3"]="牡丹のカス" ["6,4"]="牡丹のカス"
  ["7,1"]="萩の猪" ["7,2"]="萩のタン" ["7,3"]="萩のカス" ["7,4"]="萩のカス"
  ["8,1"]="芒の月" ["8,2"]="芒のカリ" ["8,3"]="芒のカス" ["8,4"]="芒のカス"
  ["9,1"]="菊の盃" ["9,2"]="菊のタン" ["9,3"]="菊のカス" ["9,4"]="菊のカス"
  ["10,1"]="紅葉の鹿" ["10,2"]="紅葉の青短" ["10,3"]="紅葉のカス" ["10,4"]="紅葉のカス"
  ["11,1"]="柳の小野道風" ["11,2"]="柳の燕" ["11,3"]="柳のタン" ["11,4"]="柳のカス"
  ["12,1"]="桐の鳳凰" ["12,2"]="桐の青短" ["12,3"]="桐のカス" ["12,4"]="桐のカス"
)

# プレイヤーの手札と場の札
player_hand=()
cpu_hand=()
field=()

# スコア
player_score=0
cpu_score=0

# ゲームの初期化
initialize_game() {
  # 山札を作成
  deck=()
  for month in {1..12}; do
    for card in {1..4}; do
      deck+=("$month,$card")
    done
  done

  # 山札をシャッフル
  for i in {48..1}; do
    j=$((RANDOM % i + 1))
    temp=${deck[i]}
    deck[i]=${deck[j]}
    deck[j]=$temp
  done

  # 手札を配る
  for i in {1..8}; do
    player_hand+=("${deck[-1]}")
    deck=("${deck[@]:0:${#deck[@]}-1}")
    cpu_hand+=("${deck[-1]}")
    deck=("${deck[@]:0:${#deck[@]}-1}")
  done

  # 場に札を置く
  for i in {1..8}; do
    field+=("${deck[-1]}")
    deck=("${deck[@]:0:${#deck[@]}-1}")
  done
}

# 画面表示
display_game() {
  clear
  echo -e "${YELLOW}======== 花札こいこい ========${NC}"
  echo -e "${BLUE}CPU の手札: ${#cpu_hand[@]} 枚${NC}"
  echo -e "${GREEN}場の札:${NC}"
  for card in "${field[@]}"; do
    echo -n "${HANAFUDA[$card]} "
  done
  echo
  echo -e "${CYAN}あなたの手札:${NC}"
  for i in "${!player_hand[@]}"; do
    echo -e "$((i+1)). ${HANAFUDA[${player_hand[$i]}]}"
  done
  echo -e "${MAGENTA}あなたのスコア: $player_score${NC}"
  echo -e "${RED}CPU のスコア: $cpu_score${NC}"
}

# プレイヤーのターン
player_turn() {
  local played=false
  while ! $played; do
    read -p "どの札を出しますか？ (1-${#player_hand[@]}): " choice
    if [[ $choice =~ ^[1-9]$ && $choice -le ${#player_hand[@]} ]]; then
      card=${player_hand[$((choice-1))]}
      player_hand=("${player_hand[@]:0:$((choice-1))}" "${player_hand[@]:$choice}")
      match_and_collect "$card" "player"
      played=true
    else
      echo "無効な選択です。もう一度選んでください。"
    fi
  done
}

# CPUのターン
cpu_turn() {
  local card=${cpu_hand[0]}
  cpu_hand=("${cpu_hand[@]:1}")
  match_and_collect "$card" "cpu"
}

# マッチングと収集
match_and_collect() {
  local card=$1
  local player=$2
  local month=${card%,*}
  local matched=false

  for i in "${!field[@]}"; do
    if [[ ${field[$i]%,*} == $month ]]; then
      if [[ $player == "player" ]]; then
        player_score=$((player_score + 1))
      else
        cpu_score=$((cpu_score + 1))
      fi
      field=("${field[@]:0:$i}" "${field[@]:$((i+1))}")
      matched=true
      break
    fi
  done

  if ! $matched; then
    field+=("$card")
  fi
}

# メインゲームループ
main_game_loop() {
  initialize_game
  local turn=0

  while ((${#player_hand[@]} > 0 && ${#cpu_hand[@]} > 0)); do
    display_game
    if ((turn % 2 == 0)); then
      echo "あなたのターンです。"
      player_turn
    else
      echo "CPU のターンです。"
      cpu_turn
    fi
    ((turn++))
    sleep 1
  done
}

# ゲーム終了処理
end_game() {
  display_game
  if ((player_score > cpu_score)); then
    echo -e "${GREEN}おめでとうございます！あなたの勝ちです！${NC}"
  elif ((player_score < cpu_score)); then
    echo -e "${RED}残念！CPU の勝ちです。${NC}"
  else
    echo -e "${YELLOW}引き分けです！${NC}"
  fi
}

# メイン処理
main() {
  while true; do
    main_game_loop
    end_game
    read -p "もう一度プレイしますか？ (y/n): " replay
    [[ $replay != [Yy]* ]] && break
  done
  echo "ゲームを終了します。ありがとうございました！"
}

main
