#!/bin/bash
# =============================================================================
# ヘルスチェック・モニタリングスクリプト
#
# システム、サービス、ネットワーク、ディスク等の健全性を監視し、
# レポートを生成する。
#
# Usage:
#   ./health_monitor.sh check all
#   ./health_monitor.sh check system --output=json
#   ./health_monitor.sh monitor services --threshold=85 --interval=60
#
# =============================================================================

set -euo pipefail

# =============================================================================
# Constants
# =============================================================================

readonly SCRIPT_NAME="${0##*/}"
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Default configuration
readonly DEFAULT_CPU_THRESHOLD=80
readonly DEFAULT_MEMORY_THRESHOLD=85
readonly DEFAULT_DISK_THRESHOLD=90
readonly DEFAULT_INTERVAL=300
readonly DEFAULT_LOG_DIR="/var/log"
readonly DEFAULT_REPORT_DIR="/tmp"

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_ERROR=1
readonly EXIT_USAGE=2
readonly EXIT_WARNING=3

# Colors (disabled if not terminal)
if [[ -t 1 ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[0;33m'
    readonly BLUE='\033[0;34m'
    readonly NC='\033[0m'
else
    readonly RED='' GREEN='' YELLOW='' BLUE='' NC=''
fi

# =============================================================================
# Configuration
# =============================================================================

declare -A CONFIG=(
    [action]=""
    [target]=""
    [output]="text"
    [silent]="false"
    [cpu_threshold]="$DEFAULT_CPU_THRESHOLD"
    [memory_threshold]="$DEFAULT_MEMORY_THRESHOLD"
    [disk_threshold]="$DEFAULT_DISK_THRESHOLD"
    [interval]="$DEFAULT_INTERVAL"
    [log_file]="${DEFAULT_LOG_DIR}/health_monitor.log"
    [report_dir]="$DEFAULT_REPORT_DIR"
)

# Counters
declare -i total_checks=0
declare -i passed_checks=0
declare -i failed_checks=0
declare -i warning_checks=0

# Report file path
report_file=""

# =============================================================================
# Utility Functions
# =============================================================================

usage() {
    cat <<EOF
Usage: $SCRIPT_NAME <action> <target> [options]

Actions:
    check       Run health checks once
    monitor     Continuous monitoring with interval
    report      Generate comprehensive report

Targets:
    all         All checks
    system      CPU, memory, load average
    services    System services status
    disk        Disk space and I/O
    network     Network connectivity and ports
    database    Database connectivity (if configured)
    security    Security-related checks

Options:
    --cpu-threshold=N      CPU usage threshold (default: $DEFAULT_CPU_THRESHOLD)
    --memory-threshold=N   Memory usage threshold (default: $DEFAULT_MEMORY_THRESHOLD)
    --disk-threshold=N     Disk usage threshold (default: $DEFAULT_DISK_THRESHOLD)
    --interval=N           Monitoring interval in seconds (default: $DEFAULT_INTERVAL)
    --output=FORMAT        Output format: text, json (default: text)
    --silent               Suppress stdout output
    --log-file=PATH        Log file path
    --help, -h             Show this help message
    --version, -v          Show version

Examples:
    $SCRIPT_NAME check all
    $SCRIPT_NAME check system --output=json
    $SCRIPT_NAME monitor disk --threshold=85 --interval=60
    $SCRIPT_NAME report all --output=json

EOF
}

version() {
    echo "$SCRIPT_NAME version $SCRIPT_VERSION"
}

log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

    local color=""
    case "$level" in
        INFO)  color="$GREEN" ;;
        WARN)  color="$YELLOW" ;;
        ERROR) color="$RED" ;;
        DEBUG) color="$BLUE" ;;
    esac

    local log_line="[$timestamp] [$level] $message"

    # Write to log file
    echo "$log_line" >> "${CONFIG[log_file]}" 2>/dev/null || true

    # Write to stdout unless silent
    if [[ "${CONFIG[silent]}" != "true" ]]; then
        echo -e "${color}${log_line}${NC}"
    fi
}

info()  { log "INFO"  "$1"; }
warn()  { log "WARN"  "$1"; }
error() { log "ERROR" "$1"; }
debug() { [[ "${DEBUG:-}" == "true" ]] && log "DEBUG" "$1" || true; }

die() {
    error "$1"
    exit "${2:-$EXIT_ERROR}"
}

require_command() {
    local cmd="$1"
    if ! command -v "$cmd" &>/dev/null; then
        die "Required command not found: $cmd"
    fi
}

