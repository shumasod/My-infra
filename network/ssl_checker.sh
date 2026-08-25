#!/bin/bash
set -euo pipefail

#
# SSL証明書チェックツール
# 作成日: 2026-08-25
# バージョン: 1.0
#
# SSL/TLS証明書の有効期限・設定を検査します
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare command_name="check"
declare warn_days=30
declare critical_days=7
declare port=443
declare timeout=10
declare output_format="text"

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション] <ホスト...>

SSL/TLS証明書の検査ツールです。

コマンド:
  check <ホスト...>      証明書の有効期限を確認
  info <ホスト>          証明書の詳細情報を表示
  chain <ホスト>         証明書チェーンを表示
  scan <ファイル>        ホストリストファイルを一括チェック

オプション:
  -h, --help             このヘルプを表示
  -v, --version          バージョン情報を表示
  -p, --port <ポート>    接続ポート [デフォルト: 443]
  -w, --warn <日数>      警告閾値(日) [デフォルト: 30]
  -c, --critical <日数>  危険閾値(日) [デフォルト: 7]
  -t, --timeout <秒>     接続タイムアウト [デフォルト: 10]
  -f, --format <形式>    出力形式 (text|json) [デフォルト: text]

例:
  $PROG_NAME check example.com google.com
  $PROG_NAME info example.com -p 8443
  $PROG_NAME chain example.com
  $PROG_NAME scan hosts.txt --warn 60
EOF
}

get_cert_info() {
    local host="$1"
    local port="${2:-443}"
    openssl s_client -connect "${host}:${port}" \
        -servername "$host" \
        -timeout "$timeout" \
        </dev/null 2>/dev/null | \
    openssl x509 -noout "$3" 2>/dev/null
}

get_days_remaining() {
    local host="$1"
    local port="${2:-443}"
    local expiry_str
    expiry_str=$(get_cert_info "$host" "$port" "-enddate" | sed 's/notAfter=//')
    if [[ -z "$expiry_str" ]]; then
        echo "-1"
        return
    fi
    local expiry_epoch now_epoch
    expiry_epoch=$(date -d "$expiry_str" +%s 2>/dev/null || echo 0)
    now_epoch=$(date +%s)
    echo $(( (expiry_epoch - now_epoch) / 86400 ))
}

