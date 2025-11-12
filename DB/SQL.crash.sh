#!/bin/bash

# MariaDB接続情報
DB_HOST="localhost"
DB_PORT="3306"
DB_USER="your_username"
DB_PASS="your_password"
DB_NAME="your_database"

# 欠損したSQLファイルのパス
SQL_FILE_PATH="/path/to/missing_file.sql"
# 新しいSQLファイルのパス
NEW_SQL_FILE_PATH="/path/to/new_file.sql"

# ログファイル
LOG_FILE="/var/log/db_connection_monitor.log"

# 最大コネクション数の閾値（デフォルト接続数の80%を警告として設定）
MAX_CONNECTION_THRESHOLD=80

# ログ出力関数
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# コネクション数をチェックする関数
check_connection_count() {
    local result=$(mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" \
        -se "SHOW STATUS LIKE 'Threads_connected';" 2>/dev/null | awk '{print $2}')
    
    local max_connections=$(mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" \
        -se "SHOW VARIABLES LIKE 'max_connections';" 2>/dev/null | awk '{print $2}')
    
    if [ -z "$result" ] || [ -z "$max_connections" ]; then
        log_message "ERROR: コネクション情報の取得に失敗しました"
        return 1
    fi
    
    local usage_percent=$((result * 100 / max_connections))
    
    log_message "INFO: 現在のコネクション数: $result / $max_connections (使用率: ${usage_percent}%)"
    
    if [ $usage_percent -ge $MAX_CONNECTION_THRESHOLD ]; then
        log_message "WARNING: コネクション使用率が${usage_percent}%に達しています（閾値: ${MAX_CONNECTION_THRESHOLD}%）"
        return 2
    fi
    
    return 0
}

# アイドルコネクションをキルする関数
kill_idle_connections() {
    log_message "INFO: アイドルコネクションのクリーンアップを開始します"
    
    # 60秒以上アイドル状態のコネクションを取得してキル
    local idle_connections=$(mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" \
        -se "SELECT ID FROM information_schema.PROCESSLIST 
             WHERE Command = 'Sleep' 
             AND Time > 60 
             AND USER != 'system user';" 2>/dev/null)
    
    if [ -z "$idle_connections" ]; then
        log_message "INFO: キル対象のアイドルコネクションはありません"
        return 0
    fi
    
    local kill_count=0
    for conn_id in $idle_connections; do
        mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" \
            -e "KILL $conn_id;" 2>/dev/null
        if [ $? -eq 0 ]; then
            ((kill_count++))
            log_message "INFO: コネクションID $conn_id をキルしました"
        fi
    done
    
    log_message "INFO: ${kill_count}個のアイドルコネクションをキルしました"
}

# コネクションリトライ機能付きSQL実行関数
execute_sql_with_retry() {
    local sql_file="$1"
    local max_retries=3
    local retry_count=0
    local wait_time=5
    
    while [ $retry_count -lt $max_retries ]; do
        # コネクション数チェック
        check_connection_count
        local check_result=$?
        
        if [ $check_result -eq 2 ]; then
            log_message "WARNING: コネクション数が多いため、アイドルコネクションをクリーンアップします"
            kill_idle_connections
            sleep $wait_time
        fi
        
        # SQL実行
        log_message "INFO: SQLファイルを実行します（試行: $((retry_count + 1))/$max_retries）"
        
        mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" < "$sql_file" 2>&1 | tee -a "$LOG_FILE"
        local exit_code=${PIPESTATUS[0]}
        
        if [ $exit_code -eq 0 ]; then
            log_message "SUCCESS: SQLファイルの実行が完了しました"
            return 0
        else
            # エラーメッセージからコネクションエラーを判定
            if grep -q "Too many connections\|Can't connect\|Lost connection" "$LOG_FILE"; then
                log_message "ERROR: コネクションエラーが発生しました（リトライ: $((retry_count + 1))/$max_retries）"
                kill_idle_connections
                ((retry_count++))
                
                if [ $retry_count -lt $max_retries ]; then
                    log_message "INFO: ${wait_time}秒待機後、リトライします"
                    sleep $wait_time
                    wait_time=$((wait_time * 2))  # 指数バックオフ
                fi
            else
                log_message "ERROR: SQL実行エラー（コネクション以外）: exit code $exit_code"
                return 1
            fi
        fi
    done
    
    log_message "ERROR: 最大リトライ回数に達しました。処理を中断します"
    return 1
}

# 新しいSQLファイルを作成する関数
create_new_sql_file() {
    log_message "INFO: 新しいSQLファイルを作成します: $NEW_SQL_FILE_PATH"
    cat > "$NEW_SQL_FILE_PATH" <<EOF
CREATE DATABASE IF NOT EXISTS $DB_NAME;
USE $DB_NAME;

-- ここに必要なテーブル定義などを追加
-- CREATE TABLE example (
--     id INT PRIMARY KEY AUTO_INCREMENT,
--     name VARCHAR(255)
-- );
EOF
    
    if [ $? -eq 0 ]; then
        log_message "SUCCESS: SQLファイルの作成が完了しました"
        return 0
    else
        log_message "ERROR: SQLファイルの作成に失敗しました"
        return 1
    fi
}

# メイン処理
main() {
    log_message "========== スクリプト開始 =========="
    
    # 初期コネクション状態チェック
    check_connection_count
    
    # 欠損したSQLファイルが存在するかチェック
    if [ ! -f "$SQL_FILE_PATH" ]; then
        log_message "INFO: 欠損したSQLファイルが見つかりません。新しいSQLファイルを作成します"
        create_new_sql_file || exit 1
    else
        log_message "INFO: SQLファイルが見つかりました。処理を中止します"
        exit 0
    fi
    
    # 新しいSQLファイルを実行
    if [ -f "$NEW_SQL_FILE_PATH" ]; then
        execute_sql_with_retry "$NEW_SQL_FILE_PATH"
        local result=$?
        
        if [ $result -eq 0 ]; then
            log_message "INFO: SQLファイルを削除します: $NEW_SQL_FILE_PATH"
            rm -f "$NEW_SQL_FILE_PATH"
        else
            log_message "ERROR: SQL実行に失敗したため、ファイルは保持されます: $NEW_SQL_FILE_PATH"
            exit 1
        fi
    else
        log_message "ERROR: 新しいSQLファイルが見つかりません。処理を中止します"
        exit 1
    fi
    
    log_message "========== スクリプト終了 =========="
}

# スクリプト実行
main
