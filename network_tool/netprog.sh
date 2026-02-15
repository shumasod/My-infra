#!/bin/bash
set -euo pipefail

#
# ネットワークプログラミングツール
# 作成日: 2024
# バージョン: 1.0
#
# 概要:
#   TUIベースのネットワークプログラミングツール
#   TCP/UDP通信、HTTP リクエスト、ポートスキャン、DNS検索などを
#   インタラクティブに実行できます
#
# 使用例:
#   ./netprog.sh                 # インタラクティブメニュー
#   ./netprog.sh tcp-client      # TCPクライアントモード
#   ./netprog.sh http            # HTTPクライアントモード
#   ./netprog.sh scan            # ポートスキャナー
#

# ===== 共通ライブラリ読み込み =====
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/../lib/common.sh" ]]; then
    # shellcheck source=../lib/common.sh
    source "${SCRIPT_DIR}/../lib/common.sh"
else
    # フォールバック
    C_RESET='\033[0m'
    C_BOLD='\033[1m'
    C_DIM='\033[2m'
    C_RED='\033[1;31m'
    C_GREEN='\033[1;32m'
    C_YELLOW='\033[1;33m'
    C_BLUE='\033[1;34m'
    C_MAGENTA='\033[1;35m'
    C_CYAN='\033[1;36m'
    C_WHITE='\033[1;37m'
    C_BG_BLUE='\033[44m'
    C_BG_GREEN='\033[42m'
    C_BG_RED='\033[41m'
fi

# ===== 設定（定数） =====
readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"
readonly LOG_DIR="/tmp/netprog_logs"
readonly DEFAULT_TIMEOUT=5

# 一般的なポート
readonly -a COMMON_PORTS=(
    21 22 23 25 53 80 110 143 443 445 993 995 3306 3389 5432 6379 8080 8443
)

# ===== グローバル変数 =====
declare -i terminal_rows=24
declare -i terminal_cols=80

# ===== ヘルパー関数 =====

update_terminal_size() {
    terminal_rows=$(tput lines 2>/dev/null || echo 24)
    terminal_cols=$(tput cols 2>/dev/null || echo 80)
}

clear_screen() {
    printf '\033[2J\033[H'
}

move_cursor() {
    printf '\033[%d;%dH' "$1" "$2"
}

show_usage() {
    cat <<EOF
${C_CYAN}ネットワークプログラミングツール${C_RESET} v${VERSION}

使用方法: $PROG_NAME [オプション] [コマンド]

コマンド:
  (なし)          インタラクティブメニュー
  tcp-client      TCPクライアント
  tcp-server      TCPサーバー
  udp-client      UDPクライアント
  http            HTTPクライアント
  scan            ポートスキャナー
  dns             DNS検索
  ping            Ping テスト
  info            ネットワーク情報

オプション:
  -h, --help      このヘルプを表示
  -v, --version   バージョン情報を表示

例:
  $PROG_NAME
  $PROG_NAME tcp-client
  $PROG_NAME scan
EOF
}

log_info() {
    echo -e "${C_CYAN}[INFO]${C_RESET} $1"
}

log_success() {
    echo -e "${C_GREEN}[SUCCESS]${C_RESET} $1"
}

log_error() {
    echo -e "${C_RED}[ERROR]${C_RESET} $1" >&2
}

log_warning() {
    echo -e "${C_YELLOW}[WARNING]${C_RESET} $1"
}

# 区切り線を表示
draw_line() {
    local char="${1:--}"
    printf '%*s\n' "${terminal_cols}" '' | tr ' ' "$char"
}

# 入力プロンプト
prompt_input() {
    local prompt="$1"
    local default="${2:-}"
    local result

    if [[ -n "$default" ]]; then
        echo -ne "${C_CYAN}${prompt}${C_RESET} [${default}]: "
    else
        echo -ne "${C_CYAN}${prompt}${C_RESET}: "
    fi
    read -r result
    echo "${result:-$default}"
}

