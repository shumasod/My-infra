#!/bin/bash
set -euo pipefail

#
# ポートスキャンツール
# 作成日: 2026-08-25
# バージョン: 1.0
#
# ホストのポート開放状況を確認します (内部ネットワーク診断用)
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare command_name="scan"
declare target_host="127.0.0.1"
declare port_range="1-1024"
declare timeout=1
declare threads=50
declare output_format="text"
declare show_closed=0

declare -A WELL_KNOWN_PORTS=(
    [21]="FTP" [22]="SSH" [23]="Telnet" [25]="SMTP" [53]="DNS"
    [80]="HTTP" [110]="POP3" [143]="IMAP" [443]="HTTPS" [445]="SMB"
    [3306]="MySQL" [5432]="PostgreSQL" [6379]="Redis" [27017]="MongoDB"
    [8080]="HTTP-Alt" [8443]="HTTPS-Alt" [9200]="Elasticsearch"
    [3389]="RDP" [5900]="VNC" [11211]="Memcached" [2181]="ZooKeeper"
    [9092]="Kafka" [2379]="etcd" [4444]="Metasploit" [1433]="MSSQL"
    [5672]="RabbitMQ" [15672]="RabbitMQ-Mgmt" [9000]="SonarQube"
)

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション] <ホスト>

ポートスキャンツールです。内部ネットワーク診断・セキュリティ確認用です。

コマンド:
  scan <ホスト>          ポートスキャン (デフォルト)
  common <ホスト>        主要ポートのみスキャン
  service <ホスト>       サービス検出付きスキャン
  local                  ローカルポート一覧

オプション:
  -h, --help             このヘルプを表示
  -v, --version          バージョン情報を表示
  -p, --ports <範囲>     ポート範囲 (例: 1-1024, 80,443,8080) [デフォルト: 1-1024]
  -t, --timeout <秒>     タイムアウト [デフォルト: 1]
  -j, --threads <数>     並列数 [デフォルト: 50]
  -a, --all              閉じたポートも表示
  -f, --format <形式>    出力形式 (text|json) [デフォルト: text]

注意: このツールは自身の管理するホストのみに使用してください。

例:
  $PROG_NAME scan 192.168.1.1
  $PROG_NAME scan localhost -p 1-65535
  $PROG_NAME common 192.168.1.1
  $PROG_NAME local
EOF
}

parse_port_range() {
    local range="$1"
    local ports=()

    if [[ "$range" == *","* ]]; then
        IFS=',' read -ra parts <<< "$range"
        for p in "${parts[@]}"; do
            if [[ "$p" =~ ^([0-9]+)-([0-9]+)$ ]]; then
                for (( i = BASH_REMATCH[1]; i <= BASH_REMATCH[2]; i++ )); do
                    ports+=("$i")
                done
            elif [[ "$p" =~ ^[0-9]+$ ]]; then
                ports+=("$p")
            fi
        done
    elif [[ "$range" =~ ^([0-9]+)-([0-9]+)$ ]]; then
        for (( i = BASH_REMATCH[1]; i <= BASH_REMATCH[2]; i++ )); do
            ports+=("$i")
        done
    elif [[ "$range" =~ ^[0-9]+$ ]]; then
        ports+=("$range")
    fi

    echo "${ports[@]}"
}

check_port() {
    local host="$1"
    local port="$2"
    local to="${3:-1}"
    (echo >/dev/tcp/"$host"/"$port") 2>/dev/null &
    local pid=$!
    sleep "$to" && kill "$pid" 2>/dev/null &
    wait "$pid" 2>/dev/null && return 0 || return 1
}

scan_port_nc() {
    local host="$1"
    local port="$2"
    nc -z -w "$timeout" "$host" "$port" 2>/dev/null
}

