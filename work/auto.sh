#!/bin/bash

# 業務効率化シェルスクリプト

# カラー定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ログファイルのパス
LOG_FILE="/var/log/system.log"

# バックアップ先ディレクトリ
BACKUP_DIR="/backup"

# 監視対象のプロセス
PROCESSES=("nginx" "mysql" "php-fpm")

# ログファイル分析
analyze_logs() {
    echo -e "${BLUE}ログファイル分析を開始します...${NC}"
    
    # エラーの数をカウント
    error_count=$(grep -ci "error" $LOG_FILE)
    
    # 警告の数をカウント
    warning_count=$(grep -ci "warning" $LOG_FILE)
    
    echo "エラー数: $error_count"
    echo "警告数: $warning_count"
    
    # 最近のエラーを表示
    echo -e "${YELLOW}最近のエラー:${NC}"
    grep -i "error" $LOG_FILE | tail -n 5
}

# バックアップの作成
create_backup() {
    echo -e "${BLUE}バックアップを開始します...${NC}"
    
    # バックアップ先ディレクトリが存在しない場合は作成
    mkdir -p $BACKUP_DIR
    
    # 現在の日時を取得
    current_date=$(date +"%Y%m%d_%H%M%S")
    
    # バックアップファイル名
    backup_file="$BACKUP_DIR/backup_$current_date.tar.gz"
    
    # 重要なディレクトリをバックアップ
    tar -czf $backup_file /etc /var/www 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}バックアップが正常に作成されました: $backup_file${NC}"
    else
        echo -e "${RED}バックアップの作成に失敗しました${NC}"
    fi
}

# システム状態の監視
monitor_system() {
    echo -e "${BLUE}システム状態の監視を開始します...${NC}"
    
    # CPU使用率
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
    echo "CPU使用率: $cpu_usage%"
    
    # メモリ使用率
    memory_usage=$(free | grep Mem | awk '{print $3/$2 * 100.0}')
    echo "メモリ使用率: $memory_usage%"
    
    # ディスク使用率
    disk_usage=$(df -h / | awk 'NR==2 {print $5}')
    echo "ディスク使用率: $disk_usage"
    
    # プロセスの状態確認
    echo -e "${YELLOW}重要なプロセスの状態:${NC}"
    for process in "${PROCESSES[@]}"; do
        if pgrep -x "$process" >/dev/null; then
            echo -e "$process: ${GREEN}実行中${NC}"
        else
            echo -e "$process: ${RED}停止${NC}"
        fi
    done
}

# メイン処理
main() {
    echo -e "${GREEN}===== 業務効率化スクリプト =====${NC}"
    
    while true; do
        echo -e "\n${YELLOW}実行したい操作を選択してください:${NC}"
        echo "1) ログファイル分析"
        echo "2) バックアップの作成"
        echo "3) システム状態の監視"
        echo "4) 終了"
        
        read -p "選択 (1-4): " choice
        
        case $choice in
            1) analyze_logs ;;
            2) create_backup ;;
            3) monitor_system ;;
            4) echo "スクリプトを終了します"; exit 0 ;;
            *) echo -e "${RED}無効な選択です。もう一度お試しください。${NC}" ;;
        esac
    done
}

# スクリプトの実行
main
