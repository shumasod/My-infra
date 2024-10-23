#!/bin/bash

# 金曜日のルルル！をシェルスクリプトで表現

# 現在の曜日を取得
day=$(date +%u)

# 金曜日かどうかチェック
if [ "$day" -eq 5 ]; then
    echo "今日は金曜日！ルルル！"
    
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

    # カウントダウンタイマー（仕事終わりまで）
    work_end_time="18:00"
    current_time=$(date +%s)
    end_time=$(date -d "$work_end_time" +%s)
    
    if [ $current_time -lt $end_time ]; then
        remaining=$((end_time - current_time))
        echo "仕事終了まであと: $(date -u -d @"$remaining" +%H時間%M分%S秒)"
    else
        echo "お疲れ様でした！週末の時間です！"
    fi
else
    echo "今日は金曜日ではありません。金曜日まであと$((5 - day))日です。"
fi
