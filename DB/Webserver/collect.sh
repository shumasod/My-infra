#!/bin/bash

# 使用方法: ./rss_collector.sh <RSS_URL> <キーワード> <出力ファイル>

RSS_URL="$1"
KEYWORD="$2"
OUTPUT_FILE="$3"

# 依存関係の確認
check_dependencies() {
    command -v curl >/dev/null 2>&1 || { echo >&2 "curlが必要です。インストールしてください。"; exit 1; }
    command -v xmllint >/dev/null 2>&1 || { echo >&2 "xmllintが必要です。libxml2-utilsをインストールしてください。"; exit 1; }
}

# RSSフィードの取得と解析
fetch_and_parse_rss() {
    curl -s "$RSS_URL" | xmllint --format -
}

# 特定のキーワードを含む項目のフィルタリング
filter_items() {
    grep -i "$KEYWORD" | sed -n '/<item>/,/<\/item>/p'
}

# 結果の整形と出力
format_output() {
    while read -r line; do
        if [[ $line == *"<title>"* ]]; then
            title=$(echo "$line" | sed -e 's/<title>//' -e 's/<\/title>//' -e 's/^[[:space:]]*//')
            echo "タイトル: $title"
        elif [[ $line == *"<link>"* ]]; then
            link=$(echo "$line" | sed -e 's/<link>//' -e 's/<\/link>//' -e 's/^[[:space:]]*//')
            echo "リンク: $link"
        elif [[ $line == *"<description>"* ]]; then
            description=$(echo "$line" | sed -e 's/<description>//' -e 's/<\/description>//' -e 's/^[[:space:]]*//')
            echo "説明: $description"
            echo "---"
        fi
    done
}

# メイン処理
main() {
    check_dependencies
    fetch_and_parse_rss | filter_items | format_output > "$OUTPUT_FILE"
    echo "結果が $OUTPUT_FILE に保存されました。"
}

# スクリプトの実行
main