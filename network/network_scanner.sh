#!/bin/bash
set -euo pipefail

#
# ネットワークスキャナー
# バージョン: 1.0
#
# LAN内のホスト探索・ポートスキャン・サービス検出ツール
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare target=""
declare -i timeout=1
declare mode="ping"
declare -a ports=()
declare output_csv=""
declare -i parallel_jobs=20

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション] <ターゲット>

ネットワーク内のホスト探索・ポートスキャンツール

引数:
  ターゲット             IPアドレス/CIDR (例: 192.168.1.0/24 または 192.168.1.1)

オプション:
  -h, --help            このヘルプを表示
  -v, --version         バージョン情報を表示
  -m, --mode MODE       スキャンモード (ping|port|service) [デフォルト: ping]
  -p, --ports PORTS     スキャンするポート (カンマ区切り: 22,80,443)
  -t, --timeout SEC     接続タイムアウト秒 [デフォルト: 1]
  -j, --jobs NUM        並列実行数 [デフォルト: 20]
  -o, --output FILE     結果をCSVで保存

モード:
  ping     pingでホストを検出
  port     ポートスキャン (--ports で指定)
  service  一般的なサービスポートを自動スキャン

例:
  $PROG_NAME 192.168.1.0/24
  $PROG_NAME -m port -p 22,80,443 192.168.1.1
  $PROG_NAME -m service 192.168.1.0/24

EOF
}

expand_cidr() {
    local cidr="$1"
    if [[ "$cidr" != */* ]]; then
        echo "$cidr"
        return
    fi

    local ip="${cidr%%/*}"
    local prefix="${cidr##*/}"
    local -a octets
    IFS='.' read -ra octets <<< "$ip"

    local base=$(( (octets[0] << 24) | (octets[1] << 16) | (octets[2] << 8) | octets[3] ))
    local mask=$(( 0xFFFFFFFF << (32 - prefix) & 0xFFFFFFFF ))
    local network=$(( base & mask ))
    local broadcast=$(( network | (~mask & 0xFFFFFFFF) ))

    for (( i = network + 1; i < broadcast; i++ )); do
        printf "%d.%d.%d.%d\n" \
            $(( (i >> 24) & 0xFF )) \
            $(( (i >> 16) & 0xFF )) \
            $(( (i >>  8) & 0xFF )) \
            $(( i & 0xFF ))
    done
}

ping_host() {
    local host="$1"
    if ping -c 1 -W "$timeout" "$host" &>/dev/null 2>&1; then
        echo "UP $host"
    fi
}

check_port() {
    local host="$1"
    local port="$2"
    if timeout "$timeout" bash -c "echo >/dev/tcp/${host}/${port}" &>/dev/null 2>&1; then
        echo "OPEN $host $port"
    fi
}

get_service_name() {
    local port="$1"
    case "$port" in
        21)   echo "FTP" ;;
        22)   echo "SSH" ;;
        23)   echo "Telnet" ;;
        25)   echo "SMTP" ;;
        53)   echo "DNS" ;;
        80)   echo "HTTP" ;;
        110)  echo "POP3" ;;
        143)  echo "IMAP" ;;
        443)  echo "HTTPS" ;;
        3306) echo "MySQL" ;;
        5432) echo "PostgreSQL" ;;
        6379) echo "Redis" ;;
        8080) echo "HTTP-Alt" ;;
        8443) echo "HTTPS-Alt" ;;
        27017) echo "MongoDB" ;;
        *)    echo "unknown" ;;
    esac
}

do_ping_scan() {
    local -a hosts=()
    while IFS= read -r h; do hosts+=("$h"); done < <(expand_cidr "$target")

    log_info "Ping スキャン: $target (${#hosts[@]} ホスト)"
    echo ""
    printf "  %-20s %s\n" "IPアドレス" "状態"
    printf "  %s\n" "$(printf '%.0s-' {1..35})"

    local tmp_dir
    tmp_dir=$(mktemp -d)
    local -i job_count=0

    for host in "${hosts[@]}"; do
        ping_host "$host" >> "${tmp_dir}/results" &
        (( job_count++ )) || true
        if (( job_count >= parallel_jobs )); then
            wait
            job_count=0
        fi
    done
    wait

    local found=0
    if [[ -f "${tmp_dir}/results" ]]; then
        while IFS=' ' read -r status host; do
            printf "  %-20s ${C_GREEN}%s${C_RESET}\n" "$host" "$status"
            [[ -n "$output_csv" ]] && echo "${host},${status}" >> "$output_csv"
            (( found++ )) || true
        done < <(sort "${tmp_dir}/results")
    fi

    rm -rf "$tmp_dir"
    echo ""
    printf "  発見: %d ホスト\n" "$found"
    echo ""
}

