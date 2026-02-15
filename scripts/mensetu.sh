#!/bin/bash

# =================================================================
# 最終面接用 Shell Script
# 技術面接でよく問われる要素を含んだ実践的なスクリプト
# =================================================================

set -euo pipefail  # エラーハンドリング: エラー時終了、未定義変数でエラー、パイプエラーを伝播

# カラー定義
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# 定数定義
readonly SCRIPT_NAME=$(basename "$0")
readonly LOG_FILE="/tmp/${SCRIPT_NAME%.*}.log"
readonly CONFIG_FILE="./config.txt"

# ログ関数
log() {
    local level="$1"
    shift
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $*" >> "$LOG_FILE"
}

# カラー出力関数
print_color() {
    local color="$1"
    shift
    echo -e "${color}$*${NC}"
}

# エラーハンドリング関数
error_exit() {
    print_color "$RED" "エラー: $1" >&2
    log "ERROR" "$1"
    exit 1
}

# ヘルプ表示
show_help() {
    cat << EOF
使用方法: $SCRIPT_NAME [オプション]

オプション:
    -h, --help          このヘルプを表示
    -v, --verbose       詳細出力モード
    -f, --file FILE     処理するファイルを指定
    -c, --count NUM     処理回数を指定 (デフォルト: 5)
    -d, --directory DIR 作業ディレクトリを指定

例:
    $SCRIPT_NAME -f data.txt -c 10
    $SCRIPT_NAME --verbose --directory /tmp

EOF
}

# 引数パース
parse_arguments() {
    VERBOSE=false
    INPUT_FILE=""
    COUNT=5
    WORK_DIR="."
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -f|--file)
                INPUT_FILE="$2"
                shift 2
                ;;
            -c|--count)
                if ! [[ "$2" =~ ^[0-9]+$ ]]; then
                    error_exit "カウントは数値で指定してください: $2"
                fi
                COUNT="$2"
                shift 2
                ;;
            -d|--directory)
                WORK_DIR="$2"
                shift 2
                ;;
            *)
                error_exit "不明なオプション: $1"
                ;;
        esac
    done
}

# 環境チェック
check_environment() {
    print_color "$BLUE" "環境チェックを開始..."
    
    # 必要なコマンドの存在確認
    local required_commands=("curl" "jq" "grep" "awk" "sed")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            error_exit "必要なコマンドが見つかりません: $cmd"
        fi
    done
    
    # ディスク容量チェック
    local available_space=$(df "$WORK_DIR" | awk 'NR==2 {print $4}')
    if [[ $available_space -lt 1000000 ]]; then  # 1GB未満の場合
        print_color "$YELLOW" "警告: ディスク容量が少なくなっています"
        log "WARN" "ディスク容量: ${available_space}KB"
    fi
    
    print_color "$GREEN" "環境チェック完了"
}

# ファイル処理関数
process_file() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        error_exit "ファイルが存在しません: $file"
    fi
    
    print_color "$BLUE" "ファイル処理中: $file"
    
    # ファイル統計情報
    local line_count=$(wc -l < "$file")
    local word_count=$(wc -w < "$file")
    local char_count=$(wc -c < "$file")
    
    print_color "$GREEN" "統計情報:"
    echo "  行数: $line_count"
    echo "  単語数: $word_count"
    echo "  文字数: $char_count"
    
    # 上位5行を表示
    print_color "$BLUE" "ファイル内容 (上位5行):"
    head -5 "$file" | nl
    
    log "INFO" "ファイル処理完了: $file (行数: $line_count)"
}

# システム情報取得
get_system_info() {
    print_color "$BLUE" "システム情報:"
    
    echo "OS: $(uname -s)"
    echo "カーネルバージョン: $(uname -r)"
    echo "アーキテクチャ: $(uname -m)"
    echo "ホスト名: $(hostname)"
    echo "現在時刻: $(date)"
    echo "アップタイム: $(uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1}')"
    
    # メモリ使用量
    if command -v free &> /dev/null; then
        echo "メモリ使用量:"
        free -h | grep -E "Mem|Swap"
    fi
    
    # 負荷平均
    echo "負荷平均: $(uptime | awk -F'load average:' '{print $2}')"
}