# 確認プロンプト
prompt_confirm() {
    local prompt="$1"
    local default="${2:-n}"
    local result

    echo -ne "${C_YELLOW}${prompt}${C_RESET} [y/N]: "
    read -r result
    [[ "${result:-$default}" =~ ^[Yy] ]]
}

# 依存コマンドチェック
check_command() {
    local cmd="$1"
    if ! command -v "$cmd" &>/dev/null; then
        log_error "コマンド '$cmd' が見つかりません"
        return 1
    fi
    return 0
}

# ===== バナー表示 =====

show_banner() {
    echo -e "${C_CYAN}"
    cat <<'EOF'
  _   _      _                      _      _____           _
 | \ | | ___| |___      _____  _ __| | __ |_   _|__   ___ | |
 |  \| |/ _ \ __\ \ /\ / / _ \| '__| |/ /   | |/ _ \ / _ \| |
 | |\  |  __/ |_ \ V  V / (_) | |  |   <    | | (_) | (_) | |
 |_| \_|\___|\__| \_/\_/ \___/|_|  |_|\_\   |_|\___/ \___/|_|
EOF
    echo -e "${C_RESET}"
    echo -e "  ${C_WHITE}${C_BOLD}ネットワークプログラミングツール${C_RESET} v${VERSION}"
    echo ""
}

# ===== TCP クライアント =====

tcp_client_mode() {
    clear_screen
    echo -e "${C_GREEN}╔════════════════════════════════════════╗${C_RESET}"
    echo -e "${C_GREEN}║${C_RESET}  ${C_WHITE}${C_BOLD}TCP クライアント${C_RESET}                      ${C_GREEN}║${C_RESET}"
    echo -e "${C_GREEN}╚════════════════════════════════════════╝${C_RESET}"
    echo ""

    local host
    local port
    host=$(prompt_input "接続先ホスト" "localhost")
    port=$(prompt_input "ポート番号" "80")

    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
        log_error "無効なポート番号です"
        return 1
    fi

    echo ""
    log_info "接続中: ${host}:${port}"

    # /dev/tcp を使用した接続テスト
    if timeout "$DEFAULT_TIMEOUT" bash -c "echo >/dev/tcp/${host}/${port}" 2>/dev/null; then
        log_success "接続成功！"
        echo ""

        echo -e "${C_YELLOW}データを送信しますか？${C_RESET}"
        if prompt_confirm "送信"; then
            echo -e "${C_CYAN}送信データを入力 (空行で終了):${C_RESET}"
            local data=""
            while IFS= read -r line; do
                [[ -z "$line" ]] && break
                data+="${line}"$'\n'
            done

            if [[ -n "$data" ]]; then
                echo ""
                log_info "送信中..."
                local response
                response=$(echo -e "$data" | timeout "$DEFAULT_TIMEOUT" nc -w 3 "$host" "$port" 2>/dev/null || true)

                if [[ -n "$response" ]]; then
                    echo ""
                    echo -e "${C_GREEN}=== レスポンス ===${C_RESET}"
                    echo "$response"
                    echo -e "${C_GREEN}==================${C_RESET}"
                else
                    log_warning "レスポンスがありませんでした"
                fi
            fi
        fi
    else
        log_error "接続失敗: ${host}:${port}"
    fi

    echo ""
    read -rp "Enterで戻る..."
}

# ===== TCP サーバー =====

