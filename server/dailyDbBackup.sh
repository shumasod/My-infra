#!/bin/bash
set -euo pipefail
export PATH=$PATH:/usr/local/bin/

#
# 日次データベースバックアップ圧縮スクリプト
# セキュリティ修正: 2026-01-31
#

S3_BUCKET=dumps
DEFAULT_YESTERDAY=$(date --date="yesterday" +"%Y%m%d")
YESTERDAY="${1:-$DEFAULT_YESTERDAY}"

# 日付形式のバリデーション
if [[ ! "$YESTERDAY" =~ ^[0-9]{8}$ ]]; then
    echo "[ERROR] 不正な日付形式: $YESTERDAY (YYYYMMDD形式で指定してください)" >&2
    exit 1
fi

main() {
    # create temporary working folder
    echo "[INFO] 一時フォルダー作成..."
    tmp_dir=$(mktemp -d -t "dbDailyBackup-$(date +%Y-%m-%d-%H-%M-%S)-XXXXXXXXXX")
    trap 'rm -rf -- "$tmp_dir"' EXIT

    if [[ $(aws s3 ls "s3://${S3_BUCKET}/${YESTERDAY}/" | head -n 1) ]]; then
        echo "[INFO] S3から昨日バックアップ分取得..."
        aws s3 sync "s3://${S3_BUCKET}/${YESTERDAY}/" "${tmp_dir}/${YESTERDAY}" --only-show-errors

        echo "[INFO] データ圧縮..."
        tar -cf "${tmp_dir}/${YESTERDAY}.tar" -C "$tmp_dir" "$YESTERDAY"

        echo "[INFO] S3へ再アップロード..."
        aws s3 cp "${tmp_dir}/${YESTERDAY}.tar" "s3://${S3_BUCKET}/" --only-show-errors

        echo "[INFO] 未圧縮データ削除..."
        aws s3 rm "s3://${S3_BUCKET}/${YESTERDAY}" --recursive --only-show-errors
    fi

    echo "[INFO] 一時フォルダー削除..."
    # trap EXIT が rm -rf を実行するので、ここでは不要だが明示的に実行
}

main "$@"