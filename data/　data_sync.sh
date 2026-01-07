#!/bin/bash

# SFTP Data Sync Script
# Usage: ./sftp_sync.sh [source_directory] [destination_directory]

# 設定
SOURCE_DIR=${1:-"/path/to/source"}
REMOTE_HOST=${REMOTE_HOST:-"example.com"}
REMOTE_USER=${REMOTE_USER:-"username"}
REMOTE_DIR=${2:-"/path/to/remote/destination"}
SSH_KEY=${SSH_KEY:-"$HOME/.ssh/id_rsa"}
SSH_PORT=${SSH_PORT:-"22"}

# ログ設定
LOG_DIR="/var/log/sftp_sync"
LOG_FILE="$LOG_DIR/sync_$(date +%Y%m%d_%H%M%S).log"
ERROR_LOG="$LOG_DIR/errors_$(date +%Y%m%d_%H%M%S).log"
SUMMARY_LOG="$LOG_DIR/summary.log"

# ログディレクトリ作成
mkdir -p "$LOG_DIR"

# 関数: メッセージをログに記録
log_message() {
  local message="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
  echo "$message" | tee -a "$LOG_FILE"
  echo "$message" >> "$SUMMARY_LOG"
}

# 関数: エラーをログに記録
log_error() {
  local message="[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1"
  echo "$message" | tee -a "$LOG_FILE" "$ERROR_LOG"
  echo "$message" >> "$SUMMARY_LOG"
}

# 開始ログ
log_message "====== SFTP同期開始 ======"
log_message "ソース: $SOURCE_DIR"
log_message "宛先: $REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR"

# ソースディレクトリの確認
if [ ! -d "$SOURCE_DIR" ]; then
  log_error "ソースディレクトリ $SOURCE_DIR が存在しません"
  exit 1
fi

# リモートサーバー接続テスト
log_message "リモートサーバーへの接続をテスト中..."
ssh -i "$SSH_KEY" -p "$SSH_PORT" "$REMOTE_USER@$REMOTE_HOST" "echo '接続テスト成功'" >> "$LOG_FILE" 2>&1

if [ $? -ne 0 ]; then
  log_error "リモートサーバーへの接続に失敗しました"
  exit 1
fi

# リモートディレクトリの存在確認と作成
log_message "リモートディレクトリの確認中..."
ssh -i "$SSH_KEY" -p "$SSH_PORT" "$REMOTE_USER@$REMOTE_HOST" "mkdir -p $REMOTE_DIR" >> "$LOG_FILE" 2>&1

if [ $? -ne 0 ]; then
  log_error "リモートディレクトリの作成に失敗しました"
  exit 1
fi

# 同期の実行
log_message "SFTPを使用してデータ同期を開始します..."

# sftpバッチファイルの作成
BATCH_FILE=$(mktemp)
echo "cd $REMOTE_DIR" > "$BATCH_FILE"
echo "lcd $SOURCE_DIR" >> "$BATCH_FILE"
echo "put -r *" >> "$BATCH_FILE"

# 同期実行
sync_start_time=$(date +%s)
sftp -i "$SSH_KEY" -P "$SSH_PORT" -b "$BATCH_FILE" "$REMOTE_USER@$REMOTE_HOST" >> "$LOG_FILE" 2>&1
SYNC_STATUS=$?
sync_end_time=$(date +%s)
sync_duration=$((sync_end_time - sync_start_time))

# バッチファイル削除
rm "$BATCH_FILE"

# 結果確認
if [ $SYNC_STATUS -eq 0 ]; then
  log_message "データ同期が正常に完了しました (所要時間: ${sync_duration}秒)"
  
  # ファイル数とサイズの取得
  LOCAL_FILE_COUNT=$(find "$SOURCE_DIR" -type f | wc -l)
  LOCAL_SIZE=$(du -sh "$SOURCE_DIR" | cut -f1)
  
  log_message "転送ファイル数: $LOCAL_FILE_COUNT"
  log_message "転送データ量: $LOCAL_SIZE"
else
  log_error "データ同期に失敗しました (終了コード: $SYNC_STATUS)"
  exit 1
fi

# 終了ログ
log_message "====== SFTP同期完了 ======"
exit 0
