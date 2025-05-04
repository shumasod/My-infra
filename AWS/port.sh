#!/bin/bash

check_port() {
    local port=$1
    case $port in
        21)
            echo "FTP (File Transfer Protocol) - TCP"
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
        80)
            echo "HTTP (Hypertext Transfer Protocol) - TCP"
            ;;
        110)
            echo "POP3 (Post Office Protocol V3) - TCP"
            ;;
        123)
            echo "NTP (Network Time Protocol) - UDP"
            ;;
        139)
            echo "NetBIOS - TCP"
            ;;
        143)
            echo "IMAP (Internet Message Access Protocol) - TCP"
            ;;
        443)
            echo "HTTPS (Secure HTTP) - TCP"
            ;;
        445)
            echo "SMB (Server Message Block) - TCP"
            ;;
        1521)
            echo "Oracle DB - TCP"
            ;;
        3306)
            echo "MySQL - TCP"
            ;;
        3389)
            echo "RDP (Remote Desktop Protocol) - TCP"
            ;;
        5432)
            echo "PostgreSQL - TCP"
            ;;
        *)
            echo "Unknown port number"
            ;;
    esac
}

# メインの処理
echo "ポート番号を入力してください:"
read port_number

if [[ ! $port_number =~ ^[0-9]+$ ]]; then
    echo "エラー: 数字を入力してください"
    exit 1
fi

result=$(check_port $port_number)
echo "結果: $result"