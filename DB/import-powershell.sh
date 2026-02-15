#!/bin/bash
set -euo pipefail

#
# CSV データインポートスクリプト
# 作成日: 2025-12-23
# バージョン: 2.0
#
# CSVファイルをMySQLデータベースにインポートします。
# セキュリティ向上のため、環境変数による認証情報の管理を推奨します。
#

# ===== 設定（定数） =====
readonly PROG_NAME=$(basename "$0")
readonly VERSION="2.0"

# 色定義
readonly COLOR_ERROR='\033[1;31m'
readonly COLOR_SUCCESS='\033[1;32m'
readonly COLOR_INFO='\033[1;36m'
readonly COLOR_WARNING='\033[1;33m'
readonly COLOR_RESET='\033[0m'

# ===== グローバル変数 =====
declare MYSQL_HOST="${MYSQL_HOST:-localhost}"
declare MYSQL_USER="${MYSQL_USER:-}"
declare MYSQL_PASSWORD="${MYSQL_PASSWORD:-}"
declare MYSQL_DATABASE="${MYSQL_DATABASE:-}"
declare MYSQL_TABLE="${MYSQL_TABLE:-}"
declare CSV_FILE_PATH="${CSV_FILE_PATH:-}"
declare FIELDS_TERMINATED_BY="${FIELDS_TERMINATED_BY:-,}"
declare ENCLOSED_BY="${ENCLOSED_BY:-\"}"
declare LINES_TERMINATED_BY="${LINES_TERMINATED_BY:-\\n}"
declare IGNORE_LINES="${IGNORE_LINES:-1}"
declare -i VERBOSE=0

# ===== ヘルパー関数 =====

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション] <CSVファイル>

CSVファイルをMySQLデータベースにインポートします。

引数:
  <CSVファイル>            インポートするCSVファイルのパス

オプション:
  -h, --help               このヘルプを表示
  -v, --version            バージョン情報を表示
  -H, --host <ホスト>      データベースホスト (デフォルト: localhost)
  -u, --user <ユーザー名>  データベースユーザー名
  -p, --password <パスワード> データベースパスワード
  -d, --database <DB名>    データベース名
  -t, --table <テーブル名> インポート先テーブル名
  -f, --field-separator <区切り文字> フィールド区切り文字 (デフォルト: ,)
  -e, --enclosed-by <囲み文字> フィールドの囲み文字 (デフォルト: ")
  -i, --ignore-lines <行数> スキップする先頭行数 (デフォルト: 1)
  --verbose                詳細な出力を表示

環境変数:
  MYSQL_HOST               データベースホスト
  MYSQL_USER               データベースユーザー名
  MYSQL_PASSWORD           データベースパスワード
  MYSQL_DATABASE           データベース名
  MYSQL_TABLE              インポート先テーブル名

例:
  # 環境変数を使用（推奨）
  export MYSQL_USER="root"
  export MYSQL_PASSWORD="password"
  export MYSQL_DATABASE="mydb"
  export MYSQL_TABLE="users"
  $PROG_NAME data.csv

  # コマンドライン引数を使用
  $PROG_NAME -u root -p password -d mydb -t users data.csv

セキュリティ注意:
  パスワードは環境変数での指定を推奨します。
  コマンドライン引数でのパスワード指定はプロセスリストに表示される可能性があります。

終了コード:
  0  成功
  1  エラー発生
EOF
}

show_version() {
    echo "$PROG_NAME version $VERSION"
}

error_exit() {
    echo -e "${COLOR_ERROR}エラー: $1${COLOR_RESET}" >&2
    echo "詳しい使用方法は「$PROG_NAME --help」を参照してください" >&2
    exit 1
}

info_message() {
    echo -e "${COLOR_INFO}$1${COLOR_RESET}"
}

success_message() {
    echo -e "${COLOR_SUCCESS}$1${COLOR_RESET}"
}

