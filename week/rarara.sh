#!/bin/bash
# 木曜日のららら！をシェルスクリプトで表現

# らららなASCIIアート
echo "
   ら   ら   ら
  ＿人人人人人人＿
  ＞ もう木曜日! ＜
  ＞ らららーん♪ ＜
  ￣Y^Y^Y^Y^Y^Y￣

    ♪(๑ᴖ◡ᴖ๑)♪
   ／    ＼
   （   ）
   │    │
"

# 週末までのカウントダウン表示
echo "週末までのカウントダウン:"
echo "月[====らら==]金"
echo "        ↑ イマココ！"
echo "あと2日！ららら～♪"

# 気分をランダムに表示
moods=(
    "週末が見えてきたららら♪"
    "明日は金曜日だららら～！"
    "今日を乗り切ればあと1日ららら！"
    "木曜日はテンション上がるららら！"
    "週末計画を立てながらららら～"
)
random_mood=${moods[$RANDOM % ${#moods[@]}]}
echo -e "\n【本日の気分】"
echo "$random_mood"

# 木曜日を楽しく過ごすためのアドバイス
advice=(
    "週末の予定を立てながら仕事するららら！"
    "午後のコーヒーブレイクでリフレッシュららら！"
    "同僚とランチで週末トークららら♪"
    "今日は早めに帰宅してリラックスららら～"
    "明日の金曜日に向けて英気を養うららら"
)
random_advice=${advice[$RANDOM % ${#advice[@]}]}
echo -e "\n【木曜日のアドバイス】"
echo "$random_advice"

# 週末の天気予報風に気分を表現
echo -e "\n【週末の気分予報】"
weather=(
    "週末は絶好調らららスキー☀️"
    "ときどき眠たいけど上々ららら～⛅"
    "たまに疲れ目だけど前向きららら！🌤"
    "明日から本気出すららら mode！🌈"
    "休み待ちで若干スローららら...💭"
)
random_weather=${weather[$RANDOM % ${#weather[@]}]}
echo "$random_weather"

# 時間帯に応じたメッセージ
hour=$(date +%H)
if [ $hour -lt 12 ]; then
    echo -e "\n朝のららら！今日も一日がんばろう！"
elif [ $hour -lt 15 ]; then
    echo -e "\nお昼のららら！午後も元気に！"
elif [ $hour -lt 19 ]; then
    echo -e "\n夕方のららら！もうすぐ終わり！"
else
    echo -e "\n夜のららら！お疲れ様でした！"
fi

# 週間進捗メーター
echo -e "\n【週間進捗メーター】"
echo "月 [■■■■らら□] 金"
echo "進捗率: 80% ららら♪"

# ランダムな週末プラン提案
weekend_plans=(
    "週末は映画でも見に行くららら？🎬"
    "友達とカフェでおしゃべりららら！☕"
    "休日の料理に向けてレシピ検索ららら♪👨‍🍳"
    "公園でピクニックとかどうららら？🧺"
    "家でのんびりゲームとかどうららら～🎮"
)
random_plan=${weekend_plans[$RANDOM % ${#weekend_plans[@]}]}
echo -e "\n【週末プラン提案】"
echo "$random_plan"

# モチベーションダンス
dances=(
    "♪～(￣ε￣) ららら～"
    "٩(ˊᗜˋ*)و ららら！"
    "⌒°(❛ᴗ❛)°⌒ らららん♪"
    "♪(o=^•ェ•)o ‎らーらーらー"
    "ヾ(๑╹◡╹)ﾉ" ららら～♪"
)
random_dance=${dances[$RANDOM % ${#dances[@]}]}
echo -e "\n【らららダンス】"
echo "$random_dance"

# 残り時間のカウントダウン
work_end="17:30"
current_time=$(date +%s)
end_time=$(date -d "$work_end" +%s)

if [ $current_time -lt $end_time ]; then
    remaining=$((end_time - current_time))
    hours=$((remaining / 3600))
    minutes=$(((remaining % 3600) / 60))
    echo -e "\n【退勤までのカウントダウン】"
    echo "あと${hours}時間${minutes}分ららら！"
    
    if [ $hours -gt 4 ]; then
        echo "まだまだこれからららら～"
    elif [ $hours -gt 2 ]; then
        echo "あと半分ららら！"
    else
        echo "もうすぐ終わりららら♪"
    fi
else
    echo -e "\nお疲れ様でした！今日も一日ららら！"
fi

# 木曜日の応援メッセージ
cheers=(
    "明日は金曜日！もう少しららら！"
    "週末まであと一踏ん張りららら！"
    "今週もよく頑張ったららら！"
    "木曜日は幸せの予感ららら♪"
)
random_cheer=${cheers[$RANDOM % ${#cheers[@]}]}
echo -e "\n【本日の応援メッセージ】"
echo "$random_cheer"

# ハッピーメ
