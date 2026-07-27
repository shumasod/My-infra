#!/bin/bash
set -euo pipefail

#
# SSL/TLSスキャナー
# バージョン: 1.0
#
# SSL/TLS設定の検査・証明書情報・暗号スイートを確認するツール
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare -a target_hosts=()
declare -i port=443
declare mode="full"
declare output_file=""
declare -i timeout_sec=10

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション] ホスト [ホスト...]

SSL/TLSスキャナー

引数:
  ホスト              検査対象のホスト名またはIP

コマンド:
  full              フル検査 (デフォルト)
  cert              証明書情報のみ
  protocols         プロトコルバージョン確認
  ciphers           暗号スイート列挙
  chain             証明書チェーン確認

オプション:
  -h, --help              このヘルプを表示
  -v, --version           バージョン情報を表示
  -m, --mode MODE         検査モード
  -p, --port PORT         ポート番号 [デフォルト: 443]
  -o, --output FILE       出力ファイル
  -t, --timeout SEC       タイムアウト秒数 [デフォルト: 10]

例:
  $PROG_NAME example.com
  $PROG_NAME -m cert example.com
  $PROG_NAME -p 8443 internal.example.com
  $PROG_NAME -m protocols example.com
  $PROG_NAME example.com other.com

EOF
}

ssl_connect() {
    local host="$1"
    local port="$2"
    local extra_opts="${3:-}"
    echo "" | timeout "$timeout_sec" openssl s_client \
        -connect "${host}:${port}" \
        -servername "$host" \
        $extra_opts 2>/dev/null || true
}

get_cert_info() {
    local host="$1"
    local port="$2"
    ssl_connect "$host" "$port" | openssl x509 -text -noout 2>/dev/null || true
}

do_cert() {
    local host="$1"
    local port="$2"

    log_info "証明書情報: ${host}:${port}"
    echo ""

    local cert_output
    cert_output=$(ssl_connect "$host" "$port")

    if [[ -z "$cert_output" ]]; then
        log_error "接続に失敗しました: ${host}:${port}"
        return 1
    fi

    local subject issuer not_before not_after san
    subject=$(echo "$cert_output" | openssl x509 -noout -subject 2>/dev/null | sed 's/subject=//')
    issuer=$(echo "$cert_output" | openssl x509 -noout -issuer 2>/dev/null | sed 's/issuer=//')
    not_before=$(echo "$cert_output" | openssl x509 -noout -startdate 2>/dev/null | sed 's/notBefore=//')
    not_after=$(echo "$cert_output" | openssl x509 -noout -enddate 2>/dev/null | sed 's/notAfter=//')
    san=$(echo "$cert_output" | openssl x509 -noout -text 2>/dev/null | grep -A1 "Subject Alternative Name" | tail -1 | tr ',' '\n' | grep -oE 'DNS:[^,]+' | tr -d ' ' || echo "")

    printf "  %-20s %s\n" "サブジェクト:" "$subject"
    printf "  %-20s %s\n" "発行者:" "$issuer"
    printf "  %-20s %s\n" "有効開始:" "$not_before"
    printf "  %-20s %s\n" "有効期限:" "$not_after"

    # 期限チェック
    local expiry_epoch
    expiry_epoch=$(date -d "$not_after" +%s 2>/dev/null || echo 0)
    local now_epoch
    now_epoch=$(date +%s)
    local days_left=$(( (expiry_epoch - now_epoch) / 86400 ))

    local expiry_color="$C_GREEN"
    local expiry_status="有効"
    if (( days_left < 0 )); then
        expiry_color="$C_RED"
        expiry_status="期限切れ"
    elif (( days_left < 14 )); then
        expiry_color="${C_RED}${C_BOLD}"
        expiry_status="まもなく期限切れ"
    elif (( days_left < 30 )); then
        expiry_color="$C_YELLOW"
        expiry_status="要更新"
    fi

    printf "  %-20s ${expiry_color}%s (%d日)${C_RESET}\n" "残り日数:" "$expiry_status" "$days_left"

    if [[ -n "$san" ]]; then
        echo ""
        printf "  %-20s\n" "SANドメイン:"
        echo "$san" | while IFS= read -r s; do
            printf "    %s\n" "${s#DNS:}"
        done
    fi

    # シリアル番号
    local serial
    serial=$(echo "$cert_output" | openssl x509 -noout -serial 2>/dev/null | sed 's/serial=//')
    printf "\n  %-20s %s\n" "シリアル番号:" "$serial"

    # フィンガープリント
    local fp_sha256
    fp_sha256=$(echo "$cert_output" | openssl x509 -noout -fingerprint -sha256 2>/dev/null | sed 's/SHA256 Fingerprint=//')
    printf "  %-20s %s\n" "SHA256フィンガープリント:" "$fp_sha256"
    echo ""
}

