#!/bin/bash
# ============================================================================
# 高品質マルチツールシェルスクリプト
# 機能: 詩の生成、ファイル名の暗号化、システムリソース監視
# 使用方法: ./script.sh [poem|encrypt|monitor]
# バージョン: 1.1
# ============================================================================

# エラーハンドリングの設定
set -e                  # エラー発生時に終了
set -u                  # 未定義の変数使用時にエラー
set -o pipefail         # パイプラインの途中のエラーも検出

# エラー処理関数
handle_error() {
    local line_no=$1
    local command=$2
    echo "エラー: スクリプト内の行 ${line_no} で \"${command}\" の実行中にエラーが発生しました" >&2
    exit 1
}

# エラートラップの設定
trap 'handle_error ${LINENO} "$BASH_COMMAND"' ERR

# 必要なコマンドの確認
check_requirements() {
    local commands=("$@")
    local missing=()
    
    for cmd in "${commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        echo "エラー: 次のコマンドがインストールされていません: ${missing[*]}" >&2
        return 1
    fi
    
    return 0
}

# ============================================================================
# 1. ランダムな詩ジェネレーター
# 使用法: generate_poem [行数]
# ============================================================================
generate_poem() {
    local lines=${1:-4}  # デフォルトは4行
    
    # 数値チェック
    if ! [[ "$lines" =~ ^[0-9]+$ ]]; then
        echo "エラー: 行数は数値で指定してください" >&2
        return 1
    fi
    
    # 詩の要素
    local -a adjectives=("赤い" "青い" "静かな" "激しい" "優しい" "儚い" "眩しい" "古い")
    local -a nouns=("海" "空" "風" "星" "雨" "月" "光" "道" "雲")
    local -a verbs=("踊る" "歌う" "眠る" "輝く" "囁く" "消える" "忘れる" "映る")
    
    local adj noun verb
    local adj_count=${#adjectives[@]}
    local noun_count=${#nouns[@]}
    local verb_count=${#verbs[@]}
    
    echo "『不思議な詩』"
    echo "------------"
    
    # 疑似乱数初期化（より良い乱数のために）
    RANDOM=$$$(date +%s)
    
    for ((i=1; i<=lines; i++)); do
        adj="${adjectives[RANDOM % adj_count]}"
        noun="${nouns[RANDOM % noun_count]}"
        verb="${verbs[RANDOM % verb_count]}"
        echo "${adj}${noun}が${verb}"
    done
    echo "------------"
    
    return 0
}

# ============================================================================
# 2. ファイル名暗号化ツール
# 使用法: encrypt_filenames [ディレクトリパス]
# ============================================================================
encrypt_filenames() {
    local dir_path=${1:-.}  # デフォルトは現在のディレクトリ
    local mapping_file="filename_mapping.txt"
    
    # ディレクトリ存在確認
    if [ ! -d "$dir_path" ]; then
        echo "エラー: ディレクトリ '$dir_path' が存在しません" >&2
        return 1
    fi
    
    # 書き込み権限確認
    if [ ! -w "$dir_path" ]; then
        echo "エラー: ディレクトリ '$dir_path' への書き込み権限がありません" >&2
        return 1
    fi
    
    # 依存コマンド確認
    check_requirements "md5sum" || return 1
    
    # 操作前の確認
    echo "警告: このディレクトリ内のすべてのファイル名がハッシュ化されます"
    echo "続行するには 'yes' と入力してください:"
    read -r confirm
    if [ "$confirm" != "yes" ]; then
        echo "操作を中止しました"
        return 0
    fi
    
    # マッピングファイル初期化
    echo "# 元のファイル名 -> 暗号化されたファイル名" > "$mapping_file"
    echo "# $(date)" >> "$mapping_file"
    echo "----------------------------" >> "$mapping_file"
    
    # ファイル名の暗号化
    local count=0
    find "$dir_path" -type f -maxdepth 1 | while read -r file; do
        # 自分自身とマッピングファイルは除外
        if [[ "$file" == *"$0"* || "$file" == *"$mapping_file"* ]]; then
            continue
        fi
        
        local filename
        filename=$(basename "$file")
        local new_name
        new_name=$(echo "$filename" | md5sum | cut -d' ' -f1)
        local extension
        extension="${filename##*.}"
        
        # 拡張子が存在する場合のみ付加
        if [ "$extension" != "$filename" ]; then
            new_name="${new_name}.${extension}"
        fi
        
        # 移動を実行
        mv "$file" "${dir_path}/${new_name}"
        echo "$filename -> $new_name" | tee -a "$mapping_file"
        ((count++))
    done
    
    echo "----------------------------"
    echo "処理完了: $count ファイルの名前を変更しました"
    echo "元のファイル名と暗号化されたファイル名のマッピングは '$mapping_file' に保存されました"
    
    return 0
}

# ============================================================================
# 3. システムリソース監視と絵文字レポート
# 使用法: emoji_resource_monitor [間隔秒数] [繰り返し回数]
# ============================================================================
emoji_resource_monitor() {
    local interval=${1:-5}       # デフォルトは5秒間隔
    local iterations=${2:-0}     # デフォルトは無限ループ（0）
    local count=0
    
    # 数値チェック
    if ! [[ "$interval" =~ ^[0-9]+$ ]]; then
        echo "エラー: 間隔は数値で指定してください" >&2
        return 1
    fi
    
    if ! [[ "$iterations" =~ ^[0-9]+$ ]]; then
        echo "エラー: 繰り返し回数は数値で指定してください" >&2
        return 1
    fi
    
    # 依存コマンド確認
    check_requirements "top" "free" "df" "awk" || return 1
    
    echo "システムリソース監視を開始します (Ctrl+C で終了)"
    echo "間隔: ${interval}秒 | 繰り返し: ${iterations:-'無限'}"
    echo "---------------------------------------------------"
    echo "🔥=高CPU使用率 ⚡=中CPU使用率 😊=低CPU使用率"
    echo "💥=高メモリ使用率 💡=中メモリ使用率 💤=低メモリ使用率"
    echo "🚨=高ディスク使用率 📦=中ディスク使用率 💾=低ディスク使用率"
    echo "---------------------------------------------------"
    
    # 終了シグナルのトラップ
    trap 'echo "モニタリングを終了します"; return 0' INT TERM
    
    while true; do
        # CPU使用率を取得
        local cpu_usage
        cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
        
        # メモリ使用率を取得
        local mem_usage
        mem_usage=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100}')
        
        # ディスク使用率を取得
        local disk_usage
        disk_usage=$(df -h / | awk '/\// {print $5}' | sed 's/%//')
        
        # 絵文字の設定
        local cpu_emoji mem_emoji disk_emoji
        
        # CPU絵文字
        if (( $(echo "$cpu_usage > 80" | bc -l 2>/dev/null) )); then
            cpu_emoji="🔥"
        elif (( $(echo "$cpu_usage > 50" | bc -l 2>/dev/null) )); then
            cpu_emoji="⚡"
        else
            cpu_emoji="😊"
        fi
        
        # メモリ絵文字
        if (( $(echo "$mem_usage > 80" | bc -l 2>/dev/null) )); then
            mem_emoji="💥"
        elif (( $(echo "$mem_usage > 50" | bc -l 2>/dev/null) )); then
            mem_emoji="💡"
        else
            mem_emoji="💤"
        fi
        
        # ディスク絵文字
        if (( disk_usage > 80 )); then
            disk_emoji="🚨"
        elif (( disk_usage > 50 )); then
            disk_emoji="📦"
        else
            disk_emoji="💾"
        fi
        
        # 結果表示
        echo "$(date '+%Y-%m-%d %H:%M:%S') | "
        echo "CPU: ${cpu_usage}% ${cpu_emoji} | "
        echo "メモリ: ${mem_usage}% ${mem_emoji} | "
        echo "ディスク: ${disk_usage}% ${disk_emoji}"
        
        # カウンターと終了条件
        ((count++))
        if [ "$iterations" -gt 0 ] && [ "$count" -ge "$iterations" ]; then
            echo "指定された回数のモニタリングが完了しました"
            break
        fi
        
        # 次の更新まで待機
        sleep "$interval"
    done
    
    return 0
}

# ============================================================================
# メイン実行部分
# ============================================================================
main() {
    # ヘルプメッセージの表示
    show_help() {
        cat << EOF
使用方法: $0 <コマンド> [オプション]

コマンド:
  poem [行数]            - ランダムな詩を生成します（デフォルト：4行）
  encrypt [ディレクトリ]  - 指定ディレクトリ内のファイル名を暗号化します（デフォルト：現在のディレクトリ）
  monitor [間隔] [回数]   - システムリソースを監視し絵文字で表示します
                          間隔はデフォルト5秒、回数は0で無限に実行

例:
  $0 poem 6           # 6行の詩を生成
  $0 encrypt ./data   # ./data ディレクトリ内のファイル名を暗号化
  $0 monitor 10 5     # 10秒間隔で5回リソース状態を表示
EOF
    }
    
    # コマンド分岐
    case "${1:-help}" in
        "poem")
            generate_poem "${2:-4}"
            ;;
        "encrypt")
            encrypt_filenames "${2:-.}"
            ;;
        "monitor")
            emoji_resource_monitor "${2:-5}" "${3:-0}"
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            echo "エラー: 不明なコマンド '${1:-}'" >&2
            show_help
            return 1
            ;;
    esac
    
    return 0
}

# スクリプトの実行
main "$@"
