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

# システムリソースチェック
check_system_resources() {
    log "Checking system resources"
    
    # CPU使用率
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    cpu_usage=${cpu_usage:-0}
    
    if (( $(echo "$cpu_usage > $CPU_THRESHOLD" | bc -l) )); then
        log "WARNING: High CPU usage: ${cpu_usage}%"
        [ "$OUTPUT_FORMAT" = "json" ] && add_json_result "cpu_usage" "warning" "High CPU usage" "$cpu_usage"
        return 1
    else
        log "CPU usage OK: ${cpu_usage}%"
        [ "$OUTPUT_FORMAT" = "json" ] && add_json_result "cpu_usage" "ok" "CPU usage normal" "$cpu_usage"
    fi
    
    # メモリ使用率
    local memory_info=$(free | grep '^Mem:')
    local total_mem=$(echo $memory_info | awk '{print $2}')
    local used_mem=$(echo $memory_info | awk '{print $3}')
    local memory_usage=$(echo "scale=2; $used_mem * 100 / $total_mem" | bc)
    
    if (( $(echo "$memory_usage > $MEMORY_THRESHOLD" | bc -l) )); then
        log "WARNING: High memory usage: ${memory_usage}%"
        [ "$OUTPUT_FORMAT" = "json" ] && add_json_result "memory_usage" "warning" "High memory usage" "$memory_usage"
        return 1
    else
        log "Memory usage OK: ${memory_usage}%"
        [ "$OUTPUT_FORMAT" = "json" ] && add_json_result "memory_usage" "ok" "Memory usage normal" "$memory_usage"
    fi
    
    # ロードアベレージ
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    local cpu_cores=$(nproc)
    local load_per_core=$(echo "scale=2; $load_avg / $cpu_cores" | bc)
    
    if (( $(echo "$load_per_core > 1.0" | bc -l) )); then
        log "WARNING: High load average: $load_avg (${load_per_core} per core)"
        [ "$OUTPUT_FORMAT" = "json" ] && add_json_result "load_average" "warning" "High load average" "$load_avg"
        return 1
    else
        log "Load average OK: $load_avg"
        [ "$OUTPUT_FORMAT" = "json" ] && add_json_result "load_average" "ok" "Load average normal" "$load_avg"
    fi
    
    return 0
}

# ディスク容量チェック
check_disk_space() {
    log "Checking disk space"
    
    local overall_status=0
    
    df -h | grep -E '^/dev/' | while read filesystem size used available percentage mountpoint; do
        local usage_percent=$(echo $percentage | sed 's/%//')
        
        if [ "$usage_percent" -gt "$DISK_THRESHOLD" ]; then
            log "WARNING: High disk usage on $mountpoint: $percentage"
            [ "$OUTPUT_FORMAT" = "json" ] && add_json_result "disk_${mountpoint//\//_}" "warning" "High disk usage" "$usage_percent"
            overall_status=1
        else
            log "Disk usage OK on $mountpoint: $percentage"
            [ "$OUTPUT_FORMAT" = "json" ] && add_json_result "disk_${mountpoint//\//_}" "ok" "Disk usage normal" "$usage_percent"
        fi
    done
    
    # inode使用率チェック
    df -i | grep -E '^/dev/' | while read filesystem inodes used available percentage mountpoint; do
        local usage_percent=$(echo $percentage | sed 's/%//')
        
        if [ "$usage_percent" -gt 80 ]; then
            log "WARNING: High inode usage on $mountpoint: $percentage"
            [ "$OUTPUT_FORMAT" = "json" ] && add_json_result "inode_${mountpoint//\//_}" "warning" "High inode usage" "$usage_percent"
            overall_status=1
        else
            log "Inode usage OK on $mountpoint: $percentage"
            [ "$OUTPUT_FORMAT" = "json" ] && add_json_result "inode_${mountpoint//\//_}" "ok" "Inode usage normal" "$usage_percent"
        fi
    done
    
    return $overall_status
}

# サービス状態チェック
check_services() {
    log "Checking critical services"
    
    local services=("nginx" "mysql" "myapp" "redis")
    local overall_status=0
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            log "Service $service is running"
            [ "$OUTPUT_FORMAT" = "json" ] && add_json_result "service_$service" "ok" "Service is running" "true"
        else
            log "ERROR: Service $service is not running"
            [ "$OUTPUT_FORMAT" = "json" ] && add_json_result "service_$service" "error" "Service is not running" "false"
            overall_status=1
        fi
        
        # サービスが有効になっているかチェック
        if systemctl is-enabled --quiet "$service"; then
            log "Service $service is enabled"
        else
            log "WARNING: Service $service is not enabled"
        fi
    done
    
    return $overall_status
}

