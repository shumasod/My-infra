#!/bin/bash
# 火曜日のわわわ！をシェルスクリプトで表現

# わわわなASCIIアート
echo "
  ＿人人人人人人＿
  ＞  わわわ!  ＜
  ＞  慌てる～  ＜
  ￣Y^Y^Y^Y^Y^Y￣

   ｜ω･`)
   ⊂  ⊃
   （   ）
   │    │
"

# 慌ただしい状況をランダムに表示
situations=(
    "「あ！月曜日のタスク、まだ終わってない！」"
    "「わわわ！会議の資料作り忘れた！」"
    "「あれれ？メールの返信忘れてた！」"
    "「やばい！朝のコーヒーこぼした！」"
    "「急いでる時に限って電車が遅れる～」"
)
random_situation=${situations[$RANDOM % ${#situations[@]}]}
echo "【本日の慌てポイント】"
echo "$random_situation"

# 火曜日を乗り切るためのアドバイス
advice=(
    "深呼吸を3回！わわわ→すーはー"
    "ToDoリストを作り直してみよう"
    "優先順位を整理する時間"
    "同僚に助けを求めるのもアリ"
    "15分早く行動開始！"
)
random_advice=${advice[$RANDOM % ${#advice[@]}]}
echo -e "\n【慌てない作戦】"
echo "$random_advice"

# 現在の時刻に基づいて焦り度を計算
hour=$(date +%H)
minute=$(date +%M)
panic_level=$((((hour - 9) * 60 + minute) / 30))
if [ $panic_level -lt 0 ]; then panic_level=0; fi
if [ $panic_level -gt 10 ]; then panic_level=10; fi

echo -e "\n【現在の焦り度】"
echo -n "["
for ((i=0; i<panic_level; i++)); do echo -n "わ"; done
for ((i=panic_level; i<10; i++)); do echo -n "・"; done
echo "] $((panic_level * 10))%"

# タスク管理の擬音語をランダムに表示
task_sounds=(
    "ｶﾀｶﾀｶﾀ(º﹃º)...≡3"
    "ﾀｯﾀｯﾀｯ ε=ε=ε=┌(;･_･)┘"
    "ｶﾞｼｬｶﾞｼｬ(_　_*)ﾉ彡☆"
    "ﾊﾞﾀﾊﾞﾀ...((((;゜Д゜)))"
    "ﾄﾞﾀﾄﾞﾀ ┗|∵|┓"
)
random_sound=${task_sounds[$RANDOM % ${#task_sounds[@]}]}
echo -e "\n【作業中の効果音】"
echo "$random_sound"

# 残り時間のカウントダウン
work_end="17:30"
current_time=$(date +%s)
end_time=$(date -d "$work_end" +%s)

if [ $current_time -lt $end_time ]; then
    remaining=$((end_time - current_time))
    hours=$((remaining / 3600))
    minutes=$(((remaining % 3600) / 60))
    echo -e "\n【退勤までのカウントダウン】"
    echo "あと${hours}時間${minutes}分...わわわ！"
else
    echo -e "\nお疲れ様でした！今日も生き残れました！"
fi

# 火曜日の応援メッセージ
cheers=(
    "わわわ！でも頑張れる！"
    "慌てたって、何とかなる！"
    "火曜日なんて、怖くない！（たぶん）"
    "わわわ言いながら、前に進もう！"
)
random_cheer=${cheers[$RANDOM % ${#cheers[@]}]}
echo -e "\n【本日の応援メッセージ】"
echo "$random_cheer"

# 進捗バー
progress_bar() {
    local width=30
    local percent=$1
    local filled=$((width * percent / 100))
    local empty=$((width - filled))
    printf "["
    printf "%${filled}s" | tr ' ' '='
    printf "%${empty}s" | tr ' ' ' '
    printf "] %d%%\n" "$percent"
}

# 一日の進捗を表示
current_hour=$(date +%H)
work_hours=$((current_hour - 9))
if [ $work_hours -lt 0 ]; then work_hours=0; fi
if [ $work_hours -gt 8 ]; then work_hours=8; fi
progress=$((work_hours * 100 / 8))

echo -e "\n【本日の進捗】"
progress_bar $progress
