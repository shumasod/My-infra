#!/bin/bash
set -euo pipefail

#
# データベースCSVバックアップスクリプト
# セキュリティ修正: 2026-01-31
#

# エラーハンドリング関数
error_exit() {
    echo "エラー: $1" >&2
    exit 1
}

# ログ出力関数
log_msg() {
    if [[ ${verbose:-0} -eq 1 ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
    fi
}

# 識別子のバリデーション（SQLインジェクション・パストラバーサル対策）
validate_identifier() {
    local value="$1"
    local name="$2"
    # 英数字とアンダースコアのみ許可（パストラバーサル防止のため / や .. を禁止）
    if [[ ! "$value" =~ ^[a-zA-Z0-9_]+$ ]]; then
        error_exit "${name}に不正な文字が含まれています: $value"
    fi
}

# MySQL実行ヘルパー（パスワードをプロセスリストに表示しない）
mysql_exec() {
    MYSQL_PWD="$db_pass" mysql -h "$db_host" -u "$db_user" "$@"
}

# 使用方法を表示
usage() {
    cat <<EOF
使用方法: $0 [-d database] [-u user] [-p password] [-h host] [-b bucket] [-P prefix] [-r region] [-v]
  -d: データベース名 (必須)
  -u: データベースユーザー名 (デフォルト: root)
  -p: データベースパスワード (環境変数 DB_PASS も使用可)
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

# パスワードが指定されていない場合は環境変数または入力を求める
if [[ -z "${db_pass:-}" ]]; then
    if [[ -n "${DB_PASS:-}" ]]; then
        db_pass="$DB_PASS"
    else
        echo -n "データベースパスワードを入力してください: "
        read -rs db_pass
        echo ""
    fi
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

# データベース名のバリデーション
validate_identifier "$db_name" "データベース名"

# MySQL接続テスト
log_msg "データベース接続をテストしています..."
mysql_exec -e "use $db_name" >/dev/null 2>&1 ||
    error_exit "データベース接続に失敗しました。認証情報を確認してください。"

# テーブル一覧の取得
log_msg "テーブル一覧を取得しています..."
tables=$(mysql_exec -N -e "SHOW TABLES FROM $db_name" 2>/dev/null)
[[ -z "$tables" ]] && error_exit "テーブルが見つかりません。データベース名を確認してください。"

table_count=$(echo "$tables" | wc -l)
log_msg "$table_count 個のテーブルを処理します。"

# 各テーブルをCSVに変換
current=0
timestamp=$(date '+%Y%m%d_%H%M%S')
backup_dir="${temp_dir}/${db_name}_${timestamp}"
mkdir -p "$backup_dir" || error_exit "バックアップディレクトリ $backup_dir を作成できませんでした。"

for table in $tables; do
    # テーブル名のバリデーション（SQLインジェクション・パストラバーサル対策）
    if ! validate_identifier "$table" "テーブル名" 2>/dev/null; then
        log_msg "警告: テーブル '$table' をスキップします（不正な名前）"
        continue
    fi

    current=$((current + 1))
    log_msg "[$current/$table_count] テーブル '$table' をエクスポートしています..."

    # ヘッダー（列名）を取得
    mysql_exec -N -e "SHOW COLUMNS FROM $db_name.$table" 2>/dev/null |
        awk '{print $1}' | tr '\n' ',' | sed 's/,$/\n/' > "${backup_dir}/${table}.csv"

    # 安全な一時ファイル名（タイムスタンプ付き）
    temp_file="/tmp/${db_name}_${table}_${timestamp}_temp.csv"

    # データをCSVとしてエクスポート
    mysql_exec -N -e "SELECT * FROM $db_name.$table INTO OUTFILE '$temp_file'
        FIELDS TERMINATED BY ','
        OPTIONALLY ENCLOSED BY '\"'
        LINES TERMINATED BY '\n'" 2>/dev/null || true

    # 一時ファイルがファイルシステムのアクセス権の関係で作成できない場合の代替方法
    if [[ ! -f "$temp_file" ]]; then
        log_msg "代替方法でエクスポートしています..."
        mysql_exec -N -e "SELECT * FROM $db_name.$table" 2>/dev/null |
            sed 's/\t/,/g' >> "${backup_dir}/${table}.csv"
    else
        # 一時ファイルの内容をバックアップディレクトリのCSVファイルに追加
        cat "$temp_file" >> "${backup_dir}/${table}.csv"
        rm -f "$temp_file"
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
echo "データベース $db_name のバックアップが完了しました。"
echo "バックアップファイル: $s3_path"
exit 0
