#!/bin/bash

# 携帯通信量計測スクリプト

# 設定
INTERFACE="wwan0"  # 携帯通信のインターフェース名（環境によって変更が必要）
INTERVAL=60        # 計測間隔（秒）
LOG_FILE="$HOME/mobile_data_usage.log"
DAILY_REPORT="$HOME/mobile_data_daily.log"

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

# 初期値を取得
RX_PREV=$(cat /sys/class/net/$INTERFACE/statistics/rx_bytes 2>/dev/null || echo 0)
TX_PREV=$(cat /sys/class/net/$INTERFACE/statistics/tx_bytes 2>/dev/null || echo 0)

# 日付
CURRENT_DATE=$(date +"%Y-%m-%d")
DAILY_RX=0
DAILY_TX=0

# ログファイルのヘッダー
echo "日時,受信,送信,合計" > "$LOG_FILE"

echo "携帯通信量計測を開始します（インターフェース: $INTERFACE, 間隔: ${INTERVAL}秒）"
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

    # 現在の値を取得
    RX_NOW=$(cat /sys/class/net/$INTERFACE/statistics/rx_bytes 2>/dev/null || echo 0)
    TX_NOW=$(cat /sys/class/net/$INTERFACE/statistics/tx_bytes 2>/dev/null || echo 0)
    
    # 差分を計算
    RX_DIFF=$((RX_NOW - RX_PREV))
    TX_DIFF=$((TX_NOW - TX_PREV))
    
    # 日次集計に加算
    DAILY_RX=$((DAILY_RX + RX_DIFF))
    DAILY_TX=$((DAILY_TX + TX_DIFF))
    
    # 時刻
    TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
    
    # 結果を表示
    echo "[$TIMESTAMP] 受信: $(format_size $RX_DIFF), 送信: $(format_size $TX_DIFF), 合計: $(format_size $((RX_DIFF + TX_DIFF)))"
    echo "$TIMESTAMP,$(format_size $RX_DIFF),$(format_size $TX_DIFF),$(format_size $((RX_DIFF + TX_DIFF)))" >> "$LOG_FILE"
    
    # 値を更新
    RX_PREV=$RX_NOW
    TX_PREV=$TX_NOW
    
    # 一定時間待機
    sleep $INTERVAL
done