scan_ports_parallel() {
    local host="$1"
    shift
    local ports=("$@")
    local tmpdir
    tmpdir=$(mktemp -d)
    local open_file="${tmpdir}/open"
    local pids=()
    local running=0

    for port in "${ports[@]}"; do
        (
            if nc -z -w "$timeout" "$host" "$port" 2>/dev/null; then
                echo "$port" >> "$open_file"
            fi
        ) &
        pids+=($!)
        (( running++ ))
        if (( running >= threads )); then
            wait "${pids[0]}" 2>/dev/null || true
            pids=("${pids[@]:1}")
            (( running-- ))
        fi
    done

    for pid in "${pids[@]}"; do
        wait "$pid" 2>/dev/null || true
    done

    local open_ports=()
    if [[ -f "$open_file" ]]; then
        while IFS= read -r p; do
            open_ports+=("$p")
        done < "$open_file"
    fi
    rm -rf "$tmpdir"

    printf '%s\n' "${open_ports[@]}" | sort -n
}

cmd_scan() {
    local host="${1:-$target_host}"
    log_info "ポートスキャン: $host (ポート: $port_range)"
    echo ""

    if ! command -v nc &>/dev/null; then
        log_warning "nc (netcat) が見つかりません。/dev/tcp を使用します"
    fi

    local start_time
    start_time=$(date +%s)

    local ports=()
    read -ra ports <<< "$(parse_port_range "$port_range")"
    local total=${#ports[@]}

    printf "  スキャン中... (%d ポート, タイムアウト: %ds, 並列: %d)\n" \
        "$total" "$timeout" "$threads"
    echo ""

    local open_ports=()
    if command -v nc &>/dev/null; then
        while IFS= read -r p; do
            [[ -n "$p" ]] && open_ports+=("$p")
        done < <(scan_ports_parallel "$host" "${ports[@]}")
    else
        for port in "${ports[@]}"; do
            if check_port "$host" "$port"; then
                open_ports+=("$port")
            fi
        done
    fi

    local end_time
    end_time=$(date +%s)
    local elapsed=$(( end_time - start_time ))

    printf "${C_BOLD}【スキャン結果: $host】${C_RESET}\n\n"
    printf "${C_BOLD}  %-8s %-15s %s${C_RESET}\n" "ポート" "状態" "サービス"
    printf "  %s\n" "$(printf '%.0s─' {1..40})"

    if [[ ${#open_ports[@]} -eq 0 ]]; then
        printf "  ${C_DIM}開放ポートなし${C_RESET}\n"
    else
        for port in "${open_ports[@]}"; do
            local svc="${WELL_KNOWN_PORTS[$port]:-不明}"
            local risk_flag=""
            case "$port" in
                23|445|4444|1433) risk_flag=" ${C_RED}[要確認]${C_RESET}" ;;
                21|3389|5900)     risk_flag=" ${C_YELLOW}[注意]${C_RESET}" ;;
            esac
            printf "  ${C_GREEN}%-8s${C_RESET} %-15s %s%s\n" \
                "$port/tcp" "open" "$svc" "$risk_flag"
        done
    fi

    echo ""
    printf "  スキャン完了: %d秒  開放ポート: ${C_GREEN}%d${C_RESET}/%d\n" \
        "$elapsed" "${#open_ports[@]}" "$total"
    echo ""

    if [[ "$output_format" == "json" ]]; then
        python3 - "$host" "${open_ports[@]+"${open_ports[@]}"}" <<'PYEOF'
import sys, json
host = sys.argv[1]
ports = [int(p) for p in sys.argv[2:]]
well_known = {22:"SSH",80:"HTTP",443:"HTTPS",3306:"MySQL",5432:"PostgreSQL",6379:"Redis"}
result = {"host": host, "open_ports": [{"port": p, "service": well_known.get(p, "unknown")} for p in ports]}
print(json.dumps(result, indent=2))
PYEOF
    fi
}

cmd_common() {
    local host="${1:-$target_host}"
    port_range="21,22,23,25,53,80,110,143,443,445,3306,5432,6379,8080,8443,27017,9200,3389,5900,11211"
    log_info "主要ポートスキャン: $host"
    cmd_scan "$host"
}

cmd_service() {
    local host="${1:-$target_host}"
    log_info "サービス検出スキャン: $host"
    echo ""

    local ports=()
    read -ra ports <<< "$(parse_port_range "$port_range")"

    local open_ports=()
    if command -v nc &>/dev/null; then
        while IFS= read -r p; do
            [[ -n "$p" ]] && open_ports+=("$p")
        done < <(scan_ports_parallel "$host" "${ports[@]}")
    fi

    printf "${C_BOLD}【サービス検出結果】${C_RESET}\n\n"
    printf "${C_BOLD}  %-8s %-20s %s${C_RESET}\n" "ポート" "サービス" "バナー"
    printf "  %s\n" "$(printf '%.0s─' {1..65})"

    for port in "${open_ports[@]}"; do
        local svc="${WELL_KNOWN_PORTS[$port]:-不明}"
        local banner=""
        banner=$(timeout 2 bash -c "echo '' | nc -w 2 '$host' '$port' 2>/dev/null | head -1 | tr -d '\r\n'" 2>/dev/null || true)
        banner="${banner:0:35}"
        printf "  ${C_GREEN}%-8s${C_RESET} ${C_CYAN}%-20s${C_RESET} ${C_DIM}%s${C_RESET}\n" \
            "$port/tcp" "$svc" "$banner"
    done
    echo ""
}

cmd_local() {
    log_info "ローカルポート一覧"
    echo ""

    printf "${C_BOLD}【リスニングポート】${C_RESET}\n\n"
    printf "${C_BOLD}  %-8s %-25s %-20s %s${C_RESET}\n" "ポート" "アドレス" "プロセス" "プロトコル"
    printf "  %s\n" "$(printf '%.0s─' {1..70})"

    if command -v ss &>/dev/null; then
        ss -tlnp 2>/dev/null | tail -n +2 | while IFS= read -r line; do
            local proto addr port pid
            addr=$(echo "$line" | awk '{print $4}')
            port="${addr##*:}"
            addr="${addr%:*}"
            pid=$(echo "$line" | grep -oP 'pid=\K[0-9]+' || echo "-")
            local proc="N/A"
            [[ "$pid" != "-" ]] && proc=$(ps -p "$pid" -o comm= 2>/dev/null || echo "N/A")
            local svc="${WELL_KNOWN_PORTS[$port]:-}"
            printf "  ${C_GREEN}%-8s${C_RESET} %-25s %-20s ${C_DIM}%s${C_RESET}\n" \
                "$port" "$addr" "${proc:0:20}" "$svc"
        done
    elif command -v netstat &>/dev/null; then
        netstat -tlnp 2>/dev/null | grep LISTEN | while IFS= read -r line; do
            local addr port proc
            addr=$(echo "$line" | awk '{print $4}')
            port="${addr##*:}"
            proc=$(echo "$line" | awk '{print $7}' | cut -d'/' -f2)
            local svc="${WELL_KNOWN_PORTS[$port]:-}"
            printf "  ${C_GREEN}%-8s${C_RESET} %-25s %-20s ${C_DIM}%s${C_RESET}\n" \
                "$port" "${addr%:*}" "${proc:0:20}" "$svc"
        done
    else
        log_warning "ss または netstat が必要です"
    fi
    echo ""
}

parse_arguments() {
    [[ $# -eq 0 ]] && { show_usage; exit 0; }
    case "$1" in
        scan|common|service|local)
            command_name="$1"; shift ;;
    esac

    local positional=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -p|--ports)   [[ $# -lt 2 ]] && error_exit "--ports には値が必要です"; port_range="$2"; shift 2 ;;
            -t|--timeout) [[ $# -lt 2 ]] && error_exit "--timeout には値が必要です"; timeout="$2"; shift 2 ;;
            -j|--threads) [[ $# -lt 2 ]] && error_exit "--threads には値が必要です"; threads="$2"; shift 2 ;;
            -a|--all)     show_closed=1; shift ;;
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
    local host="${POSITIONAL[0]:-$target_host}"
    case "$command_name" in
        scan)    cmd_scan "$host" ;;
        common)  cmd_common "$host" ;;
        service) cmd_service "$host" ;;
        local)   cmd_local ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
