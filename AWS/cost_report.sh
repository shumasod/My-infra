#!/bin/bash
set -euo pipefail

#
# AWSコストレポートツール
# バージョン: 1.0
#
# AWS Cost Explorer を使用して月次コストレポートを生成するツール
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"
readonly DEFAULT_REGION="ap-northeast-1"

declare region="${AWS_REGION:-$DEFAULT_REGION}"
declare month=""
declare output_format="table"
declare output_file=""
declare top_n=10
declare granularity="MONTHLY"

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション]

AWS Cost Explorer コストレポートツール

オプション:
  -h, --help            このヘルプを表示
  -v, --version         バージョン情報を表示
  -r, --region REGION   AWSリージョン [デフォルト: ap-northeast-1]
  -m, --month YYYY-MM   対象月 [デフォルト: 今月]
  -f, --format FMT      出力形式 (table|json|csv) [デフォルト: table]
  -o, --output FILE     出力ファイル (省略時は標準出力)
  -n, --top NUM         サービス上位N件 [デフォルト: 10]
  --daily               日次集計で表示

前提条件:
  - AWS CLI がインストール済みであること
  - Cost Explorer へのアクセス権限があること
  - AWS_PROFILE または AWS 認証情報が設定済みであること

例:
  $PROG_NAME
  $PROG_NAME -m 2024-12
  $PROG_NAME -f csv -o cost_report.csv
  $PROG_NAME -n 5 --daily

EOF
}

check_aws_cli() {
    if ! command -v aws &>/dev/null; then
        error_exit "AWS CLIが必要です。インストールしてください: https://aws.amazon.com/cli/"
    fi

    if ! aws sts get-caller-identity &>/dev/null; then
        error_exit "AWS認証情報が設定されていません。aws configure を実行してください"
    fi
}

get_month_range() {
    local target_month="$1"
    local start end
    start="${target_month}-01"
    # 翌月1日を終了日として計算
    local year="${target_month%-*}"
    local mon="${target_month#*-}"
    local next_year=$year
    local next_mon
    next_mon=$(printf "%02d" $(( 10#$mon + 1 )))
    if (( 10#$mon == 12 )); then
        next_mon="01"
        next_year=$(( year + 1 ))
    fi
    end="${next_year}-${next_mon}-01"
    echo "$start $end"
}

fetch_cost_by_service() {
    local start="$1"
    local end="$2"

    aws ce get-cost-and-usage \
        --time-period "Start=${start},End=${end}" \
        --granularity "$granularity" \
        --metrics "BlendedCost" \
        --group-by "Type=DIMENSION,Key=SERVICE" \
        --region "$region" \
        --output json 2>/dev/null
}

format_table() {
    local data="$1"
    local month_label="$2"

    log_info "AWSコストレポート: $month_label"
    echo ""
    printf "  %-45s %12s\n" "サービス" "コスト (USD)"
    printf "  %s\n" "$(printf '%.0s-' {1..60})"

    echo "$data" | jq -r '
        .ResultsByTime[].Groups[] |
        [.Keys[0], .Metrics.BlendedCost.Amount] |
        @tsv
    ' 2>/dev/null | sort -t$'\t' -k2 -rn | head -"$top_n" | while IFS=$'\t' read -r svc amount; do
        local amount_fmt
        amount_fmt=$(printf "%.2f" "$amount")
        printf "  %-45s $%11s\n" "$svc" "$amount_fmt"
    done

    echo ""
    local total
    total=$(echo "$data" | jq -r '
        [.ResultsByTime[].Groups[].Metrics.BlendedCost.Amount | tonumber] | add
    ' 2>/dev/null || echo "0")
    printf "  %-45s $%11.2f\n" "合計 (全サービス)" "$total"
    printf "  %s\n" "$(printf '%.0s-' {1..60})"
    echo ""
}

format_csv() {
    local data="$1"
    echo "service,amount_usd"
    echo "$data" | jq -r '
        .ResultsByTime[].Groups[] |
        [.Keys[0], .Metrics.BlendedCost.Amount] |
        @csv
    ' 2>/dev/null | sort -t',' -k2 -rn | head -"$top_n"
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -r|--region)
                [[ $# -lt 2 ]] && error_exit "--region には値が必要です"
                region="$2"; shift 2 ;;
            -m|--month)
                [[ $# -lt 2 ]] && error_exit "--month には値が必要です"
                if ! [[ "$2" =~ ^[0-9]{4}-[0-9]{2}$ ]]; then
                    error_exit "月はYYYY-MM形式で指定してください"
                fi
                month="$2"; shift 2 ;;
            -f|--format)
                [[ $# -lt 2 ]] && error_exit "--format には値が必要です"
                output_format="$2"; shift 2 ;;
            -o|--output)
                [[ $# -lt 2 ]] && error_exit "--output には値が必要です"
                output_file="$2"; shift 2 ;;
            -n|--top)
                [[ $# -lt 2 ]] && error_exit "--top には数値が必要です"
                top_n="$2"; shift 2 ;;
            --daily) granularity="DAILY"; shift ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  error_exit "不明な引数: $1" ;;
        esac
    done
}

main() {
    parse_arguments "$@"
    check_aws_cli

    if [[ -z "$month" ]]; then
        month=$(date "+%Y-%m")
    fi

    local range
    range=$(get_month_range "$month")
    local start="${range%% *}"
    local end="${range##* }"

    log_info "データ取得中: ${start} 〜 ${end}"
    local data
    data=$(fetch_cost_by_service "$start" "$end")

    local result
    case "$output_format" in
        table) result=$(format_table "$data" "$month") ;;
        csv)   result=$(format_csv "$data") ;;
        json)  result=$(echo "$data" | jq . 2>/dev/null) ;;
        *)     error_exit "不明な形式: $output_format (table|json|csv)" ;;
    esac

    if [[ -n "$output_file" ]]; then
        echo "$result" > "$output_file"
        log_success "レポート保存: $output_file"
    else
        echo "$result"
    fi
}

main "$@"
