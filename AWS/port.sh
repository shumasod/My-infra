#!/bin/bash

# ポートチェッカースクリプト
# 指定されたポート番号に対応するサービス情報を表示します
# Usage: ./port_checker.sh [port_number] または ./port_checker.sh -i で対話モード

set -euo pipefail

# スクリプト設定
readonly SCRIPT_NAME=$(basename "$0")
readonly MIN_PORT=0
readonly MAX_PORT=65535

# 色設定
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# ログ関数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# ヘルプ表示
show_help() {
    cat << EOF
$SCRIPT_NAME - ポート番号からサービス情報を調べるツール

使用方法:
    $SCRIPT_NAME [ポート番号]
    $SCRIPT_NAME -i|--interactive    # 対話モード
    $SCRIPT_NAME -h|--help          # このヘルプを表示
    $SCRIPT_NAME -l|--list          # 全ポート一覧を表示

引数:
    ポート番号    調べたいポート番号 (0-65535)

オプション:
    -i, --interactive    対話モードで実行
    -l, --list          サポートしているポート一覧を表示
    -h, --help          このヘルプを表示

例:
    $SCRIPT_NAME 80                 # HTTP (80番ポート) の情報を表示
    $SCRIPT_NAME -i                 # 対話モードで実行
    $SCRIPT_NAME --list             # サポートポート一覧を表示
EOF
}

# ポート番号の検証
validate_port() {
    local port="$1"
    
    # 数値チェック
    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
        log_error "ポート番号は数字で入力してください: $port"
        return 1
    fi
    
    # 範囲チェック
    if [ "$port" -lt $MIN_PORT ] || [ "$port" -gt $MAX_PORT ]; then
        log_error "ポート番号は ${MIN_PORT} から ${MAX_PORT} の範囲で入力してください: $port"
        return 1
    fi
    
    return 0
}

# ポート情報を取得する関数
check_port() {
    local port="$1"
    
    case "$port" in
        20)
            echo "FTP Data Transfer (File Transfer Protocol) - TCP"
            ;;
        21)
            echo "FTP Control (File Transfer Protocol) - TCP"
            ;;
        22)
            echo "SSH (Secure Shell) - TCP"
            ;;
        23)
            echo "Telnet (Remote login) - TCP"
            ;;
        25)
            echo "SMTP (Simple Mail Transfer Protocol) - TCP"
            ;;
        53)
            echo "DNS (Domain Name System) - TCP/UDP"
            ;;
        67)
            echo "DHCP Server (Dynamic Host Configuration Protocol) - UDP"
            ;;
        68)
            echo "DHCP Client (Dynamic Host Configuration Protocol) - UDP"
            ;;
        69)
            echo "TFTP (Trivial File Transfer Protocol) - UDP"
            ;;
        80)
            echo "HTTP (Hypertext Transfer Protocol) - TCP"
            ;;
        110)
            echo "POP3 (Post Office Protocol V3) - TCP"
            ;;
        119)
            echo "NNTP (Network News Transfer Protocol) - TCP"
            ;;
        123)
            echo "NTP (Network Time Protocol) - UDP"
            ;;
        135)
            echo "Microsoft RPC (Remote Procedure Call) - TCP/UDP"
            ;;
        137)
            echo "NetBIOS Name Service - UDP"
            ;;
        138)
            echo "NetBIOS Datagram Service - UDP"
            ;;
        139)
            echo "NetBIOS Session Service - TCP"
            ;;
        143)
            echo "IMAP (Internet Message Access Protocol) - TCP"
            ;;
        161)
            echo "SNMP (Simple Network Management Protocol) - UDP"
            ;;
        162)
            echo "SNMP Trap - UDP"
            ;;
        389)
            echo "LDAP (Lightweight Directory Access Protocol) - TCP"
            ;;
        443)
            echo "HTTPS (Secure HTTP) - TCP"
            ;;
        445)
            echo "SMB (Server Message Block) - TCP"
            ;;
        465)
            echo "SMTPS (SMTP over SSL) - TCP"
            ;;
        587)
            echo "SMTP Submission - TCP"
            ;;
        636)
            echo "LDAPS (LDAP over SSL) - TCP"
            ;;
        993)
            echo "IMAPS (IMAP over SSL) - TCP"
            ;;
        995)
            echo "POP3S (POP3 over SSL) - TCP"
            ;;
        1433)
            echo "Microsoft SQL Server - TCP"
            ;;
        1521)
            echo "Oracle Database - TCP"
            ;;
        2049)
            echo "NFS (Network File System) - TCP/UDP"
            ;;
        3306)
            echo "MySQL Database - TCP"
            ;;
        3389)
            echo "RDP (Remote Desktop Protocol) - TCP"
            ;;
        5432)
            echo "PostgreSQL Database - TCP"
            ;;
        5672)
            echo "AMQP (Advanced Message Queuing Protocol) - TCP"
            ;;
        5900)
            echo "VNC (Virtual Network Computing) - TCP"
            ;;
        6379)
            echo "Redis Database - TCP"
            ;;
        8080)
            echo "HTTP Alternative (Web Proxy) - TCP"
            ;;
        8443)
            echo "HTTPS Alternative - TCP"
            ;;
        9200)
            echo "Elasticsearch - TCP"
            ;;
        27017)
            echo "MongoDB Database - TCP"
            ;;
        *)
            echo "Unknown port number (ポート番号: $port)"
            # よく知られたポート範囲の情報を提供
            if [ "$port" -ge 0 ] && [ "$port" -le 1023 ]; then
                echo "  → Well-known ports (システム/特権ポート)"
            elif [ "$port" -ge 1024 ] && [ "$port" -le 49151 ]; then
                echo "  → Registered ports (登録済みポート)"
            elif [ "$port" -ge 49152 ] && [ "$port" -le 65535 ]; then
                echo "  → Dynamic/Private ports (動的/プライベートポート)"
            fi
            ;;
    esac
}