tcp_server_mode() {
    clear_screen
    echo -e "${C_BLUE}╔════════════════════════════════════════╗${C_RESET}"
    echo -e "${C_BLUE}║${C_RESET}  ${C_WHITE}${C_BOLD}TCP サーバー${C_RESET}                          ${C_BLUE}║${C_RESET}"
    echo -e "${C_BLUE}╚════════════════════════════════════════╝${C_RESET}"
    echo ""

    if ! check_command nc; then
        echo ""
        read -rp "Enterで戻る..."
        return 1
    fi

    local port
    port=$(prompt_input "リッスンポート" "8080")

    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
        log_error "無効なポート番号です"
        return 1
    fi

    local response_msg
    response_msg=$(prompt_input "レスポンスメッセージ" "Hello from TCP Server!")

    echo ""
    log_info "サーバーを起動: ポート ${port}"
    log_info "Ctrl+C で停止"
    echo ""

    # シンプルなTCPサーバー
    while true; do
        echo -e "${C_YELLOW}接続待機中...${C_RESET}"
        {
            echo -e "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nConnection: close\r\n\r\n${response_msg}"
        } | nc -l -p "$port" -q 1 2>/dev/null || true
        log_success "接続を処理しました"
    done
}

# ===== UDP クライアント =====

udp_client_mode() {
    clear_screen
    echo -e "${C_MAGENTA}╔════════════════════════════════════════╗${C_RESET}"
    echo -e "${C_MAGENTA}║${C_RESET}  ${C_WHITE}${C_BOLD}UDP クライアント${C_RESET}                      ${C_MAGENTA}║${C_RESET}"
    echo -e "${C_MAGENTA}╚════════════════════════════════════════╝${C_RESET}"
    echo ""

    if ! check_command nc; then
        echo ""
        read -rp "Enterで戻る..."
        return 1
    fi

    local host
    local port
    host=$(prompt_input "送信先ホスト" "localhost")
    port=$(prompt_input "ポート番号" "53")

    echo ""
    echo -e "${C_CYAN}送信データを入力:${C_RESET}"
    local data
    read -r data

    if [[ -n "$data" ]]; then
        log_info "UDP送信中: ${host}:${port}"
        echo "$data" | nc -u -w 2 "$host" "$port" 2>/dev/null && \
            log_success "送信完了" || \
            log_error "送信失敗"
    fi

    echo ""
    read -rp "Enterで戻る..."
}

# ===== HTTP クライアント =====

