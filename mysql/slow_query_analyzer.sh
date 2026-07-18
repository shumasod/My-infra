#!/bin/bash
set -euo pipefail

#
# MySQLスロークエリログアナライザー
# バージョン: 1.0
#
# MySQLのスロークエリログを解析して問題のあるクエリを特定するツール
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"
readonly DEFAULT_LOG="/var/log/mysql/slow.log"

declare log_file="$DEFAULT_LOG"
declare -i top_n=10
declare -i min_time=1
declare output_format="table"
declare output_file=""
declare time_range=""

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション] [ログファイル]

MySQLスロークエリログ解析ツール

引数:
  ログファイル          解析するログファイル [デフォルト: $DEFAULT_LOG]

オプション:
  -h, --help            このヘルプを表示
  -v, --version         バージョン情報を表示
  -n, --top NUM         上位N件を表示 [デフォルト: 10]
  -t, --min-time SEC    最低実行時間フィルター (秒) [デフォルト: 1]
  -f, --format FMT      出力形式 (table|csv|detail) [デフォルト: table]
  -o, --output FILE     出力ファイル
  -r, --range RANGE     時間範囲フィルター (例: 2024-01-01,2024-01-31)

例:
  $PROG_NAME
  $PROG_NAME -n 20 -t 5 /var/log/mysql/slow.log
  $PROG_NAME -f csv -o report.csv
  $PROG_NAME --range 2024-01-01,2024-01-31

EOF
}

parse_slow_log() {
    local file="$1"
    local -i min_sec="$2"

    awk -v min_sec="$min_sec" '
    /^# Time:/ {
        time = $3 " " $4
    }
    /^# Query_time:/ {
        query_time = $3
        lock_time = $5
        rows_examined = $11
        rows_sent = $9
    }
    /^# User@Host:/ {
        user = $3
        host = $5
    }
    /^(SELECT|INSERT|UPDATE|DELETE|REPLACE|CREATE|DROP|ALTER|SHOW)/i {
        if (query_time + 0 >= min_sec) {
            # クエリの最初の100文字を取得
            query = substr($0, 1, 100)
            gsub(/'\''[^'\'']*'\''/, "?", query)
            gsub(/[0-9]+/, "N", query)
            printf "%s\t%s\t%s\t%s\t%s\n", query_time, lock_time, rows_examined, rows_sent, query
        }
    }
    ' "$file" 2>/dev/null
}

format_table() {
    local data="$1"

    log_info "スロークエリ上位${top_n}件 (最低${min_time}秒)"
    echo ""
    printf "  %-10s %-10s %-10s %-10s %s\n" \
        "実行時間" "ロック時間" "検査行数" "返行数" "クエリ (先頭80文字)"
    printf "  %s\n" "$(printf '%.0s-' {1..100})"

    echo "$data" | sort -t$'\t' -k1 -rn | head -"$top_n" | \
    while IFS=$'\t' read -r qtime ltime rows_ex rows_sent query; do
        local time_color="$C_GREEN"
        local qtime_f
        qtime_f=$(printf "%.2f" "$qtime")
        (( ${qtime%.*} >= 10 )) && time_color="$C_RED"
        (( ${qtime%.*} >= 3  && ${qtime%.*} < 10 )) && time_color="$C_YELLOW"

        printf "  %b%-10s%b %-10s %-10s %-10s %s\n" \
            "$time_color" "${qtime_f}s" "$C_RESET" \
            "${ltime}s" "$rows_ex" "$rows_sent" \
            "${query:0:80}"
    done
    echo ""
}

format_csv() {
    local data="$1"
    echo "query_time,lock_time,rows_examined,rows_sent,query"
    echo "$data" | sort -t$'\t' -k1 -rn | head -"$top_n" | \
    while IFS=$'\t' read -r qtime ltime rows_ex rows_sent query; do
        printf '"%s","%s","%s","%s","%s"\n' \
            "$qtime" "$ltime" "$rows_ex" "$rows_sent" "${query//\"/\"\"}"
    done
}

format_detail() {
    local data="$1"
    local rank=1

    echo "$data" | sort -t$'\t' -k1 -rn | head -"$top_n" | \
    while IFS=$'\t' read -r qtime ltime rows_ex rows_sent query; do
        log_info "[$rank] 実行時間: ${qtime}秒"
        echo "  ロック時間:   ${ltime}秒"
        echo "  検査行数:     ${rows_ex}行"
        echo "  返却行数:     ${rows_sent}行"
        echo "  クエリ:"
        echo "    ${query}"
        echo ""
        (( rank++ )) || true
    done
}

show_summary() {
    local file="$1"

    log_info "ログファイルサマリー: $file"
    echo ""

    local total_queries lock_over_1s
    total_queries=$(grep -c "^# Query_time" "$file" 2>/dev/null || echo 0)
    lock_over_1s=$(awk '/^# Query_time:/ { if ($3 >= 1) count++ } END { print count+0 }' "$file" 2>/dev/null || echo 0)

    printf "  総クエリ数:        %d\n" "$total_queries"
    printf "  1秒以上のクエリ:   %d\n" "$lock_over_1s"

    local max_time
    max_time=$(awk '/^# Query_time:/ { if ($3 > max) max=$3 } END { printf "%.2f", max }' "$file" 2>/dev/null || echo "0.00")
    printf "  最大実行時間:      %ss\n" "$max_time"
    echo ""
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -n|--top)
                [[ $# -lt 2 ]] && error_exit "--top には数値が必要です"
                top_n="$2"; shift 2 ;;
            -t|--min-time)
                [[ $# -lt 2 ]] && error_exit "--min-time には数値が必要です"
                min_time="$2"; shift 2 ;;
            -f|--format)
                [[ $# -lt 2 ]] && error_exit "--format には値が必要です"
                output_format="$2"; shift 2 ;;
            -o|--output)
                [[ $# -lt 2 ]] && error_exit "--output には値が必要です"
                output_file="$2"; shift 2 ;;
            -r|--range)
                [[ $# -lt 2 ]] && error_exit "--range には値が必要です"
                time_range="$2"; shift 2 ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  log_file="$1"; shift ;;
        esac
    done
}

main() {
    parse_arguments "$@"

    [[ ! -f "$log_file" ]] && error_exit "ログファイルが見つかりません: $log_file"

    show_summary "$log_file"

    local data
    data=$(parse_slow_log "$log_file" "$min_time")

    if [[ -z "$data" ]]; then
        log_info "${min_time}秒以上のスロークエリはありません"
        exit 0
    fi

    local result
    case "$output_format" in
        table)  result=$(format_table "$data") ;;
        csv)    result=$(format_csv "$data") ;;
        detail) result=$(format_detail "$data") ;;
        *)      error_exit "不明な形式: $output_format (table|csv|detail)" ;;
    esac

    if [[ -n "$output_file" ]]; then
        echo "$result" > "$output_file"
        log_success "結果を保存: $output_file"
    else
        echo "$result"
    fi
}

main "$@"
