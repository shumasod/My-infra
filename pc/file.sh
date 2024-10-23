#!/bin/bash

# 整理対象のディレクトリを指定（デフォルトは現在のディレクトリ）
TARGET_DIR=${1:-.}

# ログファイルの設定
LOG_FILE="file_management_log.txt"

# ファイルを移動する関数
move_file() {
    local file=$1
    local dest_dir=$2

    # 移動先ディレクトリが存在しない場合は作成
    if [ ! -d "$dest_dir" ]; then
        mkdir -p "$dest_dir"
    fi

    # ファイルを移動
    mv "$file" "$dest_dir"
    echo "$(date): Moved $file to $dest_dir" >> $LOG_FILE
}

# メイン処理
main() {
    echo "Starting file management process at $(date)" > $LOG_FILE

    # 各ファイルタイプに対する処理
    find "$TARGET_DIR" -maxdepth 1 -type f | while read file; do
        case "${file,,}" in
            *.jpg|*.jpeg|*.png|*.gif)
                move_file "$file" "$TARGET_DIR/Images"
                ;;
            *.doc|*.docx|*.txt|*.pdf)
                move_file "$file" "$TARGET_DIR/Documents"
                ;;
            *.mp3|*.wav|*.flac)
                move_file "$file" "$TARGET_DIR/Audio"
                ;;
            *.mp4|*.avi|*.mkv)
                move_file "$file" "$TARGET_DIR/Video"
                ;;
            *.zip|*.rar|*.tar.gz)
                move_file "$file" "$TARGET_DIR/Archives"
                ;;
            *)
                # その他のファイルは 'Misc' ディレクトリに移動
                move_file "$file" "$TARGET_DIR/Misc"
                ;;
        esac
    done

    echo "File management process completed at $(date)" >> $LOG_FILE
}

# スクリプトを実行
main

echo "ファイル整理が完了しました。詳細は $LOG_FILE を確認してください。"
