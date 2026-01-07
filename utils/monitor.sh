#!/bin/bash
# =============================================================================
# ヘルスチェック・モニタリングスクリプト (クロスプラットフォーム版)
#
# 対応OS: Linux, macOS, FreeBSD, OpenBSD, Windows WSL/Git Bash
#
# Usage:
#   ./health_monitor.sh check all
#   ./health_monitor.sh check system --output=json
#   ./health_monitor.sh monitor disk --interval=60
#
# =============================================================================

set -euo pipefail

# =============================================================================
# Constants
# =============================================================================

readonly SCRIPT_NAME="${0##*/}"
readonly SCRIPT_VERSION="2.0.0"

# Detect OS
detect_os() {
    local os=""
    case "$(uname -s)" in
        Linux*)
            if grep -q Microsoft /proc/version 2>/dev/null; then
                os="wsl"
            elif [[ -f /etc/alpine-release ]]; then
                os="alpine"
            else
                os="linux"
            fi
            ;;
        Darwin*)  os="macos" ;;
        FreeBSD*) os="freebsd" ;;
        OpenBSD*) os="openbsd" ;;
        NetBSD*)  os="netbsd" ;;
        CYGWIN*|MINGW*|MSYS*) os="windows" ;;
        *)        os="unknown" ;;
    esac
    echo "$os"
}

readonly OS_TYPE="$(detect_os)"

# Default paths based on OS
get_default_log_dir() {
    case "$OS_TYPE" in
        macos)   echo "/var/log" ;;
        windows) echo "${TEMP:-/tmp}" ;;
        *)       echo "/var/log" ;;
    esac
}

get_default_tmp_dir() {
    case "$OS_TYPE" in
        macos)   echo "${TMPDIR:-/tmp}" ;;
        windows) echo "${TEMP:-/tmp}" ;;
        *)       echo "/tmp" ;;
    esac
}

# Default configuration
readonly DEFAULT_CPU_THRESHOLD=80
readonly DEFAULT_MEMORY_THRESHOLD=85
readonly DEFAULT_DISK_THRESHOLD=90
readonly DEFAULT_INTERVAL=300

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_ERROR=1
readonly EXIT_USAGE=2
readonly EXIT_WARNING=3

# Colors
setup_colors() {
    if [[ -t 1 ]] && [[ "${TERM:-}" != "dumb" ]]; then
        RED='\033[0;31m'
        GREEN='\033[0;32m'
        YELLOW='\033[0;33m'
        BLUE='\033[0;34m'
        BOLD='\033[1m'
        NC='\033[0m'
    else
        RED='' GREEN='' YELLOW='' BLUE='' BOLD='' NC=''
    fi
}
setup_colors

# =============================================================================
# Configuration
# =============================================================================

declare -A CONFIG
CONFIG=(
    [action]=""
    [target]=""
    [output]="text"
    [silent]="false"
    [cpu_threshold]="$DEFAULT_CPU_THRESHOLD"
    [memory_threshold]="$DEFAULT_MEMORY_THRESHOLD"
    [disk_threshold]="$DEFAULT_DISK_THRESHOLD"
    [interval]="$DEFAULT_INTERVAL"
    [log_file]="$(get_default_log_dir)/health_monitor.log"
    [report_dir]="$(get_default_tmp_dir)"
)

# Counters
declare -i total_checks=0
declare -i passed_checks=0
declare -i failed_checks=0
declare -i warning_checks=0

report_file=""

# =============================================================================
# Utility Functions
# =============================================================================

