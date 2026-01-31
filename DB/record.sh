#!/bin/bash
set -euo pipefail

#
# データベースレコード確認スクリプト
# セキュリティ修正: 2026-01-31
#
# 環境変数から認証情報を読み込みます:
#   DB_USER, DB_PASS, DB_NAME, DB_HOST, TEST_CD
#

# 環境変数のチェック
check_required_env() {
    local missing=()
    [[ -z "${DB_USER:-}" ]] && missing+=("DB_USER")
    [[ -z "${DB_PASS:-}" ]] && missing+=("DB_PASS")
    [[ -z "${DB_NAME:-}" ]] && missing+=("DB_NAME")
    [[ -z "${DB_HOST:-}" ]] && missing+=("DB_HOST")
    [[ -z "${TEST_CD:-}" ]] && missing+=("TEST_CD")

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "[ERROR] 以下の環境変数が設定されていません: ${missing[*]}" >&2
        echo "使用例:" >&2
        echo "  export DB_USER='username'" >&2
        echo "  export DB_PASS='password'" >&2
        echo "  export DB_NAME='database'" >&2
        echo "  export DB_HOST='hostname'" >&2
        echo "  export TEST_CD='test_code'" >&2
        exit 1
    fi
}

# SQLインジェクション対策: 入力値のバリデーション
validate_identifier() {
    local value="$1"
    local name="$2"
    # 英数字とアンダースコアのみ許可
    if [[ ! "$value" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "[ERROR] ${name}に不正な文字が含まれています: $value" >&2
        exit 1
    fi
}

# MySQLクエリを実行し、結果を取得する関数
# パスワードはMYSQL_PWD環境変数で渡す（プロセスリストに表示されない）
execute_query() {
    local query="$1"
    MYSQL_PWD="$DB_PASS" mysql -u"$DB_USER" -h"$DB_HOST" -D"$DB_NAME" -se "$query"
}

# エラーメッセージを表示し、スクリプトを終了する関数
exit_with_error() {
    local error_message="$1"
    echo "[ERROR] $error_message" >&2
    exit 1
}

# メイン処理
main() {
    # 環境変数チェック
    check_required_env

    # 入力値のバリデーション
    validate_identifier "$TEST_CD" "TEST_CD"

    # レコード数を取得（プリペアドステートメント相当の安全なクエリ）
    # TEST_CDはバリデーション済みなので安全
    local query="SELECT COUNT(*) FROM test_table WHERE test_cd='$TEST_CD'"
    local count
    count=$(execute_query "$query")

    # クエリ実行のエラーチェック
    if [[ -z "$count" ]]; then
        exit_with_error "test_table参照失敗。シェルスクリプトを強制終了する。"
    fi

    # レコード数のチェック
    if [[ "$count" -eq 0 ]]; then
        exit_with_error "test_tableにデータなし。シェルスクリプトを強制終了する。"
    fi

    echo "正常に処理が完了しました。レコード数: $count"
}

# スクリプトの実行
main "$@"