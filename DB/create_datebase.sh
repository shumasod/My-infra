#!/bin/bash

# Oracleの環境変数を設定
export ORACLE_HOME=/path/to/oracle_home
export PATH=$ORACLE_HOME/bin:$PATH
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$LD_LIBRARY_PATH
export NLS_LANG=JAPANESE_JAPAN.AL32UTF8

# 設定パラメータ
SQL_SCRIPT="create_database.sql"
LOG_FILE="/var/log/oracle_connection_monitor.log"
MAX_SESSION_THRESHOLD=80  # セッション使用率の閾値（%）
MAX_RETRIES=3
IDLE_TIME_THRESHOLD=3600  # アイドルセッションをキルする時間（秒）

# ログ出力関数
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Oracle接続チェック関数
check_oracle_connection() {
    log_message "INFO: Oracle接続チェックを開始します"
    
    sqlplus -S /nolog <<EOF >/dev/null 2>&1
CONNECT / AS SYSDBA
SELECT 1 FROM DUAL;
EXIT
EOF
    
    if [ $? -eq 0 ]; then
        log_message "SUCCESS: Oracle接続が正常です"
        return 0
    else
        log_message "ERROR: Oracle接続に失敗しました"
        return 1
    fi
}

# セッション数をチェックする関数
check_session_count() {
    log_message "INFO: セッション数をチェックします"
    
    local result=$(sqlplus -S /nolog <<EOF
CONNECT / AS SYSDBA
SET PAGESIZE 0 FEEDBACK OFF VERIFY OFF HEADING OFF ECHO OFF
SELECT 
    current_utilization || ',' || limit_value
FROM 
    v\$resource_limit
WHERE 
    resource_name = 'sessions';
EXIT
EOF
)
    
    if [ -z "$result" ]; then
        log_message "ERROR: セッション情報の取得に失敗しました"
        return 1
    fi
    
    local current_sessions=$(echo "$result" | cut -d',' -f1 | tr -d ' ')
    local max_sessions=$(echo "$result" | cut -d',' -f2 | tr -d ' ')
    
    if [ -z "$current_sessions" ] || [ -z "$max_sessions" ]; then
        log_message "ERROR: セッション数のパースに失敗しました"
        return 1
    fi
    
    local usage_percent=$((current_sessions * 100 / max_sessions))
    
    log_message "INFO: 現在のセッション数: $current_sessions / $max_sessions (使用率: ${usage_percent}%)"
    
    if [ $usage_percent -ge $MAX_SESSION_THRESHOLD ]; then
        log_message "WARNING: セッション使用率が${usage_percent}%に達しています（閾値: ${MAX_SESSION_THRESHOLD}%）"
        return 2
    fi
    
    return 0
}

# アイドルセッションをキルする関数
kill_idle_sessions() {
    log_message "INFO: アイドルセッションのクリーンアップを開始します"
    
    # アイドルセッションを取得してキル
    sqlplus -S /nolog <<EOF | tee -a "$LOG_FILE"
CONNECT / AS SYSDBA
SET SERVEROUTPUT ON
DECLARE
    v_kill_count NUMBER := 0;
    v_sql VARCHAR2(200);
BEGIN
    FOR rec IN (
        SELECT 
            s.sid,
            s.serial#,
            s.username,
            s.status,
            s.last_call_et
        FROM 
            v\$session s
        WHERE 
            s.type = 'USER'
            AND s.status = 'INACTIVE'
            AND s.last_call_et > ${IDLE_TIME_THRESHOLD}
            AND s.username IS NOT NULL
            AND s.username NOT IN ('SYS', 'SYSTEM')
    ) LOOP
        BEGIN
            v_sql := 'ALTER SYSTEM KILL SESSION ''' || rec.sid || ',' || rec.serial# || ''' IMMEDIATE';
            EXECUTE IMMEDIATE v_sql;
            v_kill_count := v_kill_count + 1;
            DBMS_OUTPUT.PUT_LINE('[' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS') || '] INFO: セッション ' || rec.sid || ',' || rec.serial# || ' (ユーザー: ' || rec.username || ', アイドル: ' || rec.last_call_et || '秒) をキルしました');
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('[' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS') || '] ERROR: セッション ' || rec.sid || ',' || rec.serial# || ' のキルに失敗: ' || SQLERRM);
        END;
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('[' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS') || '] INFO: ' || v_kill_count || '個のアイドルセッションをキルしました');
END;
/
EXIT
EOF
}

