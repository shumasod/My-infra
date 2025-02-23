#!/bin/bash
set -euo pipefail

# 使用方法: ./rss_collector.sh <RSS_URLs_FILE> <キーワード> <チェック間隔(秒)>

# 引数の検証
if [ $# -ne 3 ]; then
    echo "使用方法: $0 <RSS_URLs_FILE> <キーワード> <チェック間隔(秒)>" >&2
    exit 1
fi

RSS_URLS_FILE="$1"
KEYWORD="$2"
INTERVAL="$3"

# URLsファイルの存在確認
if [ ! -f "$RSS_URLS_FILE" ]; then
    echo "エラー: RSS URLsファイル ($RSS_URLS_FILE) が見つかりません。" >&2
    exit 1
fi

# データ保存用のディレクトリ
DATA_DIR="./rss_data"
mkdir -p "$DATA_DIR"

# 依存関係の確認
check_dependencies() {
    local deps=("curl" "xmllint" "sha256sum")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            echo "エラー: $dep が見つかりません。インストールしてください。" >&2
            exit 1
        fi
    done
}

# RSSフィードの取得と解析
fetch_and_parse_rss() {
    local url="$1"
    local rss_content
    rss_content=$(curl -sS --max-time 30 "$url" 2>/dev/null)
    if [ $? -eq 0 ]; then
        echo "$rss_content" | xmllint --format - 2>/dev/null
    fi
}

# 特定のキーワードを含む項目のフィルタリング
filter_items() {
    xmllint --xpath "//item[contains(translate(title, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'), '$(echo "$KEYWORD" | tr '[:upper:]' '[:lower:]')')
                      or contains(translate(description, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'), '$(echo "$KEYWORD" | tr '[:upper:]' '[:lower:]')')]" - 2>/dev/null
}

# 新規アイテムの判定
is_new_item() {
    local link="$1"
    local hash
    hash=$(echo "$link" | sha256sum | cut -d' ' -f1)
    local hash_file="$DATA_DIR/$hash"
    
    if [ ! -f "$hash_file" ]; then
        echo "$link" > "$hash_file"
        return 0
    fi
    return 1
}

# 結果の整形と出力
format_output() {
    while IFS= read -r item; do
        title=$(echo "$item" | xmllint --xpath "string(title)" - 2>/dev/null)
        link=$(echo "$item" | xmllint --xpath "string(link)" - 2>/dev/null)
        description=$(echo "$item" | xmllint --xpath "string(description)" - 2>/dev/null)
        pubDate=$(echo "$item" | xmllint --xpath "string(pubDate)" - 2>/dev/null)
        
        if is_new_item "$link"; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') - 新規アイテム検出"
            echo "タイトル: $title"
            echo "リンク: $link"
            echo "公開日: $pubDate"
            echo "説明: $description"
            echo "---"
        fi
    done
}

# クリーンアップ処理
cleanup() {
    echo "スクリプトを終了します..."
    exit 0
}

trap cleanup SIGINT SIGTERM

# メイン処理
main() {
    check_dependencies
    echo "RSSフィードの監視を開始します..."
    echo "キーワード: $KEYWORD"
    echo "チェック間隔: $INTERVAL 秒"
    echo "---"
    
    while true; do
        while IFS= read -r url; do
            # コメント行とか空行をスキップ
            [[ "$url" =~ ^[[:space:]]*# ]] && continue
            [[ -z "$url" ]] && continue
            
            echo "$(date '+%Y-%m-%d %H:%M:%S') - フィード確認中: $url"
            rss_content=$(fetch_and_parse_rss "$url")
            if [ -n "$rss_content" ]; then
                echo "$rss_content" | filter_items | format_output
            else
                echo "警告: $url からのフィード取得に失敗しました"
            fi
        done < "$RSS_URLS_FILE"
        
        sleep "$INTERVAL"
    done
}

# スクリプトの実行
main
