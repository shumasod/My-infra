#!/bin/bash

# ポートチェッカースクリプト (改善版)

# 指定されたポート番号に対応するサービス情報を表示します

# Usage: ./port_checker.sh [port_number] または ./port_checker.sh -i で対話モード

set -euo pipefail

# スクリプト設定

readonly SCRIPT_NAME=$(basename “$0”)
readonly MIN_PORT=0
readonly MAX_PORT=65535

# 色設定

readonly RED=’\033[0;31m’
readonly GREEN=’\033[0;32m’
readonly YELLOW=’\033[1;33m’
readonly BLUE=’\033[0;34m’
readonly CYAN=’\033[0;36m’
readonly NC=’\033[0m’ # No Color

# ログ関数

log_info() {
echo -e “${BLUE}[INFO]${NC} $1” >&2
}

log_success() {
echo -e “${GREEN}[SUCCESS]${NC} $1” >&2
}

log_warning() {
echo -e “${YELLOW}[WARNING]${NC} $1” >&2
}

log_error() {
echo -e “${RED}[ERROR]${NC} $1” >&2
}

# ヘルプ表示

show_help() {
cat << EOF
$SCRIPT_NAME - ポート番号からサービス情報を調べるツール

使用方法:
$SCRIPT_NAME [ポート番号]
$SCRIPT_NAME [ポート1] [ポート2] …  # 複数ポートを一度にチェック
$SCRIPT_NAME -i|–interactive         # 対話モード
$SCRIPT_NAME -r|–range START END     # 範囲チェック (例: -r 80 443)
$SCRIPT_NAME -h|–help                # このヘルプを表示
$SCRIPT_NAME -l|–list                # 全ポート一覧を表示

オプション:
-i, –interactive    対話モードで実行
-r, –range         ポート範囲を指定（範囲内の全ポートを表示）
-l, –list          サポートしているポート一覧を表示
-h, –help          このヘルプを表示

例:
$SCRIPT_NAME 80                 # HTTP (80番ポート) の情報を表示
$SCRIPT_NAME 80 443 3306        # 複数のポート情報を表示
$SCRIPT_NAME -r 80 100          # 80-100番のポート情報を表示
$SCRIPT_NAME -i                 # 対話モードで実行
EOF
}

# ポート番号の検証

validate_port() {
local port=”$1”

```
# 数値チェック
if ! [[ "$port" =~ ^[0-9]+$ ]]; then
    return 1
fi

# 範囲チェック
if [ "$port" -lt $MIN_PORT ] || [ "$port" -gt $MAX_PORT ]; then
    return 1
fi

return 0
```

}

# システムの/etc/servicesを参照してサービス情報を取得

get_service_from_system() {
local port=”$1”

```
if [ -f /etc/services ]; then
    local result
    result=$(grep -E "^\s*[a-zA-Z0-9_-]+\s+$port/(tcp|udp)" /etc/services 2>/dev/null | head -1 | awk '{print $1}' || true)
    if [ -n "$result" ]; then
        echo "$result"
        return 0
    fi
fi
return 1
```

}

# ポート情報を取得する関数（拡張版）

check_port() {
local port=”$1”

```
# 詳細なポート情報マップ
declare -A port_info=(
    # FTP
    [20]="FTP Data Transfer|TCP|ファイル転送（データ）"
    [21]="FTP Control|TCP|ファイル転送（制御）"
    
    # SSH/Telnet
    [22]="SSH|TCP|セキュアシェル"
    [23]="Telnet|TCP|リモートログイン（非暗号化）"
    
    # Mail
    [25]="SMTP|TCP|メール送信"
    [110]="POP3|TCP|メール受信"
    [143]="IMAP|TCP|メール受信（IMAP）"
    [465]="SMTPS|TCP|メール送信（SSL）"
    [587]="SMTP Submission|TCP|メール送信（暗号化）"
    [993]="IMAPS|TCP|メール受信（SSL）"
    [995]="POP3S|TCP|メール受信（SSL）"
    
    # DNS/DHCP
    [53]="DNS|TCP/UDP|ドメイン名解決"
    [67]="DHCP Server|UDP|DHCP サーバー"
    [68]="DHCP Client|UDP|DHCP クライアント"
    
    # その他のプロトコル
    [69]="TFTP|UDP|ファイル転送（シンプル版）"
    [80]="HTTP|TCP|ウェブサーバー"
    [119]="NNTP|TCP|ネットニュース"
    [123]="NTP|UDP|時刻同期"
    [135]="Microsoft RPC|TCP/UDP|リモートプロシージャーコール"
    [137]="NetBIOS Name Service|UDP|NetBIOS ネーム解決"
    [138]="NetBIOS Datagram|UDP|NetBIOS データグラム"
    [139]="NetBIOS Session|TCP|NetBIOS セッション"
    [161]="SNMP|UDP|ネットワーク管理"
    [162]="SNMP Trap|UDP|SNMP トラップ"
    [389]="LDAP|TCP|ディレクトリアクセス"
    [443]="HTTPS|TCP|セキュアウェブサーバー"
    [445]="SMB|TCP|ファイル共有（Windows）"
    [636]="LDAPS|TCP|ディレクトリアクセス（SSL）"
    [2049]="NFS|TCP/UDP|ネットワークファイルシステム"
    
    # Database
    [1433]="Microsoft SQL Server|TCP|データベースサーバー"
    [1521]="Oracle Database|TCP|データベースサーバー"
    [3306]="MySQL|TCP|データベースサーバー"
    [5432]="PostgreSQL|TCP|データベースサーバー"
    [6379]="Redis|TCP|インメモリデータベース"
    [27017]="MongoDB|TCP|NoSQL データベース"
    
    # Remote Access
    [3389]="RDP|TCP|リモートデスクトップ"
    [5900]="VNC|TCP|リモートデスクトップ"
    
    # Other Services
    [5672]="AMQP|TCP|メッセージキューイング"
    [8080]="HTTP Alternative|TCP|ウェブプロキシ"
    [8443]="HTTPS Alternative|TCP|セキュアウェブ（代替）"
    [9200]="Elasticsearch|TCP|検索エンジン"
)

# マップから情報を取得
if [ -v port_info[$port] ]; then
    echo "${port_info[$port]}"
else
    # システムファイルから取得を試みる
    local sys_service
    if sys_service=$(get_service_from_system "$port"); then
        echo "$sys_service|Unknown|（システムから取得）"
    else
        # ポート範囲の分類
        if [ "$port" -ge 0 ] && [ "$port" -le 1023 ]; then
            echo "Unknown|TCP/UDP|Well-known ports（システム/特権ポート）"
        elif [ "$port" -ge 1024 ] && [ "$port" -le 49151 ]; then
            echo "Unknown|TCP/UDP|Registered ports（登録済みポート）"
        else
            echo "Unknown|TCP/UDP|Dynamic/Private ports（動的/プライベートポート）"
        fi
    fi
fi
```

}

# ポート情報をフォーマットして表示

display_port_info() {
local port=”$1”
local info

```
if ! validate_port "$port"; then
    log_error "無効なポート番号: $port (0-65535の範囲で入力してください)"
    return 1
fi

info=$(check_port "$port")

# パイプで区切られた情報を分割
IFS='|' read -r service protocol description <<< "$info"

echo -e "${CYAN}ポート ${port}${NC}"
echo "  サービス: $service"
echo "  プロトコル: $protocol"
echo "  説明: $description"

return 0
```

}

# サポートポート一覧表示

show_port_list() {
cat << EOF
${CYAN}=== Well-known Ports (0-1023) ===${NC}
20    FTP Data Transfer (TCP)
21    FTP Control (TCP)
22    SSH - Secure Shell (TCP)
23    Telnet (TCP)
25    SMTP - Simple Mail Transfer Protocol (TCP)
53    DNS - Domain Name System (TCP/UDP)
67    DHCP Server (UDP)
68    DHCP Client (UDP)
69    TFTP - Trivial File Transfer Protocol (UDP)
80    HTTP - Hypertext Transfer Protocol (TCP)
110   POP3 - Post Office Protocol (TCP)
119   NNTP - Network News Transfer Protocol (TCP)
123   NTP - Network Time Protocol (UDP)
135   Microsoft RPC - Remote Procedure Call (TCP/UDP)
137   NetBIOS Name Service (UDP)
138   NetBIOS Datagram Service (UDP)
139   NetBIOS Session Service (TCP)
143   IMAP - Internet Message Access Protocol (TCP)
161   SNMP - Simple Network Management Protocol (UDP)
162   SNMP Trap (UDP)
389   LDAP - Lightweight Directory Access Protocol (TCP)
443   HTTPS - Secure HTTP (TCP)
445   SMB - Server Message Block (TCP)
465   SMTPS - SMTP over SSL (TCP)
587   SMTP Submission (TCP)
636   LDAPS - LDAP over SSL (TCP)
993   IMAPS - IMAP over SSL (TCP)
995   POP3S - POP3 over SSL (TCP)

${CYAN}=== Registered Ports (1024-49151) ===${NC}
1433  Microsoft SQL Server (TCP)
1521  Oracle Database (TCP)
2049  NFS - Network File System (TCP/UDP)
3306  MySQL Database (TCP)
3389  RDP - Remote Desktop Protocol (TCP)
5432  PostgreSQL Database (TCP)
5672  AMQP - Advanced Message Queuing Protocol (TCP)
5900  VNC - Virtual Network Computing (TCP)
6379  Redis Database (TCP)
8080  HTTP Alternative / Web Proxy (TCP)
8443  HTTPS Alternative (TCP)
9200  Elasticsearch (TCP)
27017 MongoDB Database (TCP)
EOF
}

# 範囲指定でポートをチェック

check_port_range() {
local start=”$1”
local end=”$2”

```
if ! validate_port "$start" || ! validate_port "$end"; then
    log_error "無効なポート番号範囲です"
    return 1
fi

if [ "$start" -gt "$end" ]; then
    log_error "開始ポートは終了ポート以下である必要があります"
    return 1
fi

log_info "ポート範囲 $start-$end をチェック中..."
echo ""

for ((port=start; port<=end; port++)); do
    if display_port_info "$port" 2>/dev/null; then
        echo ""
    fi
done
```

}

# 対話モード

interactive_mode() {
log_info “対話モードを開始します (終了するには ‘q’ または ‘quit’ を入力)”

```
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
    echo ""
    display_port_info "$input" || log_error "ポート情報の取得に失敗しました"
done
```

}

# メイン処理

main() {
# 引数がない場合は対話モード
if [ $# -eq 0 ]; then
interactive_mode
return 0
fi

```
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
    -r|--range)
        if [ $# -lt 3 ]; then
            log_error "-r オプションには2つのポート番号が必要です"
            exit 1
        fi
        check_port_range "$2" "$3"
        exit 0
        ;;
    -*)
        log_error "未知のオプション: $1"
        echo "ヘルプを表示するには: $SCRIPT_NAME --help"
        exit 1
        ;;
    *)
        # 複数のポート番号に対応
        local first_port=true
        for port in "$@"; do
            if [ "$first_port" = false ]; then
                echo ""
            fi
            display_port_info "$port" || exit 1
            first_port=false
        done
        ;;
esac
```

}

# メイン関数を実行

main “$@”