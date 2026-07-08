#!/bin/bash
set -euo pipefail

#
# ポート接続チェッカー
# 作成日: 2026-07-04
# バージョン: 1.0
#
# 指定ホストの複数ポートの開閉状態を確認するツール
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"
readonly DEFAULT_TIMEOUT=3

# よく使うポートのプリセット
declare -A PRESET_PORTS=(
    ["web"]="80 443"
    ["mail"]="25 465 587 993 995"
    ["db"]="3306 5432 6379 27017"
    ["ssh"]="22"
    ["common"]="21 22 25 80 443 3306 5432 8080 8443"
)

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション] <ホスト> [ポート...]

指定ホストのポート接続状態を確認します。

引数:
  <ホスト>      チェック対象のホスト名またはIPアドレス
  [ポート...]   チェックするポート番号（複数指定可）

オプション:
  -h, --help          このヘルプを表示
  -v, --version       バージョン情報を表示
  -t, --timeout N     接続タイムアウト秒数（デフォルト: ${DEFAULT_TIMEOUT}）
  -p, --preset NAME   プリセット使用 (web/mail/db/ssh/common)
  -o, --output FILE   結果をファイルに保存

プリセット:
  web    : 80, 443
  mail   : 25, 465, 587, 993, 995
  db     : 3306, 5432, 6379, 27017
  ssh    : 22
  common : 21, 22, 25, 80, 443, 3306, 5432, 8080, 8443

例:
  $PROG_NAME example.com 80 443
  $PROG_NAME -p web example.com
  $PROG_NAME -p common -o result.txt 192.168.1.1
EOF
}

check_port() {
    local host="$1"
    local port="$2"
    local timeout="$3"

    if timeout "$timeout" bash -c "echo > /dev/tcp/${host}/${port}" 2>/dev/null; then
        echo "open"
    else
        echo "closed"
    fi
}

check_host_reachable() {
    local host="$1"
    if ping -c 1 -W 2 "$host" &>/dev/null; then
        return 0
    fi
    return 1
}

get_service_name() {
    local port="$1"
    case "$port" in
        21)    echo "FTP" ;;
        22)    echo "SSH" ;;
        23)    echo "Telnet" ;;
        25)    echo "SMTP" ;;
        53)    echo "DNS" ;;
        80)    echo "HTTP" ;;
        110)   echo "POP3" ;;
        143)   echo "IMAP" ;;
        443)   echo "HTTPS" ;;
        465)   echo "SMTPS" ;;
        587)   echo "SMTP-Sub" ;;
        993)   echo "IMAPS" ;;
        995)   echo "POP3S" ;;
        3306)  echo "MySQL" ;;
        5432)  echo "PostgreSQL" ;;
        6379)  echo "Redis" ;;
        8080)  echo "HTTP-Alt" ;;
        8443)  echo "HTTPS-Alt" ;;
        27017) echo "MongoDB" ;;
        *)     echo "unknown" ;;
    esac
}

run_checks() {
    local host="$1"
    local timeout="$2"
    local output_file="$3"
    shift 3
    local ports=("$@")

    local open_count=0
    local closed_count=0
    local timestamp
    timestamp=$(get_timestamp)
    local results=()

    print_center "ポート接続チェッカー" 0 "${C_BOLD}${C_CYAN}"
    echo ""
    echo -e "  ${C_BOLD}ホスト:${C_RESET}   ${host}"
    echo -e "  ${C_BOLD}タイムアウト:${C_RESET} ${timeout}秒"
    echo -e "  ${C_BOLD}チェック数:${C_RESET}  ${#ports[@]}ポート"
    echo -e "  ${C_BOLD}実行時刻:${C_RESET} ${timestamp}"
    echo ""

    printf "  ${C_DIM}%-6s  %-14s  %-12s  %s${C_RESET}\n" "PORT" "SERVICE" "STATUS" "LATENCY"
    printf "  ${C_DIM}%s${C_RESET}\n" "──────────────────────────────────────"

    local port
    for port in "${ports[@]}"; do
        if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
            log_warning "無効なポート番号をスキップ: $port"
            continue
        fi

        local service
        service=$(get_service_name "$port")

        local start_ms end_ms latency
        start_ms=$(date +%s%N)
        local status
        status=$(check_port "$host" "$port" "$timeout")
        end_ms=$(date +%s%N)
        latency=$(( (end_ms - start_ms) / 1000000 ))

        local status_str color
        if [ "$status" == "open" ]; then
            status_str="OPEN"
            color="$C_GREEN"
            open_count=$(( open_count + 1 ))
        else
            status_str="CLOSED"
            color="$C_RED"
            closed_count=$(( closed_count + 1 ))
        fi

        printf "  %-6s  %-14s  ${color}%-12s${C_RESET}  %dms\n" \
            "$port" "$service" "$status_str" "$latency"

        results+=("$port|$service|$status_str|${latency}ms")
    done

    echo ""
    printf "  ${C_DIM}%s${C_RESET}\n" "──────────────────────────────────────"
    echo -e "  ${C_BOLD}結果:${C_RESET}  開放: ${C_GREEN}${open_count}${C_RESET}  閉鎖: ${C_RED}${closed_count}${C_RESET}"
    echo ""

    if [ -n "$output_file" ]; then
        {
            echo "# ポート接続チェック結果"
            echo "# ホスト: ${host}"
            echo "# 実行時刻: ${timestamp}"
            echo "# PORT|SERVICE|STATUS|LATENCY"
            local r
            for r in "${results[@]}"; do
                echo "$r"
            done
            echo "# 開放: ${open_count}  閉鎖: ${closed_count}"
        } > "$output_file"
        log_success "結果を保存しました: $output_file"
    fi
}

main() {
    local host=""
    local timeout="$DEFAULT_TIMEOUT"
    local preset=""
    local output_file=""
    local -a ports=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -t|--timeout)
                [[ $# -lt 2 ]] && error_exit "--timeout には数値が必要です"
                timeout="$2"; shift 2 ;;
            -p|--preset)
                [[ $# -lt 2 ]] && error_exit "--preset には名前が必要です"
                preset="$2"; shift 2 ;;
            -o|--output)
                [[ $# -lt 2 ]] && error_exit "--output にはファイル名が必要です"
                output_file="$2"; shift 2 ;;
            -*)
                error_exit "不明なオプション: $1" ;;
            *)
                if [ -z "$host" ]; then
                    host="$1"
                else
                    ports+=("$1")
                fi
                shift ;;
        esac
    done

    [ -z "$host" ] && error_exit "ホスト名を指定してください\n使用方法: $PROG_NAME --help"

    if [ -n "$preset" ]; then
        if [ -z "${PRESET_PORTS[$preset]+x}" ]; then
            error_exit "不明なプリセット: $preset (web/mail/db/ssh/common)"
        fi
        read -ra preset_list <<< "${PRESET_PORTS[$preset]}"
        ports=("${preset_list[@]}" "${ports[@]}")
    fi

    [ "${#ports[@]}" -eq 0 ] && error_exit "ポート番号を指定してください\n使用方法: $PROG_NAME --help"

    run_checks "$host" "$timeout" "$output_file" "${ports[@]}"
}

main "$@"
