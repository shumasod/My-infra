#!/bin/bash
set -euo pipefail

#
# ネットワーク経路追跡ツール
# 作成日: 2026-09-01
# バージョン: 1.0
#
# ネットワーク経路の可視化・分析・継続監視を行います
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare command_name="trace"
declare max_hops=30
declare count=3
declare timeout=5
declare watch_interval=60
declare output_format="text"

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション] <ホスト>

ネットワーク経路追跡・分析ツールです。

コマンド:
  trace <ホスト>       経路追跡 (デフォルト)
  mtr <ホスト>         連続経路統計
  geo <ホスト>         IPジオロケーション
  bgp <ホスト>         BGP経路情報
  watch <ホスト>       経路変化の継続監視
  compare <ホスト>     複数経路の比較

オプション:
  -h, --help           このヘルプを表示
  -v, --version        バージョン情報を表示
  -m, --max-hops <数>  最大ホップ数 [デフォルト: 30]
  -c, --count <数>     プローブ数 [デフォルト: 3]
  -t, --timeout <秒>   タイムアウト [デフォルト: 5]
  -i, --interval <秒>  監視間隔 [デフォルト: 60]
  -f, --format <形式>  出力形式 (text|json) [デフォルト: text]

例:
  $PROG_NAME trace 8.8.8.8
  $PROG_NAME trace google.com -m 20
  $PROG_NAME mtr 1.1.1.1 -c 10
  $PROG_NAME geo 8.8.8.8
  $PROG_NAME watch google.com -i 30
EOF
}

