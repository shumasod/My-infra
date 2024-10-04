#!/bin/bash

# 金曜日のルルル！をシェルスクリプトで表現

# 現在の曜日を取得
day=$(date +%u)

# 金曜日かどうかチェック
if [ "$day" -eq 5 ]; then
    echo "今日は金曜日！ルルル！"
    
    # ルルルをアスキーアートで表示
    echo "
    _    _   _ _    _   _ _    _   _ 
   | |  | | | | |  | | | | |  | | | |
   | |  | | | | |  | | | | |  | | | |
   | |__| |_| | |__| |_| | |__| |_| |
   |_____\___/|_____\___/|_____\___/ 
    "
    
    # 週末の予定をランダムに提案
    activities=("ビールを飲む" "映画を見る" "友達と会う" "新しい料理を作る" "ゲームを楽しむ" "本を読む")
    random_activity=${activities[$RANDOM % ${#activities[@]}]}
    
    echo "週末の予定: $random_activity"

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