# =============================================================================
# Argument Parsing
# =============================================================================

parse_args() {
    if [[ $# -lt 2 ]]; then
        usage
        exit $EXIT_USAGE
    fi

    CONFIG[action]="$1"
    CONFIG[target]="$2"
    shift 2

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --cpu-threshold=*)
                CONFIG[cpu_threshold]="${1#*=}"
                ;;
            --memory-threshold=*)
                CONFIG[memory_threshold]="${1#*=}"
                ;;
            --disk-threshold=*)
                CONFIG[disk_threshold]="${1#*=}"
                ;;
            --threshold=*)
                # Legacy: set all thresholds
                local val="${1#*=}"
                CONFIG[cpu_threshold]="$val"
                CONFIG[memory_threshold]="$val"
                CONFIG[disk_threshold]="$val"
                ;;
            --interval=*)
                CONFIG[interval]="${1#*=}"
                ;;
            --output=*)
                CONFIG[output]="${1#*=}"
                ;;
            --log-file=*)
                CONFIG[log_file]="${1#*=}"
                ;;
            --silent)
                CONFIG[silent]="true"
                ;;
            --help|-h)
                usage
                exit $EXIT_SUCCESS
                ;;
            --version|-v)
                version
                exit $EXIT_SUCCESS
                ;;
            *)
                die "Unknown option: $1" $EXIT_USAGE
                ;;
        esac
        shift
    done

    # Validate action
    case "${CONFIG[action]}" in
        check|monitor|report) ;;
        *) die "Invalid action: ${CONFIG[action]}" $EXIT_USAGE ;;
    esac

    # Validate target
    case "${CONFIG[target]}" in
        all|system|services|disk|network|database|security) ;;
        *) die "Invalid target: ${CONFIG[target]}" $EXIT_USAGE ;;
    esac

    # Validate output format
    case "${CONFIG[output]}" in
        text|json) ;;
        *) die "Invalid output format: ${CONFIG[output]}" $EXIT_USAGE ;;
    esac
}

# =============================================================================
# JSON Report Functions
# =============================================================================

init_json_report() {
    report_file="${CONFIG[report_dir]}/health_report_$(date +%Y%m%d_%H%M%S).json"

    cat > "$report_file" <<EOF
{
  "metadata": {
    "timestamp": "$(date -Iseconds)",
    "hostname": "$(hostname -f 2>/dev/null || hostname)",
    "script_version": "$SCRIPT_VERSION",
    "target": "${CONFIG[target]}"
  },
  "checks": [
EOF
}

add_json_check() {
    local name="$1"
    local status="$2"
    local message="$3"
    local value="${4:-null}"

    # Add comma if not first entry
    if [[ $total_checks -gt 1 ]]; then
        echo "," >> "$report_file"
    fi

    cat >> "$report_file" <<EOF
    {
      "name": "$name",
      "status": "$status",
      "message": "$message",
      "value": $value,
      "timestamp": "$(date -Iseconds)"
    }
EOF
}

finalize_json_report() {
    local overall_status="healthy"
    [[ $warning_checks -gt 0 ]] && overall_status="warning"
    [[ $failed_checks -gt 0 ]] && overall_status="critical"

    cat >> "$report_file" <<EOF

  ],
  "summary": {
    "total_checks": $total_checks,
    "passed": $passed_checks,
    "warnings": $warning_checks,
    "failed": $failed_checks,
    "status": "$overall_status"
  }
}
EOF

    info "Report saved to: $report_file"
}

# =============================================================================
# Check Functions
# =============================================================================

record_result() {
    local name="$1"
    local status="$2"
    local message="$3"
    local value="${4:-null}"

    ((total_checks++))

    case "$status" in
        pass)
            ((passed_checks++))
            info "✓ $name: $message"
            ;;
        warn)
            ((warning_checks++))
            warn "⚠ $name: $message"
            ;;
        fail)
            ((failed_checks++))
            error "✗ $name: $message"
            ;;
    esac

    if [[ "${CONFIG[output]}" == "json" ]]; then
        add_json_check "$name" "$status" "$message" "$value"
    fi
}

