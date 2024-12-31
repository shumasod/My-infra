#!/bin/bash

# ダウンロードフォルダのパスを設定
# 注: Windows環境では、/c/Users/YourUsername/Downloads のような形式で指定します
DOWNLOAD_DIR="/c/Users/$USERNAME/Downloads"

# 削除する日数を設定（例: 30日以上前のファイルを削除）
DAYS_OLD=30

# ログファイルの設定
LOG_FILE="$DOWNLOAD_DIR/cleanup_log.txt"

# 現在の日時を取得
CURRENT_DATE=$(date +"%Y-%m-%d %H:%M:%S")

# メイン処理
main() {
    echo "クリーンアップ処理を開始します: $CURRENT_DATE" > "$LOG_FILE"
    echo "対象ディレクトリ: $DOWNLOAD_DIR" >> "$LOG_FILE"
    echo "削除対象: ${DAYS_OLD}日以上前のファイル" >> "$LOG_FILE"
    echo "----------------------------------------" >> "$LOG_FILE"

    # 古いファイルを検索して削除
    find "$DOWNLOAD_DIR" -maxdepth 1 -type f -mtime +$DAYS_OLD -print0 | while IFS= read -r -d '' file; do
        # ファイル名とサイズを取得
        filename=$(basename "$file")
        filesize=$(du -h "$file" | cut -f1)

        # ファイルを削除
        rm "$file"

        echo "削除しました: $filename (サイズ: $filesize)" >> "$LOG_FILE"
    done

    echo "----------------------------------------" >> "$LOG_FILE"
    echo "クリーンアップ処理が完了しました: $(date +"%Y-%m-%d %H:%M:%S")" >> "$LOG_FILE"
}

# スクリプトを実行
main

echo "クリーンアップが完了しました。詳細は $LOG_FILE を確認してください。"
