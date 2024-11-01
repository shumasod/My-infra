#!/bin/bash
# 日曜日のシクシク！をシェルスクリプトで表現

# シクシクなASCIIアート
echo "
   シク   シク   シク
  ＿人人人人人人人人＿
  ＞ 明日から平日... ＜
  ＞ シクシクシク... ＜
  ￣Y^Y^Y^Y^Y^Y^Y^Y￣

    (´；ω；｀)
   ／    ＼
   （   ）
   │    │
"

# 残り休日時間カウンター
current_hour=$(date +%H)
remaining_hours=$((24 - current_hour))
echo "【休日残り時間】"
echo "残り約${remaining_hours}時間シクシク..."
echo "     ↓"
echo "あと少しで月曜日シクシク..."

# 憂鬱度メーター
blues=$((RANDOM % 30 + 70)) # 日曜日なので最低70%
echo -e "\n【日曜の憂鬱度メーター】"
echo -n "["
for ((i=0; i<blues/10; i++)); do echo -n "シク"; done
for ((i=blues/10; i<10; i++)); do echo -n "･"; done
echo "] $blues%"

# 時間帯に応じたメッセージ
hour=$(date +%H)
if [ $hour -lt 9 ]; then
    echo -e "\nまだ朝だから考えないシクシク..."
elif [ $hour -lt 12 ]; then
    echo -e "\n午前中が終わっていくシクシク..."
elif [ $hour -lt 15 ]; then
    echo -e "\nお昼過ぎたらあっという間シクシク..."
elif [ $hour -lt 18 ]; then
    echo -e "\n夕方が近づいてきたシクシク..."
elif [ $hour -lt 21 ]; then
    echo -e "\n夜になっちゃったシクシク..."
else
    echo -e "\nもう寝なきゃシクシク..."
fi

# 日曜あるある
situations=(
    "洗濯物が乾かないシクシク..."
    "早く寝なきゃいけないシクシク..."
    "明日の準備しなきゃシクシク..."
    "週末があっという間シクシク..."
    "明日の仕事考えちゃうシクシク..."
)
random_situation=${situations[$RANDOM % ${#situations[@]}]}
echo -e "\n【日曜あるある】"
echo "$random_situation"

# 明日への準備リスト
echo -e "\n【明日への準備リスト】シクシク..."
echo "□ かばんの準備"
echo "□ 明日の服選び"
echo "□ お弁当の買い出し"
echo "□ 早寝する決意"
echo "□ 心の準備..."

# 日曜の癒し提案
healing=(
    "お風呂にゆっくり浸かろうシクシク..."
    "好きな音楽聴いて気分転換シクシク..."
    "まったり過ごそうシクシク..."
    "おいしいものでも食べようシクシク..."
    "少しだけ昼寝しようシクシク..."
)
random_healing=${healing[$RANDOM % ${#healing[@]}]}
echo -e "\n【シクシクの癒し提案】"
echo "$random_healing"

# 日曜モード表示
echo -e "\n【現在のモード】"
echo "     ↓"
echo "シクシクモード発動中..."
echo "      ↓"
echo "（´・ω・｀）"

# 残タスクチェッカー
tasks=(
    "洗濯物まだ終わってないシクシク..."
    "部屋の掃除が残ってるシクシク..."
    "明日の準備まだシクシク..."
    "早く寝なきゃシクシク..."
    "やることいっぱいシクシク..."
)
random_task=${tasks[$RANDOM % ${#tasks[@]}]}
echo -e "\n【残タスクチェッカー】"
echo "$random_task"

# 日曜の天気予報風メッセージ
echo -e "\n【心の天気予報】"
echo "      ☁️"
echo "＼シクシクシク／"
echo "憂鬱度: 100%"
echo "月曜日まであと少し..."

# シクシクエモート
emotes=(
    "(´；ω；｀) シクシク..."
    "(っ´；ω；｀c) シクシク..."
    "｡ﾟ(ﾟ´Д｀ﾟ)ﾟ｡ シクシク..."
    "(´；ω；｀) シクシク..."
    "( ´；ω；`) シクシク..."
)
random_emote=${emotes[$RANDOM % ${#emotes[@]}]}
echo -e "\n【シクシクエモート】"
echo "$random_emote"

# 一週間カウントダウン
echo -e "\n【また次の週末まで...】"
echo "月 火 水 木 金 → 休み"
echo "⬆ シクシク..."
echo "明日はここから..."

# 日曜限定メッセージ
messages=(
    "明日からまた頑張ろう...シクシク"
    "今日は早めに寝よう...シクシク"
    "楽しかった週末...シクシク"
    "あっという間の休日...シクシク"
    "来週の週末まで待とう...シクシク"
)
random_message=${messages[$RANDOM % ${#messages[@]}]}
echo -e "\n【日曜の心の声】"
echo "$random_message"

# 日曜日限定カウントダウンタイマー
if [ $hour -lt 21 ]; then
    bedtime="21:00"
    current_time=$(date +%s)
    bedtime_time=$(date -d "$bedtime" +%s)
    if [ $current_time -lt $bedtime_time ]; then
        remaining=$((bedtime_time - current_time))
        hours=$((remaining / 3600))
        minutes=$(((remaining % 3600) / 60))
        echo -e "\n【就寝時刻までのカウントダウン】"
        echo "早く寝なきゃ...あと${hours}時間${minutes}分シクシク..."
    fi
fi
