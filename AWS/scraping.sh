#!/bin/bash

# スクリプトの設定
OUTPUT_DIR="$HOME/recommended_sites"
LOG_FILE="$OUTPUT_DIR/collection.log"
DATE=$(date '+%Y-%m-%d')
OUTPUT_FILE="$OUTPUT_DIR/$DATE-recommendations.txt"

# 必要なディレクトリの作成
mkdir -p "$OUTPUT_DIR"

# ログ関数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# エラーハンドリング
set -e
trap 'log "エラーが発生しました。終了コード: $?"' ERR

# RSS フィードからの情報収集（例としてtech系のフィード）
FEEDS=(
    "https://news.ycombinator.com/rss"
    "https://www.techmeme.com/feed.xml"
    "https://feeds.feedburner.com/TechCrunch/"
)

log "本日の収集を開始します"

# 一時ファイルの作成
TEMP_FILE=$(mktemp)

# フィードから情報を収集
for feed in "${FEEDS[@]}"; do
    curl -s "$feed" | \
    grep -E "title|link" | \
    sed 's/<[^>]*>//g' | \
    sed 's/^[ \t]*//' >> "$TEMP_FILE"
done

# 結果の整形と出力
{
    echo "======================="
    echo "本日($DATE)のおすすめサイト"
    echo "======================="
    echo ""
    
    # ランダムに5つのサイトを選択
    sort -R "$TEMP_FILE" | \
    awk 'NR%2{title=$0;next}{printf("%d. %s\n   URL: %s\n\n",NR/2,title,$0)}' | \
    head -n 15
    
    echo "======================="
} > "$OUTPUT_FILE"

# 一時ファイルの削除
rm "$TEMP_FILE"

log "本日の収集が完了しました"

# 結果の表示
cat "$OUTPUT_FILE"