do_protocols() {
    local host="$1"
    local port="$2"

    log_info "TLSプロトコルバージョン: ${host}:${port}"
    echo ""

    declare -A PROTOCOLS=(
        ["ssl2"]="-ssl2"
        ["ssl3"]="-ssl3"
        ["tls1"]="-tls1"
        ["tls1_1"]="-tls1_1"
        ["tls1_2"]="-tls1_2"
        ["tls1_3"]="-tls1_3"
    )

    printf "  ${C_BOLD}%-12s %s${C_RESET}\n" "プロトコル" "サポート状況"
    printf "  %s\n" "$(printf '%.0s-' {1..35})"

    for proto in ssl2 ssl3 tls1 tls1_1 tls1_2 tls1_3; do
        local opt="${PROTOCOLS[$proto]}"
        local result
        result=$(echo "" | timeout "$timeout_sec" openssl s_client \
            -connect "${host}:${port}" -servername "$host" "$opt" 2>&1 || true)

        local status color
        if echo "$result" | grep -q "BEGIN CERTIFICATE\|Cipher is"; then
            # 古いプロトコルは危険
            if [[ "$proto" == "ssl2" || "$proto" == "ssl3" || "$proto" == "tls1" || "$proto" == "tls1_1" ]]; then
                status="${C_RED}${C_BOLD}有効 (危険)${C_RESET}"
            else
                status="${C_GREEN}有効${C_RESET}"
            fi
        else
            if [[ "$proto" == "ssl2" || "$proto" == "ssl3" || "$proto" == "tls1" || "$proto" == "tls1_1" ]]; then
                status="${C_GREEN}無効 (推奨)${C_RESET}"
            else
                status="${C_DIM}無効${C_RESET}"
            fi
        fi

        local proto_upper
        proto_upper=$(echo "$proto" | tr '_' '.' | tr '[:lower:]' '[:upper:]')
        printf "  %-12s %b\n" "$proto_upper" "$status"
    done
    echo ""
}

do_ciphers() {
    local host="$1"
    local port="$2"

    log_info "使用中の暗号スイート: ${host}:${port}"
    echo ""

    local cipher_result
    cipher_result=$(ssl_connect "$host" "$port" | grep "^New\|^Cipher")

    if [[ -z "$cipher_result" ]]; then
        log_warning "暗号スイート情報を取得できませんでした"
        return 0
    fi

    local current_cipher
    current_cipher=$(echo "$cipher_result" | grep "Cipher" | awk '{print $NF}')

    printf "  ${C_BOLD}%-30s %s${C_RESET}\n" "使用暗号スイート" "評価"
    printf "  %s\n" "$(printf '%.0s-' {1..55})"

    if [[ -n "$current_cipher" ]]; then
        local cipher_grade color grade
        if echo "$current_cipher" | grep -qiE "AES-128-GCM|AES-256-GCM|CHACHA20"; then
            grade="A (優秀)"
            color="$C_GREEN"
        elif echo "$current_cipher" | grep -qiE "AES-128|AES-256"; then
            grade="B (良好)"
            color="$C_CYAN"
        elif echo "$current_cipher" | grep -qiE "RC4|DES|3DES|EXPORT|NULL|ANON"; then
            grade="F (危険)"
            color="${C_RED}${C_BOLD}"
        else
            grade="C (普通)"
            color="$C_YELLOW"
        fi
        printf "  ${color}%-30s %s${C_RESET}\n" "$current_cipher" "$grade"
    fi
    echo ""
}

do_chain() {
    local host="$1"
    local port="$2"

    log_info "証明書チェーン: ${host}:${port}"
    echo ""

    ssl_connect "$host" "$port" "-showcerts" | \
    awk '/-----BEGIN CERTIFICATE-----/{n++; cert=""}
         cert{cert=cert"\n"$0}
         /BEGIN CERTIFICATE/{cert=$0}
         /-----END CERTIFICATE-----/{
             print cert"\n-----END CERTIFICATE-----" | "openssl x509 -noout -subject -issuer 2>/dev/null"
             print "---"
         }' 2>/dev/null | while IFS= read -r line; do
        if [[ "$line" == "---" ]]; then
            echo ""
        elif [[ "$line" =~ ^subject= ]]; then
            printf "  ${C_CYAN}%s${C_RESET}\n" "$line"
        elif [[ "$line" =~ ^issuer= ]]; then
            printf "  ${C_DIM}%s${C_RESET}\n" "$line"
        fi
    done
    echo ""
}

do_full() {
    local host="$1"
    local port="$2"

    print_center "SSL/TLSスキャン: ${host}:${port}" 0 "$C_CYAN"
    draw_separator 0
    echo ""

    do_cert "$host" "$port"
    do_protocols "$host" "$port"
    do_ciphers "$host" "$port"
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -m|--mode)    [[ $# -lt 2 ]] && error_exit "-m には値が必要です"; mode="$2"; shift 2 ;;
            -p|--port)    [[ $# -lt 2 ]] && error_exit "-p には値が必要です"; port="$2"; shift 2 ;;
            -o|--output)  [[ $# -lt 2 ]] && error_exit "-o には値が必要です"; output_file="$2"; shift 2 ;;
            -t|--timeout) [[ $# -lt 2 ]] && error_exit "-t には値が必要です"; timeout_sec="$2"; shift 2 ;;
            full|cert|protocols|ciphers|chain) mode="$1"; shift ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  target_hosts+=("$1"); shift ;;
        esac
    done
}

main() {
    parse_arguments "$@"
    [[ ${#target_hosts[@]} -eq 0 ]] && error_exit "ホストを指定してください"

    if ! command -v openssl &>/dev/null; then
        error_exit "opensslがインストールされていません"
    fi

    for host in "${target_hosts[@]}"; do
        case "$mode" in
            full)      do_full "$host" "$port" ;;
            cert)      do_cert "$host" "$port" ;;
            protocols) do_protocols "$host" "$port" ;;
            ciphers)   do_ciphers "$host" "$port" ;;
            chain)     do_chain "$host" "$port" ;;
            *)         error_exit "不明なモード: $mode" ;;
        esac
    done
}

main "$@"
