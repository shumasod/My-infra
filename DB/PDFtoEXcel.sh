#!/bin/ksh
#
# 名前: pdf_to_excel.ksh
# 説明: PDFファイルをExcelファイルに変換するスクリプト
# 使用方法: ./pdf_to_excel.ksh [-i input_dir] [-o output_dir] [-k] [-v]
#   -i: 入力ディレクトリ (デフォルト: ./pdf_files)
#   -o: 出力ディレクトリ (デフォルト: ./excel_files)
#   -k: 中間ファイルを保持する
#   -v: 詳細モードを有効にする
#

# エラーハンドリング関数
error_exit() {
    print -u2 "エラー: $1"
    exit 1
}

# ログ出力関数
log_msg() {
    if [[ $verbose -eq 1 ]]; then
        print "$(date '+%Y-%m-%d %H:%M:%S') - $1"
    fi
}

# 使用方法を表示
usage() {
    cat <<EOF
使用方法: $0 [-i input_dir] [-o output_dir] [-k] [-v]
  -i: 入力ディレクトリ (デフォルト: ./pdf_files)
  -o: 出力ディレクトリ (デフォルト: ./excel_files)
  -k: 中間ファイルを保持する
  -v: 詳細モードを有効にする
EOF
    exit 1
}

# デフォルト値の設定
input_dir="./pdf_files"
output_dir="./excel_files"
keep_temp=0
verbose=0

# コマンドライン引数の解析
while getopts ":i:o:kv" opt; do
    case $opt in
        i) input_dir="$OPTARG" ;;
        o) output_dir="$OPTARG" ;;
        k) keep_temp=1 ;;
        v) verbose=1 ;;
        \?) usage ;;
    esac
done

# 必要なツールの確認
check_command() {
    command -v "$1" >/dev/null 2>&1 || error_exit "$1 が見つかりません。インストールしてください。"
}

check_command pdftotext
check_command awk
check_command xlsx

# 入力ディレクトリが存在するか確認
[[ -d "$input_dir" ]] || error_exit "入力ディレクトリ $input_dir が存在しません。"

# 出力ディレクトリが存在しない場合は作成
[[ -d "$output_dir" ]] || mkdir -p "$output_dir" || error_exit "出力ディレクトリ $output_dir を作成できませんでした。"

# PDFファイルの数をカウント
pdf_count=$(find "$input_dir" -name "*.pdf" -type f | wc -l)
if [[ $pdf_count -eq 0 ]]; then
    error_exit "入力ディレクトリ $input_dir にPDFファイルが見つかりません。"
fi

log_msg "変換を開始します: $pdf_count 個のPDFファイルを処理します。"

# 現在のファイル番号
current=0

# PDFファイルを処理
for pdf_file in "$input_dir"/*.pdf; do
    if [[ -f "$pdf_file" ]]; then
        current=$((current + 1))
        filename=$(basename -- "$pdf_file")
        filename_noext="${filename%.*}"
        
        log_msg "[$current/$pdf_count] '$filename' の処理を開始します。"
        
        # PDFをテキストに変換（テーブル構造を保持するオプション付き）
        log_msg "PDFをテキストに変換中..."
        pdftotext -layout -table "$pdf_file" "${output_dir}/${filename_noext}.txt" || 
            error_exit "PDFからテキストへの変換に失敗しました: $filename"
        
        # テキストをCSVに変換（より精度の高い変換）
        log_msg "テキストをCSVに変換中..."
        awk '
        BEGIN {
            FS = "[ \t]+"
            OFS = ","
        }
        
        # 空行をスキップ
        NF > 0 {
            # 各フィールドの前後のスペースを削除
            for (i=1; i<=NF; i++) {
                gsub(/^[ \t]+|[ \t]+$/, "", $i)
                
                # カンマを含むフィールドは引用符で囲む
                if ($i ~ /,/) {
                    gsub(/"/, "\"\"", $i)  # 引用符をエスケープ
                    $i = "\"" $i "\""
                }
                
                # 数値以外のフィールドで、特殊文字を含むものは引用符で囲む
                if ($i !~ /^[0-9]+([.][0-9]+)?$/ && $i ~ /[;:"(){}]/) {
                    gsub(/"/, "\"\"", $i)
                    $i = "\"" $i "\""
                }
            }
            print
        }
        ' "${output_dir}/${filename_noext}.txt" > "${output_dir}/${filename_noext}.csv" || 
            error_exit "テキストからCSVへの変換に失敗しました: $filename"
        
        # CSVをExcelに変換
        log_msg "CSVをExcelに変換中..."
        xlsx -i "${output_dir}/${filename_noext}.csv" -o "${output_dir}/${filename_noext}.xlsx" || 
            error_exit "CSVからExcelへの変換に失敗しました: $filename"
        
        # 中間ファイルを削除（オプションで保持可能）
        if [[ $keep_temp -eq 0 ]]; then
            log_msg "中間ファイルを削除中..."
            rm "${output_dir}/${filename_noext}.txt" "${output_dir}/${filename_noext}.csv"
        fi
        
        log_msg "[$current/$pdf_count] '$filename' の変換が完了しました。"
        print "変換完了 ($current/$pdf_count): $filename"
    fi
done

log_msg "すべての処理が完了しました。"
print "すべてのPDFファイル ($pdf_count 個) の変換が完了しました。"
print "変換されたファイルは $output_dir ディレクトリにあります。"

exit 0
