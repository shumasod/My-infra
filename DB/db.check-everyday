#!/bin/bash

# 設定
output_file="/tmp/db_load.log"
db_type="mysql"  # 'mysql', 'postgresql', 'oracle'のいずれかを指定
database="example"
username="root"
password="password"
host="localhost"
port="3306"  # MySQLのデフォルトポート

# データベース固有の設定
case $db_type in
  mysql)
    connection_cmd="mysql -h $host -P $port -u $username -p$password -D $database -N -e"
    load_query="SHOW GLOBAL STATUS LIKE 'Threads_running';"
    ;;
  postgresql)
    connection_cmd="PGPASSWORD=$password psql -h $host -p $port -U $username -d $database -t -c"
    load_query="SELECT count(*) FROM pg_stat_activity WHERE state = 'active';"
    ;;
  oracle)
    connection_cmd="sqlplus -S $username/$password@$host:$port/$database <<EOF"
    load_query="SELECT COUNT(*) FROM v\$session WHERE status = 'ACTIVE' AND type != 'BACKGROUND';"
    ;;
  *)
    echo "エラー: サポートされていないデータベースタイプです。" >&2
    exit 1
    ;;
esac

# メイン処理
now=$(date +"%Y-%m-%d %H:%M:%S")

# 負荷を取得
if [ "$db_type" = "oracle" ]; then
  load_avg=$(echo "$connection_cmd
  $load_query
  EXIT;
EOF" | sed -n '3p')
else
  load_avg=$($connection_cmd "$load_query" | awk '{print $2}')
fi

# 出力
echo "$now,$load_avg" >> $output_file

# エラーチェック
if [ $? -ne 0 ]; then
    echo "エラー: データベースへの接続または負荷の取得に失敗しました。" >&2
    exit 1
fi