cmd_check() {
    local hosts=("$@")
    if [[ ${#hosts[@]} -eq 0 ]]; then
        error_exit "ホストを指定してください"
    fi

    log_info "SSL証明書有効期限チェック"
    echo ""

    printf "${C_BOLD}%-35s %10s %8s %s${C_RESET}\n" "ホスト" "残り日数" "状態" "有効期限"
    printf "%s\n" "$(printf '%.0s─' {1..75})"

    local ok=0 warn=0 crit=0 err=0
    local json_results="["

    for host in "${hosts[@]}"; do
        local days
        days=$(get_days_remaining "$host" "$port")

        if [[ "$days" == "-1" ]]; then
            printf "  ${C_DIM}%-33s${C_RESET} %10s ${C_RED}%8s${C_RESET}\n" \
                "$host" "N/A" "エラー"
            (( err++ ))
            continue
        fi

        local expiry_str color status
        expiry_str=$(get_cert_info "$host" "$port" "-enddate" | sed 's/notAfter=//')
        local expiry_fmt
        expiry_fmt=$(date -d "$expiry_str" "+%Y-%m-%d" 2>/dev/null || echo "?")

        if (( days < 0 )); then
            color="$C_RED"; status="期限切れ"; (( crit++ ))
        elif (( days < critical_days )); then
            color="$C_RED"; status="危険"; (( crit++ ))
        elif (( days < warn_days )); then
            color="$C_YELLOW"; status="警告"; (( warn++ ))
        else
            color="$C_GREEN"; status="正常"; (( ok++ ))
        fi

        printf "  %-33s ${color}%10d日${C_RESET} ${color}%8s${C_RESET} %s\n" \
            "$host" "$days" "$status" "$expiry_fmt"

        if [[ "$output_format" == "json" ]]; then
            json_results+="{\"host\":\"$host\",\"days_remaining\":$days,\"status\":\"$status\",\"expiry\":\"$expiry_fmt\"},"
        fi
    done

    echo ""
    printf "  正常: ${C_GREEN}%d${C_RESET}  警告: ${C_YELLOW}%d${C_RESET}  危険: ${C_RED}%d${C_RESET}  エラー: ${C_DIM}%d${C_RESET}\n" \
        "$ok" "$warn" "$crit" "$err"
    echo ""

    if [[ "$output_format" == "json" ]]; then
        json_results="${json_results%,}]"
        echo "$json_results" | python3 -m json.tool 2>/dev/null || echo "$json_results"
    fi
}

cmd_info() {
    local host="$1"
    log_info "SSL証明書詳細情報: $host:$port"
    echo ""

    local cert
    cert=$(openssl s_client -connect "${host}:${port}" \
        -servername "$host" -timeout "$timeout" \
        </dev/null 2>/dev/null | \
        openssl x509 -noout -text 2>/dev/null) || {
        error_exit "証明書を取得できませんでした: $host"
    }

    local subject issuer not_before not_after serial
    subject=$(openssl s_client -connect "${host}:${port}" -servername "$host" \
        -timeout "$timeout" </dev/null 2>/dev/null | \
        openssl x509 -noout -subject 2>/dev/null | sed 's/subject=//')
    issuer=$(get_cert_info "$host" "$port" "-issuer" | sed 's/issuer=//')
    not_before=$(get_cert_info "$host" "$port" "-startdate" | sed 's/notBefore=//')
    not_after=$(get_cert_info "$host" "$port" "-enddate"   | sed 's/notAfter=//')
    serial=$(get_cert_info "$host" "$port" "-serial" | sed 's/serial=//')

    local days
    days=$(get_days_remaining "$host" "$port")
    local days_color="$C_GREEN"
    (( days < warn_days     )) && days_color="$C_YELLOW"
    (( days < critical_days )) && days_color="$C_RED"

    printf "${C_BOLD}【証明書情報】${C_RESET}\n\n"
    printf "  %-20s %s\n" "ホスト:"      "$host:$port"
    printf "  %-20s %s\n" "サブジェクト:" "${subject:-N/A}"
    printf "  %-20s %s\n" "発行者:"      "${issuer:-N/A}"
    printf "  %-20s %s\n" "シリアル番号:" "${serial:-N/A}"
    printf "  %-20s %s\n" "有効開始:"    "${not_before:-N/A}"
    printf "  %-20s %s\n" "有効期限:"    "${not_after:-N/A}"
    printf "  %-20s ${days_color}%d日${C_RESET}\n" "残り日数:" "$days"

    echo ""
    local san
    san=$(echo "$cert" | grep -A1 "Subject Alternative Name" | tail -1 | \
        sed 's/DNS://g; s/IP Address://g; s/, /\n    /g; s/^[[:space:]]*//' || true)
    if [[ -n "$san" ]]; then
        printf "${C_BOLD}【SANs (Subject Alternative Names)】${C_RESET}\n\n"
        echo "    $san" | head -20
        echo ""
    fi

    local tls_version cipher
    tls_version=$(openssl s_client -connect "${host}:${port}" -servername "$host" \
        -timeout "$timeout" </dev/null 2>/dev/null | grep "Protocol" | \
        awk '{print $NF}' || true)
    cipher=$(openssl s_client -connect "${host}:${port}" -servername "$host" \
        -timeout "$timeout" </dev/null 2>/dev/null | grep "Cipher" | \
        awk '{print $NF}' || true)

    printf "${C_BOLD}【TLS情報】${C_RESET}\n\n"
    printf "  %-20s %s\n" "プロトコル:" "${tls_version:-N/A}"
    printf "  %-20s %s\n" "暗号スイート:" "${cipher:-N/A}"
    echo ""
}

cmd_chain() {
    local host="$1"
    log_info "証明書チェーン: $host:$port"
    echo ""

    openssl s_client -connect "${host}:${port}" -servername "$host" \
        -timeout "$timeout" -showcerts </dev/null 2>/dev/null | \
    awk '/-----BEGIN CERTIFICATE-----/{n++; cert=""}
         cert!=""{cert=cert"\n"$0}
         /-----BEGIN CERTIFICATE-----/{cert=$0}
         /-----END CERTIFICATE-----/{
             print cert"\n"$0 | "openssl x509 -noout -subject -issuer -enddate 2>/dev/null"
             print "─────────────────────────────────"
         }' || log_warning "チェーン情報を取得できませんでした"
    echo ""
}

cmd_scan() {
    local file="$1"
    [[ ! -f "$file" ]] && error_exit "ファイルが見つかりません: $file"

    local hosts=()
    while IFS= read -r line; do
        line="${line%%#*}"
        line="${line//[[:space:]]/}"
        [[ -z "$line" ]] && continue
        hosts+=("$line")
    done < "$file"

    [[ ${#hosts[@]} -eq 0 ]] && error_exit "有効なホストがありません: $file"
    log_info "スキャン対象: ${#hosts[@]} ホスト"
    cmd_check "${hosts[@]}"
}

parse_arguments() {
    [[ $# -eq 0 ]] && { show_usage; exit 0; }
    case "$1" in
        check|info|chain|scan)
            command_name="$1"; shift ;;
    esac

    local positional=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -p|--port)     [[ $# -lt 2 ]] && error_exit "--port には値が必要です"; port="$2"; shift 2 ;;
            -w|--warn)     [[ $# -lt 2 ]] && error_exit "--warn には値が必要です"; warn_days="$2"; shift 2 ;;
            -c|--critical) [[ $# -lt 2 ]] && error_exit "--critical には値が必要です"; critical_days="$2"; shift 2 ;;
            -t|--timeout)  [[ $# -lt 2 ]] && error_exit "--timeout には値が必要です"; timeout="$2"; shift 2 ;;
            -f|--format)   [[ $# -lt 2 ]] && error_exit "--format には値が必要です"; output_format="$2"; shift 2 ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  positional+=("$1"); shift ;;
        esac
    done
    set -- "${positional[@]+"${positional[@]}"}"
    POSITIONAL=("$@")
}

declare -a POSITIONAL=()

main() {
    parse_arguments "$@"
    case "$command_name" in
        check) cmd_check "${POSITIONAL[@]}" ;;
        info)  [[ ${#POSITIONAL[@]} -eq 0 ]] && error_exit "ホストを指定してください"
               cmd_info "${POSITIONAL[0]}" ;;
        chain) [[ ${#POSITIONAL[@]} -eq 0 ]] && error_exit "ホストを指定してください"
               cmd_chain "${POSITIONAL[0]}" ;;
        scan)  [[ ${#POSITIONAL[@]} -eq 0 ]] && error_exit "ファイルを指定してください"
               cmd_scan "${POSITIONAL[0]}" ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
