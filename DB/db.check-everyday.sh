#!/bin/bash

# 設定
CONFIG_FILE="/path/to/config.ini"
OUTPUT_FILE="/tmp/db_load.log"

# 関数: エラーメッセージを表示して終了
error_exit() {
    echo "エラー: $1" >&2
    exit 1
}

# 関数: 設定ファイルから値を読み取る
read_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        error_exit "設定ファイル $CONFIG_FILE が見つかりません。"
    fi
    
    # 設定ファイルから値を読み込む
    DB_TYPE=$(awk -F '=' '/^db_type/ {print $2}' "$CONFIG_FILE" | tr -d ' ')
    DATABASE=$(awk -F '=' '/^database/ {print $2}' "$CONFIG_FILE" | tr -d ' ')
    USERNAME=$(awk -F '=' '/^username/ {print $2}' "$CONFIG_FILE" | tr -d ' ')
    PASSWORD=$(awk -F '=' '/^password/ {print $2}' "$CONFIG_FILE" | tr -d ' ')
    HOST=$(awk -F '=' '/^host/ {print $2}' "$CONFIG_FILE" | tr -d ' ')
    PORT=$(awk -F '=' '/^port/ {print $2}' "$CONFIG_FILE" | tr -d ' ')

    # 必須項目のチェック
    [ -z "$DB_TYPE" ] && error_exit "DB_TYPEが設定されていません。"
    [ -z "$DATABASE" ] && error_exit "DATABASEが設定されていません。"
    [ -z "$USERNAME" ] && error_exit "USERNAMEが設定されていません。"
    [ -z "$PASSWORD" ] && error_exit "PASSWORDが設定されていません。"
    [ -z "$HOST" ] && error_exit "HOSTが設定されていません。"
    [ -z "$PORT" ] && error_exit "PORTが設定されていません。"
}

# 関数: データベース固有の設定
set_db_specific_config() {
    case $DB_TYPE in
        mysql)
            CONNECTION_CMD="mysql -h $HOST -P $PORT -u $USERNAME -p$PASSWORD -D $DATABASE -N -e"
            LOAD_QUERY="SHOW GLOBAL STATUS LIKE 'Threads_running';"
            ;;
        postgresql)
            CONNECTION_CMD="PGPASSWORD=$PASSWORD psql -h $HOST -p $PORT -U $USERNAME -d $DATABASE -t -c"
            LOAD_QUERY="SELECT count(*) FROM pg_stat_activity WHERE state = 'active';"
            ;;
        oracle)
            CONNECTION_CMD="sqlplus -S $USERNAME/$PASSWORD@$HOST:$PORT/$DATABASE <<EOF"
            LOAD_QUERY="SELECT COUNT(*) FROM v\$session WHERE status = 'ACTIVE' AND type != 'BACKGROUND';"
            ;;
        *)
            error_exit "サポートされていないデータベースタイプです: $DB_TYPE"
            ;;
    esac
}

# 関数: データベース負荷を取得
get_db_load() {
    if [ "$DB_TYPE" = "oracle" ]; then
        load_avg=$(echo "$CONNECTION_CMD
        $LOAD_QUERY
        EXIT;
EOF" | sed -n '3p')
    else
        load_avg=$($CONNECTION_CMD "$LOAD_QUERY" | awk '{print $2}')
    fi

    if [ -z "$load_avg" ]; then
        error_exit "データベース負荷の取得に失敗しました。"
    fi

    echo "$load_avg"
}

# メイン処理
main() {
    read_config
    set_db_specific_config

    now=$(date +"%Y-%m-%d %H:%M:%S")
    load_avg=$(get_db_load)

    echo "$now,$load_avg" >> "$OUTPUT_FILE"

    if [ $? -ne 0 ]; then
        error_exit "データベース負荷の記録に失敗しました。"
    fi

    echo "データベース負荷を正常に記録しました: $now, $load_avg"
}

# スクリプトの実行
main