usage() {
    cat <<EOF
Usage: $SCRIPT_NAME <action> <target> [options]

Detected OS: $OS_TYPE

Actions:
    check       Run health checks once
    monitor     Continuous monitoring
    report      Generate JSON report

Targets:
    all         All checks
    system      CPU, memory, load
    disk        Disk usage
    services    System services
    network     Network connectivity
    database    Database health
    security    Security checks

Options:
    --cpu-threshold=N      CPU threshold % (default: $DEFAULT_CPU_THRESHOLD)
    --memory-threshold=N   Memory threshold % (default: $DEFAULT_MEMORY_THRESHOLD)
    --disk-threshold=N     Disk threshold % (default: $DEFAULT_DISK_THRESHOLD)
    --interval=N           Monitor interval seconds (default: $DEFAULT_INTERVAL)
    --output=FORMAT        Output: text, json (default: text)
    --silent               Suppress stdout
    --log-file=PATH        Log file path
    --help, -h             Show help
    --version, -v          Show version

Examples:
    $SCRIPT_NAME check all
    $SCRIPT_NAME check system --output=json
    $SCRIPT_NAME monitor disk --disk-threshold=85

EOF
}

version() {
    echo "$SCRIPT_NAME version $SCRIPT_VERSION (OS: $OS_TYPE)"
}

# Cross-platform date with ISO format
get_iso_date() {
    if date -Iseconds &>/dev/null 2>&1; then
        date -Iseconds
    elif date -u +"%Y-%m-%dT%H:%M:%S%z" &>/dev/null 2>&1; then
        date -u +"%Y-%m-%dT%H:%M:%S%z"
    else
        date +"%Y-%m-%dT%H:%M:%S"
    fi
}

get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp="$(get_timestamp)"

    local color=""
    case "$level" in
        INFO)  color="$GREEN" ;;
        WARN)  color="$YELLOW" ;;
        ERROR) color="$RED" ;;
        DEBUG) color="$BLUE" ;;
    esac

    local log_line="[$timestamp] [$level] $message"

    # Write to log file (create dir if needed)
    local log_dir
    log_dir="$(dirname "${CONFIG[log_file]}")"
    if [[ -w "$log_dir" ]] || mkdir -p "$log_dir" 2>/dev/null; then
        echo "$log_line" >> "${CONFIG[log_file]}" 2>/dev/null || true
    fi

    if [[ "${CONFIG[silent]}" != "true" ]]; then
        echo -e "${color}${log_line}${NC}"
    fi
}

info()  { log "INFO"  "$1"; }
warn()  { log "WARN"  "$1"; }
error() { log "ERROR" "$1"; }

die() {
    error "$1"
    exit "${2:-$EXIT_ERROR}"
}

# Check if command exists
has_cmd() {
    command -v "$1" &>/dev/null
}

# Cross-platform hostname
get_hostname() {
    if has_cmd hostname; then
        hostname -f 2>/dev/null || hostname 2>/dev/null || echo "unknown"
    else
        cat /etc/hostname 2>/dev/null || echo "unknown"
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
            --cpu-threshold=*)    CONFIG[cpu_threshold]="${1#*=}" ;;
            --memory-threshold=*) CONFIG[memory_threshold]="${1#*=}" ;;
            --disk-threshold=*)   CONFIG[disk_threshold]="${1#*=}" ;;
            --threshold=*)
                local val="${1#*=}"
                CONFIG[cpu_threshold]="$val"
                CONFIG[memory_threshold]="$val"
                CONFIG[disk_threshold]="$val"
                ;;
            --interval=*)  CONFIG[interval]="${1#*=}" ;;
            --output=*)    CONFIG[output]="${1#*=}" ;;
            --log-file=*)  CONFIG[log_file]="${1#*=}" ;;
            --silent)      CONFIG[silent]="true" ;;
            --help|-h)     usage; exit $EXIT_SUCCESS ;;
            --version|-v)  version; exit $EXIT_SUCCESS ;;
            *)             die "Unknown option: $1" $EXIT_USAGE ;;
        esac
        shift
    done

    # Validate
    case "${CONFIG[action]}" in
        check|monitor|report) ;;
        *) die "Invalid action: ${CONFIG[action]}" $EXIT_USAGE ;;
    esac

    case "${CONFIG[target]}" in
        all|system|services|disk|network|database|security) ;;
        *) die "Invalid target: ${CONFIG[target]}" $EXIT_USAGE ;;
    esac

    case "${CONFIG[output]}" in
        text|json) ;;
        *) die "Invalid output: ${CONFIG[output]}" $EXIT_USAGE ;;
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
    "timestamp": "$(get_iso_date)",
    "hostname": "$(get_hostname)",
    "os_type": "$OS_TYPE",
    "script_version": "$SCRIPT_VERSION"
  },
  "checks": [
EOF
}

