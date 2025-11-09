#!/bin/bash

# ヘルスチェック・モニタリングスクリプト
# 使用例: ansible all -m script -a "health_monitor.sh check all"

set -euo pipefail

# 引数チェック
if [ $# -lt 2 ]; then
    echo "Usage: $0 <action> <target> [options]"
    echo "Actions: check, monitor, alert, report"
    echo "Targets: all, system, services, database, network, disk, security"
    echo "Options: --threshold=N, --output=json, --silent"
    exit 1
fi

ACTION="$1"
TARGET="$2"
OUTPUT_FORMAT="text"
SILENT=false
CPU_THRESHOLD=80
MEMORY_THRESHOLD=85
DISK_THRESHOLD=90
LOG_FILE="/var/log/health_monitor.log"
REPORT_FILE="/tmp/health_report_$(date +%Y%m%d_%H%M%S).json"

# オプション解析
shift 2
while [ $# -gt 0 ]; do
    case "$1" in
        --threshold=*)
            CPU_THRESHOLD="${1#*=}"
            MEMORY_THRESHOLD="${1#*=}"
            ;;
        --output=*)
            OUTPUT_FORMAT="${1#*=}"
            ;;
        --silent)
            SILENT=true
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
    shift
done

# ログ関数
log() {
    if [ "$SILENT" = false ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    fi
}

# JSON出力初期化
init_json_report() {
    cat > "$REPORT_FILE" <<EOF
{
    "timestamp": "$(date -Iseconds)",
    "hostname": "$(hostname)",
    "checks": {
EOF
}

# JSON出力終了
finalize_json_report() {
    # 最後のカンマを削除
    sed -i '$ s/,$//' "$REPORT_FILE"
    cat >> "$REPORT_FILE" <<EOF
    },
    "summary": {
        "total_checks": $total_checks,
        "passed_checks": $passed_checks,
        "failed_checks": $failed_checks,
        "overall_status": "$overall_status"
    }
}
EOF
}

# チェック結果をJSONに追加
add_json_result() {
    local check_name="$1"
    local status="$2"
    local message="$3"
    local value="${4:-null}"
    
    cat >> "$REPORT_FILE" <<EOF
        "$check_name": {
            "status": "$status",
            "message": "$message",
            "value": $value,
            "timestamp": "$(date -Iseconds)"
        },
EOF
}
