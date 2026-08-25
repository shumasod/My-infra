#!/bin/bash
set -euo pipefail

#
# システムプロファイラー
# 作成日: 2026-08-25
# バージョン: 1.0
#
# システムの詳細情報を収集してレポートを生成します
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare command_name="report"
declare output_format="text"
declare output_file=""
declare verbose=0

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション]

システム詳細情報の収集・レポートツールです。

コマンド:
  report               総合レポート (デフォルト)
  hardware             ハードウェア情報
  os                   OS・カーネル情報
  cpu                  CPU詳細情報
  memory               メモリ詳細情報
  storage              ストレージ情報
  network              ネットワーク設定情報
  software             インストール済みソフトウェア
  performance          パフォーマンス指標

オプション:
  -h, --help           このヘルプを表示
  -v, --version        バージョン情報を表示
  -o, --output <ファイル> レポートをファイルに保存
  -f, --format <形式>  出力形式 (text|json|html) [デフォルト: text]
  --verbose            詳細情報を表示

例:
  $PROG_NAME report
  $PROG_NAME report -o system_report.txt
  $PROG_NAME hardware
  $PROG_NAME performance
EOF
}

section() {
    local title="$1"
    echo ""
    printf "${C_BOLD}${C_CYAN}【%s】${C_RESET}\n\n" "$title"
}

info_row() {
    local key="$1" val="$2"
    printf "  %-30s %s\n" "${key}:" "$val"
}

cmd_os() {
    section "OS・カーネル情報"

    local os_name os_version kernel arch hostname
    os_name=$(cat /etc/os-release 2>/dev/null | grep "^PRETTY_NAME" | cut -d= -f2 | tr -d '"' || echo "N/A")
    os_version=$(cat /etc/os-release 2>/dev/null | grep "^VERSION_ID" | cut -d= -f2 | tr -d '"' || echo "N/A")
    kernel=$(uname -r)
    arch=$(uname -m)
    hostname=$(hostname -f 2>/dev/null || hostname)

    info_row "ホスト名"    "$hostname"
    info_row "OS"          "${os_name:-N/A}"
    info_row "OSバージョン" "${os_version:-N/A}"
    info_row "カーネル"    "$kernel"
    info_row "アーキテクチャ" "$arch"

    local uptime_sec
    uptime_sec=$(cat /proc/uptime 2>/dev/null | awk '{print int($1)}' || echo 0)
    local days=$(( uptime_sec / 86400 ))
    local hours=$(( (uptime_sec % 86400) / 3600 ))
    local mins=$(( (uptime_sec % 3600) / 60 ))
    info_row "稼働時間"    "${days}日 ${hours}時間 ${mins}分"

    local timezone
    timezone=$(timedatectl show --property=Timezone --value 2>/dev/null || cat /etc/timezone 2>/dev/null || echo "N/A")
    info_row "タイムゾーン" "$timezone"

    local locale
    locale=$(locale | grep "^LANG=" | cut -d= -f2 || echo "N/A")
    info_row "ロケール"    "${locale:-N/A}"

    echo ""
}

cmd_cpu() {
    section "CPU情報"

    local cpu_model cores threads sockets freq_max
    cpu_model=$(grep "model name" /proc/cpuinfo 2>/dev/null | head -1 | cut -d: -f2 | sed 's/^ //' || echo "N/A")
    cores=$(grep "^cpu cores" /proc/cpuinfo 2>/dev/null | head -1 | cut -d: -f2 | tr -d ' ' || echo "N/A")
    threads=$(grep "^processor" /proc/cpuinfo 2>/dev/null | wc -l || echo "N/A")
    sockets=$(grep "^physical id" /proc/cpuinfo 2>/dev/null | sort -u | wc -l || echo "1")

    info_row "CPUモデル"   "${cpu_model:-N/A}"
    info_row "ソケット数"  "$sockets"
    info_row "物理コア数"  "${cores:-N/A}"
    info_row "論理スレッド" "$threads"

    local freq
    freq=$(grep "cpu MHz" /proc/cpuinfo 2>/dev/null | head -1 | cut -d: -f2 | sed 's/^ //' || echo "N/A")
    info_row "現在の周波数" "${freq:+${freq} MHz}"

    local cache
    cache=$(grep "cache size" /proc/cpuinfo 2>/dev/null | head -1 | cut -d: -f2 | sed 's/^ //' || echo "N/A")
    info_row "キャッシュサイズ" "${cache:-N/A}"

    local flags
    flags=$(grep "^flags" /proc/cpuinfo 2>/dev/null | head -1 | cut -d: -f2 | tr ' ' '\n' | \
        grep -E "^(vmx|svm|sse4|avx|aes|rdrand)$" | tr '\n' ' ' || echo "N/A")
    info_row "主要フラグ"  "${flags:-N/A}"

    echo ""
    section "CPU使用率 (1秒間)"
    local idle total
    local cpu1 cpu2
    cpu1=$(grep "^cpu " /proc/stat)
    sleep 1
    cpu2=$(grep "^cpu " /proc/stat)

    python3 - "$cpu1" "$cpu2" <<'PYEOF'
import sys
def parse_cpu(line):
    vals = list(map(int, line.split()[1:]))
    idle = vals[3] + (vals[4] if len(vals) > 4 else 0)
    total = sum(vals)
    return idle, total

_, line1, line2 = sys.argv[0], sys.argv[1], sys.argv[2]
idle1, total1 = parse_cpu(line1)
idle2, total2 = parse_cpu(line2)
delta_idle = idle2 - idle1
delta_total = total2 - total1
usage = 100.0 * (delta_total - delta_idle) / delta_total if delta_total > 0 else 0
color = "\033[1;32m" if usage < 50 else "\033[1;33m" if usage < 80 else "\033[1;31m"
reset = "\033[0m"
bar = "█" * int(usage / 2) + "░" * (50 - int(usage / 2))
print(f"  CPU使用率: {color}{usage:.1f}%{reset}")
print(f"  {color}{bar}{reset}")
PYEOF
    echo ""
}