do_port_scan() {
    [[ ${#ports[@]} -eq 0 ]] && error_exit "--ports でポートを指定してください"

    log_info "ポートスキャン: $target (ポート: ${ports[*]})"
    echo ""

    local tmp_dir
    tmp_dir=$(mktemp -d)

    for port in "${ports[@]}"; do
        check_port "$target" "$port" >> "${tmp_dir}/results" &
    done
    wait

    printf "  %-10s %-15s %s\n" "状態" "ポート" "サービス"
    printf "  %s\n" "$(printf '%.0s-' {1..40})"

    if [[ -f "${tmp_dir}/results" ]]; then
        while IFS=' ' read -r status host port; do
            local svc
            svc=$(get_service_name "$port")
            printf "  ${C_GREEN}%-10s${C_RESET} %-15s %s\n" "$status" "$port" "$svc"
            [[ -n "$output_csv" ]] && echo "${host},${port},${status},${svc}" >> "$output_csv"
        done < <(sort -t' ' -k3 -n "${tmp_dir}/results")
    fi

    rm -rf "$tmp_dir"
    echo ""
}

do_service_scan() {
    local service_ports=(21 22 23 25 53 80 110 143 443 3306 5432 6379 8080 8443 27017)
    ports=("${service_ports[@]}")

    log_info "サービス検出スキャン: $target"

    local -a hosts=()
    while IFS= read -r h; do hosts+=("$h"); done < <(expand_cidr "$target")

    local tmp_dir
    tmp_dir=$(mktemp -d)

    for host in "${hosts[@]}"; do
        for port in "${service_ports[@]}"; do
            check_port "$host" "$port" >> "${tmp_dir}/results" &
        done
        wait
    done

    if [[ -s "${tmp_dir}/results" ]]; then
        printf "\n  %-20s %-10s %s\n" "ホスト" "ポート" "サービス"
        printf "  %s\n" "$(printf '%.0s-' {1..45})"
        while IFS=' ' read -r status host port; do
            local svc
            svc=$(get_service_name "$port")
            printf "  %-20s %-10s %s\n" "$host" "$port" "$svc"
            [[ -n "$output_csv" ]] && echo "${host},${port},${svc}" >> "$output_csv"
        done < <(sort "${tmp_dir}/results")
    else
        log_info "オープンポートなし"
    fi

    rm -rf "$tmp_dir"
    echo ""
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -m|--mode)
                [[ $# -lt 2 ]] && error_exit "--mode には値が必要です"
                mode="$2"; shift 2 ;;
            -p|--ports)
                [[ $# -lt 2 ]] && error_exit "--ports には値が必要です"
                IFS=',' read -ra ports <<< "$2"; shift 2 ;;
            -t|--timeout)
                [[ $# -lt 2 ]] && error_exit "--timeout には数値が必要です"
                timeout="$2"; shift 2 ;;
            -j|--jobs)
                [[ $# -lt 2 ]] && error_exit "--jobs には数値が必要です"
                parallel_jobs="$2"; shift 2 ;;
            -o|--output)
                [[ $# -lt 2 ]] && error_exit "--output には値が必要です"
                output_csv="$2"; shift 2 ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  target="$1"; shift ;;
        esac
    done
}

main() {
    parse_arguments "$@"
    [[ -z "$target" ]] && error_exit "ターゲットを指定してください。詳細は --help を参照"

    if [[ -n "$output_csv" ]]; then
        echo "host,port,status,service" > "$output_csv"
    fi

    case "$mode" in
        ping)    do_ping_scan ;;
        port)    do_port_scan ;;
        service) do_service_scan ;;
        *)       error_exit "不明なモード: $mode (ping|port|service)" ;;
    esac

    [[ -n "$output_csv" ]] && log_success "結果を保存: $output_csv"
}

main "$@"
