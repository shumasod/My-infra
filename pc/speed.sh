#!/bin/bash

# デフォルトのネットワークインターフェイス
DEFAULT_INTERFACE="eth0"

# 使用方法を表示する関数
show_usage() {
    echo "使用方法: $0 [-i interface] [-t interval]"
    echo "  -i: モニターするネットワークインターフェイス（デフォルト: $DEFAULT_INTERFACE）"
    echo "  -t: 更新間隔（秒）（デフォルト: 1）"
    exit 1
}

# コマンドライン引数の解析
INTERFACE=$DEFAULT_INTERFACE
INTERVAL=1

while getopts "i:t:" opt; do
    case $opt in
        i) INTERFACE=$OPTARG ;;
        t) INTERVAL=$OPTARG ;;
        *) show_usage ;;
    esac
done

# インターフェイスの存在確認
if ! ip link show $INTERFACE > /dev/null 2>&1; then
    echo "エラー: インターフェイス $INTERFACE が見つかりません。"
    exit 1
fi

# 初期値の取得
PREV_RX=$(cat /sys/class/net/$INTERFACE/statistics/rx_bytes)
PREV_TX=$(cat /sys/class/net/$INTERFACE/statistics/tx_bytes)
PREV_TIME=$(date +%s)

# ヘッダーの表示
echo "インターフェイス: $INTERFACE"
echo "時刻               受信速度         送信速度         合計"
echo "---------------------------------------------------------"

# メイン処理ループ
while true; do
    sleep $INTERVAL

    # 現在の値を取得
    CURR_RX=$(cat /sys/class/net/$INTERFACE/statistics/rx_bytes)
    CURR_TX=$(cat /sys/class/net/$INTERFACE/statistics/tx_bytes)
    CURR_TIME=$(date +%s)

    # 差分を計算
    TIME_DIFF=$((CURR_TIME - PREV_TIME))
    RX_DIFF=$((CURR_RX - PREV_RX))
    TX_DIFF=$((CURR_TX - PREV_TX))

    # 速度を計算 (bytes/sec)
    RX_SPEED=$((RX_DIFF / TIME_DIFF))
    TX_SPEED=$((TX_DIFF / TIME_DIFF))
    TOTAL_SPEED=$((RX_SPEED + TX_SPEED))

    # 単位を変換
    RX_FORMATTED=$(numfmt --to=iec-i --suffix=B/s --padding=7 $RX_SPEED)
    TX_FORMATTED=$(numfmt --to=iec-i --suffix=B/s --padding=7 $TX_SPEED)
    TOTAL_FORMATTED=$(numfmt --to=iec-i --suffix=B/s --padding=7 $TOTAL_SPEED)

    # 結果を表示
    printf "%s   %s   %s   %s\n" "$(date +"%Y-%m-%d %H:%M:%S")" "$RX_FORMATTED" "$TX_FORMATTED" "$TOTAL_FORMATTED"

    # 現在の値を前の値として保存
    PREV_RX=$CURR_RX
    PREV_TX=$CURR_TX
    PREV_TIME=$CURR_TIME
done
