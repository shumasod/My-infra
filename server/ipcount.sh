#!/bin/bash

# 引数からIPアドレスとサブネットマスクを取得
if [ $# -ne 1 ]; then
    echo "Usage: $0 IP_ADDRESS/CIDR"
    echo "Example: $0 192.168.1.0/24"
    exit 1
fi

# IPアドレスとCIDRを分割
IP=$(echo $1 | cut -d'/' -f1)
CIDR=$(echo $1 | cut -d'/' -f2)

# IPアドレスを10進数に変換
IFS='.' read -r i1 i2 i3 i4 <<< "$IP"
ip_decimal=$(( (i1 << 24) + (i2 << 16) + (i3 << 8) + i4 ))

# サブネットマスクを計算
mask=$((0xffffffff << (32 - CIDR)))

# ネットワークアドレスを計算
network=$((ip_decimal & mask))

# ブロードキャストアドレスを計算
broadcast=$((network + (0xffffffff >> CIDR)))

# 10進数をIPアドレス形式に変換する関数
function decimal_to_ip() {
    local decimal=$1
    echo "$(((decimal >> 24) & 0xff)).$(((decimal >> 16) & 0xff)).$(((decimal >> 8) & 0xff)).$((decimal & 0xff))"
}

# 結果を表示
echo "入力されたIP: $IP/$CIDR"
echo "ネットワークアドレス: $(decimal_to_ip $network)"
echo "ブロードキャストアドレス: $(decimal_to_ip $broadcast)"
echo "使用可能なホスト数: $((broadcast - network - 1))"
echo "最初のホストIP: $(decimal_to_ip $((network + 1)))"
echo "最後のホストIP: $(decimal_to_ip $((broadcast - 1)))"
