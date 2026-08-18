#!/bin/bash
set -euo pipefail

#
# ネットワーク速度テストツール
# 作成日: 2026-08-18
# バージョン: 1.0
#
# ネットワークの帯域幅・レイテンシ・パケットロスを計測します
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare command_name="all"
declare target_host="8.8.8.8"
declare test_size="10M"
declare ping_count=10
declare watch_interval=5
declare output_format="text"

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション] [ホスト]

ネットワーク速度・品質テストツールです。

コマンド:
  all [ホスト]           総合テスト (デフォルト)
  ping [ホスト]          レイテンシ・パケットロス測定
  dns                    DNS解決速度測定
  interfaces             ネットワークインターフェース統計
  watch [ホスト]         リアルタイム監視
  bandwidth              帯域幅推定

オプション:
  -h, --help             このヘルプを表示
  -v, --version          バージョン情報を表示
  -c, --count <数>       Ping回数 [デフォルト: 10]
  -i, --interval <秒>    監視間隔 [デフォルト: 5]
  -f, --format <形式>    出力形式 (text|json) [デフォルト: text]

例:
  $PROG_NAME all
  $PROG_NAME ping 1.1.1.1 -c 20
  $PROG_NAME dns
  $PROG_NAME watch google.com
  $PROG_NAME interfaces
EOF
}

check_command() {
    command -v "$1" &>/dev/null
}

format_ms() {
    printf "%.2f ms" "$1"
}

get_interface_stats() {
    local iface="$1"
    local stat="$2"
    local path="/sys/class/net/${iface}/statistics/${stat}"
    [[ -f "$path" ]] && cat "$path" || echo 0
}

cmd_ping() {
    local host="${1:-$target_host}"
    log_info "Pingテスト: $host (${ping_count}回)"
    echo ""

    if ! ping -c 1 -W 2 "$host" &>/dev/null 2>&1; then
        log_error "ホストに到達できません: $host"
        return 1
    fi

    local result
    result=$(ping -c "$ping_count" -W 2 "$host" 2>/dev/null)

    local transmitted received packet_loss min avg max mdev
    transmitted=$(echo "$result" | grep -oP '\d+(?= packets transmitted)')
    received=$(echo "$result" | grep -oP '\d+(?= received)')
    packet_loss=$(echo "$result" | grep -oP '\d+(?=% packet loss)')

    local rtt_line
    rtt_line=$(echo "$result" | grep "rtt\|round-trip" || true)
    if [[ -n "$rtt_line" ]]; then
        min=$(echo "$rtt_line"  | grep -oP '[\d.]+' | sed -n '1p')
        avg=$(echo "$rtt_line"  | grep -oP '[\d.]+' | sed -n '2p')
        max=$(echo "$rtt_line"  | grep -oP '[\d.]+' | sed -n '3p')
        mdev=$(echo "$rtt_line" | grep -oP '[\d.]+' | sed -n '4p')
    else
        min="0"; avg="0"; max="0"; mdev="0"
    fi

    printf "${C_BOLD}【Ping結果: $host】${C_RESET}\n\n"
    printf "  %-20s %s\n" "送信パケット数:" "${transmitted:-0}"
    printf "  %-20s %s\n" "受信パケット数:" "${received:-0}"

    local loss_color="$C_GREEN"
    local loss_num="${packet_loss:-0}"
    (( loss_num > 0  )) && loss_color="$C_YELLOW"
    (( loss_num > 10 )) && loss_color="$C_RED"
    printf "  %-20s ${loss_color}%s%%${C_RESET}\n" "パケットロス:" "${packet_loss:-0}"

    echo ""
    printf "${C_BOLD}【レイテンシ統計】${C_RESET}\n\n"

    local avg_color="$C_GREEN"
    local avg_int="${avg%.*}"
    (( ${avg_int:-0} > 50  )) && avg_color="$C_YELLOW"
    (( ${avg_int:-0} > 150 )) && avg_color="$C_RED"

    printf "  %-20s %s ms\n" "最小 (min):" "${min:-0}"
    printf "  %-20s ${avg_color}%s ms${C_RESET}\n" "平均 (avg):" "${avg:-0}"
    printf "  %-20s %s ms\n" "最大 (max):" "${max:-0}"
    printf "  %-20s %s ms\n" "ジッター (mdev):" "${mdev:-0}"
    echo ""

    if [[ "$output_format" == "json" ]]; then
        python3 - <<EOF
import json
data = {
    "host": "$host",
    "transmitted": ${transmitted:-0},
    "received": ${received:-0},
    "packet_loss_pct": ${packet_loss:-0},
    "latency_ms": {
        "min": ${min:-0},
        "avg": ${avg:-0},
        "max": ${max:-0},
        "mdev": ${mdev:-0}
    }
}
print(json.dumps(data, indent=2, ensure_ascii=False))
EOF
    fi
}