check_cpu() {
    local cpu_usage
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print int($2 + $4)}' 2>/dev/null || echo "0")

    if [[ $cpu_usage -ge ${CONFIG[cpu_threshold]} ]]; then
        record_result "cpu_usage" "fail" "CPU usage ${cpu_usage}% exceeds threshold ${CONFIG[cpu_threshold]}%" "$cpu_usage"
    elif [[ $cpu_usage -ge $((CONFIG[cpu_threshold] - 10)) ]]; then
        record_result "cpu_usage" "warn" "CPU usage ${cpu_usage}% approaching threshold" "$cpu_usage"
    else
        record_result "cpu_usage" "pass" "CPU usage ${cpu_usage}% within limits" "$cpu_usage"
    fi
}

check_memory() {
    local memory_usage
    memory_usage=$(free | awk '/Mem:/ {printf "%.0f", $3/$2 * 100}' 2>/dev/null || echo "0")

    if [[ $memory_usage -ge ${CONFIG[memory_threshold]} ]]; then
        record_result "memory_usage" "fail" "Memory usage ${memory_usage}% exceeds threshold" "$memory_usage"
    elif [[ $memory_usage -ge $((CONFIG[memory_threshold] - 10)) ]]; then
        record_result "memory_usage" "warn" "Memory usage ${memory_usage}% approaching threshold" "$memory_usage"
    else
        record_result "memory_usage" "pass" "Memory usage ${memory_usage}% within limits" "$memory_usage"
    fi
}

check_load() {
    local load_avg num_cpus load_per_cpu
    load_avg=$(awk '{print $1}' /proc/loadavg 2>/dev/null || echo "0")
    num_cpus=$(nproc 2>/dev/null || echo "1")
    load_per_cpu=$(awk "BEGIN {printf \"%.2f\", $load_avg / $num_cpus}")

    if awk "BEGIN {exit !($load_per_cpu >= 2.0)}"; then
        record_result "load_average" "fail" "Load per CPU ${load_per_cpu} is very high" "$load_per_cpu"
    elif awk "BEGIN {exit !($load_per_cpu >= 1.0)}"; then
        record_result "load_average" "warn" "Load per CPU ${load_per_cpu} is elevated" "$load_per_cpu"
    else
        record_result "load_average" "pass" "Load per CPU ${load_per_cpu} is normal" "$load_per_cpu"
    fi
}

check_disk() {
    local threshold="${CONFIG[disk_threshold]}"

    while IFS= read -r line; do
        local mount usage
        mount=$(echo "$line" | awk '{print $6}')
        usage=$(echo "$line" | awk '{print int($5)}')

        if [[ $usage -ge $threshold ]]; then
            record_result "disk_${mount//\//_}" "fail" "Disk ${mount} at ${usage}% usage" "$usage"
        elif [[ $usage -ge $((threshold - 10)) ]]; then
            record_result "disk_${mount//\//_}" "warn" "Disk ${mount} at ${usage}% usage" "$usage"
        else
            record_result "disk_${mount//\//_}" "pass" "Disk ${mount} at ${usage}% usage" "$usage"
        fi
    done < <(df -h --output=source,fstype,size,used,pcent,target 2>/dev/null | \
             grep -E '^/dev/' | grep -v 'tmpfs')
}

check_services() {
    local services=("sshd" "cron" "rsyslog")

    # Add custom services if systemd is available
    if command -v systemctl &>/dev/null; then
        for service in "${services[@]}"; do
            if systemctl is-active --quiet "$service" 2>/dev/null; then
                record_result "service_${service}" "pass" "Service $service is running" "true"
            else
                record_result "service_${service}" "fail" "Service $service is not running" "false"
            fi
        done
    else
        record_result "services" "warn" "systemctl not available, skipping service checks" "null"
    fi
}

check_network() {
    # DNS resolution
    if host google.com &>/dev/null || nslookup google.com &>/dev/null; then
        record_result "dns_resolution" "pass" "DNS resolution working" "true"
    else
        record_result "dns_resolution" "fail" "DNS resolution failed" "false"
    fi

    # Internet connectivity
    if ping -c 1 -W 3 8.8.8.8 &>/dev/null; then
        record_result "internet_connectivity" "pass" "Internet connectivity OK" "true"
    else
        record_result "internet_connectivity" "fail" "Internet connectivity failed" "false"
    fi

    # SSH port
    if ss -tlnp 2>/dev/null | grep -q ':22\s'; then
        record_result "ssh_port" "pass" "SSH port 22 is listening" "true"
    else
        record_result "ssh_port" "warn" "SSH port 22 not detected" "false"
    fi
}

