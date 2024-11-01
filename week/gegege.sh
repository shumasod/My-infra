#!/bin/bash
# 月曜日のゲゲゲ！をシェルスクリプトで表現

# ASCIIアートで妖怪風の顔を表示
echo "
   ゲ   ゲ   ゲ
  ∩( ´∀｀)∩
   ⊂    ⊃
   （   ）
   │    │
"

# やる気が出る名言をランダムに表示
quotes=(
    "月曜日だって、妖怪のように強く生きろ！"
    "ゲゲゲ...月曜日が来たぞー"
    "目玉おやじ: 「バケモノの世界も、月曜日は月曜日じゃ」"
    "鬼太郎: 「月曜日こそ、妖怪たちが頑張る日だ！」"
    "ねこ娘: 「月曜日って、ゲゲゲッ」"
)
random_quote=${quotes[$RANDOM % ${#quotes[@]}]}
echo "【本日の妖怪からのメッセージ】"
echo "$random_quote"

# 月曜日を乗り切るためのアドバイスをランダムに表示
advice=(
    "今日はコーヒーを一杯多めに飲もう"
    "昼休みに少し長めの散歩をしてみては？"
    "おやつは妖怪メニュー（きのこ系）がおすすめ"
    "夕方には深呼吸で妖気を吸収"
    "帰宅後は温かいお風呂でリフレッシュ"
)
random_advice=${advice[$RANDOM % ${#advice[@]}]}
echo -e "\n【妖怪からの月曜アドバイス】"
echo "$random_advice"

# 現在時刻に応じてメッセージを変更
hour=$(date +%H)
if [ $hour -lt 12 ]; then
    echo -e "\n妖怪たちも朝は苦手...でも頑張ろう！"
elif [ $hour -lt 15 ]; then
    echo -e "\nお昼を過ぎても妖気は健在！"
elif [ $hour -lt 19 ]; then
    echo -e "\n夕方の妖気で最後まで頑張れ！"
else
    echo -e "\n今日も一日、よく頑張った！"
fi

# 週間天気予報風に週の進捗を表示
day_of_week=$(date +%u)
progress=$((day_of_week * 20))
echo -e "\n週の進捗状況:"
echo "月[$(printf '█%.0s' $(seq 1 $((day_of_week))))$(printf '░%.0s' $(seq 1 $((5 - day_of_week))))]金"
echo "現在$progress%完了"

# 妖怪が使いそうなやる気が出る呪文
spells=(
    "ゲゲゲッと行こう！"
    "妖気上昇チャージ！"
    "月曜返し！月曜返し！"
    "いただき妖怪パワー！"
)
random_spell=${spells[$RANDOM % ${#spells[@]}]}
echo -e "\n【本日の妖怪呪文】"
echo "$random_spell"