cmd_dns() {
    log_info "DNS解決速度テスト"
    echo ""

    local domains=("google.com" "github.com" "amazon.com" "cloudflare.com" "yahoo.co.jp")
    local resolvers=("8.8.8.8" "1.1.1.1" "8.8.4.4")

    if ! check_command dig; then
        log_warning "dig コマンドが見つかりません。nslookupで代替します"
        for domain in "${domains[@]}"; do
            local start_ns elapsed_ns result_ms
            start_ns=$(date +%s%N)
            nslookup "$domain" &>/dev/null || true
            elapsed_ns=$(( $(date +%s%N) - start_ns ))
            result_ms=$(echo "scale=2; $elapsed_ns / 1000000" | bc 2>/dev/null || echo "?")
            printf "  %-30s %s ms\n" "$domain" "$result_ms"
        done
        return
    fi

    printf "${C_BOLD}【デフォルトDNS解決速度】${C_RESET}\n\n"
    printf "${C_BOLD}  %-30s %10s${C_RESET}\n" "ドメイン" "応答時間"
    printf "  %s\n" "$(printf '%.0s─' {1..45})"

    for domain in "${domains[@]}"; do
        local start_ns elapsed_ns result_ms
        start_ns=$(date +%s%N)
        dig +short +time=2 "$domain" &>/dev/null || true
        elapsed_ns=$(( $(date +%s%N) - start_ns ))
        result_ms=$(echo "scale=2; $elapsed_ns / 1000000" | bc 2>/dev/null || echo "?")
        local color="$C_GREEN"
        local ms_int="${result_ms%.*}"
        (( ${ms_int:-0} > 100 )) && color="$C_YELLOW"
        (( ${ms_int:-0} > 500 )) && color="$C_RED"
        printf "  %-30s ${color}%10s ms${C_RESET}\n" "$domain" "$result_ms"
    done

    echo ""
    printf "${C_BOLD}【DNSサーバー別応答時間 (google.com)】${C_RESET}\n\n"
    printf "${C_BOLD}  %-15s %10s${C_RESET}\n" "DNSサーバー" "応答時間"
    printf "  %s\n" "$(printf '%.0s─' {1..30})"

    for resolver in "${resolvers[@]}"; do
        local start_ns elapsed_ns result_ms
        start_ns=$(date +%s%N)
        dig +short +time=2 "@${resolver}" google.com &>/dev/null || true
        elapsed_ns=$(( $(date +%s%N) - start_ns ))
        result_ms=$(echo "scale=2; $elapsed_ns / 1000000" | bc 2>/dev/null || echo "?")
        local color="$C_GREEN"
        local ms_int="${result_ms%.*}"
        (( ${ms_int:-0} > 50  )) && color="$C_YELLOW"
        (( ${ms_int:-0} > 200 )) && color="$C_RED"
        printf "  %-15s ${color}%10s ms${C_RESET}\n" "$resolver" "$result_ms"
    done
    echo ""
}

