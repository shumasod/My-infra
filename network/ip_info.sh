#!/bin/bash
set -euo pipefail

#
# IPアドレス情報表示ツール
# 作成日: 2026-07-14
# バージョン: 1.0
#
# ローカル・リモートのIPアドレス情報を収集・表示する
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション]

ローカルおよびネットワークのIPアドレス情報を表示します。

オプション:
  -h, --help       このヘルプを表示
  -v, --version    バージョン情報を表示
  -l, --local      ローカルインターフェース情報のみ
  -r, --route      ルーティングテーブルを表示
  -s, --summary    サマリーのみ表示
  -o, --output     ファイルに保存

例:
  $PROG_NAME
  $PROG_NAME --local
  $PROG_NAME --route
EOF
}

section() {
    echo ""
    echo -e "  ${C_BOLD}${C_CYAN}── $1 ──${C_RESET}"
    echo ""
}

show_local_interfaces() {
    section "ローカルインターフェース"

    if command -v ip &>/dev/null; then
        while IFS= read -r line; do
            if [[ "$line" =~ ^[0-9]+:\ ([^:]+): ]]; then
                iface="${BASH_REMATCH[1]}"
                echo -e "  ${C_BOLD}${C_YELLOW}[${iface}]${C_RESET}"
            elif [[ "$line" =~ "inet " ]]; then
                addr=$(echo "$line" | awk '{print $2}')
                brd=$(echo "$line" | awk '{print $4}' 2>/dev/null || echo "N/A")
                echo -e "    ${C_GREEN}IPv4:${C_RESET}  $addr"
                echo -e "    ${C_DIM}Bcast: $brd${C_RESET}"
            elif [[ "$line" =~ "inet6" ]]; then
                addr=$(echo "$line" | awk '{print $2}')
                echo -e "    ${C_CYAN}IPv6:${C_RESET}  $addr"
            elif [[ "$line" =~ "link/ether" ]]; then
                mac=$(echo "$line" | awk '{print $2}')
                echo -e "    ${C_DIM}MAC:   $mac${C_RESET}"
            fi
        done < <(ip addr 2>/dev/null)
    elif command -v ifconfig &>/dev/null; then
        ifconfig 2>/dev/null | while IFS= read -r line; do
            if [[ "$line" =~ ^[a-z] ]]; then
                iface=$(echo "$line" | awk '{print $1}' | tr -d ':')
                echo -e "  ${C_BOLD}${C_YELLOW}[${iface}]${C_RESET}"
            elif [[ "$line" =~ "inet " ]]; then
                addr=$(echo "$line" | awk '{print $2}' | tr -d 'addr:')
                echo -e "    ${C_GREEN}IPv4:${C_RESET}  $addr"
            fi
        done
    else
        log_warning "ip / ifconfig コマンドが見つかりません"
    fi
}

show_default_route() {
    section "デフォルトゲートウェイ"

    if command -v ip &>/dev/null; then
        local gw iface
        gw=$(ip route 2>/dev/null | grep "^default" | awk '{print $3}' | head -1)
        iface=$(ip route 2>/dev/null | grep "^default" | awk '{print $5}' | head -1)
        if [[ -n "$gw" ]]; then
            echo -e "  ${C_GREEN}ゲートウェイ:${C_RESET} $gw"
            echo -e "  ${C_GREEN}インターフェース:${C_RESET} $iface"
        else
            log_warning "デフォルトゲートウェイが見つかりません"
        fi
    fi
}

show_routing_table() {
    section "ルーティングテーブル"

    if command -v ip &>/dev/null; then
        printf "  ${C_BOLD}%-20s %-16s %-10s %-8s${C_RESET}\n" "宛先" "ゲートウェイ" "インターフェース" "メトリック"
        echo -e "  ${C_DIM}$(printf '%.0s─' {1..55})${C_RESET}"
        ip route 2>/dev/null | while read -r line; do
            dest=$(echo "$line" | awk '{print $1}')
            gw=$(echo "$line" | grep -o "via [^ ]*" | awk '{print $2}' || echo "-")
            dev=$(echo "$line" | grep -o "dev [^ ]*" | awk '{print $2}' || echo "-")
            metric=$(echo "$line" | grep -o "metric [0-9]*" | awk '{print $2}' || echo "-")
            printf "  ${C_GREEN}%-20s${C_RESET} %-16s %-10s %-8s\n" "$dest" "${gw:-direct}" "${dev:--}" "${metric:--}"
        done
    fi
}

show_dns_info() {
    section "DNS設定"

    if [[ -f "/etc/resolv.conf" ]]; then
        while IFS= read -r line; do
            if [[ "$line" =~ ^nameserver ]]; then
                ns=$(echo "$line" | awk '{print $2}')
                echo -e "  ${C_GREEN}ネームサーバー:${C_RESET} $ns"
            elif [[ "$line" =~ ^search ]]; then
                domain=$(echo "$line" | cut -d' ' -f2-)
                echo -e "  ${C_GREEN}検索ドメイン:${C_RESET}  $domain"
            fi
        done < /etc/resolv.conf
    else
        log_warning "/etc/resolv.conf が見つかりません"
    fi
}

show_hostname_info() {
    section "ホスト名情報"

    echo -e "  ${C_GREEN}ホスト名:${C_RESET}  $(hostname 2>/dev/null || echo 'N/A')"
    if command -v hostname &>/dev/null; then
        local fqdn
        fqdn=$(hostname -f 2>/dev/null || echo "N/A")
        echo -e "  ${C_GREEN}FQDN:${C_RESET}      $fqdn"
    fi

    if [[ -f "/etc/hostname" ]]; then
        echo -e "  ${C_GREEN}設定ファイル:${C_RESET} /etc/hostname"
    fi
}

show_connection_summary() {
    section "接続サマリー"

    if command -v ss &>/dev/null; then
        local total listen established
        total=$(ss -tn 2>/dev/null | tail -n +2 | wc -l)
        listen=$(ss -tnl 2>/dev/null | tail -n +2 | wc -l)
        established=$(ss -tn 2>/dev/null | grep ESTAB | wc -l)
        echo -e "  ${C_GREEN}リッスン中:${C_RESET}    $listen ポート"
        echo -e "  ${C_GREEN}接続中:${C_RESET}        $established セッション"
        echo -e "  ${C_GREEN}合計ソケット:${C_RESET}  $total"
    fi
}

main() {
    local show_local=false
    local show_route=false
    local summary_only=false
    local output_file=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -l|--local)   show_local=true; shift ;;
            -r|--route)   show_route=true; shift ;;
            -s|--summary) summary_only=true; shift ;;
            -o|--output)
                [[ $# -lt 2 ]] && error_exit "--output にはファイル名が必要です"
                output_file="$2"; shift 2 ;;
            *) error_exit "不明なオプション: $1" ;;
        esac
    done

    run_report() {
        echo ""
        print_center "IP アドレス情報ツール" 0 "${C_BOLD}${C_CYAN}"
        print_center "$(get_timestamp)" 0 "$C_DIM"

        if "$summary_only"; then
            show_hostname_info
            show_default_route
            show_connection_summary
        elif "$show_local"; then
            show_local_interfaces
            show_default_route
        elif "$show_route"; then
            show_routing_table
        else
            show_hostname_info
            show_local_interfaces
            show_default_route
            show_dns_info
            show_connection_summary
        fi
        echo ""
    }

    if [[ -n "$output_file" ]]; then
        run_report | tee "$output_file"
        log_success "レポートを保存: $output_file"
    else
        run_report
    fi
}

main "$@"
