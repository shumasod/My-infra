#!/bin/bash

# データベース接続情報（環境変数または設定ファイルから読み込むことを推奨）
DB_USER="your_username"
DB_PASS="your_password"
DB_NAME="your_database"
DB_HOST="your_host"
TEST_CD="your_test_code"

# MySQLクエリを実行し、結果を取得する関数
execute_query() {
    local query="$1"
    result=$(mysql -u"$DB_USER" -p"$DB_PASS" -h"$DB_HOST" -D"$DB_NAME" -se "$query")
    echo "$result"
}

# エラーメッセージを表示し、スクリプトを終了する関数
exit_with_error() {
    local error_message="$1"
    echo "[ERROR] $error_message"
    exit 1
}

# メイン処理
main() {
    # レコード数を取得
    query="SELECT COUNT(*) FROM test_table WHERE test_cd='$TEST_CD'"
    count=$(execute_query "$query")

    # クエリ実行のエラーチェック
    if [ $? -ne 0 ]; then
        exit_with_error "test_table参照失敗。シェルスクリプトを強制終了する。"
    fi

    # レコード数のチェック
    if [ "$count" -eq 0 ]; then
        exit_with_error "test_tableにデータなし。シェルスクリプトを強制終了する。"
    fi

    echo "正常に処理が完了しました。レコード数: $count"
}

# スクリプトの実行
main