add_json_check() {
    local name="$1"
    local status="$2"
    local message="$3"
    local value="${4:-null}"

    [[ $total_checks -gt 1 ]] && echo "," >> "$report_file"

    cat >> "$report_file" <<EOF
    {"name": "$name", "status": "$status", "message": "$message", "value": $value}
EOF
}

finalize_json_report() {
    local overall_status="healthy"
    [[ $warning_checks -gt 0 ]] && overall_status="warning"
    [[ $failed_checks -gt 0 ]] && overall_status="critical"

    cat >> "$report_file" <<EOF

  ],
  "summary": {
    "total": $total_checks,
    "passed": $passed_checks,
    "warnings": $warning_checks,
    "failed": $failed_checks,
    "status": "$overall_status"
  }
}
EOF
    info "Report: $report_file"
}

# =============================================================================
# Result Recording
# =============================================================================

record_result() {
    local name="$1"
    local status="$2"
    local message="$3"
    local value="${4:-null}"

    ((total_checks++))

    case "$status" in
        pass) ((passed_checks++));   info "✓ $name: $message" ;;
        warn) ((warning_checks++));  warn "⚠ $name: $message" ;;
        fail) ((failed_checks++));   error "✗ $name: $message" ;;
    esac

    [[ "${CONFIG[output]}" == "json" ]] && add_json_check "$name" "$status" "$message" "$value"
}

# =============================================================================
# Cross-Platform Check Functions
# =============================================================================

# --- CPU Usage ---
get_cpu_usage() {
    local cpu=0

    case "$OS_TYPE" in
        linux|wsl|alpine)
            if [[ -f /proc/stat ]]; then
                local idle total
                read -r _ user nice system idle iowait irq softirq _ < /proc/stat
                total=$((user + nice + system + idle + iowait + irq + softirq))
                cpu=$(( (total - idle) * 100 / total ))
            elif has_cmd top; then
                cpu=$(top -bn1 2>/dev/null | awk '/Cpu\(s\)/ {print int($2 + $4)}')
            fi
            ;;
        macos)
            if has_cmd top; then
                cpu=$(top -l 1 -n 0 2>/dev/null | awk '/CPU usage/ {gsub(/%/,""); print int($3 + $5)}')
            fi
            ;;
        freebsd|openbsd|netbsd)
            if has_cmd top; then
                cpu=$(top -b -d 1 2>/dev/null | awk '/CPU:/ {gsub(/%/,""); print int(100 - $NF)}' | head -1)
            fi
            ;;
        windows)
            if has_cmd wmic; then
                cpu=$(wmic cpu get loadpercentage 2>/dev/null | grep -E '^[0-9]+' | head -1)
            fi
            ;;
    esac

    echo "${cpu:-0}"
}

check_cpu() {
    local cpu_usage
    cpu_usage=$(get_cpu_usage)
    local threshold="${CONFIG[cpu_threshold]}"

    if [[ $cpu_usage -ge $threshold ]]; then
        record_result "cpu_usage" "fail" "CPU ${cpu_usage}% >= ${threshold}%" "$cpu_usage"
    elif [[ $cpu_usage -ge $((threshold - 10)) ]]; then
        record_result "cpu_usage" "warn" "CPU ${cpu_usage}% approaching threshold" "$cpu_usage"
    else
        record_result "cpu_usage" "pass" "CPU ${cpu_usage}% OK" "$cpu_usage"
    fi
}

