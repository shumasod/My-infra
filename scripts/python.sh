#!/bin/bash

# ログファイルのパス設定
LOG_FILE="/var/log/syslog"  # Ubuntuの場合
# LOG_FILE="/var/log/messages"  # RHEL/CentOS/Fedoraの場合

# エラーメッセージの検索パターン
ERROR_PATTERN="Host key verification failed"

# ログファイルのチェック
check_log() {
    echo "ログファイル ${LOG_FILE} をチェックしています..."
    
    # 過去1時間以内にエラーがあるか確認（タイムスタンプの形式によって調整が必要）
    ERROR_COUNT=$(grep -i "${ERROR_PATTERN}" ${LOG_FILE} | grep "$(date +"%b %e" | sed 's/  / /')" | grep -c "$(date +"%H" --date="1 hour ago")-$(date +"%H")")
    
    if [ ${ERROR_COUNT} -gt 0 ]; then
        echo "警告: ${ERROR_COUNT} 件の「${ERROR_PATTERN}」エラーが検出されました。"
        echo "詳細は以下の通りです:"
        grep -i "${ERROR_PATTERN}" ${LOG_FILE} | grep "$(date +"%b %e" | sed 's/  / /')" | tail -n 10
        
        # 必要に応じて通知を送信（メール、Slack、その他の方法）
        # send_notification "${ERROR_COUNT} 件のHost key verification failedエラーが発生しました"
        
        return 1
    else
        echo "エラーは検出されませんでした。"
        return 0
    fi
}

# メール通知関数（必要に応じて設定）
send_notification() {
    MESSAGE="$1"
    SUBJECT="[警告] CRONジョブエラー検出"
    
    # メール送信の例
    # echo "${MESSAGE}" | mail -s "${SUBJECT}" admin@example.com
    
    # または別の通知方法（Slack、Teams等）
    echo "${SUBJECT}: ${MESSAGE}"
}

# メイン実行部分
main() {
    check_log
    exit_code=$?
    
    if [ ${exit_code} -ne 0 ]; then
        echo "エラーが検出されたため、管理者の確認が必要です。"
    fi
    
    exit ${exit_code}
}

# スクリプト実行
main
