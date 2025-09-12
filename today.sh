#!/usr/bin/env bash
# today.sh - 毎朝「今日何するの？」を通知する
# 保存先例: ~/bin/today.sh
# 必要なツール:
#  - Linux: notify-send (libnotify) / macOS: osascript
#  - 任意: paplay / afplay で音を鳴らせます

set -euo pipefail

# --- 設定 ---
TODO_FILE="$HOME/todo.txt"   # 存在すればここから読み込む（1行1タスク）
DEFAULT_TASKS=(
  "メールチェックと返信（30分）"
  "今日のプライオリティを決める（3つ）"
  "コードを書く / レビューする（1時間）"
  "休憩をとる（ストレッチ）"
  "ドキュメント整備"
  "学習タイム（30分）"
  "ランチの準備 / 外出"
)
TITLE="今日何するの？"
TIME_STR="$(date '+%Y/%m/%d %a')"

# --- タスク取得 ---
tasks=()
if [[ -f "$TODO_FILE" ]]; then
  # ファイルの非空行を配列に
  while IFS= read -r line; do
    line="${line%%$'\r'}"
    [[ -n "$line" ]] && tasks+=("$line")
  done < "$TODO_FILE"
fi

# 無ければデフォルトからランダムで3つ選ぶ
if [[ ${#tasks[@]} -eq 0 ]]; then
  # シャッフルして先頭3つ（存在する分だけ）
  mapfile -t shuffled < <(printf "%s\n" "${DEFAULT_TASKS[@]}" | awk 'BEGIN{srand()} {a[NR]=$0} END{for(i=NR;i>=1;i--){j=int(rand()*i)+1; print a[j]; a[j]=a[i]}}')
  pick_n=3
  for ((i=0;i<pick_n && i<${#shuffled[@]}; i++)); do
    tasks+=("${shuffled[i]}")
  done
fi

# --- メッセージ生成 ---
body="$TIME_STR\n"
i=1
for t in "${tasks[@]}"; do
  body+="$i. $t\n"
  ((i++))
done

# --- 通知表示関数 ---
notify_linux() {
  # notify-sendへ渡す（要 libnotify）
  # cronから実行する場合は DBUS_SESSION_BUS_ADDRESS を設定する必要がある場合あり（後述）
  printf "%b" "$body" | /usr/bin/notify-send "$TITLE" "$(sed ':a;N;$!ba;s/\n/\\n/g' <<<"$body")"
}

notify_macos() {
  # macOSのNotification（osascript）
  # 一行メッセージにするため改行を「 — 」に置換（見やすさ調整）
  short=$(printf "%b" "$body" | tr '\n' ' ' | sed 's/  */ /g')
  /usr/bin/osascript -e "display notification \"${short//\"/\\\"}\" with title \"${TITLE}\" subtitle \"${TIME_STR}\""
}

# --- 音を鳴らす（任意） ---
play_sound() {
  if command -v paplay >/dev/null 2>&1 && [[ -f /usr/share/sounds/freedesktop/stereo/complete.oga ]]; then
    paplay /usr/share/sounds/freedesktop/stereo/complete.oga &>/dev/null || true
  elif command -v afplay >/dev/null 2>&1 && [[ -f /System/Library/Sounds/Glass.aiff ]]; then
    afplay /System/Library/Sounds/Glass.aiff &>/dev/null || true
  fi
}

# --- 実行（環境判定） ---
OS="$(uname)"
if [[ "$OS" == "Darwin" ]]; then
  notify_macos
  play_sound
else
  # Linux系
  if command -v notify-send >/dev/null 2>&1; then
    notify_linux
  else
    # 代替: コンソール出力
    printf "%b\n" "$TITLE"
    printf "%b\n" "$body"
  fi
  play_sound
fi

# exit success
exit 0
