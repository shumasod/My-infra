#!/bin/bash
set -euo pipefail

#
# データベースバックアップスクリプト
# 作成日: 2025-12-23
# バージョン: 2.0
#
# MySQLデータベースのバックアップを実行します。
# 環境変数またはコマンドライン引数で設定を指定できます。
#

# ===== 設定（定数） =====
readonly PROG_NAME=$(basename "$0")
readonly VERSION="2.0"

# 色定義
readonly COLOR_ERROR='\033[1;31m'
readonly COLOR_SUCCESS='\033[1;32m'
readonly COLOR_INFO='\033[1;36m'
readonly COLOR_RESET='\033[0m'

# ===== グローバル変数 =====
declare DB_USER="${DB_USER:-}"
declare DB_PASS="${DB_PASS:-}"
declare DB_HOST="${DB_HOST:-localhost}"
declare DB_NAME="${DB_NAME:-}"
declare BACKUP_BASE_DIR="${BACKUP_BASE_DIR:-./backups/}"

# ===== ヘルパー関数 =====

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション]

MySQLデータベースのバックアップを実行します。

オプション:
  -h, --help              このヘルプを表示
  -v, --version           バージョン情報を表示
  -u, --user <ユーザー名>   データベースユーザー名
  -p, --password <パスワード> データベースパスワード
  -H, --host <ホスト>      データベースホスト (デフォルト: localhost)
  -d, --database <DB名>   データベース名
  -o, --output <ディレクトリ> バックアップ出力先 (デフォルト: ./backups/)

環境変数:
  DB_USER              データベースユーザー名
  DB_PASS              データベースパスワード
  DB_HOST              データベースホスト
  DB_NAME              データベース名
  BACKUP_BASE_DIR      バックアップ出力先ディレクトリ

例:
  # 環境変数を使用
  export DB_USER="root"
  export DB_PASS="password"
  export DB_NAME="mydb"
  $PROG_NAME

  # コマンドライン引数を使用
  $PROG_NAME -u root -p password -d mydb -o /var/backups/

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

validate_required_variables() {
    local missing_vars=()

    [[ -z "$DB_USER" ]] && missing_vars+=("DB_USER またはオプション --user")
    [[ -z "$DB_PASS" ]] && missing_vars+=("DB_PASS またはオプション --password")
    [[ -z "$DB_NAME" ]] && missing_vars+=("DB_NAME またはオプション --database")

    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        error_exit "以下の必須設定が指定されていません: ${missing_vars[*]}"
    fi
}

check_mysqldump_available() {
    if ! command -v mysqldump &> /dev/null; then
        error_exit "mysqldump コマンドが見つかりません。MySQL クライアントをインストールしてください"
    fi
}

# ===== メインロジック =====

create_backup_directory() {
    if [[ ! -d "$BACKUP_BASE_DIR" ]]; then
        info_message "バックアップディレクトリを作成: $BACKUP_BASE_DIR"
        mkdir -p "$BACKUP_BASE_DIR" || error_exit "バックアップディレクトリの作成に失敗しました: $BACKUP_BASE_DIR"
    fi
}

perform_backup() {
    local timestamp
    timestamp=$(date "+%Y%m%d%H%M%S")

    local backup_file="${BACKUP_BASE_DIR}${DB_NAME}_${timestamp}.dump"

    info_message "データベースバックアップを開始: $DB_NAME"
    info_message "出力先: $backup_file"

    # mysqldump実行
    # パスワードを安全に渡すため、環境変数MYSQL_PWDを使用
    if MYSQL_PWD="$DB_PASS" mysqldump \
        --add-locks \
        --disable-keys \
        --extended-insert \
        --lock-all-tables \
        --quick \
        --quote-names \
        -u "$DB_USER" \
        -h "$DB_HOST" \
        -B "$DB_NAME" \
        > "$backup_file"; then

        success_message "バックアップが正常に完了しました: $backup_file"

        # ファイルサイズを表示
        local file_size
        file_size=$(du -h "$backup_file" | cut -f1)
        info_message "バックアップファイルサイズ: $file_size"

        return 0
    else
        error_exit "バックアップに失敗しました"
    fi
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
            -u|--user)
                [[ $# -lt 2 ]] && error_exit "--user オプションには値が必要です"
                DB_USER="$2"
                shift 2
                ;;
            -p|--password)
                [[ $# -lt 2 ]] && error_exit "--password オプションには値が必要です"
                DB_PASS="$2"
                shift 2
                ;;
            -H|--host)
                [[ $# -lt 2 ]] && error_exit "--host オプションには値が必要です"
                DB_HOST="$2"
                shift 2
                ;;
            -d|--database)
                [[ $# -lt 2 ]] && error_exit "--database オプションには値が必要です"
                DB_NAME="$2"
                shift 2
                ;;
            -o|--output)
                [[ $# -lt 2 ]] && error_exit "--output オプションには値が必要です"
                BACKUP_BASE_DIR="$2"
                # ディレクトリパスの末尾にスラッシュを追加
                [[ "$BACKUP_BASE_DIR" != */ ]] && BACKUP_BASE_DIR="${BACKUP_BASE_DIR}/"
                shift 2
                ;;
            -*)
                error_exit "不明なオプション: $1"
                ;;
            *)
                error_exit "予期しない引数: $1"
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

    # mysqldumpコマンドの確認
    check_mysqldump_available

    # バックアップディレクトリの作成
    create_backup_directory

    # バックアップ実行
    perform_backup

    exit 0
}

# スクリプト実行
main "$@"