cmd_memory() {
    section "メモリ情報"

    local mem_total mem_avail mem_free mem_buffers mem_cached swap_total swap_used
    mem_total=$(grep "^MemTotal:"    /proc/meminfo | awk '{print $2}')
    mem_avail=$(grep "^MemAvailable:" /proc/meminfo | awk '{print $2}')
    mem_free=$(grep  "^MemFree:"    /proc/meminfo | awk '{print $2}')
    mem_buffers=$(grep "^Buffers:" /proc/meminfo | awk '{print $2}')
    mem_cached=$(grep  "^Cached:"  /proc/meminfo | awk '{print $2}')
    swap_total=$(grep  "^SwapTotal:" /proc/meminfo | awk '{print $2}')
    swap_used=$(grep  "^SwapFree:" /proc/meminfo | awk '{print $2}')
    swap_used=$(( swap_total - swap_used ))

    local used=$(( mem_total - mem_avail ))
    local used_pct=$(( used * 100 / (mem_total > 0 ? mem_total : 1) ))
    local used_color="$C_GREEN"
    (( used_pct > 70 )) && used_color="$C_YELLOW"
    (( used_pct > 90 )) && used_color="$C_RED"

    local to_mb="scale=1; "
    info_row "合計メモリ"  "$(echo "scale=1; $mem_total/1024" | bc) MB"
    info_row "使用中"      "$(echo "scale=1; $used/1024" | bc) MB (${used_color}${used_pct}%${C_RESET})"
    info_row "利用可能"    "$(echo "scale=1; $mem_avail/1024" | bc) MB"
    info_row "バッファ"    "$(echo "scale=1; $mem_buffers/1024" | bc) MB"
    info_row "キャッシュ"  "$(echo "scale=1; $mem_cached/1024" | bc) MB"

    echo ""
    local bar_filled=$(( used_pct / 2 ))
    printf "  [${used_color}"
    printf '%0.s█' $(seq 1 $bar_filled 2>/dev/null) || true
    printf "${C_RESET}"
    printf '%0.s░' $(seq 1 $(( 50 - bar_filled )) 2>/dev/null) || true
    printf "] ${used_color}%d%%${C_RESET}\n" "$used_pct"

    echo ""
    if (( swap_total > 0 )); then
        local swap_pct=$(( swap_used * 100 / swap_total ))
        info_row "スワップ合計" "$(echo "scale=1; $swap_total/1024" | bc) MB"
        info_row "スワップ使用" "$(echo "scale=1; $swap_used/1024" | bc) MB (${swap_pct}%)"
    else
        info_row "スワップ" "無効"
    fi
    echo ""
}

cmd_storage() {
    section "ストレージ情報"

    printf "${C_BOLD}  ディスク一覧:${C_RESET}\n\n"
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE 2>/dev/null | \
    while IFS= read -r line; do
        printf "  %s\n" "$line"
    done

    echo ""
    printf "${C_BOLD}  ファイルシステム使用量:${C_RESET}\n\n"
    df -h --output=source,size,used,avail,pcent,target 2>/dev/null | \
    grep -v "^tmpfs\|^devtmpfs\|^udev\|Filesystem" | \
    while IFS= read -r line; do
        local pct
        pct=$(echo "$line" | awk '{print $5}' | tr -d '%')
        local color="$C_GREEN"
        (( ${pct:-0} > 70 )) && color="$C_YELLOW"
        (( ${pct:-0} > 90 )) && color="$C_RED"
        printf "  ${color}%s${C_RESET}\n" "$line"
    done
    echo ""
}

