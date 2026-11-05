#!/bin/bash
set -euo pipefail

#
# ネットワークセキュリティ監査ツール
# 作成日: 2026-11-05
# バージョン: 1.0
#
# 脆弱性対応: ネットワーク設定・開放ポートの脆弱性検出
# CVE該当: CWE-200 (Exposure of Sensitive Information), CWE-319 (Cleartext Transmission)
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare command_name="audit"

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション]

ネットワークセキュリティを監査します。

コマンド:
  audit                ネットワーク全体監査 (デフォルト)
  ports                開放ポートと危険なサービス確認
  firewall             ファイアウォール設定確認
  interfaces           ネットワークインターフェース確認
  connections          アクティブな接続確認
  exposed              外部公開サービスの確認

オプション:
  -h, --help           このヘルプを表示
  -v, --version        バージョン情報を表示
EOF
}

# 危険なポートの定義
declare -A DANGEROUS_PORTS=(
    [21]="FTP (平文転送)"
    [23]="Telnet (平文通信)"
    [25]="SMTP (認証なし)"
    [110]="POP3 (平文)"
    [143]="IMAP (平文)"
    [445]="SMB (ランサムウェア標的)"
    [1433]="MSSQL (外部公開危険)"
    [3306]="MySQL (外部公開危険)"
    [3389]="RDP (ブルートフォース標的)"
    [4444]="Metasploit デフォルト"
    [5432]="PostgreSQL (外部公開危険)"
    [5900]="VNC (平文・弱認証)"
    [6379]="Redis (認証なし)"
    [27017]="MongoDB (認証なし)"
)

cmd_audit() {
    log_info "ネットワークセキュリティ監査"
    echo ""
    cmd_ports
    cmd_firewall
    cmd_connections
}

cmd_ports() {
    log_info "開放ポートと危険なサービス確認"
    echo ""

    local listening_ports=()
    if command -v ss &>/dev/null; then
        while IFS= read -r port; do
            listening_ports+=("$port")
        done < <(ss -tlnp 2>/dev/null | awk 'NR>1 {print $4}' | grep -oE '[0-9]+$' | sort -un)
    elif command -v netstat &>/dev/null; then
        while IFS= read -r port; do
            listening_ports+=("$port")
        done < <(netstat -tlnp 2>/dev/null | awk 'NR>2 {print $4}' | grep -oE '[0-9]+$' | sort -un)
    fi

    printf "${C_BOLD}【開放ポート一覧】${C_RESET}\n\n"
    printf "  %-8s %-30s %s\n" "ポート" "サービス" "リスク"
    draw_separator 0 "-"

    for port in "${listening_ports[@]}"; do
        local service risk_color risk_text
        service="${DANGEROUS_PORTS[$port]:-}"
        if [[ -n "$service" ]]; then
            risk_color="$C_RED"
            risk_text="[危険]"
        else
            risk_color="$C_GREEN"
            risk_text="[正常]"
            service=$(getent services "$port" 2>/dev/null | awk '{print $1}' || echo "unknown")
        fi
        printf "  %-8s %-30s ${risk_color}%s${C_RESET}\n" "$port" "$service" "$risk_text"
    done
    echo ""

    local dangerous_found=0
    for port in "${!DANGEROUS_PORTS[@]}"; do
        if printf '%s\n' "${listening_ports[@]}" | grep -qx "$port"; then
            (( dangerous_found++ ))
        fi
    done

    if [[ "$dangerous_found" -gt 0 ]]; then
        log_error "$dangerous_found 件の危険なポートが開放されています"
    else
        log_success "危険なポートは開放されていません"
    fi
    echo ""
}