# --- Memory Usage ---
get_memory_usage() {
    local mem=0

    case "$OS_TYPE" in
        linux|wsl|alpine)
            if [[ -f /proc/meminfo ]]; then
                local total available
                total=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
                available=$(awk '/MemAvailable/ {print $2}' /proc/meminfo 2>/dev/null)
                if [[ -z "$available" ]]; then
                    local free buffers cached
                    free=$(awk '/MemFree/ {print $2}' /proc/meminfo)
                    buffers=$(awk '/Buffers/ {print $2}' /proc/meminfo)
                    cached=$(awk '/^Cached/ {print $2}' /proc/meminfo)
                    available=$((free + buffers + cached))
                fi
                mem=$(( (total - available) * 100 / total ))
            fi
            ;;
        macos)
            if has_cmd vm_stat; then
                local page_size free_pages
                page_size=$(sysctl -n hw.pagesize 2>/dev/null || echo 4096)
                free_pages=$(vm_stat 2>/dev/null | awk '/Pages free/ {gsub(/\./,""); print $3}')
                local total_mem
                total_mem=$(sysctl -n hw.memsize 2>/dev/null)
                if [[ -n "$free_pages" && -n "$total_mem" ]]; then
                    local free_mem=$((free_pages * page_size))
                    mem=$(( (total_mem - free_mem) * 100 / total_mem ))
                fi
            fi
            ;;
        freebsd)
            if has_cmd sysctl; then
                local total free
                total=$(sysctl -n hw.physmem 2>/dev/null)
                free=$(sysctl -n vm.stats.vm.v_free_count 2>/dev/null)
                local page_size
                page_size=$(sysctl -n hw.pagesize 2>/dev/null || echo 4096)
                if [[ -n "$total" && -n "$free" ]]; then
                    mem=$(( (total - free * page_size) * 100 / total ))
                fi
            fi
            ;;
        openbsd|netbsd)
            if has_cmd vmstat; then
                # Simplified for BSD variants
                mem=$(vmstat 2>/dev/null | tail -1 | awk '{print int($4 / ($3 + $4) * 100)}')
            fi
            ;;
        windows)
            if has_cmd wmic; then
                local free total
                free=$(wmic OS get FreePhysicalMemory 2>/dev/null | grep -E '^[0-9]+')
                total=$(wmic OS get TotalVisibleMemorySize 2>/dev/null | grep -E '^[0-9]+')
                if [[ -n "$free" && -n "$total" ]]; then
                    mem=$(( (total - free) * 100 / total ))
                fi
            fi
            ;;
    esac

    echo "${mem:-0}"
}

check_memory() {
    local memory_usage
    memory_usage=$(get_memory_usage)
    local threshold="${CONFIG[memory_threshold]}"

    if [[ $memory_usage -ge $threshold ]]; then
        record_result "memory_usage" "fail" "Memory ${memory_usage}% >= ${threshold}%" "$memory_usage"
    elif [[ $memory_usage -ge $((threshold - 10)) ]]; then
        record_result "memory_usage" "warn" "Memory ${memory_usage}% approaching threshold" "$memory_usage"
    else
        record_result "memory_usage" "pass" "Memory ${memory_usage}% OK" "$memory_usage"
    fi
}

# --- Load Average ---
get_load_average() {
    local load="0"

    case "$OS_TYPE" in
        linux|wsl|alpine)
            [[ -f /proc/loadavg ]] && load=$(awk '{print $1}' /proc/loadavg)
            ;;
        macos|freebsd|openbsd|netbsd)
            if has_cmd sysctl; then
                load=$(sysctl -n vm.loadavg 2>/dev/null | awk '{print $2}')
            elif has_cmd uptime; then
                load=$(uptime | awk -F'load average:' '{print $2}' | awk -F',' '{gsub(/ /,""); print $1}')
            fi
            ;;
        windows)
            # Windows doesn't have traditional load average
            load="0"
            ;;
    esac

    echo "${load:-0}"
}

get_cpu_count() {
    local count=1

    case "$OS_TYPE" in
        linux|wsl|alpine)
            if [[ -f /proc/cpuinfo ]]; then
                count=$(grep -c ^processor /proc/cpuinfo 2>/dev/null || echo 1)
            elif has_cmd nproc; then
                count=$(nproc 2>/dev/null || echo 1)
            fi
            ;;
        macos)
            count=$(sysctl -n hw.ncpu 2>/dev/null || echo 1)
            ;;
        freebsd|openbsd|netbsd)
            count=$(sysctl -n hw.ncpu 2>/dev/null || echo 1)
            ;;
        windows)
            count="${NUMBER_OF_PROCESSORS:-1}"
            ;;
    esac

    echo "${count:-1}"
}