check_security() {
    # Check for failed login attempts
    local failed_logins=0
    if [[ -f /var/log/auth.log ]]; then
        failed_logins=$(grep -c "Failed password" /var/log/auth.log 2>/dev/null || echo "0")
    elif [[ -f /var/log/secure ]]; then
        failed_logins=$(grep -c "Failed password" /var/log/secure 2>/dev/null || echo "0")
    fi

    if [[ $failed_logins -gt 100 ]]; then
        record_result "failed_logins" "fail" "$failed_logins failed login attempts detected" "$failed_logins"
    elif [[ $failed_logins -gt 10 ]]; then
        record_result "failed_logins" "warn" "$failed_logins failed login attempts detected" "$failed_logins"
    else
        record_result "failed_logins" "pass" "$failed_logins failed login attempts" "$failed_logins"
    fi

    # Check for running firewall
    if command -v ufw &>/dev/null && ufw status 2>/dev/null | grep -q "active"; then
        record_result "firewall" "pass" "UFW firewall is active" "true"
    elif command -v firewall-cmd &>/dev/null && firewall-cmd --state &>/dev/null; then
        record_result "firewall" "pass" "firewalld is active" "true"
    elif iptables -L -n &>/dev/null 2>&1; then
        local rules
        rules=$(iptables -L -n 2>/dev/null | wc -l)
        if [[ $rules -gt 10 ]]; then
            record_result "firewall" "pass" "iptables rules configured" "true"
        else
            record_result "firewall" "warn" "Minimal iptables rules" "false"
        fi
    else
        record_result "firewall" "warn" "No firewall detected" "false"
    fi
}

check_database() {
    # PostgreSQL
    if command -v psql &>/dev/null; then
        if pg_isready &>/dev/null; then
            record_result "postgresql" "pass" "PostgreSQL is ready" "true"
        else
            record_result "postgresql" "fail" "PostgreSQL is not ready" "false"
        fi
    fi

    # MySQL/MariaDB
    if command -v mysqladmin &>/dev/null; then
        if mysqladmin ping &>/dev/null 2>&1; then
            record_result "mysql" "pass" "MySQL is responding" "true"
        else
            record_result "mysql" "fail" "MySQL is not responding" "false"
        fi
    fi

    # Redis
    if command -v redis-cli &>/dev/null; then
        if redis-cli ping &>/dev/null 2>&1; then
            record_result "redis" "pass" "Redis is responding" "true"
        else
            record_result "redis" "fail" "Redis is not responding" "false"
        fi
    fi
}

# =============================================================================
# Main Check Dispatcher
# =============================================================================

run_checks() {
    local target="${CONFIG[target]}"

    if [[ "${CONFIG[output]}" == "json" ]]; then
        init_json_report
    fi

    info "Starting health checks for target: $target"

    case "$target" in
        all)
            check_cpu
            check_memory
            check_load
            check_disk
            check_services
            check_network
            check_security
            check_database
            ;;
        system)
            check_cpu
            check_memory
            check_load
            ;;
        disk)
            check_disk
            ;;
        services)
            check_services
            ;;
        network)
            check_network
            ;;
        security)
            check_security
            ;;
        database)
            check_database
            ;;
    esac

    if [[ "${CONFIG[output]}" == "json" ]]; then
        finalize_json_report
    fi

    # Print summary
    echo ""
    info "========== Summary =========="
    info "Total: $total_checks | Passed: $passed_checks | Warnings: $warning_checks | Failed: $failed_checks"

    # Return appropriate exit code
    if [[ $failed_checks -gt 0 ]]; then
        return $EXIT_ERROR
    elif [[ $warning_checks -gt 0 ]]; then
        return $EXIT_WARNING
    fi
    return $EXIT_SUCCESS
}

run_monitor() {
    local interval="${CONFIG[interval]}"

    info "Starting continuous monitoring (interval: ${interval}s)"
    info "Press Ctrl+C to stop"

    trap 'info "Monitoring stopped"; exit 0' INT TERM

    while true; do
        # Reset counters
        total_checks=0
        passed_checks=0
        failed_checks=0
        warning_checks=0

        run_checks || true

        info "Next check in ${interval} seconds..."
        sleep "$interval"
    done
}

# =============================================================================
# Main
# =============================================================================

main() {
    parse_args "$@"

    # Ensure log directory exists
    mkdir -p "$(dirname "${CONFIG[log_file]}")" 2>/dev/null || true

    case "${CONFIG[action]}" in
        check)
            run_checks
            ;;
        monitor)
            run_monitor
            ;;
        report)
            CONFIG[output]="json"
            run_checks
            ;;
    esac
}

main "$@"