resolve_ip() {
    local host="$1"
    if [[ "$host" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "$host"
    else
        dig +short "$host" 2>/dev/null | grep -E "^[0-9]" | head -1 || \
        host "$host" 2>/dev/null | grep "has address" | awk '{print $NF}' | head -1 || \
        echo "$host"
    fi
}

get_ip_info() {
    local ip="$1"
    python3 - "$ip" <<'PYEOF'
import sys, json, urllib.request, urllib.error

ip = sys.argv[1]
if ip.startswith(("10.", "172.", "192.168.", "127.")):
    print("プライベートIPアドレス")
    sys.exit(0)

try:
    with urllib.request.urlopen(f"http://ip-api.com/json/{ip}?fields=country,regionName,city,isp,as", timeout=3) as r:
        data = json.loads(r.read())
    parts = [data.get("country",""), data.get("regionName",""), data.get("city",""), data.get("isp","")]
    print(" / ".join(p for p in parts if p))
except:
    print("N/A")
PYEOF
}

cmd_trace() {
    local host="${1:-}"
    [[ -z "$host" ]] && error_exit "ホストを指定してください"

    local ip
    ip=$(resolve_ip "$host")
    log_info "経路追跡: $host ($ip)"
    echo ""

    printf "${C_BOLD}  %3s  %-20s %8s %8s %8s  %s${C_RESET}\n" \
        "Hop" "IPアドレス" "1st" "2nd" "3rd" "ホスト名"
    printf "  %s\n" "$(printf '%.0s─' {1..75})"

    if command -v traceroute &>/dev/null; then
        traceroute -m "$max_hops" -q "$count" -w "$timeout" "$host" 2>/dev/null | \
        tail -n +2 | while IFS= read -r line; do
            local hop ip1 latencies
            hop=$(echo "$line" | awk '{print $1}')
            local fields
            read -ra fields <<< "$line"

            local ip_addr="*"
            local rtt1="*" rtt2="*" rtt3="*"
            local hostname=""
            local field_idx=1

            for (( i=1; i<${#fields[@]}; i++ )); do
                local f="${fields[$i]}"
                if [[ "$f" =~ ^\( ]]; then
                    ip_addr="${f//[()]/}"
                elif [[ "$f" =~ ^[0-9]+\.[0-9]+$ || "$f" == "*" ]]; then
                    if [[ "$rtt1" == "*" ]]; then rtt1="$f ms"
                    elif [[ "$rtt2" == "*" ]]; then rtt2="$f ms"
                    elif [[ "$rtt3" == "*" ]]; then rtt3="$f ms"
                    fi
                elif [[ ! "$f" =~ ^ms$ ]]; then
                    hostname="$f"
                fi
            done

            local ip_color="$C_CYAN"
            [[ "$ip_addr" == "*" ]] && ip_color="$C_DIM"

            printf "  %3s  ${ip_color}%-20s${C_RESET} %8s %8s %8s  ${C_DIM}%s${C_RESET}\n" \
                "$hop" "${ip_addr:0:20}" "$rtt1" "$rtt2" "$rtt3" "${hostname:0:25}"
        done
    else
        log_warning "traceroute が見つかりません。pingでホップを推定します"
        for (( ttl=1; ttl<=max_hops; ttl++ )); do
            local result
            result=$(ping -c 1 -t "$ttl" -W "$timeout" "$host" 2>/dev/null | \
                grep "From\|bytes from" | head -1 || echo "")
            local ip_addr
            ip_addr=$(echo "$result" | grep -oE "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | head -1 || echo "*")
            printf "  %3s  ${C_CYAN}%-20s${C_RESET}\n" "$ttl" "$ip_addr"
            [[ "$ip_addr" == "$ip" ]] && break
        done
    fi
    echo ""
}

cmd_mtr() {
    local host="${1:-}"
    [[ -z "$host" ]] && error_exit "ホストを指定してください"

    if command -v mtr &>/dev/null; then
        log_info "MTR統計: $host (${count}サイクル)"
        echo ""
        mtr --report --report-cycles "$count" --no-dns "$host" 2>/dev/null | \
        while IFS= read -r line; do
            if echo "$line" | grep -qE "^\s+[0-9]+\."; then
                local loss
                loss=$(echo "$line" | awk '{print $3}')
                local loss_num="${loss%\%}"
                local color="$C_GREEN"
                (( ${loss_num%.*} > 0  )) && color="$C_YELLOW"
                (( ${loss_num%.*} > 20 )) && color="$C_RED"
                printf "${color}%s${C_RESET}\n" "$line"
            else
                printf "${C_BOLD}%s${C_RESET}\n" "$line"
            fi
        done
    else
        log_warning "mtr が見つかりません。traceroute + ping で代替します"
        cmd_trace "$host"
    fi
    echo ""
}

cmd_geo() {
    local host="${1:-}"
    [[ -z "$host" ]] && error_exit "ホストを指定してください"

    local ip
    ip=$(resolve_ip "$host")
    log_info "IPジオロケーション: $host ($ip)"
    echo ""

    python3 - "$ip" <<'PYEOF'
import sys, json, urllib.request, urllib.error

ip = sys.argv[1]

if ip.startswith(("10.", "172.1","172.2","172.3","192.168.","127.")):
    print("  プライベートIPアドレスのため位置情報取得不可")
    sys.exit(0)

try:
    with urllib.request.urlopen(f"http://ip-api.com/json/{ip}?fields=status,country,regionName,city,zip,lat,lon,isp,org,as", timeout=5) as r:
        data = json.loads(r.read())

    if data.get("status") != "success":
        print("  位置情報を取得できませんでした")
        sys.exit(0)

    GREEN = "\033[1;32m"
    CYAN  = "\033[1;36m"
    RESET = "\033[0m"

    fields = [
        ("IPアドレス",   ip),
        ("国",           data.get("country",    "N/A")),
        ("地域",         data.get("regionName", "N/A")),
        ("都市",         data.get("city",       "N/A")),
        ("郵便番号",     data.get("zip",        "N/A")),
        ("緯度/経度",    f"{data.get('lat','N/A')}, {data.get('lon','N/A')}"),
        ("ISP",          data.get("isp",        "N/A")),
        ("組織",         data.get("org",        "N/A")),
        ("AS番号",       data.get("as",         "N/A")),
    ]
    for k, v in fields:
        print(f"  {CYAN}{k:<15}{RESET} {v}")
except urllib.error.URLError as e:
    print(f"  ネットワークエラー: {e}")
except Exception as e:
    print(f"  エラー: {e}")
PYEOF
    echo ""
}

cmd_watch() {
    local host="${1:-}"
    [[ -z "$host" ]] && error_exit "ホストを指定してください"

    log_info "経路変化監視: $host (間隔: ${watch_interval}秒)"
    echo ""

    local prev_trace=""
    local cleanup_done=false
    cleanup() { $cleanup_done && return; cleanup_done=true; echo ""; }
    trap cleanup EXIT INT TERM

    while true; do
        local curr_trace
        curr_trace=$(traceroute -m "$max_hops" -q 1 -w 2 "$host" 2>/dev/null | tail -n +2 | \
            awk '{print $2}' | tr '\n' ' ' || echo "")

        local ts
        ts=$(date '+%H:%M:%S')

        if [[ "$prev_trace" != "$curr_trace" && -n "$prev_trace" ]]; then
            printf "\n${C_YELLOW}[%s] 経路変化検出!${C_RESET}\n" "$ts"
            printf "  前: ${C_DIM}%s${C_RESET}\n" "$prev_trace"
            printf "  後: ${C_CYAN}%s${C_RESET}\n" "$curr_trace"
        else
            printf "\r${C_DIM}[%s] 経路監視中... (変化なし)${C_RESET}  " "$ts"
        fi

        prev_trace="$curr_trace"
        sleep "$watch_interval"
    done
}

cmd_compare() {
    local hosts=("$@")
    [[ ${#hosts[@]} -lt 2 ]] && error_exit "比較するホストを2つ以上指定してください"

    log_info "経路比較: ${hosts[*]}"
    echo ""

    for host in "${hosts[@]}"; do
        local ip
        ip=$(resolve_ip "$host")
        printf "${C_BOLD}${C_CYAN}=== $host ($ip) ===${C_RESET}\n"

        if command -v traceroute &>/dev/null; then
            traceroute -m "$max_hops" -q 1 -w "$timeout" "$host" 2>/dev/null | \
            tail -n +2 | while IFS= read -r line; do
                printf "  ${C_DIM}%s${C_RESET}\n" "$line"
            done
        fi
        echo ""
    done
}

parse_arguments() {
    [[ $# -eq 0 ]] && { show_usage; exit 0; }
    case "$1" in
        trace|mtr|geo|bgp|watch|compare)
            command_name="$1"; shift ;;
    esac

    local positional=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -m|--max-hops) [[ $# -lt 2 ]] && error_exit "--max-hops には値が必要です"; max_hops="$2"; shift 2 ;;
            -c|--count)   [[ $# -lt 2 ]] && error_exit "--count には値が必要です"; count="$2"; shift 2 ;;
            -t|--timeout) [[ $# -lt 2 ]] && error_exit "--timeout には値が必要です"; timeout="$2"; shift 2 ;;
            -i|--interval) [[ $# -lt 2 ]] && error_exit "--interval には値が必要です"; watch_interval="$2"; shift 2 ;;
            -f|--format)  [[ $# -lt 2 ]] && error_exit "--format には値が必要です"; output_format="$2"; shift 2 ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  positional+=("$1"); shift ;;
        esac
    done
    POSITIONAL=("${positional[@]+"${positional[@]}"}")
}

declare -a POSITIONAL=()

main() {
    parse_arguments "$@"
    case "$command_name" in
        trace)   cmd_trace   "${POSITIONAL[0]:-}" ;;
        mtr)     cmd_mtr     "${POSITIONAL[0]:-}" ;;
        geo)     cmd_geo     "${POSITIONAL[0]:-}" ;;
        watch)   cmd_watch   "${POSITIONAL[0]:-}" ;;
        compare) cmd_compare "${POSITIONAL[@]+"${POSITIONAL[@]}"}" ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
