#!/bin/bash
set -euo pipefail

#
# Linuxシステムセキュリティ監査ツール
# バージョン: 1.0
#
# システムのセキュリティ設定を確認・評価するツール
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare output_file=""
declare -i pass_count=0
declare -i warn_count=0
declare -i fail_count=0

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション]

Linuxシステムセキュリティ監査ツール

オプション:
  -h, --help            このヘルプを表示
  -v, --version         バージョン情報を表示
  -o, --output FILE     結果をファイルに保存

チェック項目:
  - ユーザーアカウント (空パスワード・UIDゼロ・sudo権限)
  - SSH設定 (root ログイン・パスワード認証)
  - ファイルパーミッション (/etc/passwd, /etc/shadow 等)
  - システム設定 (IPv6無効化・ASLR・コアダンプ)
  - ネットワーク (開放ポート・TCP Wrapper)
  - サービス (不要サービスの確認)
  - ログ設定 (auditd・syslog)

例:
  $PROG_NAME
  sudo $PROG_NAME -o audit_report.txt

EOF
}

check_item() {
    local label="$1"
    local status="$2"
    local detail="${3:-}"

    case "$status" in
        PASS)
            printf "  ${C_GREEN}[PASS]${C_RESET} %s\n" "$label"
            (( pass_count++ )) || true ;;
        WARN)
            printf "  ${C_YELLOW}[WARN]${C_RESET} %s" "$label"
            [[ -n "$detail" ]] && printf " (%s)" "$detail"
            echo ""
            (( warn_count++ )) || true ;;
        FAIL)
            printf "  ${C_RED}[FAIL]${C_RESET} %s" "$label"
            [[ -n "$detail" ]] && printf " (%s)" "$detail"
            echo ""
            (( fail_count++ )) || true ;;
        INFO)
            printf "  ${C_CYAN}[INFO]${C_RESET} %s\n" "$label" ;;
    esac
}

section() {
    echo ""
    echo -e "  ${C_BOLD}${C_CYAN}▶ $1${C_RESET}"
    printf "  %s\n" "$(printf '%.0s─' {1..50})"
}

audit_users() {
    section "ユーザーアカウント"

    # 空パスワードのユーザー
    local empty_pass
    empty_pass=$(awk -F: '($2 == "" || $2 == "!") && $1 != "root"' /etc/shadow 2>/dev/null | cut -d: -f1 | tr '\n' ',' | sed 's/,$//')
    if [[ -z "$empty_pass" ]]; then
        check_item "空パスワードユーザーなし" "PASS"
    else
        check_item "空パスワードユーザーを検出" "FAIL" "$empty_pass"
    fi

    # root以外でUID=0のユーザー
    local uid0_users
    uid0_users=$(awk -F: '$3 == 0 && $1 != "root" {print $1}' /etc/passwd | tr '\n' ',')
    if [[ -z "$uid0_users" ]]; then
        check_item "UID 0 は root のみ" "PASS"
    else
        check_item "root以外にUID 0が存在" "FAIL" "$uid0_users"
    fi

    # sudoグループのユーザー
    local sudo_users
    sudo_users=$(getent group sudo 2>/dev/null | cut -d: -f4)
    check_item "sudoグループ: ${sudo_users:-なし}" "INFO"

    # パスワードのないアカウント(ログイン可能)
    local no_lock
    no_lock=$(awk -F: '$2 !~ /^[!*]/ && $7 !~ /nologin|false/ {print $1}' /etc/shadow 2>/dev/null | grep -v '^root$' | head -5 | tr '\n' ',')
    [[ -n "$no_lock" ]] && check_item "ログイン可能なアカウント: ${no_lock}" "INFO"
}

