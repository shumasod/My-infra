
#!/bin/bash

# 設定ファイルの読み込み
CONFIG_FILE="/etc/apache_monitor.conf"

# デフォルト設定
ACCESS_LOG="/var/log/apache2/access.log"
MAIL_TO="your_email@example.com"
ERROR_CODES="300 400 500"
CHECK_INTERVAL=60  # 秒単位でのチェック間隔
LAST_POSITION_FILE="/tmp/apache_monitor_position"
LOG_FILE="/var/log/apache_monitor.log"
BATCH_INTERVAL=300  # 通知をまとめる間隔（秒）
MAX_ERRORS_PER_MAIL=50  # 1通のメールに含める最大エラー数

# 設定ファイルがあれば読み込む
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# ログディレクトリの確認と作成
LOG_DIR=$(dirname "$LOG_FILE")
if [ ! -d "$LOG_DIR" ]; then
    mkdir -p "$LOG_DIR" || { echo "ログディレクトリを作成できません: $LOG_DIR"; exit 1; }
fi

# 関数: メッセージをログに記録
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" >> "$LOG_FILE"
}

# 関数: エラーメッセージを収集
collect_error() {
    local code=$1
    local line=$2
    
    # エラーをバッファに追加
    ERROR_BUFFER+=("エラーコード $code: $line")
    
    # バッファサイズをログに記録
    log_message "エラーを検出しました: コード $code (バッファサイズ: ${#ERROR_BUFFER[@]})"
}

# 関数: 収集したエラーメッセージを送信
send_error_batch() {
    if [ ${#ERROR_BUFFER[@]} -eq 0 ]; then
        return
    fi
    
    local total_errors=${#ERROR_BUFFER[@]}
    local mail_body="Apache監視システムから ${total_errors} 件のエラーが検出されました。\n\n"
    
    # エラー数が多い場合は制限する
    local display_count=$total_errors
    if [ $total_errors -gt $MAX_ERRORS_PER_MAIL ]; then
        display_count=$MAX_ERRORS_PER_MAIL
    fi
    
    # エラーメッセージを追加
    for (( i=0; i<$display_count; i++ )); do
        mail_body+="${ERROR_BUFFER[$i]}\n"
    done
    
    # 残りのエラー数を表示
    if [ $total_errors -gt $MAX_ERRORS_PER_MAIL ]; then
        mail_body+="\n... さらに $((total_errors - MAX_ERRORS_PER_MAIL)) 件のエラーが省略されています ...\n"
    fi
    
    # メール送信
    echo -e "$mail_body" | mail -s "Apache エラー通知: $total_errors 件検出" "$MAIL_TO"
    
    log_message "$total_errors 件のエラーを $MAIL_TO に通知しました"
    
    # バッファをクリア
    ERROR_BUFFER=()
    LAST_NOTIFY_TIME=$(date +%s)
}

# 初期化
ERROR_BUFFER=()
LAST_NOTIFY_TIME=$(date +%s)

# 必要なファイルの存在チェック
if [ ! -f "$ACCESS_LOG" ]; then
    log_message "エラー: ログファイルが見つかりません: $ACCESS_LOG"
    echo "エラー: ログファイルが見つかりません: $ACCESS_LOG" >&2
    exit 1
fi

# 最後に読み取った位置を取得
if [ -f "$LAST_POSITION_FILE" ]; then
    last_position=$(cat "$LAST_POSITION_FILE")
else
    last_position=0
    echo "$last_position" > "$LAST_POSITION_FILE"
    log_message "新しいポジションファイルを作成しました: $LAST_POSITION_FILE"
fi

log_message "Apache ログ監視を開始しました"

trap 'log_message "シグナルを受信したため、監視を終了します"; send_error_batch; exit 0' INT TERM

while true; do
    # ファイルサイズを取得
    if [ -f "$ACCESS_LOG" ]; then
        current_size=$(wc -c < "$ACCESS_LOG")
    else
        log_message "警告: ログファイルが見つかりません: $ACCESS_LOG"
        sleep "$CHECK_INTERVAL"
        continue
    fi

    if [ "$current_size" -gt "$last_position" ]; then
        # 新しいログエントリを読み込む
        tail -c +$((last_position + 1)) "$ACCESS_LOG" | while IFS= read -r line
        do
            # HTTPステータスコードを抽出
            code=$(echo "$line" | awk '{print $9}')
            
            # 数値でない場合はスキップ
            if ! [[ "$code" =~ ^[0-9]+$ ]]; then
                continue
            }
            
            # エラーコードをチェック
            for error_code in $ERROR_CODES; do
                if [ "${code:0:1}" = "${error_code:0:1}" ]; then
                    collect_error "$code" "$line"
                    break
                fi
            done
        done
        
        # 最後に読み取った位置を更新
        echo "$current_size" > "$LAST_POSITION_FILE"
        
    elif [ "$current_size" -lt "$last_position" ]; then
        # ログファイルがローテートされた場合
        log_message "ログローテーションを検出しました"
        echo "0" > "$LAST_POSITION_FILE"
        last_position=0
    fi

    # 現在時刻を取得
    current_time=$(date +%s)
    
    # バッチ通知間隔を超えたか、エラーバッファが大きくなった場合に通知
    if [ $((current_time - LAST_NOTIFY_TIME)) -ge $BATCH_INTERVAL ] && [ ${#ERROR_BUFFER[@]} -gt 0 ]; then
        send_error_batch
    fi

    # 次のチェックまで待機
    sleep "$CHECK_INTERVAL"
done