http_client_mode() {
    clear_screen
    echo -e "${C_YELLOW}╔════════════════════════════════════════╗${C_RESET}"
    echo -e "${C_YELLOW}║${C_RESET}  ${C_WHITE}${C_BOLD}HTTP クライアント${C_RESET}                     ${C_YELLOW}║${C_RESET}"
    echo -e "${C_YELLOW}╚════════════════════════════════════════╝${C_RESET}"
    echo ""

    echo "メソッドを選択:"
    echo "  1) GET"
    echo "  2) POST"
    echo "  3) HEAD"
    echo "  4) PUT"
    echo "  5) DELETE"
    echo ""
    local method_choice
    method_choice=$(prompt_input "選択" "1")

    local method
    case "$method_choice" in
        1) method="GET" ;;
        2) method="POST" ;;
        3) method="HEAD" ;;
        4) method="PUT" ;;
        5) method="DELETE" ;;
        *) method="GET" ;;
    esac

    local url
    url=$(prompt_input "URL" "http://example.com")

    local headers=""
    if prompt_confirm "カスタムヘッダーを追加"; then
        echo -e "${C_CYAN}ヘッダーを入力 (形式: Header: Value、空行で終了):${C_RESET}"
        while IFS= read -r line; do
            [[ -z "$line" ]] && break
            headers+=" -H '$line'"
        done
    fi

    local data=""
    if [[ "$method" == "POST" || "$method" == "PUT" ]]; then
        echo -e "${C_CYAN}リクエストボディを入力:${C_RESET}"
        read -r data
    fi

    echo ""
    log_info "リクエスト送信中: ${method} ${url}"
    echo ""

    # curlまたはwgetを使用
    if check_command curl 2>/dev/null; then
        local curl_cmd="curl -s -X ${method} -w '\n\n--- Response Info ---\nHTTP Code: %{http_code}\nTime: %{time_total}s\nSize: %{size_download} bytes\n'"

        if [[ -n "$headers" ]]; then
            curl_cmd+=" ${headers}"
        fi

        if [[ -n "$data" ]]; then
            curl_cmd+=" -d '${data}'"
        fi

        curl_cmd+=" '${url}'"

        echo -e "${C_GREEN}=== レスポンス ===${C_RESET}"
        eval "$curl_cmd" 2>/dev/null || log_error "リクエスト失敗"
        echo -e "${C_GREEN}==================${C_RESET}"

    elif check_command wget 2>/dev/null; then
        log_info "wgetを使用"
        wget -q -O - "$url" 2>/dev/null || log_error "リクエスト失敗"
    else
        # /dev/tcp を使用した簡易HTTPクライアント
        local host port path
        if [[ "$url" =~ ^https?://([^/:]+)(:([0-9]+))?(/.*)?$ ]]; then
            host="${BASH_REMATCH[1]}"
            port="${BASH_REMATCH[3]:-80}"
            path="${BASH_REMATCH[4]:-/}"

            log_info "シンプルHTTPクライアントを使用: ${host}:${port}${path}"

            {
                echo -e "${method} ${path} HTTP/1.1\r"
                echo -e "Host: ${host}\r"
                echo -e "Connection: close\r"
                echo -e "\r"
            } | nc -w 5 "$host" "$port" 2>/dev/null || log_error "接続失敗"
        else
            log_error "無効なURL形式です"
        fi
    fi

    echo ""
    read -rp "Enterで戻る..."
}

# ===== ポートスキャナー =====

port_scanner_mode() {
    clear_screen
    echo -e "${C_RED}╔════════════════════════════════════════╗${C_RESET}"
    echo -e "${C_RED}║${C_RESET}  ${C_WHITE}${C_BOLD}ポートスキャナー${C_RESET}                      ${C_RED}║${C_RESET}"
    echo -e "${C_RED}╚════════════════════════════════════════╝${C_RESET}"
    echo ""
    echo -e "${C_YELLOW}※ 許可されたホストのみスキャンしてください${C_RESET}"
    echo ""

    local host
    host=$(prompt_input "スキャン対象ホスト" "localhost")

    echo ""
    echo "スキャン範囲を選択:"
    echo "  1) 一般的なポート (${#COMMON_PORTS[@]}個)"
    echo "  2) 範囲指定"
    echo "  3) 特定ポート指定"
    echo ""
    local scan_type
    scan_type=$(prompt_input "選択" "1")

    local ports=()
    case "$scan_type" in
        1)
            ports=("${COMMON_PORTS[@]}")
            ;;
        2)
            local start_port end_port
            start_port=$(prompt_input "開始ポート" "1")
            end_port=$(prompt_input "終了ポート" "1024")
            for ((p = start_port; p <= end_port; p++)); do
                ports+=("$p")
            done
            ;;
        3)
            local port_list
            port_list=$(prompt_input "ポート番号（カンマ区切り）" "22,80,443")
            IFS=',' read -ra ports <<< "$port_list"
            ;;
    esac

    echo ""
    log_info "スキャン開始: ${host} (${#ports[@]} ポート)"
    draw_line "-"

    local open_ports=()
    local total=${#ports[@]}
    local current=0

    for port in "${ports[@]}"; do
        ((current++))
        printf "\r${C_CYAN}[%d/%d]${C_RESET} ポート %d をスキャン中..." "$current" "$total" "$port"

        if timeout 1 bash -c "echo >/dev/tcp/${host}/${port}" 2>/dev/null; then
            open_ports+=("$port")
            printf "\r${C_GREEN}[OPEN]${C_RESET} ポート %d                    \n" "$port"
        fi
    done

    printf "\r%*s\r" 50 ""
    echo ""
    draw_line "-"
    echo ""

    if [[ ${#open_ports[@]} -gt 0 ]]; then
        log_success "開いているポート (${#open_ports[@]}個):"
        for port in "${open_ports[@]}"; do
            local service=""
            case $port in
                21) service="FTP" ;;
                22) service="SSH" ;;
                23) service="Telnet" ;;
                25) service="SMTP" ;;
                53) service="DNS" ;;
                80) service="HTTP" ;;
                110) service="POP3" ;;
                143) service="IMAP" ;;
                443) service="HTTPS" ;;
                445) service="SMB" ;;
                993) service="IMAPS" ;;
                995) service="POP3S" ;;
                3306) service="MySQL" ;;
                3389) service="RDP" ;;
                5432) service="PostgreSQL" ;;
                6379) service="Redis" ;;
                8080) service="HTTP-Alt" ;;
                8443) service="HTTPS-Alt" ;;
            esac
            if [[ -n "$service" ]]; then
                echo -e "  ${C_GREEN}●${C_RESET} ${port} (${service})"
            else
                echo -e "  ${C_GREEN}●${C_RESET} ${port}"
            fi
        done
    else
        log_warning "開いているポートは見つかりませんでした"
    fi

    echo ""
    read -rp "Enterで戻る..."
}