cmd_interfaces() {
    log_info "ネットワークインターフェース統計"
    echo ""

    local ifaces=()
    while IFS= read -r iface; do
        [[ "$iface" == "lo" ]] && continue
        ifaces+=("$iface")
    done < <(ls /sys/class/net/ 2>/dev/null | grep -v "^lo$")

    if [[ ${#ifaces[@]} -eq 0 ]]; then
        log_warning "ネットワークインターフェースが見つかりません"
        return
    fi

    printf "${C_BOLD}【インターフェース一覧】${C_RESET}\n\n"

    for iface in "${ifaces[@]}"; do
        local state link_speed
        state=$(cat "/sys/class/net/${iface}/operstate" 2>/dev/null || echo "unknown")
        link_speed=$(cat "/sys/class/net/${iface}/speed" 2>/dev/null || echo "-")

        local state_color="$C_RED"
        [[ "$state" == "up" ]] && state_color="$C_GREEN"

        local rx_bytes tx_bytes rx_packets tx_packets rx_errors tx_errors
        rx_bytes=$(get_interface_stats "$iface" "rx_bytes")
        tx_bytes=$(get_interface_stats "$iface" "tx_bytes")
        rx_packets=$(get_interface_stats "$iface" "rx_packets")
        tx_packets=$(get_interface_stats "$iface" "tx_packets")
        rx_errors=$(get_interface_stats "$iface" "rx_errors")
        tx_errors=$(get_interface_stats "$iface" "tx_errors")

        local rx_mb tx_mb
        rx_mb=$(echo "scale=2; $rx_bytes / 1048576" | bc 2>/dev/null || echo "0")
        tx_mb=$(echo "scale=2; $tx_bytes / 1048576" | bc 2>/dev/null || echo "0")

        printf "  ${C_BOLD}${C_CYAN}%s${C_RESET}  ${state_color}%s${C_RESET}" "$iface" "$state"
        [[ "$link_speed" != "-" ]] && printf "  ${C_DIM}%s Mbps${C_RESET}" "$link_speed"
        echo ""
        printf "    受信: %s MB (%s パケット" "$rx_mb" "$rx_packets"
        (( rx_errors > 0 )) && printf ", ${C_RED}%s エラー${C_RESET}" "$rx_errors"
        echo ")"
        printf "    送信: %s MB (%s パケット" "$tx_mb" "$tx_packets"
        (( tx_errors > 0 )) && printf ", ${C_RED}%s エラー${C_RESET}" "$tx_errors"
        echo ")"

        local ip_addr
        ip_addr=$(ip addr show "$iface" 2>/dev/null | grep -oP '(?<=inet )\d+\.\d+\.\d+\.\d+/\d+' | head -1 || true)
        [[ -n "$ip_addr" ]] && printf "    IPアドレス: ${C_YELLOW}%s${C_RESET}\n" "$ip_addr"
        echo ""
    done
}

cmd_bandwidth() {
    log_info "帯域幅推定テスト"
    echo ""

    local ifaces=()
    while IFS= read -r iface; do
        [[ "$iface" == "lo" ]] && continue
        local state
        state=$(cat "/sys/class/net/${iface}/operstate" 2>/dev/null || echo "down")
        [[ "$state" == "up" ]] && ifaces+=("$iface")
    done < <(ls /sys/class/net/ 2>/dev/null | grep -v "^lo$")

    if [[ ${#ifaces[@]} -eq 0 ]]; then
        log_warning "アクティブなインターフェースが見つかりません"
        return
    fi

    printf "${C_BOLD}【帯域幅計測 (1秒間隔)】${C_RESET}\n\n"
    printf "${C_BOLD}  %-12s %15s %15s${C_RESET}\n" "インターフェース" "受信速度" "送信速度"
    printf "  %s\n" "$(printf '%.0s─' {1..45})"

    for iface in "${ifaces[@]}"; do
        local rx1 tx1 rx2 tx2
        rx1=$(get_interface_stats "$iface" "rx_bytes")
        tx1=$(get_interface_stats "$iface" "tx_bytes")
        sleep 1
        rx2=$(get_interface_stats "$iface" "rx_bytes")
        tx2=$(get_interface_stats "$iface" "tx_bytes")

        local rx_rate tx_rate
        rx_rate=$(( rx2 - rx1 ))
        tx_rate=$(( tx2 - tx1 ))

        local rx_str tx_str
        if (( rx_rate >= 1048576 )); then
            rx_str=$(printf "%.1f MB/s" "$(echo "scale=1; $rx_rate/1048576" | bc)")
        elif (( rx_rate >= 1024 )); then
            rx_str=$(printf "%.1f KB/s" "$(echo "scale=1; $rx_rate/1024" | bc)")
        else
            rx_str="${rx_rate} B/s"
        fi

        if (( tx_rate >= 1048576 )); then
            tx_str=$(printf "%.1f MB/s" "$(echo "scale=1; $tx_rate/1048576" | bc)")
        elif (( tx_rate >= 1024 )); then
            tx_str=$(printf "%.1f KB/s" "$(echo "scale=1; $tx_rate/1024" | bc)")
        else
            tx_str="${tx_rate} B/s"
        fi

        printf "  %-12s %15s %15s\n" "$iface" "↓ $rx_str" "↑ $tx_str"
    done
    echo ""
}

cmd_watch() {
    local host="${1:-$target_host}"
    local cleanup_done=false
    cleanup() {
        $cleanup_done && return
        cleanup_done=true
        show_cursor
        printf '\033[?1049l'
    }
    trap cleanup EXIT INT TERM
    printf '\033[?1049h'
    hide_cursor

    local loss_history=()
    local latency_history=()
    local max_history=20

    while true; do
        clear_screen
        update_terminal_size
        print_center "ネットワーク監視ダッシュボード" 1 "$C_CYAN"
        draw_separator 2
        move_cursor 3 2
        printf "${C_DIM}ホスト: %s  更新: %s  間隔: %ds  q=終了${C_RESET}" \
            "$host" "$(get_timestamp)" "$watch_interval"

        local result latency packet_loss
        result=$(ping -c 3 -W 2 "$host" 2>/dev/null || true)

        local rtt_line
        rtt_line=$(echo "$result" | grep "rtt\|round-trip" || true)
        if [[ -n "$rtt_line" ]]; then
            latency=$(echo "$rtt_line" | grep -oP '[\d.]+' | sed -n '2p')
        else
            latency="0"
        fi
        packet_loss=$(echo "$result" | grep -oP '\d+(?=% packet loss)' || echo "100")

        loss_history+=("${packet_loss:-100}")
        latency_history+=("${latency:-0}")
        if (( ${#loss_history[@]} > max_history )); then
            loss_history=("${loss_history[@]:1}")
            latency_history=("${latency_history[@]:1}")
        fi

        move_cursor 5 2
        local lat_color="$C_GREEN"
        local lat_int="${latency%.*}"
        (( ${lat_int:-0} > 50  )) && lat_color="$C_YELLOW"
        (( ${lat_int:-0} > 150 )) && lat_color="$C_RED"
        printf "レイテンシ: ${lat_color}%s ms${C_RESET}  パケットロス: " "${latency:-?}"
        local loss_color="$C_GREEN"
        local loss_num="${packet_loss:-0}"
        (( loss_num > 0  )) && loss_color="$C_YELLOW"
        (( loss_num > 20 )) && loss_color="$C_RED"
        printf "${loss_color}%s%%${C_RESET}\n" "$loss_num"

        move_cursor 7 2
        printf "${C_BOLD}レイテンシ履歴:${C_RESET}\n"
        move_cursor 8 2
        local chart_width=$(( TERM_COLS - 10 ))
        local max_lat=1
        for lat in "${latency_history[@]}"; do
            local l="${lat%.*}"
            (( ${l:-0} > max_lat )) && max_lat="${l:-1}"
        done

        for lat in "${latency_history[@]}"; do
            local l="${lat%.*}"
            local bar_h=$(( ${l:-0} * 5 / (max_lat > 0 ? max_lat : 1) ))
            local c="$C_GREEN"
            (( ${l:-0} > 50  )) && c="$C_YELLOW"
            (( ${l:-0} > 150 )) && c="$C_RED"
            printf "${c}▐${C_RESET}"
        done
        printf "\n"

        if read -rsn1 -t "$watch_interval" key 2>/dev/null; then
            [[ "$key" == "q" || "$key" == "Q" ]] && break
        fi
    done
}

cmd_all() {
    local host="${1:-$target_host}"
    log_info "総合ネットワークテスト開始"
    echo ""

    cmd_ping "$host"
    cmd_dns
    cmd_interfaces
    cmd_bandwidth

    log_success "総合テスト完了"
}

parse_arguments() {
    [[ $# -eq 0 ]] && return 0
    case "$1" in
        all|ping|dns|interfaces|watch|bandwidth)
            command_name="$1"; shift ;;
    esac

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -c|--count)   [[ $# -lt 2 ]] && error_exit "--count には値が必要です"; ping_count="$2"; shift 2 ;;
            -i|--interval) [[ $# -lt 2 ]] && error_exit "--interval には値が必要です"; watch_interval="$2"; shift 2 ;;
            -f|--format)  [[ $# -lt 2 ]] && error_exit "--format には値が必要です"; output_format="$2"; shift 2 ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  target_host="$1"; shift ;;
        esac
    done
}

main() {
    parse_arguments "$@"
    case "$command_name" in
        all)        cmd_all "$target_host" ;;
        ping)       cmd_ping "$target_host" ;;
        dns)        cmd_dns ;;
        interfaces) cmd_interfaces ;;
        watch)      cmd_watch "$target_host" ;;
        bandwidth)  cmd_bandwidth ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
