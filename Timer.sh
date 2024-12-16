#!/bin/bash

# 引数をチェック
if [ $# -ne 1 ]; then
    echo "使用方法: $0 <分>"
    exit 1
fi

# 引数が数字かチェック
if ! [[ $1 =~ ^[0-9]+$ ]]; then
    echo "エラー: 数字を入力してください"
    exit 1
fi

# 分を秒に変換
total_seconds=$(( $1 * 60 ))
end_time=$(( $(date +%s) + total_seconds ))

clear

while [ $(date +%s) -lt $end_time ]; do
    # 残り時間を計算
    current_time=$(date +%s)
    remaining_seconds=$(( end_time - current_time ))
    minutes=$(( remaining_seconds / 60 ))
    seconds=$(( remaining_seconds % 60 ))
    
    # プログレスバーの作成
    progress_bar=""
    progress=$(( (total_seconds - remaining_seconds) * 20 / total_seconds ))
    
    for (( i=0; i<20; i++ )); do
        if [ $i -lt $progress ]; then
            progress_bar+="█"
        else
            progress_bar+="░"
        fi
    done
    
    # 画面をクリアして表示
    clear
    echo "残り時間: ${minutes}分 ${seconds}秒"
    echo -e "\n[$progress_bar]"
    echo -e "\nCtrl+C で終了"
    
    sleep 1
done

# タイマー終了時の処理
clear
echo "時間になりました！"
for i in {1..3}; do
    echo -e "\a"  # ビープ音を鳴らす
    sleep 1
done