cmd_firewall() {
    log_info "ファイアウォール設定確認"
    echo ""

    # iptables
    if command -v iptables &>/dev/null; then
        local rules_count
        rules_count=$(iptables -L 2>/dev/null | grep -c "^ACCEPT\|^DROP\|^REJECT" || echo 0)
        printf "  iptables ルール数: %s\n" "$rules_count"

        local default_policy
        default_policy=$(iptables -L INPUT 2>/dev/null | head -1 | grep -oE "policy \w+" || echo "不明")
        printf "  INPUTデフォルトポリシー: "
        if echo "$default_policy" | grep -q "DROP\|REJECT"; then
            printf "${C_GREEN}%s (安全)${C_RESET}\n" "$default_policy"
        else
            printf "${C_YELLOW}%s (確認推奨)${C_RESET}\n" "$default_policy"
        fi
    fi

    # ufw
    if command -v ufw &>/dev/null; then
        local ufw_status
        ufw_status=$(ufw status 2>/dev/null | head -1 | awk '{print $2}' || echo "不明")
        printf "  UFWステータス: "
        if [[ "$ufw_status" == "active" ]]; then
            printf "${C_GREEN}有効${C_RESET}\n"
        else
            printf "${C_RED}無効 (要有効化)${C_RESET}\n"
        fi
    fi

    # firewalld
    if command -v firewall-cmd &>/dev/null; then
        local fw_state
        fw_state=$(firewall-cmd --state 2>/dev/null || echo "not running")
        printf "  firewalld: "
        if [[ "$fw_state" == "running" ]]; then
            printf "${C_GREEN}実行中${C_RESET}\n"
        else
            printf "${C_RED}停止中${C_RESET}\n"
        fi
    fi
    echo ""
}

cmd_interfaces() {
    log_info "ネットワークインターフェース確認"
    echo ""

    if command -v ip &>/dev/null; then
        ip -o addr show 2>/dev/null | awk '{print $2, $4}' | \
        while IFS=' ' read -r iface addr; do
            printf "  %-15s %s\n" "$iface" "$addr"
            # プロミスキャスモード確認
            if ip link show "$iface" 2>/dev/null | grep -q "PROMISC"; then
                printf "  ${C_RED}  [警告] プロミスキャスモード有効 (スニッフィング可能)${C_RESET}\n"
            fi
        done
    fi
    echo ""
}

cmd_connections() {
    log_info "アクティブな接続確認"
    echo ""

    if command -v ss &>/dev/null; then
        local established
        established=$(ss -tn state established 2>/dev/null | wc -l)
        printf "  確立済み接続数: %s\n\n" "$established"

        printf "${C_BOLD}外部接続 (上位10件):${C_RESET}\n"
        ss -tn state established 2>/dev/null | awk 'NR>1 {print $5}' | \
        grep -v "127\.\|::1" | sort | uniq -c | sort -rn | head -10 | \
        while IFS= read -r line; do
            printf "  %s\n" "$line"
        done
    fi
    echo ""
}

cmd_exposed() {
    log_info "外部公開サービス確認"
    echo ""

    local public_ip
    public_ip=$(curl -s --max-time 5 "https://api.ipify.org" 2>/dev/null || echo "取得失敗")
    printf "  パブリックIP: %s\n\n" "$public_ip"

    printf "${C_BOLD}0.0.0.0でリスニングのサービス (外部公開):${C_RESET}\n"
    if command -v ss &>/dev/null; then
        ss -tlnp 2>/dev/null | grep "0\.0\.0\.0\|:::" | \
        while IFS= read -r line; do
            local port
            port=$(echo "$line" | awk '{print $4}' | grep -oE '[0-9]+$')
            local service="${DANGEROUS_PORTS[$port]:-}"
            if [[ -n "$service" ]]; then
                printf "  ${C_RED}[危険]${C_RESET} %s (%s)\n" "$line" "$service"
            else
                printf "  ${C_YELLOW}[要確認]${C_RESET} %s\n" "$line"
            fi
        done
    fi
    echo ""
}

parse_arguments() {
    [[ $# -eq 0 ]] && return 0
    case "$1" in
        audit|ports|firewall|interfaces|connections|exposed)
            command_name="$1"; shift ;;
    esac
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -*) error_exit "不明なオプション: $1" ;;
            *) shift ;;
        esac
    done
}

main() {
    parse_arguments "$@"
    case "$command_name" in
        audit)       cmd_audit ;;
        ports)       cmd_ports ;;
        firewall)    cmd_firewall ;;
        interfaces)  cmd_interfaces ;;
        connections) cmd_connections ;;
        exposed)     cmd_exposed ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
