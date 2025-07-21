#!/bin/bash

# Apache監視・パフォーマンスチューニングスクリプト
# 設定ファイルの読み込み
CONFIG_FILE="/etc/apache_monitor.conf"

# デフォルト設定
ACCESS_LOG="/var/log/apache2/access.log"
ERROR_LOG="/var/log/apache2/error.log"
MAIL_TO="your_email@example.com"
ERROR_CODES="300 400 500"
CHECK_INTERVAL=60  # 秒単位でのチェック間隔
LAST_POSITION_FILE="/tmp/apache_monitor_position"
LOG_FILE="/var/log/apache_monitor.log"
BATCH_INTERVAL=300  # 通知をまとめる間隔（秒）
MAX_ERRORS_PER_MAIL=50  # 1通のメールに含める最大エラー数

# パフォーマンス監視設定
RESPONSE_TIME_THRESHOLD=5000  # ミリ秒（5秒以上で警告）
HIGH_TRAFFIC_THRESHOLD=100    # 1分間のリクエスト数閾値
MEMORY_THRESHOLD=80          # メモリ使用率閾値（%）
CPU_THRESHOLD=80             # CPU使用率閾値（%）
PERFORMANCE_LOG="/var/log/apache_performance.log"
STATS_FILE="/tmp/apache_stats.tmp"

# 設定ファイルがあれば読み込む
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# ログディレクトリの確認と作成
for log_path in "$LOG_FILE" "$PERFORMANCE_LOG"; do
    LOG_DIR=$(dirname "$log_path")
    if [ ! -d "$LOG_DIR" ]; then
        mkdir -p "$LOG_DIR" || { echo "ログディレクトリを作成できません: $LOG_DIR"; exit 1; }
    fi
done

# 関数: メッセージをログに記録
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" >> "$LOG_FILE"
}

# 関数: パフォーマンスログに記録
log_performance() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" >> "$PERFORMANCE_LOG"
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

# 関数: レスポンス時間を監視
monitor_response_time() {
    local line=$1
    
    # Apacheのログフォーマットが '%h %l %u %t "%r" %>s %O "%{Referer}i" "%{User-Agent}i" %D' の場合
    # %D は応答時間をマイクロ秒で記録
    local response_time=$(echo "$line" | awk '{print $NF}')
    
    # 数値チェック
    if [[ "$response_time" =~ ^[0-9]+$ ]]; then
        # マイクロ秒をミリ秒に変換
        local response_time_ms=$((response_time / 1000))
        
        if [ "$response_time_ms" -gt "$RESPONSE_TIME_THRESHOLD" ]; then
            local url=$(echo "$line" | awk -F'"' '{print $2}' | awk '{print $2}')
            local ip=$(echo "$line" | awk '{print $1}')
            PERFORMANCE_ISSUES+=("遅いレスポンス: ${response_time_ms}ms - $url (IP: $ip)")
            log_performance "遅いレスポンス検出: ${response_time_ms}ms - $url"
        fi
        
        # 統計用に記録
        RESPONSE_TIMES+=("$response_time_ms")
    fi
}

# 関数: トラフィック統計を更新
update_traffic_stats() {
    local line=$1
    local timestamp=$(echo "$line" | awk -F'[' '{print $2}' | awk -F']' '{print $1}')
    local url=$(echo "$line" | awk -F'"' '{print $2}' | awk '{print $2}')
    local ip=$(echo "$line" | awk '{print $1}')
    local user_agent=$(echo "$line" | awk -F'"' '{print $6}')
    
    # リクエスト数をカウント
    ((TOTAL_REQUESTS++))
    
    # IPアドレス別統計
    if [[ -n "${IP_STATS[$ip]}" ]]; then
        ((IP_STATS[$ip]++))
    else
        IP_STATS[$ip]=1
    fi
    
    # URL別統計
    if [[ -n "${URL_STATS[$url]}" ]]; then
        ((URL_STATS[$url]++))
    else
        URL_STATS[$url]=1
    fi
    
    # User-Agent別統計（ボット検出用）
    if [[ "$user_agent" =~ [Bb]ot|[Cc]rawler|[Ss]pider ]]; then
        ((BOT_REQUESTS++))
    fi
}

# 関数: システムリソースを監視
monitor_system_resources() {
    # CPU使用率を取得
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | awk -F'%' '{print $1}')
    
    # メモリ使用率を取得
    local memory_info=$(free | grep Mem)
    local total_mem=$(echo $memory_info | awk '{print $2}')
    local used_mem=$(echo $memory_info | awk '{print $3}')
    local memory_usage=$((used_mem * 100 / total_mem))
    
    # Apacheプロセス数を取得
    local apache_processes=$(pgrep -c apache2 2>/dev/null || pgrep -c httpd 2>/dev/null || echo "0")
    
    # 閾値チェック
    if (( $(echo "$cpu_usage > $CPU_THRESHOLD" | bc -l 2>/dev/null || echo "0") )); then
        PERFORMANCE_ISSUES+=("高CPU使用率: ${cpu_usage}%")
        log_performance "高CPU使用率警告: ${cpu_usage}%"
    fi
    
    if [ "$memory_usage" -gt "$MEMORY_THRESHOLD" ]; then
        PERFORMANCE_ISSUES+=("高メモリ使用率: ${memory_usage}%")
        log_performance "高メモリ使用率警告: ${memory_usage}%"
    fi
    
    # 統計情報を保存
    echo "CPU_USAGE=$cpu_usage" > "$STATS_FILE"
    echo "MEMORY_USAGE=$memory_usage" >> "$STATS_FILE"
    echo "APACHE_PROCESSES=$apache_processes" >> "$STATS_FILE"
    echo "TIMESTAMP=$(date +%s)" >> "$STATS_FILE"
}

