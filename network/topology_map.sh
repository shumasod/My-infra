#!/bin/bash
set -euo pipefail

#
# ネットワークトポロジーマッパー
# 作成日: 2026-07-30
# バージョン: 1.0
#
# ネットワーク上のホストをスキャンしてASCIIトポロジーマップを生成します
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare command_name="map"
declare target_network=""
declare timeout_sec=2
declare ping_count=1
declare show_ports=false
declare common_ports=(22 80 443 3306 5432 6379 8080 8443)
declare output_format="ascii"
declare max_hosts=254

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション] <ネットワーク>

ネットワークトポロジーをスキャン・表示します。

コマンド:
  map <ネットワーク>     トポロジーマップを生成
  scan <ネットワーク>    ホストスキャン
  route                  ルーティングテーブル表示
  interfaces             インターフェース一覧
  arp                    ARPテーブル表示

引数:
  <ネットワーク>         スキャン対象 (例: 192.168.1.0/24 または 192.168.1.)

オプション:
  -h, --help             このヘルプを表示
  -v, --version          バージョン情報を表示
  -t, --timeout <秒>     タイムアウト [デフォルト: 2]
  -p, --ports            共通ポートをスキャン
  --format <形式>        出力形式 (ascii|csv) [デフォルト: ascii]
  --max <数>             最大スキャンホスト数 [デフォルト: 254]

例:
  $PROG_NAME map 192.168.1.0/24
  $PROG_NAME scan 192.168.1. -p
  $PROG_NAME interfaces
  $PROG_NAME arp
EOF
}

expand_cidr() {
    local network="$1"
    # /24 形式を展開
    if [[ "$network" =~ ^([0-9]+\.[0-9]+\.[0-9]+)\.0/24$ ]]; then
        echo "${BASH_REMATCH[1]}."
    elif [[ "$network" =~ ^([0-9]+\.[0-9]+\.[0-9]+)\. ]]; then
        echo "${BASH_REMATCH[1]}."
    else
        echo "$network"
    fi
}

ping_host() {
    local host="$1"
    ping -c "$ping_count" -W "$timeout_sec" "$host" &>/dev/null
}

get_hostname() {
    local ip="$1"
    local hostname
    hostname=$(nslookup "$ip" 2>/dev/null | awk '/name =/ {print $NF}' | sed 's/\.$//' | head -1)
    echo "${hostname:-$ip}"
}

get_mac() {
    local ip="$1"
    arp -n "$ip" 2>/dev/null | awk '/ether/ {print $3}' | head -1
}

scan_ports() {
    local host="$1"
    local open_ports=()
    for port in "${common_ports[@]}"; do
        if timeout "$timeout_sec" bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null; then
            open_ports+=("$port")
        fi
    done
    echo "${open_ports[*]:-}"
}

guess_device_type() {
    local ports="$1"
    local hostname="${2:-}"

    if echo "$ports" | grep -qw "22"; then
        if echo "$ports" | grep -qwE "80|443"; then
            if echo "$hostname" | grep -qi "router\|gateway\|gw"; then
                echo "ルーター"
            else
                echo "サーバー"
            fi
        else
            echo "Linux/Unix"
        fi
    elif echo "$ports" | grep -qwE "80|443|8080|8443"; then
        echo "Webサーバー"
    elif echo "$ports" | grep -qwE "3306|5432"; then
        echo "DBサーバー"
    elif echo "$ports" | grep -qw "6379"; then
        echo "Redisサーバー"
    else
        echo "ホスト"
    fi
}