# ===== DNS 検索 =====

dns_lookup_mode() {
    clear_screen
    echo -e "${C_CYAN}╔════════════════════════════════════════╗${C_RESET}"
    echo -e "${C_CYAN}║${C_RESET}  ${C_WHITE}${C_BOLD}DNS 検索${C_RESET}                              ${C_CYAN}║${C_RESET}"
    echo -e "${C_CYAN}╚════════════════════════════════════════╝${C_RESET}"
    echo ""

    local domain
    domain=$(prompt_input "ドメイン名" "example.com")

    echo ""
    echo "クエリタイプを選択:"
    echo "  1) A (IPv4アドレス)"
    echo "  2) AAAA (IPv6アドレス)"
    echo "  3) MX (メールサーバー)"
    echo "  4) NS (ネームサーバー)"
    echo "  5) TXT (テキストレコード)"
    echo "  6) CNAME (別名)"
    echo "  7) ALL (すべて)"
    echo ""
    local query_type
    query_type=$(prompt_input "選択" "1")

    local record_type
    case "$query_type" in
        1) record_type="A" ;;
        2) record_type="AAAA" ;;
        3) record_type="MX" ;;
        4) record_type="NS" ;;
        5) record_type="TXT" ;;
        6) record_type="CNAME" ;;
        7) record_type="ANY" ;;
        *) record_type="A" ;;
    esac

    echo ""
    log_info "DNS検索: ${domain} (${record_type})"
    draw_line "-"

    # nslookup, dig, host のいずれかを使用
    if check_command dig 2>/dev/null; then
        echo -e "${C_GREEN}=== dig ${record_type} ${domain} ===${C_RESET}"
        dig +short "$record_type" "$domain" 2>/dev/null || log_error "検索失敗"
        echo ""
        echo -e "${C_DIM}--- 詳細情報 ---${C_RESET}"
        dig "$record_type" "$domain" +noall +answer 2>/dev/null || true

    elif check_command nslookup 2>/dev/null; then
        echo -e "${C_GREEN}=== nslookup ${domain} ===${C_RESET}"
        nslookup -type="$record_type" "$domain" 2>/dev/null || log_error "検索失敗"

    elif check_command host 2>/dev/null; then
        echo -e "${C_GREEN}=== host ${domain} ===${C_RESET}"
        host -t "$record_type" "$domain" 2>/dev/null || log_error "検索失敗"

    else
        # getent を使用したフォールバック
        if [[ "$record_type" == "A" ]]; then
            echo -e "${C_GREEN}=== getent hosts ${domain} ===${C_RESET}"
            getent hosts "$domain" 2>/dev/null || log_error "検索失敗"
        else
            log_error "DNS検索ツールが見つかりません (dig, nslookup, host)"
        fi
    fi

    echo ""
    draw_line "-"
    read -rp "Enterで戻る..."
}

