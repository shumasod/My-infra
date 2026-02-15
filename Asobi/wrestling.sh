#!/usr/bin/env bash
# prowrestling_simulator.sh - プロレス対戦シミュレーター（改良版）
# usage: ./prowrestling_simulator.sh [選手1名] [選手2名]

set -u

# カラー定義
if [ -t 1 ]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  CYAN='\033[0;36m'
  MAGENTA='\033[0;35m'
  BOLD='\033[1m'
  RESET='\033[0m'
else
  RED='' GREEN='' YELLOW='' BLUE='' CYAN='' MAGENTA='' BOLD='' RESET=''
fi

# 選手名（引数から取得、デフォルトあり）
P1=${1:-"炎のファイター"}
P2=${2:-"雷電キング"}

# 初期体力
HP_MAX=100
hp1=$HP_MAX
hp2=$HP_MAX

# ラウンド設定
MAX_ROUNDS=25
round=1

# 連続攻撃カウンター（コンボシステム）
combo1=0
combo2=0

# 必殺技ゲージ
special_gauge1=0
special_gauge2=0

# 技の配列（名前|最小ダメージ|最大ダメージ|発生確率(重み)|ゲージ増加量）
moves=(
  "ドロップキック|8|15|20|8"
  "ラリアット|12|20|15|10"
  "バックドロップ|15|25|12|12"
  "スープレックス|13|22|14|11"
  "チョップの連打|6|12|18|7"
  "フライングエルボー|10|18|16|9"
  "ボディスラム|9|16|17|8"
  "DDT|14|24|10|13"
  "パワーボム|18|28|8|15"
  "ムーンサルトプレス|16|26|9|14"
  "シャイニングウィザード|17|27|7|16"
  "スピアー|15|25|11|12"
  "垂直落下式ブレーンバスター|20|32|5|18"
  "場外乱闘|10|18|6|5"
  "カウンター攻撃|12|22|8|10"
)

# 必殺技（ゲージ100で発動可能）
finishers=(
  "フェニックススプラッシュ|30|45"
  "ジャックハマー|32|48"
  "ファイナルカット|35|50"
  "デストロイヤー|28|42"
)

# 実況コメントの配列
comments=(
  "なんという攻防だ！"
  "会場が揺れている！"
  "これぞプロレスの醍醐味！"
  "観客総立ち！"
  "激しい攻防が続く！"
  "両者一歩も譲らない！"
  "場内の熱気が最高潮に！"
  "これは名勝負の予感！"
  "歴史に残る一戦だ！"
)

