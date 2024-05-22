#!/bin/bash

# ファイル名を引数として受け取る
INPUT_FILE=$1
OUTPUT_FILE="translated_$INPUT_FILE"

# Google Cloud Translation APIキーを設定
API_KEY="YOUR_GOOGLE_CLOUD_API_KEY"

# ファイルが存在するか確認
if [ ! -f "$INPUT_FILE" ]; then
  echo "Error: File $INPUT_FILE not found!"
  exit 1
fi

# ファイル内容を読み込み
TEXT=$(cat "$INPUT_FILE")

# テキストをURLエンコード
ENCODED_TEXT=$(echo "$TEXT" | jq -sRr @uri)

# 翻訳APIを呼び出して翻訳
RESPONSE=$(curl -s -X POST "https://translation.googleapis.com/language/translate/v2" \
  -d "q=$ENCODED_TEXT" \
  -d "source=en" \
  -d "target=ja" \
  -d "format=text" \
  -d "key=$API_KEY")

# 翻訳結果を抽出
TRANSLATED_TEXT=$(echo $RESPONSE | jq -r '.data.translations[0].translatedText')

# 翻訳結果をファイルに書き込み
echo "$TRANSLATED_TEXT" > "$OUTPUT_FILE"

echo "Translation complete. Output written to $OUTPUT_FILE"