# 配列とループのデモ
array_demo() {
    print_color "$BLUE" "配列処理のデモ:"
    
    # 連想配列の使用例
    declare -A server_status
    server_status["web01"]="running"
    server_status["db01"]="stopped"
    server_status["cache01"]="running"
    
    echo "サーバーステータス:"
    for server in "${!server_status[@]}"; do
        local status="${server_status[$server]}"
        if [[ "$status" == "running" ]]; then
            print_color "$GREEN" "  $server: $status"
        else
            print_color "$RED" "  $server: $status"
        fi
    done
}

# ネットワークチェック
network_check() {
    print_color "$BLUE" "ネットワークチェック:"
    
    local test_hosts=("google.com" "github.com")
    
    for host in "${test_hosts[@]}"; do
        if ping -c 1 -W 3 "$host" &> /dev/null; then
            print_color "$GREEN" "  $host: 接続OK"
        else
            print_color "$RED" "  $host: 接続NG"
        fi
    done
}

# バックアップ作成
create_backup() {
    local source_dir="$1"
    local backup_name="backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    
    if [[ ! -d "$source_dir" ]]; then
        print_color "$YELLOW" "バックアップ対象ディレクトリが存在しません: $source_dir"
        return 1
    fi
    
    print_color "$BLUE" "バックアップ作成中..."
    
    if tar -czf "/tmp/$backup_name" -C "$(dirname "$source_dir")" "$(basename "$source_dir")" 2>/dev/null; then
        print_color "$GREEN" "バックアップ完了: /tmp/$backup_name"
        log "INFO" "バックアップ作成: /tmp/$backup_name"
    else
        print_color "$RED" "バックアップ失敗"
        log "ERROR" "バックアップ失敗: $source_dir"
        return 1
    fi
}

# JSON処理のデモ
json_demo() {
    print_color "$BLUE" "JSON処理のデモ:"
    
    # サンプルJSONデータ
    local json_data='{
        "users": [
            {"id": 1, "name": "田中太郎", "role": "admin"},
            {"id": 2, "name": "佐藤花子", "role": "user"},
            {"id": 3, "name": "鈴木次郎", "role": "user"}
        ],
        "timestamp": "2024-01-01T12:00:00Z"
    }'
    
    if command -v jq &> /dev/null; then
        echo "ユーザー一覧:"
        echo "$json_data" | jq -r '.users[] | "  ID: \(.id), 名前: \(.name), 役割: \(.role)"'
        
        echo "管理者ユーザー:"
        echo "$json_data" | jq -r '.users[] | select(.role == "admin") | "  \(.name)"'
    else
        print_color "$YELLOW" "jqコマンドが利用できないため、JSON処理をスキップします"
    fi
}

# 並列処理のデモ
parallel_demo() {
    print_color "$BLUE" "並列処理のデモ:"
    
    echo "5つのタスクを並列実行中..."
    
    for i in {1..5}; do
        (
            sleep $((i * 2))
            echo "タスク $i 完了 ($(date +%H:%M:%S))"
        ) &
    done
    
    wait
    print_color "$GREEN" "全タスク完了"
}

# クリーンアップ処理
cleanup() {
    print_color "$BLUE" "クリーンアップ中..."
    # 一時ファイルの削除など
    if [[ -f "/tmp/temp_$$" ]]; then
        rm -f "/tmp/temp_$$"
    fi
    print_color "$GREEN" "クリーンアップ完了"
}

# シグナルハンドラ設定
trap cleanup EXIT
trap 'error_exit "スクリプトが中断されました"' INT TERM

# メイン処理
main() {
    print_color "$GREEN" "=== 最終面接用 Shell Script 実行開始 ==="
    log "INFO" "スクリプト開始"
    
    # 引数解析
    parse_arguments "$@"
    
    [[ "$VERBOSE" == true ]] && print_color "$YELLOW" "詳細モードで実行中..."
    
    # 各種処理の実行
    check_environment
    get_system_info
    array_demo
    network_check
    json_demo
    
    # ファイルが指定されている場合は処理
    if [[ -n "$INPUT_FILE" ]]; then
        process_file "$INPUT_FILE"
    fi
    
    # 作業ディレクトリのバックアップ作成
    create_backup "$WORK_DIR"
    
    # 並列処理デモ
    parallel_demo
    
    print_color "$GREEN" "=== スクリプト実行完了 ==="
    log "INFO" "スクリプト正常終了"
}

# スクリプトが直接実行された場合のみmainを呼び出し
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