# 関数: 統計レポートを生成
generate_stats_report() {
    local report="=== Apache パフォーマンスレポート ===\n"
    report+="期間: $(date)\n\n"
    
    # 基本統計
    report+="【基本統計】\n"
    report+="総リクエスト数: $TOTAL_REQUESTS\n"
    report+="ボットリクエスト数: $BOT_REQUESTS\n"
    report+="人間のリクエスト数: $((TOTAL_REQUESTS - BOT_REQUESTS))\n\n"
    
    # レスポンス時間統計
    if [ ${#RESPONSE_TIMES[@]} -gt 0 ]; then
        local sum=0
        local max=0
        local min=999999
        
        for time in "${RESPONSE_TIMES[@]}"; do
            sum=$((sum + time))
            if [ "$time" -gt "$max" ]; then max=$time; fi
            if [ "$time" -lt "$min" ]; then min=$time; fi
        done
        
        local avg=$((sum / ${#RESPONSE_TIMES[@]}))
        
        report+="【レスポンス時間統計】\n"
        report+="平均: ${avg}ms\n"
        report+="最大: ${max}ms\n"
        report+="最小: ${min}ms\n"
        report+="測定数: ${#RESPONSE_TIMES[@]}\n\n"
    fi
    
    # トップアクセスIP
    report+="【トップアクセスIP（上位5位）】\n"
    for ip in $(printf '%s\n' "${!IP_STATS[@]}" | head -5); do
        report+="$ip: ${IP_STATS[$ip]} リクエスト\n"
    done
    report+="\n"
    
    # トップアクセスURL
    report+="【トップアクセスURL（上位5位）】\n"
    for url in $(printf '%s\n' "${!URL_STATS[@]}" | head -5); do
        report+="$url: ${URL_STATS[$url]} リクエスト\n"
    done
    report+="\n"
    
    # システムリソース
    if [ -f "$STATS_FILE" ]; then
        source "$STATS_FILE"
        report+="【システムリソース】\n"
        report+="CPU使用率: ${CPU_USAGE}%\n"
        report+="メモリ使用率: ${MEMORY_USAGE}%\n"
        report+="Apacheプロセス数: ${APACHE_PROCESSES}\n\n"
    fi
    
    # パフォーマンス問題
    if [ ${#PERFORMANCE_ISSUES[@]} -gt 0 ]; then
        report+="【パフォーマンス問題】\n"
        for issue in "${PERFORMANCE_ISSUES[@]}"; do
            report+="- $issue\n"
        done
        report+="\n"
    fi
    
    echo -e "$report"
}

# 関数: 収集したエラーメッセージを送信
send_error_batch() {
    if [ ${#ERROR_BUFFER[@]} -eq 0 ] && [ ${#PERFORMANCE_ISSUES[@]} -eq 0 ]; then
        return
    fi
    
    local total_errors=${#ERROR_BUFFER[@]}
    local total_performance_issues=${#PERFORMANCE_ISSUES[@]}
    local mail_body="Apache監視システムレポート\n\n"
    
    # エラー情報
    if [ $total_errors -gt 0 ]; then
        mail_body+="=== エラー情報 ($total_errors 件) ===\n"
        
        local display_count=$total_errors
        if [ $total_errors -gt $MAX_ERRORS_PER_MAIL ]; then
            display_count=$MAX_ERRORS_PER_MAIL
        fi
        
        for (( i=0; i<$display_count; i++ )); do
            mail_body+="${ERROR_BUFFER[$i]}\n"
        done
        
        if [ $total_errors -gt $MAX_ERRORS_PER_MAIL ]; then
            mail_body+="\n... さらに $((total_errors - MAX_ERRORS_PER_MAIL)) 件のエラーが省略されています ...\n"
        fi
        mail_body+="\n"
    fi
    
    # パフォーマンス問題
    if [ $total_performance_issues -gt 0 ]; then
        mail_body+="=== パフォーマンス問題 ($total_performance_issues 件) ===\n"
        for issue in "${PERFORMANCE_ISSUES[@]}"; do
            mail_body+="$issue\n"
        done
        mail_body+="\n"
    fi
    
    # 統計レポート
    mail_body+="$(generate_stats_report)\n"
    
    # メール送信
    echo -e "$mail_body" | mail -s "Apache 監視レポート: エラー${total_errors}件, パフォーマンス問題${total_performance_issues}件" "$MAIL_TO"
    
    log_message "レポートを送信: エラー${total_errors}件, パフォーマンス問題${total_performance_issues}件"
    
    # バッファをクリア
    ERROR_BUFFER=()
    PERFORMANCE_ISSUES=()
    LAST_NOTIFY_TIME=$(date +%s)
}

# 関数: 詳細なパフォーマンス分析
detailed_performance_analysis() {
    log_performance "=== 詳細パフォーマンス分析開始 ==="
    
    # Apache ServerStatus が有効な場合の情報取得
    if command -v curl >/dev/null 2>&1; then
        local server_status=$(curl -s http://localhost/server-status?auto 2>/dev/null)
        if [ $? -eq 0 ] && [ -n "$server_status" ]; then
            log_performance "Apache ServerStatus情報:"
            echo "$server_status" | while read line; do
                log_performance "  $line"
            done
        fi
    fi
    
    # プロセス情報の詳細分析
    local apache_memory=$(ps aux | grep -E "(apache2|httpd)" | grep -v grep | awk '{sum += $6} END {print sum/1024 " MB"}')
    log_performance "Apache総メモリ使用量: $apache_memory"
    
    # 接続数の確認
    local connections=$(netstat -an | grep ":80 " | wc -l)
    log_performance "現在のHTTP接続数: $connections"
    
    # ディスク使用量の確認
    local disk_usage=$(df -h | grep -E "/$|/var" | awk '{print $1 ": " $5}')
    log_performance "ディスク使用量: $disk_usage"
}

# 初期化
ERROR_BUFFER=()
PERFORMANCE_ISSUES=()
RESPONSE_TIMES=()
declare -A IP_STATS
declare -A URL_STATS
TOTAL_REQUESTS=0
BOT_REQUESTS=0
LAST_NOTIFY_TIME=$(date +%s)
LAST_ANALYSIS_TIME=$(date +%s)

# 必要なファイルの存在チェック
for log_file in "$ACCESS_LOG" "$ERROR_LOG"; do
    if [ ! -f "$log_file" ]; then
        log_message "警告: ログファイルが見つかりません: $log_file"
    fi
done

# 最後に読み取った位置を取得
if [ -f "$LAST_POSITION_FILE" ]; then
    last_position=$(cat "$LAST_POSITION_FILE")
else
    last_position=0
    echo "$last_position" > "$LAST_POSITION_FILE"
    log_message "新しいポジションファイルを作成しました: $LAST_POSITION_FILE"
fi

log_message "Apache ログ監視・パフォーマンス分析を開始しました"

# シグナルハンドリング
cleanup() {
    log_message "シグナルを受信したため、監視を終了します"
    send_error_batch
    log_performance "=== 監視終了 ==="
    exit 0
}

trap cleanup INT TERM

# メインループ
while true; do
    current_time=$(date +%s)
    
    # アクセスログの監視
    if [ -f "$ACCESS_LOG" ]; then
        current_size=$(wc -c < "$ACCESS_LOG")
        
        if [ "$current_size" -gt "$last_position" ]; then
            # 新しいログエントリを処理
            tail -c +$((last_position + 1)) "$ACCESS_LOG" | while IFS= read -r line; do
                if [ -n "$line" ]; then
                    # HTTPステータスコードをチェック
                    code=$(echo "$line" | awk '{print $9}')
                    
                    if [[ "$code" =~ ^[0-9]+$ ]]; then
                        # エラーコードをチェック
                        for error_code in $ERROR_CODES; do
                            if [ "${code:0:1}" = "${error_code:0:1}" ]; then
                                collect_error "$code" "$line"
                                break
                            fi
                        done
                    fi
                    
                    # パフォーマンス監視
                    monitor_response_time "$line"
                    update_traffic_stats "$line"
                fi
            done
            
            # 位置を更新
            echo "$current_size" > "$LAST_POSITION_FILE"
            last_position=$current_size
            
        elif [ "$current_size" -lt "$last_position" ]; then
            # ログローテーション検出
            log_message "ログローテーションを検出しました"
            echo "0" > "$LAST_POSITION_FILE"
            last_position=0
        fi
    fi
    
    # システムリソース監視（1分おき）
    monitor_system_resources
    
    # 詳細パフォーマンス分析（10分おき）
    if [ $((current_time - LAST_ANALYSIS_TIME)) -ge 600 ]; then
        detailed_performance_analysis
        LAST_ANALYSIS_TIME=$current_time
    fi
    
    # バッチ通知の送信チェック
    if [ $((current_time - LAST_NOTIFY_TIME)) -ge $BATCH_INTERVAL ]; then
        if [ ${#ERROR_BUFFER[@]} -gt 0 ] || [ ${#PERFORMANCE_ISSUES[@]} -gt 0 ]; then
            send_error_batch
        fi
        
        # 統計をリセット（1時間ごと）
        if [ $((current_time % 3600)) -lt $CHECK_INTERVAL ]; then
            log_performance "統計をリセットしました"
            RESPONSE_TIMES=()
            IP_STATS=()
            URL_STATS=()
            TOTAL_REQUESTS=0
            BOT_REQUESTS=0
        fi
    fi
    
    # 次のチェックまで待機
    sleep "$CHECK_INTERVAL"
done