# データベース接続チェック
check_database() {
    log "Checking database connectivity"
    
    local config_file="/etc/myapp/db_production.conf"
    if [ ! -f "$config_file" ]; then
        log "ERROR: Database configuration file not found"
        [ "$OUTPUT_FORMAT" = "json" ] && add_json_result "database_connection" "error" "Configuration file not found" "false"
        return 1
    fi
    
    source "$config_file"
    
    # 接続テスト
    if mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" -e "SELECT 1;" "$DB_NAME" >/dev/null 2>&1; then
        log "Database connection OK"
        [ "$OUTPUT_FORMAT" = "json" ] && add_json_result "database_connection" "ok" "Database connection successful" "true"
        
        # 接続数チェック
        local connections=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" -N -e "SHOW STATUS LIKE 'Threads_connected';" | awk '{print $2}')
        local max_connections=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" -N -e "SHOW VARIABLES LIKE 'max_connections';" | awk '{print $2}')
        local connection_usage=$(echo "scale=2; $connections * 100 / $max_connections" | bc)
        
        if (( $(echo "$connection_usage > 80" | bc -l) )); then
            log "WARNING: High database connection usage: ${connection_usage}%"
            [ "$OUTPUT_FORMAT" = "json" ] && add_json_result "database_connections" "warning" "High connection usage" "$connection_usage"
        else
            log "Database connections OK: ${connections}/${max_connections}"
            [ "$OUTPUT_FORMAT" = "json" ] && add_json_result "database_connections" "ok" "Connection usage normal" "$connection_usage"
        fi
        
        return 0
    else
        log "ERROR: Database connection failed"
        [ "$OUTPUT_FORMAT" = "json" ] && add_json_result "database_connection" "error" "Database connection failed" "false"
        return 1
    fi
}

# ネットワーク接続チェック
check_network() {
    log "Checking network connectivity"
    
    local hosts=("8.8.8.8" "1.1.1.1" "google.com")
    local overall_status=0
    
    for host in "${hosts[@]}"; do
        if ping -c 1 -W 5 "$host" >/dev/null 2>&1; then
            log "Network connectivity to $host OK"
            [ "$OUTPUT_FORMAT" = "json" ] && add_json_result "network_$host" "ok" "Network connectivity OK" "true"
        else
            log "ERROR: Network connectivity to $host failed"
            [ "$OUTPUT_FORMAT" = "json" ] && add_json_result "network_$host" "error" "Network connectivity failed" "false"
            overall_status=1
        fi
    done
    
    # ポート接続チェック
    local ports=("80:nginx" "443:nginx" "3306:mysql" "8080:myapp")
    
    for port_service in "${ports[@]}"; do
        local port=$(echo $port_service | cut -d: -f1)
        local service=$(echo $port_service | cut -d: -f2)
        
        if netstat -tuln | grep ":$port " >/dev/null; then
            log "Port $port ($service) is listening"
            [ "$OUTPUT_FORMAT" = "json" ] && add_json_result "port_$port" "ok" "Port is listening" "true"
        else
            log "WARNING: Port $port ($service) is not listening"
            [ "$OUTPUT_FORMAT" = "json" ] && add_json_result "port_$port" "warning" "Port is not listening" "false"
            overall_status=1
        fi
    done
    
    return $overall_status
}

# セキュリティチェック
check_security() {
    log "Checking security status"
    
    local overall_status=0
    
    # ファイアウォール状態
    if command -v ufw >/dev/null 2>&1; then
        if ufw status | grep -q "Status: active"; then
            log "Firewall is active"
            [ "$OUTPUT_FORMAT" = "json" ] && add_json_result "firewall" "ok" "Firewall is active" "true"
        else
            log "WARNING: Firewall is not active"
            [ "$OUTPUT_FORMAT" = "json" ] && add_json_result "firewall" "warning" "Firewall is not active" "false"
            overall_status=1
        fi
    fi
    
    # SSH設定チェック
    if [ -f "/etc/ssh/sshd_config" ]; then
        if grep -q "PermitRootLogin no" /etc/ssh/sshd_config; then
            log "SSH root login is disabled"
            [ "$OUTPUT_FORMAT" = "json" ] && add_json_result "ssh_root_login" "ok" "SSH root login disabled" "true"
        else
            log "WARNING: SSH root login may be enabled"
            [ "$OUTPUT_FORMAT" = "json" ] && add_json_result "ssh_root_login" "warning" "SSH root login may be enabled" "false"
            overall_status=1
        fi
    fi
    
    # 失敗したログイン試行チェック
    local failed_logins=$(grep "Failed password" /var/log/auth.log 2>/dev/null | wc -l || echo "0")
    if [ "$failed_logins" -gt 100 ]; then
        log "WARNING: High number of failed login attempts: $failed_logins"
        [ "$OUTPUT_FORMAT" = "json" ] && add_json_result "failed_logins" "warning" "High number of failed login attempts" "$failed_logins"
        overall_status=1
    else
        log "Failed login attempts normal: $failed_logins"
        [ "$OUTPUT_FORMAT" = "json" ] && add_json_result "failed_logins" "ok" "Failed login attempts normal" "$failed_logins"
    fi
    
    return $overall_status
}

