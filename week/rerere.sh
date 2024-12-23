#!/bin/bash
# 水曜日のれれれ！をシェルスクリプトで表現

# れれれなASCIIアート
echo "
   れ   れ   れ
  ＿人人人人人人＿
  ＞ 週の真ん中! ＜
  ＞ がんばれれ! ＜
  ￣Y^Y^Y^Y^Y^Y￣

    (◍•ᴗ•◍)
   ＼    ／
    （   ）
    │    │
"

# 一週間の進捗バーを表示
echo "週の進捗状況:"
echo "月[===れれれ===]金"
echo "      ↑ イマココ！"

# 疲労度チェッカー
tiredness=(
    "まだまだ元気れれれ！"
    "ちょっと疲れてきたれ..."
    "お昼寝したいれ～"
    "コーヒーが欲しいれ！"
    "週末が待ち遠しいれ"
)
random_tired=${tiredness[$RANDOM % ${#tiredness[@]}]}
echo -e "\n【疲労度チェック】"
echo "$random_tired"

# 水曜日を乗り切るためのアドバイス
advice=(
    "昼休みは少し長めの散歩がおすすめれ！"
    "午後のおやつを用意するれ！"
    "3分間だけでも瞑想するれ～"
    "同僚とちょっとおしゃべりするれ"
    "好きな音楽を聴きながら仕事するれ"
)
random_advice=${advice[$RANDOM % ${#advice[@]}]}
echo -e "\n【水曜日のアドバイス】"
echo "$random_advice"

# ランダムなモチベーションブースター
boosters=(
    "٩(ˊᗜˋ*)و れれれ！"
    "(ノ°∀°)ノ⌒･*:.｡. .｡.:*･゜れれれ！"
    "҉♡*(。☌ᴗ☌｡)*♡҉ れれれ！"
    "｡.｡:+* れれれ ヽ(°◇° )ノ"
    "✧*。ヾ(｡>﹏<｡)ﾉﾞ✧*。 れれれ！"
)
random_booster=${boosters[$RANDOM % ${#boosters[@]}]}
echo -e "\n【モチベーションブースト】"
echo "$random_booster"

# 時間帯に応じたメッセージ
hour=$(date +%H)
if [ $hour -lt 12 ]; then
    echo -e "\n朝のれれれ！まだまだこれから！"
elif [ $hour -lt 15 ]; then
    echo -e "\nお昼のれれれ！あと半分！"
elif [ $hour -lt 19 ]; then
    echo -e "\n夕方のれれれ！もうすぐ終わり！"
else
    echo -e "\n夜のれれれ！お疲れ様！"
fi

# 週の折り返し地点カウンター
echo -e "\n【週の折り返しカウンター】"
echo "月曜日 → 火曜日 → 水曜日れれれ！← 木曜日 ← 金曜日"

# ランダムな昼食提案
lunches=(
    "今日のランチは麺類がおすすめれ！"
    "お弁当を食べながら短い散歩はどうれ？"
    "同僚とランチに行くれ！"
    "今日はちょっと贅沢なランチにするれ！"
    "デザート付きランチで元気チャージれ！"
)
random_lunch=${lunches[$RANDOM % ${#lunches[@]}]}
echo -e "\n【お昼ごはんアドバイス】"
echo "$random_lunch"

# タスク進捗状況
echo -e "\n【週間タスクの進捗】"
echo "            水"
echo "月     火 れ 木     金"
echo "      ＼  |  /"
echo "        ＼|／"
echo "         〇"

# 残り時間のカウントダウン
work_end="17:30"
current_time=$(date +%s)
end_time=$(date -d "$work_end" +%s)

if [ $current_time -lt $end_time ]; then
    remaining=$((end_time - current_time))
    hours=$((remaining / 3600))
    minutes=$(((remaining % 3600) / 60))
    echo -e "\n【退勤までのカウントダウン】"
    echo "あと${hours}時間${minutes}分れれれ！"
    
    # 残り時間に応じた励まし
    if [ $hours -gt 4 ]; then
        echo "まだまだこれかられ！"
    elif [ $hours -gt 2 ]; then
        echo "折り返し地点れ！"
    else
        echo "もうすぐ終わりれ！"
    fi
else
    echo -e "\nお疲れ様でした！今日も一日れれれ！"
fi

# 水曜日の応援メッセージ
cheers=(
    "週の真ん中、ここが踏ん張りどころれ！"
    "前半戦お疲れ様！後半戦もがんばれれれ！"
    "あと半分！れれれっと行こう！"
    "水曜日を乗り切れば、あとは下り坂れ！"
)
random_cheer=${cheers[$RANDOM % ${#cheers[@]}]}
echo -e "\n【本日の応援メッセージ】"
echo "$random_cheer"

# エネルギー残量メーター
energy=$((RANDOM % 100))
echo -e "\n【現在のエネルギー残量】"
echo -n "["
for ((i=0; i<energy/10; i++)); do echo -n "れ"; done
for ((i=energy/10; i<10; i++)); do echo -n "･"; done
echo "] $energy%"