# ===== Ping テスト =====

ping_test_mode() {
    clear_screen
    echo -e "${C_GREEN}╔════════════════════════════════════════╗${C_RESET}"
    echo -e "${C_GREEN}║${C_RESET}  ${C_WHITE}${C_BOLD}Ping テスト${C_RESET}                           ${C_GREEN}║${C_RESET}"
    echo -e "${C_GREEN}╚════════════════════════════════════════╝${C_RESET}"
    echo ""

    local host
    host=$(prompt_input "対象ホスト" "8.8.8.8")

    local count
    count=$(prompt_input "回数" "4")

    echo ""
    log_info "Ping テスト: ${host}"
    draw_line "-"

    if check_command ping; then
        ping -c "$count" "$host" 2>/dev/null || log_error "Ping失敗"
    else
        log_error "pingコマンドが見つかりません"
    fi

    echo ""
    draw_line "-"
    read -rp "Enterで戻る..."
}

# ===== ネットワーク情報 =====

network_info_mode() {
    clear_screen
    echo -e "${C_BLUE}╔════════════════════════════════════════╗${C_RESET}"
    echo -e "${C_BLUE}║${C_RESET}  ${C_WHITE}${C_BOLD}ネットワーク情報${C_RESET}                      ${C_BLUE}║${C_RESET}"
    echo -e "${C_BLUE}╚════════════════════════════════════════╝${C_RESET}"
    echo ""

    # ホスト名
    echo -e "${C_CYAN}【ホスト名】${C_RESET}"
    hostname 2>/dev/null || echo "不明"
    echo ""

    # IPアドレス
    echo -e "${C_CYAN}【IPアドレス】${C_RESET}"
    if check_command ip 2>/dev/null; then
        ip -4 addr show 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | while read -r ip; do
            echo "  $ip"
        done
    elif check_command ifconfig 2>/dev/null; then
        ifconfig 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | while read -r ip; do
            echo "  $ip"
        done
    fi
    echo ""

    # デフォルトゲートウェイ
    echo -e "${C_CYAN}【デフォルトゲートウェイ】${C_RESET}"
    if check_command ip 2>/dev/null; then
        ip route 2>/dev/null | grep default | awk '{print "  " $3}'
    elif check_command route 2>/dev/null; then
        route -n 2>/dev/null | grep '^0.0.0.0' | awk '{print "  " $2}'
    fi
    echo ""

    # DNS サーバー
    echo -e "${C_CYAN}【DNSサーバー】${C_RESET}"
    if [[ -f /etc/resolv.conf ]]; then
        grep '^nameserver' /etc/resolv.conf 2>/dev/null | awk '{print "  " $2}'
    fi
    echo ""

    # インターフェース一覧
    echo -e "${C_CYAN}【ネットワークインターフェース】${C_RESET}"
    if check_command ip 2>/dev/null; then
        ip link show 2>/dev/null | grep -E '^[0-9]+:' | awk -F': ' '{print "  " $2}'
    elif check_command ifconfig 2>/dev/null; then
        ifconfig -a 2>/dev/null | grep -E '^[a-zA-Z]' | awk -F':' '{print "  " $1}'
    fi
    echo ""

    # 外部IPアドレス
    echo -e "${C_CYAN}【外部IPアドレス】${C_RESET}"
    if check_command curl 2>/dev/null; then
        local ext_ip
        ext_ip=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "取得失敗")
        echo "  $ext_ip"
    else
        echo "  (curlが必要です)"
    fi
    echo ""

    draw_line "-"
    read -rp "Enterで戻る..."
}

# ===== Traceroute =====

