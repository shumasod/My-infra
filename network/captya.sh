#!/bin/bash

# NetShark - Wireshark風のパケットキャプチャツール
# 使用例: sudo ./netshark.sh

set -e

# 色の定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# グローバル変数
CAPTURE_FILE="/tmp/netshark_$(date +%s).pcap"
INTERFACE=""
FILTER=""
PACKET_COUNT=0
CAPTURE_PID=""

# ヘルプメッセージ
show_help() {
    cat << EOF
${CYAN}NetShark - Wireshark風パケットキャプチャツール${NC}

使用方法:
    sudo $0 [オプション]

オプション:
    -i <interface>    キャプチャするネットワークインターフェース
    -f <filter>       BPFフィルタ (例: "port 80", "host 192.168.1.1")
    -c <count>        キャプチャするパケット数 (デフォルト: 無制限)
    -w <file>         出力ファイル名
    -h                このヘルプメッセージを表示

例:
    sudo $0 -i eth0
    sudo $0 -i wlan0 -f "port 443"
    sudo $0 -i eth0 -f "host 8.8.8.8" -c 100

EOF
}

# root権限チェック
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}エラー: このスクリプトはroot権限で実行する必要があります${NC}"
        echo "sudo $0 を使用してください"
        exit 1
    fi
}

# 依存関係チェック
check_dependencies() {
    local missing_deps=()
    
    for cmd in tcpdump tshark; do
        if ! command -v $cmd &> /dev/null; then
            missing_deps+=($cmd)
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${RED}エラー: 以下のコマンドが見つかりません: ${missing_deps[*]}${NC}"
        echo "インストール方法:"
        echo "  Ubuntu/Debian: sudo apt-get install tcpdump wireshark-common"
        echo "  CentOS/RHEL:   sudo yum install tcpdump wireshark"
        exit 1
    fi
}

# ネットワークインターフェース一覧表示
show_interfaces() {
    echo -e "${CYAN}利用可能なネットワークインターフェース:${NC}"
    echo ""
    
    local i=1
    while IFS= read -r line; do
        if [[ $line =~ ^[0-9]+\. ]]; then
            echo -e "${GREEN}$line${NC}"
        fi
        ((i++))
    done < <(ip link show 2>/dev/null | grep -E "^[0-9]+:" | sed 's/://g')
    
    echo ""
}

# インターフェース選択
select_interface() {
    show_interfaces
    
    read -p "キャプチャするインターフェース名を入力してください: " INTERFACE
    
    if ! ip link show "$INTERFACE" &> /dev/null; then
        echo -e "${RED}エラー: インターフェース '$INTERFACE' が見つかりません${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}インターフェース '$INTERFACE' を選択しました${NC}"
}

# フィルタ設定
set_filter() {
    echo ""
    echo -e "${CYAN}パケットフィルタを設定しますか？ (y/n)${NC}"
    echo "例: port 80, host 192.168.1.1, tcp, udp"
    read -p "> " use_filter
    
    if [[ $use_filter =~ ^[Yy]$ ]]; then
        read -p "BPFフィルタを入力: " FILTER
        echo -e "${GREEN}フィルタ設定: $FILTER${NC}"
    fi
}

# パケットキャプチャ開始
start_capture() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  パケットキャプチャを開始します${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo -e "インターフェース: ${GREEN}$INTERFACE${NC}"
    echo -e "出力ファイル: ${GREEN}$CAPTURE_FILE${NC}"
    [ -n "$FILTER" ] && echo -e "フィルタ: ${GREEN}$FILTER${NC}"
    [ $PACKET_COUNT -gt 0 ] && echo -e "パケット数: ${GREEN}$PACKET_COUNT${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo -e "${YELLOW}Ctrl+C でキャプチャを停止します${NC}"
    echo ""
    
    # tcpdumpコマンドの構築
    local tcpdump_cmd="tcpdump -i $INTERFACE -w $CAPTURE_FILE"
    [ -n "$FILTER" ] && tcpdump_cmd="$tcpdump_cmd $FILTER"
    [ $PACKET_COUNT -gt 0 ] && tcpdump_cmd="$tcpdump_cmd -c $PACKET_COUNT"
    
    # バックグラウンドでキャプチャ開始
    $tcpdump_cmd &
    CAPTURE_PID=$!
    
    # リアルタイム表示用
    sleep 2
    show_live_capture
}

# リアルタイムパケット表示
show_live_capture() {
    local display_cmd="tcpdump -i $INTERFACE -n -l"
    [ -n "$FILTER" ] && display_cmd="$display_cmd $FILTER"
    [ $PACKET_COUNT -gt 0 ] && display_cmd="$display_cmd -c $PACKET_COUNT"
    
    $display_cmd 2>/dev/null | while IFS= read -r line; do
        # プロトコル別に色分け
        if [[ $line =~ "TCP" ]] || [[ $line =~ "tcp" ]]; then
            echo -e "${BLUE}$line${NC}"
        elif [[ $line =~ "UDP" ]] || [[ $line =~ "udp" ]]; then
            echo -e "${GREEN}$line${NC}"
        elif [[ $line =~ "ICMP" ]] || [[ $line =~ "icmp" ]]; then
            echo -e "${YELLOW}$line${NC}"
        elif [[ $line =~ "ARP" ]] || [[ $line =~ "arp" ]]; then
            echo -e "${MAGENTA}$line${NC}"
        else
            echo "$line"
        fi
    done
}

