#!/bin/bash

# 日付を取得するよ
DATE=$(date +"%Y-%m-%d")

# レポートファイル名を設定するよ
REPORT_FILE="report_${DATE}.txt"

# レポートを生成するんよ
generate_report() {
    echo "日次レポート: ${DATE}" > ${REPORT_FILE}
    echo "-------------------" >> ${REPORT_FILE}
    echo "1. システム状況:" >> ${REPORT_FILE}
    uptime >> ${REPORT_FILE}
    echo "2. ディスク使用量:" >> ${REPORT_FILE}
    df -h >> ${REPORT_FILE}
    echo "3. メモリ使用量:" >> ${REPORT_FILE}
    free -m >> ${REPORT_FILE}
    echo "-------------------" >> ${REPORT_FILE}
    echo "レポート終了" >> ${REPORT_FILE}
}

# メールを送信
send_email() {
    RECIPIENT="your-email@example.com"
    SUBJECT="日次レポート: ${DATE}"
    BODY="添付のレポートをご確認ください。"

    echo "${BODY}" | mail -s "${SUBJECT}" -a ${REPORT_FILE} ${RECIPIENT}
}

# メイン処理
main() {
    generate_report
    send_email
    echo "レポートが生成され、メールで送信されました。"
}

# スクリプトを実行
main
