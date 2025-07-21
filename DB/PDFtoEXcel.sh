#!/bin/ksh
#
# 名前: db_backup_to_s3.ksh
# 説明: データベースの情報をCSVとしてS3にバックアップするスクリプト
# 使用方法: ./db_backup_to_s3.ksh [-d database] [-u user] [-p password] [-h host] [-b bucket] [-P prefix] [-r region] [-v]
#   -d: データベース名 (必須)
#   -u: データベースユーザー名 (デフォルト: root)
#   -p: データベースパスワード
#   -h: データベースホスト (デフォルト: localhost)
#   -b: S3バケット名 (必須)
#   -P: S3プレフィックス/パス (デフォルト: backups/db)
#   -r: AWSリージョン (デフォルト: ap-northeast-1)
#   -v: 詳細モードを有効にする
#

# エラーハンドリング関数
error_exit() {
    print -u2 "エラー: $1"
    exit 1
}

# ログ出力関数
log_msg() {
    if [[ $verbose -eq 1 ]]; then
        print "$(date '+%Y-%m-%d %H:%M:%S') - $1"
    fi
}

# 使用方法を表示
usage() {
    cat <<EOF
使用方法: $0 [-d database] [-u user] [-p password] [-h host] [-b bucket] [-P prefix] [-r region] [-v]
  -d: データベース名 (必須)
  -u: データベースユーザー名 (デフォルト: root)
  -p: データベースパスワード
  -h: データベースホスト (デフォルト: localhost)
  -b: S3バケット名 (必須)
  -P: S3プレフィックス/パス (デフォルト: backups/db)
  -r: AWSリージョン (デフォルト: ap-northeast-1)
  -v: 詳細モードを有効にする
EOF
    exit 1
}

# デフォルト値の設定
db_user="root"
db_host="localhost"
s3_prefix="backups/db"
aws_region="ap-northeast-1"
verbose=0
temp_dir="/tmp/db_backup_$(date '+%Y%m%d%H%M%S')"

# コマンドライン引数の解析
while getopts ":d:u:p:h:b:P:r:v" opt; do
    case $opt in
        d) db_name="$OPTARG" ;;
        u) db_user="$OPTARG" ;;
        p) db_pass="$OPTARG" ;;
        h) db_host="$OPTARG" ;;
        b) s3_bucket="$OPTARG" ;;
        P) s3_prefix="$OPTARG" ;;
        r) aws_region="$OPTARG" ;;
        v) verbose=1 ;;
        \?) usage ;;
    esac
done

# 必須パラメータのチェック
[[ -z "$db_name" ]] && error_exit "データベース名(-d)は必須です"
[[ -z "$s3_bucket" ]] && error_exit "S3バケット名(-b)は必須です"

# パスワードが指定されていない場合は入力を求める
if [[ -z "$db_pass" ]]; then
    print -n "データベースパスワードを入力してください: "
    read -s db_pass
    print ""
fi

# 必要なツールの確認
check_command() {
    command -v "$1" >/dev/null 2>&1 || error_exit "$1 が見つかりません。インストールしてください。"
}

check_command mysql
check_command mysqldump
check_command aws
check_command gzip

# テンポラリディレクトリの作成
mkdir -p "$temp_dir" || error_exit "テンポラリディレクトリ $temp_dir を作成できませんでした。"
log_msg "テンポラリディレクトリ $temp_dir を作成しました。"

# MySQL接続テスト
log_msg "データベース接続をテストしています..."
mysql -h "$db_host" -u "$db_user" -p"$db_pass" -e "use $db_name" >/dev/null 2>&1 || 
    error_exit "データベース接続に失敗しました。認証情報を確認してください。"

# テーブル一覧の取得
log_msg "テーブル一覧を取得しています..."
tables=$(mysql -h "$db_host" -u "$db_user" -p"$db_pass" -N -e "SHOW TABLES FROM $db_name" 2>/dev/null)
[[ -z "$tables" ]] && error_exit "テーブルが見つかりません。データベース名を確認してください。"

table_count=$(echo "$tables" | wc -l)
log_msg "$table_count 個のテーブルを処理します。"

# 各テーブルをCSVに変換
current=0
timestamp=$(date '+%Y%m%d_%H%M%S')
backup_dir="${temp_dir}/${db_name}_${timestamp}"
mkdir -p "$backup_dir" || error_exit "バックアップディレクトリ $backup_dir を作成できませんでした。"

for table in $tables; do
    current=$((current + 1))
    log_msg "[$current/$table_count] テーブル '$table' をエクスポートしています..."
    
    # ヘッダー（列名）を取得
    mysql -h "$db_host" -u "$db_user" -p"$db_pass" -N -e "SHOW COLUMNS FROM $db_name.$table" 2>/dev/null | 
        awk '{print $1}' | tr '\n' ',' | sed 's/,$/\n/' > "${backup_dir}/${table}.csv"
    
    # データをCSVとしてエクスポート
    mysql -h "$db_host" -u "$db_user" -p"$db_pass" -N -e "SELECT * FROM $db_name.$table INTO OUTFILE '/tmp/${table}_temp.csv' 
        FIELDS TERMINATED BY ',' 
        OPTIONALLY ENCLOSED BY '\"' 
        LINES TERMINATED BY '\n'" 2>/dev/null
    
    # 一時ファイルがファイルシステムのアクセス権の関係で作成できない場合の代替方法
    if [[ ! -f "/tmp/${table}_temp.csv" ]]; then
        log_msg "代替方法でエクスポートしています..."
        mysql -h "$db_host" -u "$db_user" -p"$db_pass" -N -e "SELECT * FROM $db_name.$table" 2>/dev/null | 
            sed 's/\t/,/g' >> "${backup_dir}/${table}.csv"
    else
        # 一時ファイルの内容をバックアップディレクトリのCSVファイルに追加
        cat "/tmp/${table}_temp.csv" >> "${backup_dir}/${table}.csv"
        rm "/tmp/${table}_temp.csv"
    fi
    
    log_msg "[$current/$table_count] テーブル '$table' のエクスポートが完了しました。"
done

# CSVファイルを圧縮
log_msg "CSVファイルを圧縮しています..."
archive_name="${db_name}_${timestamp}.tar.gz"
tar -czf "${temp_dir}/${archive_name}" -C "${temp_dir}" "$(basename "$backup_dir")" || 
    error_exit "CSVファイルの圧縮に失敗しました。"

# S3にアップロード
log_msg "S3にアップロードしています..."
s3_path="s3://${s3_bucket}/${s3_prefix}/${archive_name}"
aws s3 cp "${temp_dir}/${archive_name}" "$s3_path" --region "$aws_region" || 
    error_exit "S3へのアップロードに失敗しました。"

# クリーンアップ
log_msg "一時ファイルを削除しています..."
rm -rf "$temp_dir"

log_msg "バックアップが完了しました。"
print "データベース $db_name のバックアップが完了しました。"
print "バックアップファイル: $s3_path"
exit 0
