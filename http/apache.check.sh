#!/bin/bash

# 設定
ACCESS_LOG="/var/log/apache2/access.log"
MAIL_TO="your_email@example.com"
ERROR_CODES="300 400 500"
CHECK_INTERVAL=60  # 秒単位でのチェック間隔
LAST_POSITION_FILE="/tmp/apache_monitor_position"

# 関数: エラーメッセージを送信
send_error_notification() {
    local code=$1
    local line=$2
    echo "エラーコード $code が検出されました。詳細: $line" | \
    mail -s "Apache エラー通知: コード $code" "$MAIL_TO"
}

# 最後に読み取った位置を取得
if [ -f "$LAST_POSITION_FILE" ]; then
    last_position=$(cat "$LAST_POSITION_FILE")
else
    last_position=0
fi

while true; do
    # ファイルサイズを取得
    current_size=$(wc -c < "$ACCESS_LOG")

    if [ "$current_size" -gt "$last_position" ]; then
        # 新しいログエントリを読み込む
        tail -c +$((last_position + 1)) "$ACCESS_LOG" | while IFS= read -r line
        do
            # HTTPステータスコードを抽出
            code=$(echo "$line" | awk '{print $9}')
            
            # エラーコードをチェック
            for error_code in $ERROR_CODES; do
                if [ "$code" = "$error_code" ]; then
                    send_error_notification "$code" "$line"
                    break
                fi
            done
        done
        
        # 最後に読み取った位置を更新
        echo "$current_size" > "$LAST_POSITION_FILE"
    elif [ "$current_size" -lt "$last_position" ]; then
        # ログファイルがローテートされた場合
        echo "0" > "$LAST_POSITION_FILE"
    fi

    # 次のチェックまで待機
    sleep "$CHECK_INTERVAL"
done