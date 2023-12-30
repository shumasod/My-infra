#!/bin/bash
set -e
export PATH=$PATH:/usr/local/bin/
S3_BUCKET=-dumps
DEFAULT_YESTERDAY=$(date --date="yesterday" +"%Y%m%d")
YESTERDAY="${1:-$DEFAULT_YESTERDAY}"

main() {

        # create temporary working folder
        echo "[INFO] 一時フォルダー作成..."
        tmp_dir=$(mktemp -d -t dbDailyBackup-$(date +%Y-%m-%d-%H-%M-%S)-XXXXXXXXXX)
        trap 'rm -rf -- "$tmp_dir"' EXIT

        if [[ $(aws s3 ls s3://$S3_BUCKET/$YESTERDAY | head) ]]; then
                echo "[INFO] S3から昨日バックアップ分取得..."
                aws s3 sync s3://$S3_BUCKET/$YESTERDAY/ $tmp_dir/$YESTERDAY --only-show-errors
                echo "[INFO] データ圧縮..."
                tar -cf "${tmp_dir}/${YESTERDAY}.tar" -C $tmp_dir $YESTERDAY
                echo "[INFO] S3へ再アップロード..."
                aws s3 cp "${tmp_dir}/${YESTERDAY}.tar" s3://$S3_BUCKET/ --only-show-errors
                echo "[INFO] 未圧縮データ削除..."
                aws s3 rm s3://$S3_BUCKET/$YESTERDAY --recursive --only-show-errors
        fi

    # remove temporary working folder when fnished
    echo "[INFO] 一時フォルダー削除..."
    rm -rf $tmp_dir
}

main
