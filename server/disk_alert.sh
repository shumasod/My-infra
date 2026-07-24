#!/bin/bash
set -euo pipefail

#
# ディスク使用量アラートツール
# バージョン: 1.0
#
# ディスク使用量を監視して閾値超過時にアラートを送信するツール
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare -i warn_threshold=80
declare -i crit_threshold=90
declare -a mount_points=()
declare alert_cmd=""
declare webhook_url="${SLACK_WEBHOOK_URL:-}"
declare output_format="table"
declare -i top_dirs=10
declare watch_mode=false
declare -i watch_interval=60

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション] [マウントポイント...]

ディスク使用量監視・アラートツール

引数:
  マウントポイント      監視対象 (省略時: 全ファイルシステム)

オプション:
  -h, --help            このヘルプを表示
  -v, --version         バージョン情報を表示
  -w, --warn PCT        警告閾値% [デフォルト: 80]
  -c, --crit PCT        重大閾値% [デフォルト: 90]
  -a, --alert CMD       アラート時に実行するコマンド
  -W, --webhook URL     Slack Webhook URL
  -f, --format FMT      出力形式 (table|csv) [デフォルト: table]
  -n, --top NUM         大きいディレクトリ上位N件 [デフォルト: 10]
  --watch               定期監視モード
  -i, --interval SEC    監視間隔秒 [デフォルト: 60]

例:
  $PROG_NAME
  $PROG_NAME -w 70 -c 85 /
  $PROG_NAME --watch -i 300
  SLACK_WEBHOOK_URL=https://... $PROG_NAME -c 85

EOF
}

send_slack_alert() {
    local mount="$1"
    local usage="$2"
    local level="$3"
    [[ -z "$webhook_url" ]] && return

    local emoji color
    if [[ "$level" == "CRITICAL" ]]; then
        emoji="🚨"; color="#ff0000"
    else
        emoji="⚠️"; color="#ff9900"
    fi

    local payload
    payload=$(cat <<JSON
{
    "attachments": [{
        "title": "${emoji} ディスク使用量${level}",
        "color": "${color}",
        "fields": [
            {"title": "マウントポイント", "value": "${mount}", "short": true},
            {"title": "使用率", "value": "${usage}%", "short": true},
            {"title": "ホスト", "value": "$(hostname)", "short": true},
            {"title": "時刻", "value": "$(date '+%Y-%m-%d %H:%M:%S')", "short": true}
        ]
    }]
}
JSON
)
    curl -s -X POST -H "Content-Type: application/json" \
        -d "$payload" "$webhook_url" &>/dev/null || true
}

check_disk() {
    local -i has_warn=0
    local -i has_crit=0

    log_info "ディスク使用量チェック (警告: ${warn_threshold}%, 重大: ${crit_threshold}%)"
    echo ""

    if [[ "$output_format" == "table" ]]; then
        printf "  %-25s %6s %8s %8s %6s %s\n" \
            "ファイルシステム" "使用%" "使用量" "空き" "合計" "状態"
        printf "  %s\n" "$(printf '%.0s-' {1..70})"
    fi

    local df_targets=("${mount_points[@]:-}")
    if [[ ${#mount_points[@]} -eq 0 ]]; then
        mapfile -t df_targets < <(df -h --output=target 2>/dev/null | tail -n +2)
    fi

    for mp in "${df_targets[@]}"; do
        [[ "$mp" == /proc/* || "$mp" == /sys/* || "$mp" == /dev/* ]] && continue

        local df_line
        df_line=$(df -h "$mp" 2>/dev/null | tail -1) || continue

        local fs use_pct used avail total
        fs=$(echo "$df_line" | awk '{print $1}')
        use_pct=$(echo "$df_line" | awk '{gsub(/%/,""); print $5}')
        used=$(echo "$df_line" | awk '{print $3}')
        avail=$(echo "$df_line" | awk '{print $4}')
        total=$(echo "$df_line" | awk '{print $2}')

        local status_color status_label
        if   (( use_pct >= crit_threshold )); then
            status_color="$C_RED";    status_label="CRITICAL"
            has_crit=1
            send_slack_alert "$mp" "$use_pct" "CRITICAL"
            [[ -n "$alert_cmd" ]] && eval "$alert_cmd" &>/dev/null || true
        elif (( use_pct >= warn_threshold )); then
            status_color="$C_YELLOW"; status_label="WARNING "
            has_warn=1
            send_slack_alert "$mp" "$use_pct" "WARNING"
        else
            status_color="$C_GREEN";  status_label="OK      "
        fi

        local bar_width=20
        local bar_fill=$(( use_pct * bar_width / 100 ))
        local bar
        bar=$(printf "%${bar_fill}s" | tr ' ' '█')
        local bar_empty
        bar_empty=$(printf "%$(( bar_width - bar_fill ))s" | tr ' ' '░')

        if [[ "$output_format" == "table" ]]; then
            printf "  %-25s %b%5s%%%b %8s %8s %6s %b%-8s%b [%s%s]\n" \
                "${mp:0:23}" "$status_color" "$use_pct" "$C_RESET" \
                "$used" "$avail" "$total" \
                "$status_color" "$status_label" "$C_RESET" \
                "$bar" "$bar_empty"
        else
            printf "%s,%s,%s,%s,%s,%s\n" \
                "$mp" "$use_pct" "$used" "$avail" "$total" "$status_label"
        fi
    done

    echo ""
    if   (( has_crit )); then log_error  "重大な使用量を検出しました"
    elif (( has_warn  )); then log_warning "警告レベルの使用量を検出しました"
    else                       log_success "すべて正常です"
    fi

    return $(( has_crit > 0 ? 2 : has_warn > 0 ? 1 : 0 ))
}

show_top_dirs() {
    local target="${mount_points[0]:-/}"
    log_info "大きいディレクトリ Top${top_dirs}: $target"
    echo ""
    du -sh "${target}"/* 2>/dev/null | sort -rh | head -"$top_dirs" | \
    while read -r size dir; do
        printf "  %-10s %s\n" "$size" "$dir"
    done
    echo ""
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -w|--warn)    [[ $# -lt 2 ]] && error_exit "--warn には数値が必要です"; warn_threshold="$2"; shift 2 ;;
            -c|--crit)    [[ $# -lt 2 ]] && error_exit "--crit には数値が必要です"; crit_threshold="$2"; shift 2 ;;
            -a|--alert)   [[ $# -lt 2 ]] && error_exit "--alert には値が必要です"; alert_cmd="$2"; shift 2 ;;
            -W|--webhook) [[ $# -lt 2 ]] && error_exit "--webhook には値が必要です"; webhook_url="$2"; shift 2 ;;
            -f|--format)  [[ $# -lt 2 ]] && error_exit "--format には値が必要です"; output_format="$2"; shift 2 ;;
            -n|--top)     [[ $# -lt 2 ]] && error_exit "--top には数値が必要です"; top_dirs="$2"; shift 2 ;;
            --watch)      watch_mode=true; shift ;;
            -i|--interval) [[ $# -lt 2 ]] && error_exit "--interval には数値が必要です"; watch_interval="$2"; shift 2 ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  mount_points+=("$1"); shift ;;
        esac
    done
}

main() {
    parse_arguments "$@"

    if [[ "$watch_mode" == true ]]; then
        log_info "監視モード開始 (間隔: ${watch_interval}秒, Ctrl+C で終了)"
        while true; do
            check_disk || true
            sleep "$watch_interval"
        done
    else
        check_disk || exit $?
    fi
}

main "$@"