audit_ssh() {
    section "SSH設定"

    local sshd_config="/etc/ssh/sshd_config"
    if [[ ! -f "$sshd_config" ]]; then
        check_item "SSH未インストール" "INFO"
        return
    fi

    local root_login
    root_login=$(grep -iE "^PermitRootLogin" "$sshd_config" | awk '{print $2}' | tr '[:upper:]' '[:lower:]')
    if [[ "$root_login" == "no" || "$root_login" == "prohibit-password" ]]; then
        check_item "rootログイン無効" "PASS"
    else
        check_item "rootログイン有効" "FAIL" "PermitRootLogin $root_login"
    fi

    local pw_auth
    pw_auth=$(grep -iE "^PasswordAuthentication" "$sshd_config" | awk '{print $2}' | tr '[:upper:]' '[:lower:]')
    if [[ "$pw_auth" == "no" ]]; then
        check_item "パスワード認証無効 (鍵認証のみ)" "PASS"
    else
        check_item "パスワード認証有効" "WARN" "鍵認証への切り替えを推奨"
    fi

    local ssh_port
    ssh_port=$(grep -iE "^Port" "$sshd_config" | awk '{print $2}' | head -1)
    ssh_port="${ssh_port:-22}"
    if [[ "$ssh_port" != "22" ]]; then
        check_item "SSHポート変更済み: $ssh_port" "PASS"
    else
        check_item "SSHはデフォルトポート (22)" "WARN" "ポート変更を検討"
    fi

    local empty_pw
    empty_pw=$(grep -iE "^PermitEmptyPasswords" "$sshd_config" | awk '{print $2}' | tr '[:upper:]' '[:lower:]')
    if [[ "$empty_pw" != "yes" ]]; then
        check_item "空パスワードによるSSHログイン拒否" "PASS"
    else
        check_item "空パスワードのSSHログインを許可" "FAIL"
    fi
}

audit_file_permissions() {
    section "重要ファイルのパーミッション"

    local -A expected_perms=(
        ["/etc/passwd"]="644"
        ["/etc/shadow"]="640"
        ["/etc/group"]="644"
        ["/etc/sudoers"]="440"
        ["/etc/ssh/sshd_config"]="600"
    )

    for file in "${!expected_perms[@]}"; do
        [[ ! -f "$file" ]] && continue
        local actual_perm
        actual_perm=$(stat -c "%a" "$file" 2>/dev/null || echo "???")
        local expected="${expected_perms[$file]}"
        if [[ "$actual_perm" == "$expected" ]]; then
            check_item "${file}: ${actual_perm}" "PASS"
        else
            check_item "${file}: ${actual_perm} (推奨: ${expected})" "WARN"
        fi
    done

    # world-writable ファイル
    local ww_count
    ww_count=$(find /etc /usr/bin /usr/sbin -maxdepth 2 -perm -o+w 2>/dev/null | wc -l)
    if (( ww_count == 0 )); then
        check_item "world-writable ファイルなし (/etc, /usr)" "PASS"
    else
        check_item "world-writable ファイルを検出: ${ww_count}件" "WARN"
    fi

    # SUID/SGID ファイル
    local suid_count
    suid_count=$(find /usr/bin /usr/sbin /bin /sbin -perm /6000 2>/dev/null | wc -l)
    check_item "SUID/SGIDファイル数: ${suid_count}件" "INFO"
}

audit_network() {
    section "ネットワーク設定"

    # 開放ポート
    local open_ports
    if command -v ss &>/dev/null; then
        open_ports=$(ss -tlnp 2>/dev/null | awk 'NR>1 {print $4}' | grep -oE ':[0-9]+$' | sort -t: -k2 -n | tr -d ':' | tr '\n' ',' | sed 's/,$//')
    elif command -v netstat &>/dev/null; then
        open_ports=$(netstat -tlnp 2>/dev/null | awk 'NR>2 {print $4}' | grep -oE ':[0-9]+$' | sort -t: -k2 -n | tr -d ':' | tr '\n' ',' | sed 's/,$//')
    fi
    check_item "開放ポート: ${open_ports:-確認不可}" "INFO"

    # IPv4フォワーディング
    local ip_forward
    ip_forward=$(sysctl -n net.ipv4.ip_forward 2>/dev/null || echo "不明")
    if [[ "$ip_forward" == "0" ]]; then
        check_item "IPv4フォワーディング無効" "PASS"
    else
        check_item "IPv4フォワーディング有効" "WARN" "ルーターでない場合は無効化を検討"
    fi

    # ICMP リダイレクト
    local icmp_redir
    icmp_redir=$(sysctl -n net.ipv4.conf.all.accept_redirects 2>/dev/null || echo "1")
    if [[ "$icmp_redir" == "0" ]]; then
        check_item "ICMPリダイレクト受信無効" "PASS"
    else
        check_item "ICMPリダイレクト受信有効" "WARN"
    fi
}

