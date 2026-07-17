#!/bin/bash
set -euo pipefail

#
# SSL証明書有効期限チェッカー
# バージョン: 1.0
#
# 指定したホストのSSL証明書の有効期限を確認するツール
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"
readonly DEFAULT_PORT=443
readonly DEFAULT_WARN_DAYS=30

declare -a HOSTS=()
declare warn_days=$DEFAULT_WARN_DAYS
declare timeout=5
declare verbose=false
declare output_csv=""

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション] ホスト名 [ホスト名...]

SSL証明書の有効期限を確認するツール

引数:
  ホスト名              確認するホスト (例: example.com または example.com:8443)

オプション:
  -h, --help            このヘルプを表示
  -v, --version         バージョン情報を表示
  -w, --warn DAYS       警告閾値 (日数) [デフォルト: 30]
  -t, --timeout SEC     接続タイムアウト秒 [デフォルト: 5]
  --verbose             詳細情報を表示
  --csv FILE            結果をCSV形式で保存

例:
  $PROG_NAME example.com
  $PROG_NAME google.com github.com example.com
  $PROG_NAME -w 60 example.com
  $PROG_NAME --csv result.csv example.com github.com

EOF
}

check_cert() {
    local host_port="$1"
    local host port
    if [[ "$host_port" == *:* ]]; then
        host="${host_port%%:*}"
        port="${host_port##*:}"
    else
        host="$host_port"
        port=$DEFAULT_PORT
    fi

    local cert_info expiry_date expiry_ts now_ts days_left subject issuer
    cert_info=$(echo | timeout "$timeout" openssl s_client \
        -connect "${host}:${port}" \
        -servername "$host" 2>/dev/null) || {
        echo -e "${C_RED}ERROR${C_RESET}  ${host}:${port}  接続失敗"
        [[ -n "$output_csv" ]] && echo "${host},${port},ERROR,,,," >> "$output_csv"
        return
    }

    expiry_date=$(echo "$cert_info" | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2) || {
        echo -e "${C_RED}ERROR${C_RESET}  ${host}:${port}  証明書解析失敗"
        return
    }

    expiry_ts=$(date -d "$expiry_date" +%s 2>/dev/null || date -j -f "%b %d %H:%M:%S %Y %Z" "$expiry_date" +%s 2>/dev/null)
    now_ts=$(date +%s)
    days_left=$(( (expiry_ts - now_ts) / 86400 ))

    local expiry_fmt
    expiry_fmt=$(date -d "$expiry_date" "+%Y-%m-%d" 2>/dev/null || echo "$expiry_date")

    local status_color status_label
    if [[ $days_left -lt 0 ]]; then
        status_color="$C_RED"
        status_label="EXPIRED"
    elif [[ $days_left -lt $warn_days ]]; then
        status_color="$C_YELLOW"
        status_label="WARNING"
    else
        status_color="$C_GREEN"
        status_label="OK     "
    fi

    printf "%b%s%b  %-35s  期限: %s  残り: %d日\n" \
        "$status_color" "$status_label" "$C_RESET" \
        "${host}:${port}" "$expiry_fmt" "$days_left"

    if [[ "$verbose" == true ]]; then
        subject=$(echo "$cert_info" | openssl x509 -noout -subject 2>/dev/null | sed 's/subject=/  Subject: /')
        issuer=$(echo "$cert_info" | openssl x509 -noout -issuer 2>/dev/null | sed 's/issuer=/  Issuer:  /')
        echo "$subject"
        echo "$issuer"
    fi

    if [[ -n "$output_csv" ]]; then
        echo "${host},${port},${status_label// /},${expiry_fmt},${days_left}" >> "$output_csv"
    fi
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -w|--warn)
                [[ $# -lt 2 ]] && error_exit "--warn には日数が必要です"
                if ! [[ "$2" =~ ^[0-9]+$ ]]; then
                    error_exit "日数は数値で指定してください"
                fi
                warn_days="$2"; shift 2 ;;
            -t|--timeout)
                [[ $# -lt 2 ]] && error_exit "--timeout には秒数が必要です"
                timeout="$2"; shift 2 ;;
            --verbose) verbose=true; shift ;;
            --csv)
                [[ $# -lt 2 ]] && error_exit "--csv にはファイル名が必要です"
                output_csv="$2"; shift 2 ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  HOSTS+=("$1"); shift ;;
        esac
    done
}

main() {
    parse_arguments "$@"

    if [[ ${#HOSTS[@]} -eq 0 ]]; then
        error_exit "ホスト名を指定してください。詳細は --help を参照"
    fi

    if ! command -v openssl &>/dev/null; then
        error_exit "opensslコマンドが必要です"
    fi

    if [[ -n "$output_csv" ]]; then
        echo "host,port,status,expiry_date,days_left" > "$output_csv"
    fi

    log_info "SSL証明書チェック (警告閾値: ${warn_days}日)"
    echo ""

    for host in "${HOSTS[@]}"; do
        check_cert "$host"
    done

    echo ""
    if [[ -n "$output_csv" ]]; then
        log_success "結果をCSVに保存: $output_csv"
    fi
}

main "$@"