# アラート送信
send_alert() {
    local message="$1"
    local severity="$2"
    
    log "Sending alert: $message"
    
    # メール送信（mailコマンドが利用可能な場合）
    if command -v mail >/dev/null 2>&1; then
        echo "$message" | mail -s "[$severity] Health Check Alert - $(hostname)" admin@example.com
    fi
    
    # Slackウェブフック（設定されている場合）
    if [ -f "/etc/myapp/slack_webhook.conf" ]; then
        source "/etc/myapp/slack_webhook.conf"
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"[$severity] $(hostname): $message\"}" \
            "$SLACK_WEBHOOK_URL" 2>/dev/null || true
    fi
}

# レポート生成
generate_report() {
    log "Generating health report"
    
    local report_file="/tmp/health_report_$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$report_file" <<EOF
Health Check Report
==================
Generated: $(date)
Hostname: $(hostname)
Uptime: $(uptime)

System Information:
- OS: $(lsb_release -d 2>/dev/null | cut -f2 || echo "Unknown")
- Kernel: $(uname -r)
- Architecture: $(uname -m)

EOF
    
    # 各チェック実行してレポートに追加
    {
        echo "=== System Resources ==="
        check_system_resources
        echo
        
        echo "=== Disk Space ==="
        check_disk_space
        echo
        
        echo "=== Services ==="
        check_services
        echo
        
        echo "=== Database ==="
        check_database
        echo
        
        echo "=== Network ==="
        check_network
        echo
        
        echo "=== Security ==="
        check_security
        echo
    } >> "$report_file" 2>&1
    
    log "Report generated: $report_file"
    
    if [ "$OUTPUT_FORMAT" = "json" ]; then
        cat "$REPORT_FILE"
    else
        cat "$report_file"
    fi
}

# メイン処理
total_checks=0
passed_checks=0
failed_checks=0
overall_status="ok"

if [ "$OUTPUT_FORMAT" = "json" ]; then
    init_json_report
fi

case "$ACTION" in
    "check")
        case "$TARGET" in
            "all")
                check_system_resources; total_checks=$((total_checks+1)); [ $? -eq 0 ] && passed_checks=$((passed_checks+1)) || failed_checks=$((failed_checks+1))
                check_disk_space; total_checks=$((total_checks+1)); [ $? -eq 0 ] && passed_checks=$((passed_checks+1)) || failed_checks=$((failed_checks+1))
                check_services; total_checks=$((total_checks+1)); [ $? -eq 0 ] && passed_checks=$((passed_checks+1)) || failed_checks=$((failed_checks+1))
                check_database; total_checks=$((total_checks+1)); [ $? -eq 0 ] && passed_checks=$((passed_checks+1)) || failed_checks=$((failed_checks+1))
                check_network; total_checks=$((total_checks+1)); [ $? -eq 0 ] && passed_checks=$((passed_checks+1)) || failed_checks=$((failed_checks+1))
                check_security; total_checks=$((total_checks+1)); [ $? -eq 0 ] && passed_checks=$((passed_checks+1)) || failed_checks=$((failed_checks+1))
                ;;
            "system")
                check_system_resources
                ;;
            "services")
                check_services
                ;;
            "database")
                check_database
                ;;
            "network")
                check_network
                ;;
            "disk")
                check_disk_space
                ;;
            "security")
                check_security
                ;;
            *)
                echo "Invalid target: $TARGET"
                exit 1
                ;;
        esac
        ;;
    "monitor")
        # 継続監視（cron等での使用を想定）
        while true; do
            check_system_resources
            sleep 60
        done
        ;;
    "alert")
        # 閾値を超えた場合のアラート
        if ! check_system_resources; then
            send_alert "System resource usage is high" "WARNING"
        fi
        ;;
    "report")
        generate_report
        ;;
    *)
        echo "Invalid action: $ACTION"
        exit 1
        ;;
esac

if [ "$failed_checks" -gt 0 ]; then
    overall_status="warning"
fi

if [ "$OUTPUT_FORMAT" = "json" ]; then
    finalize_json_report
    cat "$REPORT_FILE"
fi

log "Health check completed. Passed: $passed_checks, Failed: $failed_checks"

exit $failed_checks
