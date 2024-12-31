#!/bin/bash

# 必要なツールがインストールされているか確認
command -v pdftotext >/dev/null 2>&1 || { echo >&2 "pdftotext が必要です。インストールしてください。"; exit 1; }
command -v csv2xlsx >/dev/null 2>&1 || { echo >&2 "csv2xlsx が必要です。インストールしてください。"; exit 1; }

# 入力ディレクトリと出力ディレクトリを設定
input_dir="./pdf_files"
output_dir="./excel_files"

# 出力ディレクトリが存在しない場合は作成
mkdir -p "$output_dir"

# PDFファイルを処理
for pdf_file in "$input_dir"/*.pdf; do
    if [ -f "$pdf_file" ]; then
        filename=$(basename -- "$pdf_file")
        filename_noext="${filename%.*}"
        
        # PDFをテキストに変換
        pdftotext -layout "$pdf_file" "${output_dir}/${filename_noext}.txt"
        
        # テキストをCSVに変換（タブ区切り）
        sed 's/  */,/g' "${output_dir}/${filename_noext}.txt" > "${output_dir}/${filename_noext}.csv"
        
        # CSVをExcelに変換
        csv2xlsx -i "${output_dir}/${filename_noext}.csv" -o "${output_dir}/${filename_noext}.xlsx"
        
        # 中間ファイルを削除
        rm "${output_dir}/${filename_noext}.txt" "${output_dir}/${filename_noext}.csv"
        
        echo "変換完了: $filename"
    fi
done

echo "すべてのPDFファイルの変換が完了しました。"