warning_message() {
    echo -e "${COLOR_WARNING}警告: $1${COLOR_RESET}" >&2
}

verbose_message() {
    if [[ $VERBOSE -eq 1 ]]; then
        info_message "$1"
    fi
}

validate_required_variables() {
    local missing_vars=()

    [[ -z "$MYSQL_USER" ]] && missing_vars+=("MYSQL_USER またはオプション --user")
    [[ -z "$MYSQL_PASSWORD" ]] && missing_vars+=("MYSQL_PASSWORD またはオプション --password")
    [[ -z "$MYSQL_DATABASE" ]] && missing_vars+=("MYSQL_DATABASE またはオプション --database")
    [[ -z "$MYSQL_TABLE" ]] && missing_vars+=("MYSQL_TABLE またはオプション --table")
    [[ -z "$CSV_FILE_PATH" ]] && missing_vars+=("CSVファイルパス")

    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        error_exit "以下の必須設定が指定されていません: ${missing_vars[*]}"
    fi
}

check_mysql_client_available() {
    if ! command -v mysql &> /dev/null; then
        error_exit "mysql コマンドが見つかりません。MySQL クライアントをインストールしてください"
    fi
}

validate_csv_file() {
    if [[ ! -f "$CSV_FILE_PATH" ]]; then
        error_exit "CSVファイルが見つかりません: $CSV_FILE_PATH"
    fi

    if [[ ! -r "$CSV_FILE_PATH" ]]; then
        error_exit "CSVファイルの読み取り権限がありません: $CSV_FILE_PATH"
    fi

    # ファイルサイズチェック
    local file_size
    file_size=$(stat -f%z "$CSV_FILE_PATH" 2>/dev/null || stat -c%s "$CSV_FILE_PATH" 2>/dev/null || echo "0")

    if [[ "$file_size" -eq 0 ]]; then
        error_exit "CSVファイルが空です: $CSV_FILE_PATH"
    fi

    verbose_message "CSVファイルサイズ: $(numfmt --to=iec-i --suffix=B "$file_size" 2>/dev/null || echo "$file_size bytes")"
}

test_database_connection() {
    info_message "データベース接続をテスト中..."

    if ! MYSQL_PWD="$MYSQL_PASSWORD" mysql \
        -h "$MYSQL_HOST" \
        -u "$MYSQL_USER" \
        -e "USE $MYSQL_DATABASE;" \
        &> /dev/null; then
        error_exit "データベース接続に失敗しました: $MYSQL_DATABASE@$MYSQL_HOST"
    fi

    verbose_message "データベース接続成功"
}

