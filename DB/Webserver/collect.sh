#!/bin/bash

set -euo pipefail

# 使用方法: ./rss_collector.sh <RSS_URL> <キーワード>

# 引数の検証
if [ $# -ne 2 ]; then
    echo "使用方法: $0 <RSS_URL> <キーワード>" >&2
    exit 1
fi

RSS_URL="$1"
KEYWORD="$2"

# 依存関係の確認
check_dependencies() {
    local deps=("curl" "xmllint")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            echo "エラー: $dep が見つかりません。インストールしてください。" >&2
            exit 1
        fi
    done
}

# RSSフィードの取得と解析
fetch_and_parse_rss() {
    local rss_content
    rss_content=$(curl -sS "$RSS_URL")
    if [ $? -ne 0 ]; then
        echo "エラー: RSSフィードの取得に失敗しました。" >&2
        exit 1
    fi
    echo "$rss_content" | xmllint --format - 2>/dev/null
}

# 特定のキーワードを含む項目のフィルタリング
filter_items() {
    xmllint --xpath "//item[contains(translate(title, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'), '$(echo "$KEYWORD" | tr '[:upper:]' '[:lower:]')')
                      or contains(translate(description, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'), '$(echo "$KEYWORD" | tr '[:upper:]' '[:lower:]')')]" - 2>/dev/null
}

# 結果の整形と出力
format_output() {
    while IFS= read -r item; do
        title=$(echo "$item" | xmllint --xpath "string(title)" - 2>/dev/null)
        link=$(echo "$item" | xmllint --xpath "string(link)" - 2>/dev/null)
        description=$(echo "$item" | xmllint --xpath "string(description)" - 2>/dev/null)
        
        echo "タイトル: $title"
        echo "リンク: $link"
        echo "説明: $description"
        echo "---"
    done
}

# メイン処理
main() {
    check_dependencies
    local rss_content
    rss_content=$(fetch_and_parse_rss)
    echo "$rss_content" | filter_items | format_output
}

# スクリプトの実行
main