# キャプチャ終了処理
stop_capture() {
    echo ""
    echo -e "${YELLOW}キャプチャを停止しています...${NC}"
    
    if [ -n "$CAPTURE_PID" ]; then
        kill -INT $CAPTURE_PID 2>/dev/null || true
        wait $CAPTURE_PID 2>/dev/null || true
    fi
    
    echo ""
    analyze_capture
}

# キャプチャファイル解析
analyze_capture() {
    if [ ! -f "$CAPTURE_FILE" ]; then
        echo -e "${RED}キャプチャファイルが見つかりません${NC}"
        return
    fi
    
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  キャプチャ統計情報${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    
    # 基本統計
    echo -e "${GREEN}[基本情報]${NC}"
    capinfos "$CAPTURE_FILE" 2>/dev/null || echo "統計情報を取得できません"
    
    echo ""
    echo -e "${GREEN}[プロトコル分布]${NC}"
    tshark -r "$CAPTURE_FILE" -q -z io,phs 2>/dev/null || echo "プロトコル情報を取得できません"
    
    echo ""
    echo -e "${GREEN}[トップ10の送信元IP]${NC}"
    tshark -r "$CAPTURE_FILE" -T fields -e ip.src 2>/dev/null | sort | uniq -c | sort -rn | head -10
    
    echo ""
    echo -e "${GREEN}[トップ10の宛先IP]${NC}"
    tshark -r "$CAPTURE_FILE" -T fields -e ip.dst 2>/dev/null | sort | uniq -c | sort -rn | head -10
    
    echo ""
    echo -e "${GREEN}[トップ10のポート]${NC}"
    tshark -r "$CAPTURE_FILE" -T fields -e tcp.dstport -e udp.dstport 2>/dev/null | grep -v "^$" | sort | uniq -c | sort -rn | head -10
    
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "キャプチャファイル: ${GREEN}$CAPTURE_FILE${NC}"
    echo ""
    echo "詳細解析を行いますか？ (y/n)"
    read -p "> " detailed
    
    if [[ $detailed =~ ^[Yy]$ ]]; then
        detailed_analysis
    fi
    
    # ファイル保存の確認
    echo ""
    echo "キャプチャファイルを保存しますか？ (y/n)"
    read -p "> " save_file
    
    if [[ $save_file =~ ^[Yy]$ ]]; then
        read -p "保存先パスを入力 (デフォルト: ./netshark_capture.pcap): " save_path
        save_path=${save_path:-./netshark_capture.pcap}
        cp "$CAPTURE_FILE" "$save_path"
        echo -e "${GREEN}ファイルを保存しました: $save_path${NC}"
    else
        rm -f "$CAPTURE_FILE"
        echo -e "${YELLOW}キャプチャファイルを削除しました${NC}"
    fi
}

# 詳細解析
detailed_analysis() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  詳細解析${NC}"
    echo -e "${CYAN}========================================${NC}"
    
    # HTTPリクエスト
    echo ""
    echo -e "${GREEN}[HTTPリクエスト]${NC}"
    tshark -r "$CAPTURE_FILE" -Y "http.request" -T fields -e http.request.method -e http.host -e http.request.uri 2>/dev/null | head -20
    
    # DNS クエリ
    echo ""
    echo -e "${GREEN}[DNSクエリ]${NC}"
    tshark -r "$CAPTURE_FILE" -Y "dns.qry.name" -T fields -e dns.qry.name 2>/dev/null | sort | uniq | head -20
    
    # TLS/SSL
    echo ""
    echo -e "${GREEN}[TLS/SSL接続]${NC}"
    tshark -r "$CAPTURE_FILE" -Y "ssl.handshake.type == 1" -T fields -e ip.dst -e ssl.handshake.extensions_server_name 2>/dev/null | head -20
    
    echo ""
}

# シグナルハンドラ
trap stop_capture SIGINT SIGTERM

# メイン処理
main() {
    echo -e "${CYAN}"
    cat << "EOF"
    _   __     __  _____ __               __  
   / | / /__  / /_/ ___// /_  ____ ______/ /__
  /  |/ / _ \/ __/\__ \/ __ \/ __ `/ ___/ //_/
 / /|  /  __/ /_ ___/ / / / / /_/ / /  / ,<   
/_/ |_/\___/\__//____/_/ /_/\__,_/_/  /_/|_|  
                                               
EOF
    echo -e "${NC}"
    
    check_root
    check_dependencies
    
    # コマンドライン引数処理
    while getopts "i:f:c:w:h" opt; do
        case $opt in
            i) INTERFACE="$OPTARG" ;;
            f) FILTER="$OPTARG" ;;
            c) PACKET_COUNT="$OPTARG" ;;
            w) CAPTURE_FILE="$OPTARG" ;;
            h) show_help; exit 0 ;;
            *) show_help; exit 1 ;;
        esac
    done
    
    # インターフェース未指定の場合は選択
    if [ -z "$INTERFACE" ]; then
        select_interface
    fi
    
    # フィルタ未指定の場合は対話的に設定
    if [ -z "$FILTER" ]; then
        set_filter
    fi
    
    start_capture
}

main "$@"
