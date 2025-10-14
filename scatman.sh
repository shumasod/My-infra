#!/usr/bin/env bash
# scatman.sh
# Scatman風のランダム・スキャットを表示（おまけで簡易音出力）
# 保存: chmod +x scatman.sh && ./scatman.sh

# 設定
LINES=12             # 表示するフレーズ数
SPEED=0.03           # 1文字あたりの表示速度（秒）
PAUSE_BETWEEN=0.6    # フレーズ間の待ち時間（秒）
USE_SOUND=true       # 音を鳴らすか (true/false) -- コマンド play (sox) があるときのみ鳴る

# スキャット音節リスト（自由に増やしてOK）
SYLLABLES=( "sha" "scat" "doo" "ba" "bop" "bee" "zah" "da" "dip" "zin" "la" "li" "vo" "pa" "tum" "ta" "do" "ri" "na" )

# ランダムに長さを決めてフレーズを作る関数
make_phrase(){
  local len=$((RANDOM % 6 + 3))   # 3〜8 音節
  local phrase=""
  for ((i=0;i<len;i++)); do
    # 何%かで小文字/大文字をミックス
    s="${SYLLABLES[RANDOM % ${#SYLLABLES[@]}]}"
    if (( RANDOM % 5 == 0 )); then
      s="$(tr '[:lower:]' '[:upper:]' <<<"$s")"
    fi
    phrase+="$s"
    if (( i < len-1 )); then
      phrase+="-"   # 音節の区切り
    fi
  done
  echo "$phrase"
}

# タイピング風に表示する関数
type_out(){
  local text="$1"
  for ((i=0;i<${#text};i++)); do
    printf "%s" "${text:i:1}"
    sleep $SPEED
  done
  printf "\n"
}

# 簡易音（トーン）を鳴らす関数（sox の play があれば使う）
play_tone(){
  local freq=$1
  local dur=${2:-0.12}
  if command -v play >/dev/null 2>&1; then
    # -q は冗長出力抑制。サイン波を短く鳴らす
    play -q -n synth "$dur" sine "$freq" >/dev/null 2>&1 &
  fi
}

# ASCII アート風ヘッダ
cat <<'EOF'
   ____  _               _                __  __
  / ___|| |__   __ _  __| | ___  _ __ ___|  \/  | __ _ _ __
  \___ \| '_ \ / _` |/ _` |/ _ \| '__/ _ \ |\/| |/ _` | '_ \
   ___) | | | | (_| | (_| | (_