check_load() {
    local load_avg num_cpus load_per_cpu
    load_avg=$(get_load_average)
    num_cpus=$(get_cpu_count)

    # Use awk for float division
    load_per_cpu=$(awk "BEGIN {printf \"%.2f\", $load_avg / $num_cpus}")

    if awk "BEGIN {exit !($load_per_cpu >= 2.0)}"; then
        record_result "load_average" "fail" "Load/CPU ${load_per_cpu} very high" "\"$load_per_cpu\""
    elif awk "BEGIN {exit !($load_per_cpu >= 1.0)}"; then
        record_result "load_average" "warn" "Load/CPU ${load_per_cpu} elevated" "\"$load_per_cpu\""
    else
        record_result "load_average" "pass" "Load/CPU ${load_per_cpu} normal" "\"$load_per_cpu\""
    fi
}

# --- Disk Usage ---
check_disk() {
    local threshold="${CONFIG[disk_threshold]}"
    local df_cmd=""
    local parse_awk=""

    case "$OS_TYPE" in
        linux|wsl|alpine)
            df_cmd="df -P"
            parse_awk='{if (NR>1 && $1 ~ /^\/dev/) print $6, $5}'
            ;;
        macos)
            df_cmd="df -P"
            parse_awk='{if (NR>1 && $1 ~ /^\/dev/) print $6, $5}'
            ;;
        freebsd|openbsd|netbsd)
            df_cmd="df"
            parse_awk='{if (NR>1 && $1 ~ /^\/dev/) print $6, $5}'
            ;;
        windows)
            # Use df from Git Bash/Cygwin or fallback
            if has_cmd df; then
                df_cmd="df -P"
                parse_awk='{if (NR>1) print $6, $5}'
            else
                record_result "disk" "warn" "df command not available" "null"
                return
            fi
            ;;
    esac

    local disk_data
    disk_data=$($df_cmd 2>/dev/null | awk "$parse_awk" | sed 's/%//g')

    if [[ -z "$disk_data" ]]; then
        record_result "disk" "warn" "Could not retrieve disk info" "null"
        return
    fi

    while read -r mount usage; do
        [[ -z "$mount" || -z "$usage" ]] && continue

        # Sanitize mount point for JSON key
        local safe_mount="${mount//\//_}"
        safe_mount="${safe_mount#_}"
        [[ -z "$safe_mount" ]] && safe_mount="root"

        if [[ $usage -ge $threshold ]]; then
            record_result "disk_${safe_mount}" "fail" "${mount} at ${usage}%" "$usage"
        elif [[ $usage -ge $((threshold - 10)) ]]; then
            record_result "disk_${safe_mount}" "warn" "${mount} at ${usage}%" "$usage"
        else
            record_result "disk_${safe_mount}" "pass" "${mount} at ${usage}%" "$usage"
        fi
    done <<< "$disk_data"
}

# --- Services ---
check_services() {
    local services=()

    case "$OS_TYPE" in
        linux|wsl|alpine)
            services=("sshd" "cron" "rsyslog")
            ;;
        macos)
            services=("sshd" "com.apple.cron")
            ;;
        freebsd)
            services=("sshd" "cron" "syslogd")
            ;;
        *)
            record_result "services" "warn" "Service check not supported on $OS_TYPE" "null"
            return
            ;;
    esac

    # systemd
    if has_cmd systemctl; then
        for svc in "${services[@]}"; do
            if systemctl is-active --quiet "$svc" 2>/dev/null; then
                record_result "service_${svc}" "pass" "$svc running" "true"
            elif systemctl list-unit-files 2>/dev/null | grep -q "^${svc}"; then
                record_result "service_${svc}" "fail" "$svc not running" "false"
            fi
        done
        return
    fi

    # launchd (macOS)
    if has_cmd launchctl && [[ "$OS_TYPE" == "macos" ]]; then
        for svc in "${services[@]}"; do
            if launchctl list 2>/dev/null | grep -q "$svc"; then
                record_result "service_${svc}" "pass" "$svc loaded" "true"
            fi
        done
        return
    fi

    # rc.d (BSD)
    if [[ -d /etc/rc.d ]]; then
        for svc in "${services[@]}"; do
            if /etc/rc.d/"$svc" status &>/dev/null 2>&1; then
                record_result "service_${svc}" "pass" "$svc running" "true"
            fi
        done
        return
    fi

    record_result "services" "warn" "No service manager detected" "null"
}

