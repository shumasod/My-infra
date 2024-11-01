#!/bin/bash
# 金曜日のルルル！をシェルスクリプトで表現

# ルルルをカタカナで表示
echo "
ル  ル  ル
ル  ル  ル
ル  ル  ル
"

# 週末の予定をランダムに提案
activities=("ビールを飲む" "映画を見る" "友達と会う" "新しい料理を作る" "ゲームを楽しむ" "本を読む")
random_activity=${activities[$RANDOM % ${#activities[@]}]}

echo "週末の予定: $random_activity"

# Spotifyリンクを提案
echo "金曜日をもっと楽しむには、[Spotifyで『金曜日のルルル』を聴く](https://open.spotify.com/intl-ja/track/50pszP5c5FV4vkHInrtFtV)"

# 現在19時なので、仕事終了メッセージを表示
echo "お疲れ様でした！週末の時間です！"