# 実況コメントを表示
show_commentary() {
  if [ $((RANDOM % 4)) -eq 0 ]; then
    local idx=$((RANDOM % ${#comments[@]}))
    echo -e "${MAGENTA}【実況】${comments[$idx]}${RESET}"
  fi
}

# 技をランダムに選ぶ（重み付き）
choose_move() {
  local total=0
  local weights=()
  
  # 重みの合計を計算
  for move in "${moves[@]}"; do
    IFS='|' read -r name lo hi weight gauge <<< "$move"
    weights+=("$weight")
    total=$((total + weight))
  done
  
  # ランダム選択
  local pick=$((RANDOM % total))
  local cum=0
  
  for i in "${!moves[@]}"; do
    cum=$((cum + ${weights[i]}))
    if [ $pick -lt $cum ]; then
      echo "${moves[i]}"
      return
    fi
  done
  
  # フォールバック
  echo "${moves[0]}"
}

# 必殺技をランダムに選ぶ
choose_finisher() {
  local idx=$((RANDOM % ${#finishers[@]}))
  echo "${finishers[idx]}"
}

# 攻撃処理
attack() {
  local attacker="$1"
  local defender="$2"
  local attacker_color="$3"
  local attacker_hp_var="$4"
  local defender_hp_var="$5"
  local attacker_gauge_var="$6"
  local defender_gauge_var="$7"
  local attacker_combo_var="$8"
  
  local defender_hp=$(eval echo \$$defender_hp_var)
  local attacker_hp=$(eval echo \$$attacker_hp_var)
  local attacker_gauge=$(eval echo \$$attacker_gauge_var)
  local attacker_combo=$(eval echo \$$attacker_combo_var)
  
  sleep 0.4
  
  # 必殺技判定（ゲージ100以上かつ30%の確率で発動）
  if [ $attacker_gauge -ge 100 ] && [ $((RANDOM % 10)) -lt 3 ]; then
    IFS='|' read -r mv_name mv_lo mv_hi <<< "$(choose_finisher)"
    local dmg=$(( (RANDOM % (mv_hi - mv_lo + 1)) + mv_lo ))
    
    echo -e "${attacker_color}${BOLD}${attacker}${RESET}${attacker_color} が必殺技の構えを取る！${RESET}"
    sleep 0.5
    echo -e "${RED}${BOLD}★★★ ${mv_name}！！！ ★★★${RESET}"
    sleep 0.5
    
    # 必殺技後はゲージリセット
    eval ${attacker_gauge_var}=0
    
    local new_def_hp=$((defender_hp - dmg))
    if [ $new_def_hp -lt 0 ]; then new_def_hp=0; fi
    eval ${defender_hp_var}=$new_def_hp
    
    echo -e "${RED}${BOLD}${dmg}ダメージ！${RESET}"
    echo -e "${CYAN}${defender}の残りHP: ${new_def_hp}${RESET}"
    
    return
  fi
  
  # 通常技
  IFS='|' read -r mv_name mv_lo mv_hi mv_weight mv_gauge <<< "$(choose_move)"
  local dmg=$(( (RANDOM % (mv_hi - mv_lo + 1)) + mv_lo ))
  
  # コンボボーナス（3連続攻撃以上でダメージ増加）
  if [ $attacker_combo -ge 3 ]; then
    dmg=$((dmg * 120 / 100))
    echo -e "${YELLOW}【コンボ継続中！ダメージ+20%】${RESET}"
  fi
  
  echo -e "${attacker_color}${attacker}の攻撃！${RESET}"
  sleep 0.3
  echo -e "${attacker_color}${BOLD}『${mv_name}』${RESET}"
  sleep 0.4
  
  # クリティカルヒット判定（15%の確率）
  if [ $((RANDOM % 100)) -lt 15 ]; then
    dmg=$((dmg * 150 / 100))
    echo -e "${GREEN}${BOLD}━━━ クリティカルヒット！！ ━━━${RESET}"
    sleep 0.4
  fi
  
  # 場外乱闘の特殊処理
  if [ "$mv_name" = "場外乱闘" ]; then
    local self_dmg=$(( (RANDOM % 6) + 4 ))
    local new_def_hp=$((defender_hp - dmg))
    local new_self_hp=$((attacker_hp - self_dmg))
    
    if [ $new_def_hp -lt 0 ]; then new_def_hp=0; fi
    if [ $new_self_hp -lt 0 ]; then new_self_hp=0; fi
    
    eval ${defender_hp_var}=$new_def_hp
    eval ${attacker_hp_var}=$new_self_hp
    
    echo -e "${YELLOW}場外での激しい攻防！${RESET}"
    echo -e "${RED}${defender} - ${dmg}ダメージ！${RESET}"
    echo -e "${RED}${attacker} - ${self_dmg}ダメージ（反動）！${RESET}"
    echo -e "${CYAN}${attacker}の残りHP: ${new_self_hp}${RESET}"
    echo -e "${CYAN}${defender}の残りHP: ${new_def_hp}${RESET}"
  else
    local new_def_hp=$((defender_hp - dmg))
    if [ $new_def_hp -lt 0 ]; then new_def_hp=0; fi
    eval ${defender_hp_var}=$new_def_hp
    
    echo -e "${RED}${dmg}ダメージ！${RESET}"
    echo -e "${CYAN}${defender}の残りHP: ${new_def_hp}${RESET}"
  fi
  
  # ゲージ増加
  attacker_gauge=$((attacker_gauge + mv_gauge))
  if [ $attacker_gauge -gt 150 ]; then attacker_gauge=150; fi
  eval ${attacker_gauge_var}=$attacker_gauge
  
  # ゲージ表示（100以上で必殺技使用可能）
  if [ $attacker_gauge -ge 100 ]; then
    echo -e "${MAGENTA}【${attacker}の必殺技ゲージが満タン！】${RESET}"
  fi
  
  # HP警告
  if [ $new_def_hp -le 30 ] && [ $new_def_hp -gt 0 ]; then
    echo -e "${YELLOW}${BOLD}⚠ ${defender}が大ピンチ！ ⚠${RESET}"
  fi
  
  # 実況コメント
  show_commentary
}

# ステータスバー表示
status_bar() {
  local name="$1"
  local hp="$2"
  local max="$3"
  local gauge="$4"
  local combo="$5"
  
  local percent=$((hp * 100 / max))
  if [ $percent -lt 0 ]; then percent=0; fi
  
  local bar_len=20
  local filled=$((percent * bar_len / 100))
  local empty=$((bar_len - filled))
  
  local bar=""
  for ((i=0; i<filled; i++)); do bar+="█"; done
  for ((i=0; i<empty; i++)); do bar+="░"; done
  
  # ゲージバー
  local gauge_percent=$((gauge * 100 / 150))
  if [ $gauge_percent -gt 100 ]; then gauge_percent=100; fi
  local gauge_len=10
  local gauge_filled=$((gauge_percent * gauge_len / 100))
  local gauge_empty=$((gauge_len - gauge_filled))
  
  local gauge_bar=""
  for ((i=0; i<gauge_filled; i++)); do gauge_bar+="▓"; done
  for ((i=0; i<gauge_empty; i++)); do gauge_bar+="░"; done
  
  printf "%s%-14s%s HP:%3d/%3d [%s] %3d%%  " "${BOLD}" "$name" "${RESET}" "$hp" "$max" "$bar" "$percent"
  printf "ゲージ:[%s]  " "$gauge_bar"
  if [ $combo -gt 0 ]; then
    printf "コンボ:%d" "$combo"
  fi
  printf "\n"
}

# メイン試合処理
main() {
  echo -e "${BOLD}╔═════════════════════════════════════════════════╗${RESET}"
  echo -e "${BOLD}║     プロレス対戦シミュレーター ver 2.0         ║${RESET}"
  echo -e "${BOLD}╚═════════════════════════════════════════════════╝${RESET}"
  echo ""
  echo -e "${RED}【レッドコーナー】${BOLD}${P1}${RESET}  HP:${hp1}/${HP_MAX}"
  echo -e "           ${BOLD}VS${RESET}"
  echo -e "${BLUE}【ブルーコーナー】${BOLD}${P2}${RESET}  HP:${hp2}/${HP_MAX}"
  echo ""
  echo -e "${GREEN}${BOLD}========== ゴング！試合開始！ ==========${RESET}"
  echo ""
  
  while [ $round -le $MAX_ROUNDS ] && [ $hp1 -gt 0 ] && [ $hp2 -gt 0 ]; do
    echo ""
    echo -e "${CYAN}${BOLD}━━━━━━━━━━ ラウンド ${round} ━━━━━━━━━━${RESET}"
    echo ""
    
    # ランダムで先攻決定
    local starter=$((RANDOM % 2))
    
    if [ $starter -eq 0 ]; then
      attack "$P1" "$P2" "$RED" "hp1" "hp2" "special_gauge1" "special_gauge2" "combo1"
      combo1=$((combo1 + 1))
      combo2=0
      
      if [ $hp2 -le 0 ]; then
        echo ""
        echo -e "${GREEN}${BOLD}★ KO勝利！ ★${RESET}"
        break
      fi
      
      echo ""
      sleep 0.3
      
      attack "$P2" "$P1" "$BLUE" "hp2" "hp1" "special_gauge2" "special_gauge1" "combo2"
      combo2=$((combo2 + 1))
      combo1=0
      
      if [ $hp1 -le 0 ]; then
        echo ""
        echo -e "${GREEN}${BOLD}★ KO勝利！ ★${RESET}"
        break
      fi
    else
      attack "$P2" "$P1" "$BLUE" "hp2" "hp1" "special_gauge2" "special_gauge1" "combo2"
      combo2=$((combo2 + 1))
      combo1=0
      
      if [ $hp1 -le 0 ]; then
        echo ""
        echo -e "${GREEN}${BOLD}★ KO勝利！ ★${RESET}"
        break
      fi
      
      echo ""
      sleep 0.3
      
      attack "$P1" "$P2" "$RED" "hp1" "hp2" "special_gauge1" "special_gauge2" "combo1"
      combo1=$((combo1 + 1))
      combo2=0
      
      if [ $hp2 -le 0 ]; then
        echo ""
        echo -e "${GREEN}${BOLD}★ KO勝利！ ★${RESET}"
        break
      fi
    fi
    
    echo ""
    echo -e "${YELLOW}┄┄┄┄┄┄ 現在の状況 ┄┄┄┄┄┄${RESET}"
    status_bar "$P1" $hp1 $HP_MAX $special_gauge1 $combo1
    status_bar "$P2" $hp2 $HP_MAX $special_gauge2 $combo2
    echo ""
    
    # ラウンド間の体力回復（30%の確率）
    if [ $((RANDOM % 100)) -lt 30 ]; then
      local heal1=$(( (RANDOM % 8) + 3 ))
      local heal2=$(( (RANDOM % 8) + 3 ))
      hp1=$((hp1 + heal1))
      hp2=$((hp2 + heal2))
      
      if [ $hp1 -gt $HP_MAX ]; then hp1=$HP_MAX; fi
      if [ $hp2 -gt $HP_MAX ]; then hp2=$HP_MAX; fi
      
      echo -e "${YELLOW}両者が息を整える... ${P1}(+${heal1}) ${P2}(+${heal2})${RESET}"
      echo ""
    fi
    
    round=$((round + 1))
    sleep 0.5
  done
  
  # 勝敗判定
  echo ""
  echo -e "${BOLD}═══════════════════════════════════════════${RESET}"
  echo -e "${GREEN}${BOLD}========== 試合終了！ ==========${RESET}"
  echo -e "${BOLD}═══════════════════════════════════════════${RESET}"
  echo ""
  sleep 0.8
  
  if [ $hp1 -gt 0 ] && [ $hp2 -gt 0 ]; then
    echo -e "${YELLOW}${BOLD}★★★ 時間切れ引き分け！ ★★★${RESET}"
    echo ""
    echo "最終状態："
    status_bar "$P1" $hp1 $HP_MAX $special_gauge1 $combo1
    status_bar "$P2" $hp2 $HP_MAX $special_gauge2 $combo2
  elif [ $hp1 -gt $hp2 ]; then
    echo -e "${RED}${BOLD}┏━━━━━━━━━━━━━━━━━━━━━━━┓${RESET}"
    echo -e "${RED}${BOLD}┃  🏆 勝者: ${P1} 🏆  ┃${RESET}"
    echo -e "${RED}${BOLD}┗━━━━━━━━━━━━━━━━━━━━━━━┛${RESET}"
    echo -e "残りHP: ${hp1}/${HP_MAX}"
  else
    echo -e "${BLUE}${BOLD}┏━━━━━━━━━━━━━━━━━━━━━━━┓${RESET}"
    echo -e "${BLUE}${BOLD}┃  🏆 勝者: ${P2} 🏆  ┃${RESET}"
    echo -e "${BLUE}${BOLD}┗━━━━━━━━━━━━━━━━━━━━━━━┛${RESET}"
    echo -e "残りHP: ${hp2}/${HP_MAX}"
  fi
  
  echo ""
  echo -e "${CYAN}両者の健闘を称え、観客から大きな拍手が送られる！${RESET}"
  echo -e "${BOLD}═══════════════════════════════════════════${RESET}"
  echo ""
}

# スクリプト実行
main