traceroute_mode() {
    clear_screen
    echo -e "${C_MAGENTA}╔════════════════════════════════════════╗${C_RESET}"
    echo -e "${C_MAGENTA}║${C_RESET}  ${C_WHITE}${C_BOLD}Traceroute${C_RESET}                            ${C_MAGENTA}║${C_RESET}"
    echo -e "${C_MAGENTA}╚════════════════════════════════════════╝${C_RESET}"
    echo ""

    local host
    host=$(prompt_input "対象ホスト" "8.8.8.8")

    echo ""
    log_info "経路追跡: ${host}"
    draw_line "-"

    if check_command traceroute 2>/dev/null; then
        traceroute -m 15 "$host" 2>/dev/null || log_error "Traceroute失敗"
    elif check_command tracepath 2>/dev/null; then
        tracepath -m 15 "$host" 2>/dev/null || log_error "Tracepath失敗"
    else
        log_error "traceroute/tracepathコマンドが見つかりません"
    fi

    echo ""
    draw_line "-"
    read -rp "Enterで戻る..."
}

# ===== 接続テスト =====

connection_test_mode() {
    clear_screen
    echo -e "${C_YELLOW}╔════════════════════════════════════════╗${C_RESET}"
    echo -e "${C_YELLOW}║${C_RESET}  ${C_WHITE}${C_BOLD}接続テスト${C_RESET}                            ${C_YELLOW}║${C_RESET}"
    echo -e "${C_YELLOW}╚════════════════════════════════════════╝${C_RESET}"
    echo ""

    local host
    local port
    host=$(prompt_input "ホスト" "google.com")
    port=$(prompt_input "ポート" "443")

    echo ""
    log_info "接続テスト: ${host}:${port}"
    draw_line "-"

    local start_time end_time elapsed

    start_time=$(date +%s%N)
    if timeout "$DEFAULT_TIMEOUT" bash -c "echo >/dev/tcp/${host}/${port}" 2>/dev/null; then
        end_time=$(date +%s%N)
        elapsed=$(( (end_time - start_time) / 1000000 ))
        log_success "接続成功！"
        echo -e "  レイテンシ: ${C_GREEN}${elapsed}ms${C_RESET}"
    else
        log_error "接続失敗"
    fi

    # SSL/TLS情報の取得（443の場合）
    if [[ "$port" == "443" ]] && check_command openssl 2>/dev/null; then
        echo ""
        echo -e "${C_CYAN}【SSL/TLS 証明書情報】${C_RESET}"
        echo | timeout 5 openssl s_client -connect "${host}:${port}" 2>/dev/null | \
            openssl x509 -noout -subject -issuer -dates 2>/dev/null || \
            log_warning "証明書情報を取得できませんでした"
    fi

    echo ""
    draw_line "-"
    read -rp "Enterで戻る..."
}

# ===== メインメニュー =====

