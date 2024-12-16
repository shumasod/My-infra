#!/bin/bash
# 土曜日のうぉうぉうぉ！をシェルスクリプトで表現

# うぉうぉうぉなASCIIアート
echo "
   うぉ   うぉ   うぉ
  ＿人人人人人人人人＿
  ＞  週末ｷﾀ━━━!! ＜
  ＞ うぉうぉうぉー! ＜
  ￣Y^Y^Y^Y^Y^Y^Y^Y￣

    (ﾉ≧∀≦)ﾉ
   ／    ＼
   （   ）
   │    │
"

# 休日モードの表示
echo "【休日モード起動！】"
echo "     ▼"
echo " 平日モード"
echo "     ↓"
echo "⚡うぉうぉうぉモード起動⚡"

# 元気ゲージ表示
energy=$((RANDOM % 30 + 70)) # 土曜日なので最低70%以上
echo -e "\n【週末元気ゲージ】"
echo -n "["
for ((i=0; i<energy/10; i++)); do echo -n "うぉ"; done
for ((i=energy/10; i<10; i++)); do echo -n "･"; done
echo "] $energy%"

# ランダムな週末の予定提案
plans=(
    "今日は朝までうぉうぉうぉー！🎉"
    "友達とカラオケでうぉうぉうぉー！🎤"
    "買い物行ってうぉうぉうぉー！🛍"
    "スポーツでうぉうぉうぉー！⚽"
    "映画見てうぉうぉうぉー！🎬"
    "ゲームしてうぉうぉうぉー！🎮"
    "料理作ってうぉうぉうぉー！🍳"
)
random_plan=${plans[$RANDOM % ${#plans[@]}]}
echo -e "\n【週末プラン】"
echo "$random_plan"

# 時間帯に応じたハイテンションメッセージ
hour=$(date +%H)
if [ $hour -lt 9 ]; then
    echo -e "\n朝だけどうぉうぉうぉー！"
elif [ $hour -lt 12 ]; then
    echo -e "\n午前のうぉうぉうぉー！"
elif [ $hour -lt 15 ]; then
    echo -e "\nランチタイムうぉうぉうぉー！"
elif [ $hour -lt 18 ]; then
    echo -e "\n午後のうぉうぉうぉー！"
elif [ $hour -lt 21 ]; then
    echo -e "\n夜のうぉうぉうぉー！"
else
    echo -e "\n深夜のうぉうぉうぉー！"
fi

# 週末モードエフェクト
effects=(
    "∩(´∀｀)∩ うぉうぉうぉー！"
    "ヽ(°▽°)ノ うぉうぉうぉー！"
    "(ﾉ´∀｀*)ﾉ うぉうぉうぉー！"
    "✧*。٩(ˊᗜˋ*)و✧*。 うぉうぉうぉー！"
    "＼(๑❛ᴗ❛๑)／ うぉうぉうぉー！"
)
random_effect=${effects[$RANDOM % ${#effects[@]}]}
echo -e "\n【週末モードエフェクト】"
echo "$random_effect"

# 休日アクティビティサジェスト
activities=(
    "カフェでまったりうぉうぉうぉ☕"
    "公園でピクニックうぉうぉうぉ🧺"
    "新しいお店探索うぉうぉうぉ🔍"
    "趣味の時間うぉうぉうぉ✨"
    "友達とおしゃべりうぉうぉうぉ💬"
)
random_activity=${activities[$RANDOM % ${#activities[@]}]}
echo -e "\n【今日のアクティビティ提案】"
echo "$random_activity"

# 週末天気予報風メッセージ
echo -e "\n【週末気分予報】"
echo "      ☀️"
echo "＼うぉうぉうぉ／"
echo "最高気分度: 100%"
echo "解放感指数: 極高"

# ストレス解放メーター
echo -e "\n【ストレス解放メーター】"
echo "平日のストレス"
echo "[■■■■■■■■■■]"
echo "     ↓"
echo "うぉうぉうぉモード発動！"
echo "[          ] ストレスゼロ！"

# 休日限定ダンス
dances=(
    "♪～(￣ε￣♪～(￣ε￣♪～(￣ε￣) うぉうぉうぉ～"
    "＼(^o^)／＼(^o^)／＼(^o^)／ うぉうぉうぉ！"
    "┗(＾0＾)┓┏(＾0＾)┛┗(＾0＾)┓ うぉうぉうぉ！"
    "ヾ(⌒∇⌒)ノ♪ヾ(⌒∇⌒)ノ♪ うぉうぉうぉ～"
    "♪┏(・o･)┛♪┗ ( ･o･) ┓♪ うぉうぉうぉ！"
)
random_dance=${dances[$RANDOM % ${#dances[@]}]}
echo -e "\n【うぉうぉうぉダンス】"
echo "$random_dance"

# 週末やりたいことリスト
echo -e "\n【週末やりたいことリスト】"
echo "□ 朝はゆっくり起きてうぉうぉうぉ"
echo "□ 美味しいもの食べてうぉうぉうぉ"
echo "□ 好きなことして過ごすうぉうぉうぉ"
echo "□ 思いっきり楽しむうぉうぉうぉ"
echo "□ 明日の月曜まで充電うぉうぉうぉ"

# 週末限定ボーナスメッセージ
bonuses=(
    "今日は何してもOK！うぉうぉうぉ！"
    "思いっきり楽しもう！うぉうぉうぉ！"
    "やりたいことやろう！うぉうぉうぉ！"
    "全力で週末満喫！うぉうぉうぉ！"
    "明日の心配は無し！うぉうぉうぉ！"
)
random_bonus=${bonuses[$RANDOM % ${#bonuses[@]}]}
echo -e "\n【週末限定ボーナス】"
echo "$random_bonus"

# 残りの週末時間カウンター
echo -e "\n【週末タイムカウンター】"
current_hour=$(date +%H)
remaining_hours=$((48 - current_hour))
echo "週末残り約${remaining_hours}時間！"
echo "うぉうぉうぉー！楽しもう！"
