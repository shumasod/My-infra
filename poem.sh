#!/bin/bash

# 1. ランダムな詩ジェネレーター
generate_poem() {
    local adjectives=("赤い" "青い" "静かな" "激しい" "優しい")
    local nouns=("海" "空" "風" "星" "雨")
    local verbs=("踊る" "歌う" "眠る" "輝く" "囁く")

    echo "『不思議な詩』"
    for i in {1..4}; do
        adj=${adjectives[$RANDOM % ${#adjectives[@]}]}
        noun=${nouns[$RANDOM % ${#nouns[@]}]}
        verb=${verbs[$RANDOM % ${#verbs[@]}]}
        echo "$adj$nounが$verb"
    done
}

# 2. ファイル名暗号化ツール
encrypt_filenames() {
    for file in *; do
        if [ -f "$file" ]; then
            new_name=$(echo "$file" | md5sum | cut -d' ' -f1)
            extension="${file##*.}"
            mv "$file" "${new_name}.${extension}"
            echo "$file -> ${new_name}.${extension}"
        fi
    done
}

# 3. システムリソース監視と絵文字レポート
emoji_resource_monitor() {
    while true; do
        cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
        mem_usage=$(free | grep Mem | awk '{print $3/$2 * 100.0}')
        disk_usage=$(df -h / | awk '/\// {print $5}' | sed 's/%//')
        
        if (( $(echo "$cpu_usage > 80" | bc -l) )); then
            cpu_emoji="🔥"
        elif (( $(echo "$cpu_usage > 50" | bc -l) )); then
            cpu_emoji="⚡"
        else
            cpu_emoji="😊"
        fi
        
        if (( $(echo "$mem_usage > 80" | bc -l) )); then
            mem_emoji="💥"
        elif (( $(echo "$mem_usage > 50" | bc -l) )); then
            mem_emoji="💡"
        else
            mem_emoji="💤"
        fi
        
        if (( disk_usage > 80 )); then
            disk_emoji="🚨"
        elif (( disk_usage > 50 )); then
            disk_emoji="📦"
        else
            disk_emoji="💾"
        fi
        
        echo "システム状況: $cpu_emoji $mem_emoji $disk_emoji"
        sleep 5
    done
}

# スクリプトの使用例
case "$1" in
    "poem") generate_poem ;;
    "encrypt") encrypt_filenames ;;
    "monitor") emoji_resource_monitor ;;
    *) echo "使用方法: $0 [poem|encrypt|monitor]" ;;
esac