# サポートポート一覧表示
show_port_list() {
    cat << EOF
サポートしているポート一覧:

=== Well-known Ports (0-1023) ===
20    FTP Data Transfer
21    FTP Control
22    SSH (Secure Shell)
23    Telnet
25    SMTP
53    DNS
67    DHCP Server
68    DHCP Client
69    TFTP
80    HTTP
110   POP3
119   NNTP
123   NTP
135   Microsoft RPC
137   NetBIOS Name Service
138   NetBIOS Datagram Service
139   NetBIOS Session Service
143   IMAP
161   SNMP
162   SNMP Trap
389   LDAP
443   HTTPS
445   SMB
465   SMTPS
587   SMTP Submission
636   LDAPS
993   IMAPS
995   POP3S

=== Registered Ports (1024-49151) ===
1433  Microsoft SQL Server
1521  Oracle Database
2049  NFS
3306  MySQL
3389  RDP
5432  PostgreSQL
5672  AMQP
5900  VNC
6379  Redis
8080  HTTP Alternative
8443  HTTPS Alternative
9200  Elasticsearch
27017 MongoDB
EOF
}

# 対話モード
interactive_mode() {
    log_info "対話モードを開始します (終了するには 'q' または 'quit' を入力)"
    
    while true; do
        echo ""
        echo -n "ポート番号を入力してください (終了: q): "
        
        local input
        if ! read -r input; then
            echo ""
            log_info "入力が中断されました。終了します。"
            break
        fi
        
        # 終了チェック
        case "$input" in
            q|quit|exit)
                log_info "対話モードを終了します。"
                break
                ;;
            "")
                log_warning "ポート番号を入力してください。"
                continue
                ;;
        esac
        
        # ポート番号の検証と処理
        if validate_port "$input"; then
            local result
            result=$(check_port "$input")
            log_success "結果: $result"
        fi
    done
}

# メイン処理
main() {
    # 引数がない場合は対話モード
    if [ $# -eq 0 ]; then
        interactive_mode
        return 0
    fi
    
    # 引数解析
    case "${1:-}" in
        -h|--help)
            show_help
            exit 0
            ;;
        -l|--list)
            show_port_list
            exit 0
            ;;
        -i|--interactive)
            interactive_mode
            exit 0
            ;;
        -*)
            log_error "未知のオプション: $1"
            echo "ヘルプを表示するには: $SCRIPT_NAME --help"
            exit 1
            ;;
        *)
            # ポート番号として処理
            local port_number="$1"
            
            if validate_port "$port_number"; then
                local result
                result=$(check_port "$port_number")
                echo "ポート $port_number: $result"
            else
                exit 1
            fi
            ;;
    esac
}

# メイン関数を実行
main "$@"