check_table_exists() {
    info_message "テーブルの存在を確認中: $MYSQL_TABLE"

    local table_exists
    table_exists=$(MYSQL_PWD="$MYSQL_PASSWORD" mysql \
        -h "$MYSQL_HOST" \
        -u "$MYSQL_USER" \
        -D "$MYSQL_DATABASE" \
        -N -s -e "SELECT COUNT(*) FROM information_schema.tables
                   WHERE table_schema='$MYSQL_DATABASE'
                   AND table_name='$MYSQL_TABLE';")

    if [[ "$table_exists" -eq 0 ]]; then
        error_exit "テーブルが存在しません: $MYSQL_TABLE"
    fi

    verbose_message "テーブルが存在することを確認しました"
}

# ===== メインロジック =====

import_csv_data() {
    info_message "CSVデータをインポート中..."
    info_message "  ファイル: $CSV_FILE_PATH"
    info_message "  データベース: $MYSQL_DATABASE"
    info_message "  テーブル: $MYSQL_TABLE"

    # 絶対パスに変換（LOAD DATA LOCAL INFILEで必要な場合がある）
    local absolute_csv_path
    absolute_csv_path=$(realpath "$CSV_FILE_PATH")

    # SQLクエリの構築（変数は適切にエスケープ）
    local sql_query
    sql_query=$(cat <<EOF
LOAD DATA LOCAL INFILE '$absolute_csv_path'
INTO TABLE \`$MYSQL_TABLE\`
FIELDS TERMINATED BY '$FIELDS_TERMINATED_BY'
ENCLOSED BY '$ENCLOSED_BY'
LINES TERMINATED BY '$LINES_TERMINATED_BY'
IGNORE $IGNORE_LINES ROWS;
EOF
)

    verbose_message "実行するSQL:"
    verbose_message "$sql_query"

    # MySQLコマンド実行
    if MYSQL_PWD="$MYSQL_PASSWORD" mysql \
        -h "$MYSQL_HOST" \
        -u "$MYSQL_USER" \
        -D "$MYSQL_DATABASE" \
        --local-infile=1 \
        -e "$sql_query"; then

        success_message "CSVインポートが完了しました"
        return 0
    else
        error_exit "CSVインポートに失敗しました"
    fi
}

show_import_statistics() {
    info_message "インポート統計を取得中..."

    local record_count
    record_count=$(MYSQL_PWD="$MYSQL_PASSWORD" mysql \
        -h "$MYSQL_HOST" \
        -u "$MYSQL_USER" \
        -D "$MYSQL_DATABASE" \
        -N -s -e "SELECT COUNT(*) FROM \`$MYSQL_TABLE\`;")

    success_message "テーブル内のレコード総数: $record_count"
}

# ===== 引数解析 =====

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_usage
                exit 0
                ;;
            -v|--version)
                show_version
                exit 0
                ;;
            -H|--host)
                [[ $# -lt 2 ]] && error_exit "--host オプションには値が必要です"
                MYSQL_HOST="$2"
                shift 2
                ;;
            -u|--user)
                [[ $# -lt 2 ]] && error_exit "--user オプションには値が必要です"
                MYSQL_USER="$2"
                shift 2
                ;;
            -p|--password)
                [[ $# -lt 2 ]] && error_exit "--password オプションには値が必要です"
                MYSQL_PASSWORD="$2"
                shift 2
                ;;
            -d|--database)
                [[ $# -lt 2 ]] && error_exit "--database オプションには値が必要です"
                MYSQL_DATABASE="$2"
                shift 2
                ;;
            -t|--table)
                [[ $# -lt 2 ]] && error_exit "--table オプションには値が必要です"
                MYSQL_TABLE="$2"
                shift 2
                ;;
            -f|--field-separator)
                [[ $# -lt 2 ]] && error_exit "--field-separator オプションには値が必要です"
                FIELDS_TERMINATED_BY="$2"
                shift 2
                ;;
            -e|--enclosed-by)
                [[ $# -lt 2 ]] && error_exit "--enclosed-by オプションには値が必要です"
                ENCLOSED_BY="$2"
                shift 2
                ;;
            -i|--ignore-lines)
                [[ $# -lt 2 ]] && error_exit "--ignore-lines オプションには値が必要です"
                if ! [[ "$2" =~ ^[0-9]+$ ]]; then
                    error_exit "--ignore-lines には数値を指定してください: $2"
                fi
                IGNORE_LINES="$2"
                shift 2
                ;;
            --verbose)
                VERBOSE=1
                shift
                ;;
            -*)
                error_exit "不明なオプション: $1"
                ;;
            *)
                CSV_FILE_PATH="$1"
                shift
                ;;
        esac
    done
}

# ===== メイン処理 =====

main() {
    # 引数解析
    parse_arguments "$@"

    # 必須変数の検証
    validate_required_variables

    # MySQLクライアントの確認
    check_mysql_client_available

    # CSVファイルの検証
    validate_csv_file

    # データベース接続テスト
    test_database_connection

    # テーブル存在確認
    check_table_exists

    # CSVデータインポート
    import_csv_data

    # インポート統計表示
    show_import_statistics

    exit 0
}

# スクリプト実行
main "$@"