cmd_scan() {
    local prefix
    prefix=$(expand_cidr "$target_network")

    log_info "ネットワークをスキャン中: ${prefix}1-${max_hosts}..."
    echo ""

    declare -A host_info
    local found=0
    local scanned=0

    printf "${C_BOLD}%-18s %-25s %-20s %s${C_RESET}\n" "IPアドレス" "ホスト名" "開放ポート" "デバイス種別"
    printf "%s\n" "$(printf '%.0s─' {1..75})"

    for (( i=1; i<=max_hosts; i++ )); do
        local ip="${prefix}${i}"
        (( scanned++ ))

        if ! ping_host "$ip"; then
            continue
        fi

        (( found++ ))
        local hostname mac ports device_type
        hostname=$(get_hostname "$ip")
        mac=$(get_mac "$ip")

        if $show_ports; then
            ports=$(scan_ports "$ip")
        else
            ports=""
        fi

        device_type=$(guess_device_type "$ports" "$hostname")

        local display_hostname
        if [[ "$hostname" == "$ip" ]]; then
            display_hostname="${C_DIM}(名前解決不可)${C_RESET}"
        else
            display_hostname="${C_CYAN}${hostname:0:24}${C_RESET}"
        fi

        local ports_display="${ports:-─}"

        printf "  ${C_GREEN}%-16s${C_RESET}  %b  %-18s  %s\n" \
            "$ip" "$display_hostname" "$ports_display" "$device_type"

        host_info["$ip"]="${hostname}|${ports}|${device_type}|${mac:-N/A}"

        # 進捗表示
        printf "\r  ${C_DIM}スキャン中: %d/%d (%d件発見)${C_RESET}" "$scanned" "$max_hosts" "$found" >&2
    done

    printf "\r%-60s\r" " " >&2
    echo ""
    printf "  スキャン完了: ${C_GREEN}%d${C_RESET}/%d ホスト発見\n\n" "$found" "$scanned"
}

cmd_map() {
    local prefix
    prefix=$(expand_cidr "$target_network")

    log_info "トポロジーマップを生成中..."
    echo ""

    # まずゲートウェイを検出
    local gateway
    gateway=$(ip route show default 2>/dev/null | awk '/default/ {print $3}' | head -1)

    local my_ip
    my_ip=$(hostname -I 2>/dev/null | awk '{print $1}')

    printf "${C_BOLD}${C_CYAN}"
    printf "  ╔══════════════════════════════════════╗\n"
    printf "  ║     ネットワークトポロジーマップ     ║\n"
    printf "  ╚══════════════════════════════════════╝\n"
    printf "${C_RESET}\n"

    printf "  %s ネットワーク: %s\n" "🌐" "${target_network}"
    [[ -n "$my_ip" ]]   && printf "  %s 自ホスト: %s\n" "💻" "$my_ip"
    [[ -n "$gateway" ]] && printf "  %s ゲートウェイ: %s\n" "🔀" "$gateway"
    echo ""

    # ゲートウェイを中心にASCIIツリーを描画
    printf "  ${C_YELLOW}[ゲートウェイ: %s]${C_RESET}\n" "${gateway:-不明}"
    printf "         │\n"

    local found=0
    for (( i=1; i<=max_hosts; i++ )); do
        local ip="${prefix}${i}"
        [[ "$ip" == "$gateway" ]] && continue
        [[ "$ip" == "$my_ip" ]] && continue
        ping_host "$ip" || continue

        (( found++ ))
        local hostname
        hostname=$(get_hostname "$ip")

        if [[ $found -eq 1 ]]; then
            printf "         ├── "
        else
            printf "         ├── "
        fi

        if [[ "$hostname" != "$ip" ]]; then
            printf "${C_GREEN}%s${C_RESET} ${C_DIM}(%s)${C_RESET}\n" "$ip" "$hostname"
        else
            printf "${C_GREEN}%s${C_RESET}\n" "$ip"
        fi
    done

    # 自ホスト
    if [[ -n "$my_ip" ]]; then
        printf "         └── ${C_CYAN}%s${C_RESET} ${C_BOLD}(このホスト)${C_RESET}\n" "$my_ip"
    fi

    echo ""
    printf "  合計 ${C_GREEN}%d${C_RESET} 台のホストが見つかりました\n\n" "$found"
}