main_menu() {
    while true; do
        clear_screen
        update_terminal_size
        show_banner

        echo -e "${C_WHITE}┌─────────────────────────────────────────┐${C_RESET}"
        echo -e "${C_WHITE}│${C_RESET}  ${C_CYAN}メインメニュー${C_RESET}                         ${C_WHITE}│${C_RESET}"
        echo -e "${C_WHITE}├─────────────────────────────────────────┤${C_RESET}"
        echo -e "${C_WHITE}│${C_RESET}                                         ${C_WHITE}│${C_RESET}"
        echo -e "${C_WHITE}│${C_RESET}   ${C_GREEN}1)${C_RESET} TCP クライアント                  ${C_WHITE}│${C_RESET}"
        echo -e "${C_WHITE}│${C_RESET}   ${C_GREEN}2)${C_RESET} TCP サーバー                      ${C_WHITE}│${C_RESET}"
        echo -e "${C_WHITE}│${C_RESET}   ${C_GREEN}3)${C_RESET} UDP クライアント                  ${C_WHITE}│${C_RESET}"
        echo -e "${C_WHITE}│${C_RESET}   ${C_GREEN}4)${C_RESET} HTTP クライアント                 ${C_WHITE}│${C_RESET}"
        echo -e "${C_WHITE}│${C_RESET}   ${C_GREEN}5)${C_RESET} ポートスキャナー                  ${C_WHITE}│${C_RESET}"
        echo -e "${C_WHITE}│${C_RESET}   ${C_GREEN}6)${C_RESET} DNS 検索                          ${C_WHITE}│${C_RESET}"
        echo -e "${C_WHITE}│${C_RESET}   ${C_GREEN}7)${C_RESET} Ping テスト                       ${C_WHITE}│${C_RESET}"
        echo -e "${C_WHITE}│${C_RESET}   ${C_GREEN}8)${C_RESET} Traceroute                        ${C_WHITE}│${C_RESET}"
        echo -e "${C_WHITE}│${C_RESET}   ${C_GREEN}9)${C_RESET} 接続テスト                        ${C_WHITE}│${C_RESET}"
        echo -e "${C_WHITE}│${C_RESET}   ${C_GREEN}0)${C_RESET} ネットワーク情報                  ${C_WHITE}│${C_RESET}"
        echo -e "${C_WHITE}│${C_RESET}                                         ${C_WHITE}│${C_RESET}"
        echo -e "${C_WHITE}│${C_RESET}   ${C_RED}q)${C_RESET} 終了                              ${C_WHITE}│${C_RESET}"
        echo -e "${C_WHITE}│${C_RESET}                                         ${C_WHITE}│${C_RESET}"
        echo -e "${C_WHITE}└─────────────────────────────────────────┘${C_RESET}"
        echo ""
        echo -ne "${C_CYAN}選択 [0-9, q]: ${C_RESET}"

        read -r choice

        case "$choice" in
            1) tcp_client_mode ;;
            2) tcp_server_mode ;;
            3) udp_client_mode ;;
            4) http_client_mode ;;
            5) port_scanner_mode ;;
            6) dns_lookup_mode ;;
            7) ping_test_mode ;;
            8) traceroute_mode ;;
            9) connection_test_mode ;;
            0) network_info_mode ;;
            q|Q)
                clear_screen
                echo -e "${C_CYAN}ネットワークプログラミングツールを終了します${C_RESET}"
                exit 0
                ;;
            *)
                log_error "無効な選択です"
                sleep 1
                ;;
        esac
    done
}

# ===== 引数解析 =====

parse_arguments() {
    local command=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_usage
                exit 0
                ;;
            -v|--version)
                echo "$PROG_NAME version $VERSION"
                exit 0
                ;;
            tcp-client)
                command="tcp-client"
                shift
                ;;
            tcp-server)
                command="tcp-server"
                shift
                ;;
            udp-client|udp)
                command="udp-client"
                shift
                ;;
            http)
                command="http"
                shift
                ;;
            scan|port-scan)
                command="scan"
                shift
                ;;
            dns)
                command="dns"
                shift
                ;;
            ping)
                command="ping"
                shift
                ;;
            traceroute|trace)
                command="traceroute"
                shift
                ;;
            info)
                command="info"
                shift
                ;;
            test|connect)
                command="test"
                shift
                ;;
            *)
                log_error "不明なコマンド: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    case "$command" in
        tcp-client) tcp_client_mode ;;
        tcp-server) tcp_server_mode ;;
        udp-client) udp_client_mode ;;
        http) http_client_mode ;;
        scan) port_scanner_mode ;;
        dns) dns_lookup_mode ;;
        ping) ping_test_mode ;;
        traceroute) traceroute_mode ;;
        info) network_info_mode ;;
        test) connection_test_mode ;;
        "") main_menu ;;
    esac
}

# ===== メイン処理 =====

main() {
    # ログディレクトリ作成
    mkdir -p "$LOG_DIR" 2>/dev/null || true

    parse_arguments "$@"
}

# スクリプト実行
main "$@"