cmd_network() {
    section "ネットワーク設定"

    info_row "ホスト名" "$(hostname)"

    local default_gw
    default_gw=$(ip route show default 2>/dev/null | awk '{print $3}' | head -1 || echo "N/A")
    info_row "デフォルトGW" "${default_gw:-N/A}"

    local dns
    dns=$(grep "^nameserver" /etc/resolv.conf 2>/dev/null | awk '{print $2}' | tr '\n' ' ' || echo "N/A")
    info_row "DNSサーバー" "${dns:-N/A}"

    echo ""
    printf "${C_BOLD}  インターフェース:${C_RESET}\n\n"
    ip addr show 2>/dev/null | grep -E "^[0-9]+:|inet " | \
    while IFS= read -r line; do
        if [[ "$line" =~ ^[0-9]+: ]]; then
            local iface
            iface=$(echo "$line" | awk '{print $2}' | tr -d ':')
            printf "  ${C_CYAN}%s${C_RESET}\n" "$iface"
        else
            printf "    %s\n" "$(echo "$line" | awk '{print $2}')"
        fi
    done
    echo ""
}

cmd_software() {
    section "インストール済みソフトウェア"

    local pkg_count="N/A"
    if command -v dpkg &>/dev/null; then
        pkg_count=$(dpkg -l 2>/dev/null | grep "^ii" | wc -l || echo "N/A")
        info_row "パッケージ管理" "apt/dpkg"
    elif command -v rpm &>/dev/null; then
        pkg_count=$(rpm -qa 2>/dev/null | wc -l || echo "N/A")
        info_row "パッケージ管理" "rpm/yum"
    fi
    info_row "パッケージ数" "$pkg_count"

    echo ""
    printf "${C_BOLD}  主要コマンド:${C_RESET}\n\n"
    local tools=(bash python3 python ruby node npm java go docker kubectl terraform ansible aws)
    for t in "${tools[@]}"; do
        if command -v "$t" &>/dev/null; then
            local ver
            ver=$("$t" --version 2>/dev/null | head -1 | tr -d '\n' || echo "?")
            printf "  ${C_GREEN}%-12s${C_RESET} %s\n" "$t" "${ver:0:60}"
        fi
    done
    echo ""
}

cmd_performance() {
    section "パフォーマンス指標"

    local load1 load5 load15
    read -r load1 load5 load15 _ < /proc/loadavg
    info_row "ロードアベレージ (1/5/15m)" "$load1 / $load5 / $load15"

    local procs
    procs=$(wc -l < /proc/loadavg)
    info_row "実行中プロセス数" "$(cat /proc/loadavg | awk '{print $4}' | cut -d/ -f1)"

    echo ""
    section "トッププロセス (CPU使用率)"
    printf "${C_BOLD}  %-8s %-15s %6s %6s %s${C_RESET}\n" "PID" "ユーザー" "CPU%" "MEM%" "コマンド"
    printf "  %s\n" "$(printf '%.0s─' {1..60})"
    ps aux --sort=-%cpu 2>/dev/null | tail -n +2 | head -10 | \
    while IFS= read -r line; do
        local pid user cpu mem cmd
        pid=$(echo "$line"  | awk '{print $2}')
        user=$(echo "$line" | awk '{print $1}')
        cpu=$(echo "$line"  | awk '{print $3}')
        mem=$(echo "$line"  | awk '{print $4}')
        cmd=$(echo "$line"  | awk '{for(i=11;i<=NF;i++) printf "%s ", $i; print ""}' | cut -c1-30)
        local cpu_color="$C_GREEN"
        local cpu_int="${cpu%.*}"
        (( ${cpu_int:-0} > 50 )) && cpu_color="$C_YELLOW"
        (( ${cpu_int:-0} > 80 )) && cpu_color="$C_RED"
        printf "  %-8s %-15s ${cpu_color}%6s${C_RESET} %6s %s\n" \
            "$pid" "${user:0:15}" "$cpu" "$mem" "${cmd:0:30}"
    done
    echo ""
}

cmd_hardware() {
    cmd_cpu
    cmd_memory
    cmd_storage
}

cmd_report() {
    log_info "システム総合レポート生成中..."
    echo ""
    cmd_os
    cmd_cpu
    cmd_memory
    cmd_storage
    cmd_network
    cmd_software
    cmd_performance
    log_success "レポート生成完了"
}

parse_arguments() {
    [[ $# -eq 0 ]] && return 0
    case "$1" in
        report|hardware|os|cpu|memory|storage|network|software|performance)
            command_name="$1"; shift ;;
    esac

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -o|--output)  [[ $# -lt 2 ]] && error_exit "--output には値が必要です"; output_file="$2"; shift 2 ;;
            -f|--format)  [[ $# -lt 2 ]] && error_exit "--format には値が必要です"; output_format="$2"; shift 2 ;;
            --verbose)    verbose=1; shift ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  shift ;;
        esac
    done
}

main() {
    parse_arguments "$@"

    if [[ -n "$output_file" ]]; then
        exec > >(tee "$output_file") 2>&1
    fi

    case "$command_name" in
        report)      cmd_report ;;
        hardware)    cmd_hardware ;;
        os)          cmd_os ;;
        cpu)         cmd_cpu ;;
        memory)      cmd_memory ;;
        storage)     cmd_storage ;;
        network)     cmd_network ;;
        software)    cmd_software ;;
        performance) cmd_performance ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