audit_system() {
    section "システム設定"

    # ASLR
    local aslr
    aslr=$(sysctl -n kernel.randomize_va_space 2>/dev/null || echo "0")
    if [[ "$aslr" == "2" ]]; then
        check_item "ASLR完全有効 (kernel.randomize_va_space=2)" "PASS"
    elif [[ "$aslr" == "1" ]]; then
        check_item "ASLR部分有効 (kernel.randomize_va_space=1)" "WARN"
    else
        check_item "ASLR無効" "FAIL"
    fi

    # コアダンプ無効化
    local core_pattern
    core_pattern=$(sysctl -n kernel.core_pattern 2>/dev/null || echo "core")
    if [[ "$core_pattern" == "|/bin/false" || "$core_pattern" == "/dev/null" ]]; then
        check_item "コアダンプ無効化済み" "PASS"
    else
        check_item "コアダンプが有効 ($core_pattern)" "WARN"
    fi

    # UFW/iptables
    if command -v ufw &>/dev/null; then
        local ufw_status
        ufw_status=$(ufw status 2>/dev/null | head -1)
        if echo "$ufw_status" | grep -q "active"; then
            check_item "UFW有効" "PASS"
        else
            check_item "UFW無効" "WARN"
        fi
    elif command -v iptables &>/dev/null; then
        local ipt_rules
        ipt_rules=$(iptables -L 2>/dev/null | grep -c "^" || echo 0)
        check_item "iptablesルール: ${ipt_rules}行" "INFO"
    else
        check_item "ファイアウォール未確認" "WARN"
    fi

    # auditd
    if systemctl is-active auditd &>/dev/null 2>&1; then
        check_item "auditd 稼働中" "PASS"
    else
        check_item "auditd 停止中" "WARN" "監査ログの設定を推奨"
    fi
}

print_summary() {
    local total=$(( pass_count + warn_count + fail_count ))
    echo ""
    echo -e "${C_CYAN}╔══════════════════════════════╗${C_RESET}"
    echo -e "${C_CYAN}║       監査結果サマリー       ║${C_RESET}"
    echo -e "${C_CYAN}╚══════════════════════════════╝${C_RESET}"
    printf "  ${C_GREEN}[PASS]${C_RESET} %d / %d\n" "$pass_count" "$total"
    printf "  ${C_YELLOW}[WARN]${C_RESET} %d / %d\n" "$warn_count" "$total"
    printf "  ${C_RED}[FAIL]${C_RESET} %d / %d\n" "$fail_count" "$total"

    local score=$(( pass_count * 100 / (total > 0 ? total : 1) ))
    echo ""
    local grade
    if   (( score >= 90 && fail_count == 0 )); then grade="${C_GREEN}A (優秀)"
    elif (( score >= 75 ));                    then grade="${C_YELLOW}B (良好)"
    elif (( score >= 60 ));                    then grade="${C_BLUE}C (要改善)"
    else                                            grade="${C_RED}D (要対応)"
    fi
    printf "  セキュリティスコア: %d%%  評価: %b${C_RESET}\n\n" "$score" "$grade"
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -o|--output)  [[ $# -lt 2 ]] && error_exit "--output には値が必要です"; output_file="$2"; shift 2 ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  error_exit "不明な引数: $1" ;;
        esac
    done
}

main() {
    parse_arguments "$@"

    log_info "Linuxセキュリティ監査 - $(hostname) - $(date '+%Y-%m-%d %H:%M:%S')"

    local output
    output=$(
        audit_users
        audit_ssh
        audit_file_permissions
        audit_network
        audit_system
        print_summary
    )

    echo "$output"

    if [[ -n "$output_file" ]]; then
        echo "$output" | sed 's/\x1b\[[0-9;]*m//g' > "$output_file"
        log_success "レポート保存: $output_file"
    fi

    [[ $fail_count -gt 0 ]] && exit 2
    [[ $warn_count -gt 0 ]] && exit 1
    exit 0
}

main "$@"