# --- Network ---
check_network() {
    # DNS resolution
    local dns_ok=false
    if has_cmd host; then
        host google.com &>/dev/null && dns_ok=true
    elif has_cmd nslookup; then
        nslookup google.com &>/dev/null && dns_ok=true
    elif has_cmd dig; then
        dig google.com +short &>/dev/null && dns_ok=true
    elif has_cmd getent; then
        getent hosts google.com &>/dev/null && dns_ok=true
    fi

    if $dns_ok; then
        record_result "dns" "pass" "DNS resolution OK" "true"
    else
        record_result "dns" "fail" "DNS resolution failed" "false"
    fi

    # Internet connectivity
    local ping_ok=false
    local ping_target="8.8.8.8"

    case "$OS_TYPE" in
        macos|freebsd|openbsd|netbsd)
            ping -c 1 -W 3 "$ping_target" &>/dev/null && ping_ok=true
            ;;
        linux|wsl|alpine)
            ping -c 1 -W 3 "$ping_target" &>/dev/null && ping_ok=true
            ;;
        windows)
            ping -n 1 -w 3000 "$ping_target" &>/dev/null && ping_ok=true
            ;;
    esac

    if $ping_ok; then
        record_result "internet" "pass" "Internet connectivity OK" "true"
    else
        record_result "internet" "fail" "Internet connectivity failed" "false"
    fi

    # SSH port check
    local ssh_listening=false
    if has_cmd ss; then
        ss -tlnp 2>/dev/null | grep -q ':22\s' && ssh_listening=true
    elif has_cmd netstat; then
        netstat -tlnp 2>/dev/null | grep -q ':22\s' && ssh_listening=true
    elif has_cmd lsof; then
        lsof -i :22 -sTCP:LISTEN &>/dev/null && ssh_listening=true
    fi

    if $ssh_listening; then
        record_result "ssh_port" "pass" "SSH port 22 listening" "true"
    else
        record_result "ssh_port" "warn" "SSH port 22 not detected" "false"
    fi
}

# --- Security ---
check_security() {
    # Failed logins
    local failed_logins=0
    local auth_log=""

    case "$OS_TYPE" in
        linux|wsl)
            [[ -f /var/log/auth.log ]] && auth_log="/var/log/auth.log"
            [[ -f /var/log/secure ]] && auth_log="/var/log/secure"
            ;;
        macos)
            # macOS uses different logging
            if has_cmd log; then
                failed_logins=$(log show --predicate 'eventMessage contains "authentication failure"' --last 1d 2>/dev/null | wc -l | tr -d ' ')
            fi
            ;;
        freebsd)
            [[ -f /var/log/auth.log ]] && auth_log="/var/log/auth.log"
            ;;
    esac

    if [[ -n "$auth_log" && -r "$auth_log" ]]; then
        failed_logins=$(grep -c "Failed password\|authentication failure" "$auth_log" 2>/dev/null || echo 0)
    fi

    if [[ $failed_logins -gt 100 ]]; then
        record_result "failed_logins" "fail" "$failed_logins failed attempts" "$failed_logins"
    elif [[ $failed_logins -gt 10 ]]; then
        record_result "failed_logins" "warn" "$failed_logins failed attempts" "$failed_logins"
    else
        record_result "failed_logins" "pass" "$failed_logins failed attempts" "$failed_logins"
    fi

    # Firewall check
    local fw_active=false
    local fw_name="none"

    if has_cmd ufw && ufw status 2>/dev/null | grep -q "active"; then
        fw_active=true; fw_name="ufw"
    elif has_cmd firewall-cmd && firewall-cmd --state &>/dev/null; then
        fw_active=true; fw_name="firewalld"
    elif has_cmd pfctl && pfctl -s info &>/dev/null 2>&1; then
        fw_active=true; fw_name="pf"
    elif has_cmd ipfw && ipfw list &>/dev/null 2>&1; then
        fw_active=true; fw_name="ipfw"
    elif [[ "$OS_TYPE" == "macos" ]]; then
        if /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null | grep -q "enabled"; then
            fw_active=true; fw_name="macOS Application Firewall"
        fi
    fi

    if $fw_active; then
        record_result "firewall" "pass" "$fw_name active" "true"
    else
        record_result "firewall" "warn" "No active firewall detected" "false"
    fi
}

