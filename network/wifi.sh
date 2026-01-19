#!/bin/bash

# Wi-Fi通信量計測スクリプト

# 設定
INTERFACE="wlan0"  # Wi-Fiのインターフェース名（環境によって変更が必要）
INTERVAL=60        # 計測間隔（秒）
LOG_FILE="$HOME/wifi_data_usage.log"
DAILY_REPORT="$HOME/wifi_data_daily.log"

# ヘルプメッセージ
function show_help {
    echo "使用法: $0 [オプション]"
    echo "オプション:"
    echo "  -i INTERFACE  計測するネットワークインターフェース（デフォルト: $INTERFACE）"
    echo "  -t INTERVAL   計測間隔（秒）（デフォルト: $INTERVAL）"
    echo "  -l FILE       ログファイルのパス（デフォルト: $LOG_FILE）"
    echo "  -h            ヘルプを表示"
    exit 0
}

# オプション解析
while getopts "i:t:l:h" opt; do
    case $opt in
        i) INTERFACE=$OPTARG ;;
        t) INTERVAL=$OPTARG ;;
        l) LOG_FILE=$OPTARG ;;
        h) show_help ;;
        *) show_help ;;
    esac
done

# インターフェースが存在するか確認
if ! ip link show $INTERFACE &>/dev/null; then
    echo "エラー: インターフェース '$INTERFACE' が見つかりません"
    echo "利用可能なインターフェース:"
    ip -br link show
    exit 1
fi

# Wi-Fi接続状態を確認
function check_wifi_status {
    local state=$(cat /sys/class/net/$INTERFACE/operstate 2>/dev/null)
    if [ "$state" != "up" ]; then
        echo "警告: Wi-Fi接続が確立されていません。状態: $state"
        return 1
    fi
    return 0
}

# バイト単位を読みやすい形式に変換
function format_size {
    local bytes=$1
    if [ $bytes -lt 1024 ]; then
        echo "${bytes}B"
    elif [ $bytes -lt 1048576 ]; then
        echo "$(echo "scale=2; $bytes/1024" | bc)KB"
    elif [ $bytes -lt 1073741824 ]; then
        echo "$(echo "scale=2; $bytes/1048576" | bc)MB"
    else
        echo "$(echo "scale=2; $bytes/1073741824" | bc)GB"
    fi
}

# SSID取得（可能な場合）
function get_ssid {
    if command -v iwgetid >/dev/null 2>&1; then
        iwgetid -r 2>/dev/null || echo "不明なSSID"
    else
        echo "不明なSSID"
    fi
}

# 初期値を取得
RX_PREV=$(cat /sys/class/net/$INTERFACE/statistics/rx_bytes 2>/dev/null || echo 0)
TX_PREV=$(cat /sys/class/net/$INTERFACE/statistics/tx_bytes 2>/dev/null || echo 0)

# 日付
CURRENT_DATE=$(date +"%Y-%m-%d")
DAILY_RX=0
DAILY_TX=0

# ログファイルのヘッダー
echo "日時,SSID,受信,送信,合計" > "$LOG_FILE"

echo "Wi-Fi通信量計測を開始します（インターフェース: $INTERFACE, 間隔: ${INTERVAL}秒）"
echo "ログファイル: $LOG_FILE"
echo "Ctrl+Cで終了します"

# メインループ
while true; do
    # 現在の日付
    NEW_DATE=$(date +"%Y-%m-%d")
    
    # 日付が変わったら日次集計をリセット
    if [ "$NEW_DATE" != "$CURRENT_DATE" ]; then
        echo "$CURRENT_DATE: 受信 $(format_size $DAILY_RX), 送信 $(format_size $DAILY_TX), 合計 $(format_size $((DAILY_RX + DAILY_TX)))" >> "$DAILY_REPORT"
        CURRENT_DATE=$NEW_DATE
        DAILY_RX=0
        DAILY_TX=0
    fi

    # Wi-Fi状態チェック
    if check_wifi_status; then
        SSID=$(get_ssid)
