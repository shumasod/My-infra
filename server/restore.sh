#!/bin/bash
set -euo pipefail
export PATH=$PATH:/usr/local/bin/

#
# データベースリストアスクリプト
# セキュリティ修正: 2026-01-31
#

TODAY=$(date "+%Y%m%d")
S3_BUCKET=-dumps
DIR="$(cd "$(dirname "$0")" && pwd)"
# mysqlのdumpを管理するディレクトリ
DUMP_DIR="${DIR}/../data"
TEBLE_DUMP_DIR="${DUMP_DIR}/dump_tables"
RDIFF_DIR="${DUMP_DIR}/rdiff"

dbIdentifier="${1:-}"
dbUser="${2:-}"
dbPass="${3:-}"
restoreTime="${4:-}"
slackToken="${5:-}"
slackPayload="${6:-}"

# 必須引数のチェック
if [[ -z "$dbIdentifier" || -z "$dbUser" || -z "$dbPass" ]]; then
    echo "使用方法: $0 <dbIdentifier> <dbUser> <dbPass> [restoreTime] [slackToken] [slackPayload]" >&2
    exit 1
fi

dbHostName=$(aws rds describe-db-instances --db-instance-identifier "$dbIdentifier" --output json | jq -r '.DBInstances[0].Endpoint.Address')

downloadBackup() {
    aws s3 cp "s3://${S3_BUCKET}/${TODAY}" "${RDIFF_DIR}_${TODAY}" --recursive --only-show-errors
}

restoreDatabase() {
    # パスワードを環境変数で渡す（プロセスリストに表示されない）
    # myloaderの設定ファイルを一時的に作成
    local config_file
    config_file=$(mktemp)
    chmod 600 "$config_file"

    cat > "$config_file" <<EOF
[client]
user=$dbUser
password=$dbPass
host=$dbHostName
EOF

    # 設定ファイルを使用してリストア実行
    myloader --defaults-file="$config_file" --directory="${RDIFF_DIR}_${TODAY}" --queries-per-transaction=1000 --threads=200 --compress-protocol --verbose=3

    # 設定ファイルを安全に削除
    rm -f "$config_file"
}

slackNotify() {
    if [[ -z "$slackToken" || -z "$slackPayload" ]]; then
        echo "Skip slack notification due to no argument supplied"
        return
    fi
    # トークンはヘッダーで渡す（比較的安全だが、ログに注意）
    curl -s -H "Content-type: application/json" \
        -H "Authorization: Bearer ${slackToken}" \
        --data "${slackPayload}" \
        -X POST "https://slack.com/api/chat.postMessage"
}

main() {
    # Download backup from s3
    downloadBackup

    # restore database
    restoreDatabase

    # Slack通知
    slackNotify
}

main "$@"