# --- Database ---
check_database() {
    local db_found=false

    # PostgreSQL
    if has_cmd pg_isready; then
        db_found=true
        if pg_isready &>/dev/null; then
            record_result "postgresql" "pass" "PostgreSQL ready" "true"
        else
            record_result "postgresql" "fail" "PostgreSQL not ready" "false"
        fi
    fi

    # MySQL/MariaDB
    if has_cmd mysqladmin; then
        db_found=true
        if mysqladmin ping &>/dev/null 2>&1; then
            record_result "mysql" "pass" "MySQL responding" "true"
        else
            record_result "mysql" "fail" "MySQL not responding" "false"
        fi
    fi

    # Redis
    if has_cmd redis-cli; then
        db_found=true
        if redis-cli ping &>/dev/null 2>&1; then
            record_result "redis" "pass" "Redis responding" "true"
        else
            record_result "redis" "fail" "Redis not responding" "false"
        fi
    fi

    # MongoDB
    if has_cmd mongosh || has_cmd mongo; then
        db_found=true
        local mongo_cmd="mongosh"
        has_cmd mongosh || mongo_cmd="mongo"
        if $mongo_cmd --eval "db.adminCommand('ping')" &>/dev/null 2>&1; then
            record_result "mongodb" "pass" "MongoDB responding" "true"
        else
            record_result "mongodb" "fail" "MongoDB not responding" "false"
        fi
    fi

    if ! $db_found; then
        record_result "database" "warn" "No database clients found" "null"
    fi
}

# =============================================================================
# Main Check Dispatcher
# =============================================================================

run_checks() {
    local target="${CONFIG[target]}"

    [[ "${CONFIG[output]}" == "json" ]] && init_json_report

    info "Health check starting (OS: $OS_TYPE, target: $target)"

    case "$target" in
        all)
            check_cpu; check_memory; check_load; check_disk
            check_services; check_network; check_security; check_database
            ;;
        system)   check_cpu; check_memory; check_load ;;
        disk)     check_disk ;;
        services) check_services ;;
        network)  check_network ;;
        security) check_security ;;
        database) check_database ;;
    esac

    [[ "${CONFIG[output]}" == "json" ]] && finalize_json_report

    echo ""
    info "═══════════════════════════════════════════"
    info "Total: $total_checks | Pass: $passed_checks | Warn: $warning_checks | Fail: $failed_checks"
    info "═══════════════════════════════════════════"

    [[ $failed_checks -gt 0 ]] && return $EXIT_ERROR
    [[ $warning_checks -gt 0 ]] && return $EXIT_WARNING
    return $EXIT_SUCCESS
}

run_monitor() {
    local interval="${CONFIG[interval]}"

    info "Continuous monitoring started (interval: ${interval}s)"
    info "Press Ctrl+C to stop"

    trap 'info "Stopped"; exit 0' INT TERM

    while true; do
        total_checks=0; passed_checks=0; failed_checks=0; warning_checks=0
        run_checks || true
        info "Next check in ${interval}s..."
        sleep "$interval"
    done
}

# =============================================================================
# Main
# =============================================================================

main() {
    parse_args "$@"

    case "${CONFIG[action]}" in
        check)   run_checks ;;
        monitor) run_monitor ;;
        report)  CONFIG[output]="json"; run_checks ;;
    esac
}

main "$@"