cmd_interfaces() {
    log_info "ネットワークインターフェース一覧"
    echo ""

    printf "${C_BOLD}%-15s %-20s %-20s %s${C_RESET}\n" "インターフェース" "IPアドレス" "MACアドレス" "状態"
    printf "%s\n" "$(printf '%.0s─' {1..65})"

    ip link show 2>/dev/null | awk '
        /^[0-9]+:/ {
            split($2, a, ":")
            iface=a[1]
            state = /UP/ ? "UP" : "DOWN"
            printf "  iface=%s state=%s\n", iface, state
        }
        /link\/ether/ {
            printf "  mac=%s\n", $2
        }
    ' | paste - - | while read -r line; do
        local iface mac state
        iface=$(echo "$line" | grep -o 'iface=[^ ]*' | cut -d= -f2)
        state=$(echo "$line" | grep -o 'state=[^ ]*' | cut -d= -f2)
        mac=$(echo "$line" | grep -o 'mac=[^ ]*' | cut -d= -f2)

        local ip_addr
        ip_addr=$(ip addr show "$iface" 2>/dev/null | awk '/inet / {print $2}' | head -1)

        local state_color="$C_RED"
        [[ "$state" == "UP" ]] && state_color="$C_GREEN"

        printf "  ${C_CYAN}%-13s${C_RESET} %-20s %-20s ${state_color}%s${C_RESET}\n" \
            "${iface:-?}" "${ip_addr:-N/A}" "${mac:-N/A}" "${state:-?}"
    done || ip addr show 2>/dev/null | awk '
        /^[0-9]+:/ {iface=$2; gsub(":", "", iface)}
        /inet / {printf "  %-15s %s\n", iface, $2}
    '
    echo ""
}

cmd_route() {
    log_info "ルーティングテーブル"
    echo ""
    ip route show 2>/dev/null | while IFS= read -r line; do
        if [[ "$line" =~ ^default ]]; then
            printf "${C_YELLOW}  %s${C_RESET}\n" "$line"
        else
            printf "  %s\n" "$line"
        fi
    done || netstat -rn 2>/dev/null
    echo ""
}

cmd_arp() {
    log_info "ARPテーブル"
    echo ""
    printf "${C_BOLD}%-20s %-20s %-15s %s${C_RESET}\n" "IPアドレス" "MACアドレス" "インターフェース" "状態"
    printf "%s\n" "$(printf '%.0s─' {1..65})"
    arp -n 2>/dev/null | tail -n +2 | while IFS= read -r line; do
        local ip mac iface state
        ip=$(echo "$line" | awk '{print $1}')
        mac=$(echo "$line" | awk '{print $3}')
        iface=$(echo "$line" | awk '{print $5}')
        state=$(echo "$line" | awk '{print $4}' | tr -d '()')

        printf "  ${C_GREEN}%-18s${C_RESET} %-20s %-15s ${C_DIM}%s${C_RESET}\n" \
            "$ip" "$mac" "$iface" "$state"
    done
    echo ""
}

parse_arguments() {
    [[ $# -eq 0 ]] && { show_usage; exit 0; }

    case "$1" in
        map|scan|route|interfaces|arp)
            command_name="$1"; shift ;;
    esac

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -t|--timeout)
                [[ $# -lt 2 ]] && error_exit "--timeout には値が必要です"
                timeout_sec="$2"; shift 2 ;;
            -p|--ports)   show_ports=true; shift ;;
            --format)
                [[ $# -lt 2 ]] && error_exit "--format には値が必要です"
                output_format="$2"; shift 2 ;;
            --max)
                [[ $# -lt 2 ]] && error_exit "--max には値が必要です"
                max_hosts="$2"; shift 2 ;;
            -*)  error_exit "不明なオプション: $1" ;;
            *)
                if [[ -z "$target_network" ]]; then
                    target_network="$1"
                fi
                shift ;;
        esac
    done
}

main() {
    parse_arguments "$@"

    case "$command_name" in
        map)
            [[ -z "$target_network" ]] && error_exit "ネットワークを指定してください"
            cmd_map ;;
        scan)
            [[ -z "$target_network" ]] && error_exit "ネットワークを指定してください"
            cmd_scan ;;
        route)      cmd_route ;;
        interfaces) cmd_interfaces ;;
        arp)        cmd_arp ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