# プロセス数をチェックして調整する関数
check_and_adjust_processes() {
    log_message "INFO: プロセス数をチェックします"
    
    sqlplus -S /nolog <<EOF | tee -a "$LOG_FILE"
CONNECT / AS SYSDBA
SET SERVEROUTPUT ON
DECLARE
    v_current_processes NUMBER;
    v_max_processes NUMBER;
    v_usage_percent NUMBER;
BEGIN
    SELECT value INTO v_current_processes 
    FROM v\$resource_limit 
    WHERE resource_name = 'processes' AND rownum = 1;
    
    SELECT value INTO v_max_processes 
    FROM v\$parameter 
    WHERE name = 'processes';
    
    v_usage_percent := ROUND((v_current_processes / v_max_processes) * 100, 2);
    
    DBMS_OUTPUT.PUT_LINE('[' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS') || '] INFO: プロセス使用状況: ' || v_current_processes || ' / ' || v_max_processes || ' (' || v_usage_percent || '%)');
    
    IF v_usage_percent >= ${MAX_SESSION_THRESHOLD} THEN
        DBMS_OUTPUT.PUT_LINE('[' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS') || '] WARNING: プロセス使用率が高くなっています');
    END IF;
END;
/
EXIT
EOF
}

# リトライ機能付きSQL実行関数
execute_sql_with_retry() {
    local sql_file="$1"
    local retry_count=0
    local wait_time=5
    
    if [ ! -f "$sql_file" ]; then
        log_message "ERROR: SQLファイルが見つかりません: $sql_file"
        return 1
    fi
    
    while [ $retry_count -lt $MAX_RETRIES ]; do
        log_message "INFO: SQLスクリプトを実行します（試行: $((retry_count + 1))/$MAX_RETRIES）"
        
        # セッション数チェック
        check_session_count
        local check_result=$?
        
        if [ $check_result -eq 2 ]; then
            log_message "WARNING: セッション数が多いため、クリーンアップを実行します"
            kill_idle_sessions
            check_and_adjust_processes
            sleep $wait_time
        fi
        
        # SQL実行
        local output=$(sqlplus -S /nolog <<EOF 2>&1
CONNECT / AS SYSDBA
SET ECHO ON
SET SERVEROUTPUT ON
WHENEVER SQLERROR EXIT SQL.SQLCODE
WHENEVER OSERROR EXIT FAILURE
SPOOL ${LOG_FILE}.sql.log APPEND
@${sql_file}
SPOOL OFF
EXIT
EOF
)
        
        local exit_code=$?
        echo "$output" | tee -a "$LOG_FILE"
        
        if [ $exit_code -eq 0 ]; then
            log_message "SUCCESS: SQLスクリプトの実行が完了しました"
            return 0
        else
            # エラー内容をチェック
            if echo "$output" | grep -qiE "ORA-00018|ORA-00020|maximum number of sessions exceeded|maximum number of processes"; then
                log_message "ERROR: セッション/プロセス上限エラーが発生しました（リトライ: $((retry_count + 1))/$MAX_RETRIES）"
                kill_idle_sessions
                ((retry_count++))
                
                if [ $retry_count -lt $MAX_RETRIES ]; then
                    log_message "INFO: ${wait_time}秒待機後、リトライします"
                    sleep $wait_time
                    wait_time=$((wait_time * 2))  # 指数バックオフ
                fi
            else
                log_message "ERROR: SQL実行エラー（セッション以外）: exit code $exit_code"
                log_message "ERROR: エラー詳細:"
                echo "$output" | grep -i "ORA-" | tee -a "$LOG_FILE"
                return 1
            fi
        fi
    done
    
    log_message "ERROR: 最大リトライ回数に達しました。処理を中断します"
    return 1
}

# 環境変数チェック関数
check_oracle_environment() {
    log_message "INFO: Oracle環境変数をチェックします"
    
    if [ -z "$ORACLE_HOME" ]; then
        log_message "ERROR: ORACLE_HOMEが設定されていません"
        return 1
    fi
    
    if [ ! -d "$ORACLE_HOME" ]; then
        log_message "ERROR: ORACLE_HOMEディレクトリが存在しません: $ORACLE_HOME"
        return 1
    fi
    
    if [ ! -x "$ORACLE_HOME/bin/sqlplus" ]; then
        log_message "ERROR: sqlplusが実行できません: $ORACLE_HOME/bin/sqlplus"
        return 1
    fi
    
    log_message "SUCCESS: Oracle環境変数が正しく設定されています"
    log_message "INFO: ORACLE_HOME=$ORACLE_HOME"
    return 0
}

# メイン処理
main() {
    log_message "========== スクリプト開始 =========="
    
    # 環境変数チェック
    check_oracle_environment || exit 1
    
    # Oracle接続チェック
    check_oracle_connection || exit 1
    
    # 初期セッション状態チェック
    check_session_count
    check_and_adjust_processes
    
    # SQLスクリプト実行
    execute_sql_with_retry "$SQL_SCRIPT"
    local result=$?
    
    if [ $result -eq 0 ]; then
        log_message "SUCCESS: すべての処理が正常に完了しました"
    else
        log_message "ERROR: 処理が失敗しました"
        exit 1
    fi
    
    log_message "========== スクリプト終了 =========="
}

# スクリプト実行
main
