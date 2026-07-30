#!/bin/bash
set -euo pipefail

#
# Linuxセキュリティ強化チェックツール
# 作成日: 2026-07-30
# バージョン: 1.0
#
# Linux システムのセキュリティ設定をチェックし、改善提案を行います
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare command_name="check"
declare output_format="pretty"
declare report_file=""
declare fix_mode=false
declare category_filter=""

declare -i total_checks=0
declare -i passed=0
declare -i failed=0
declare -i warnings=0

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション]

Linuxシステムのセキュリティ強化チェックツールです。

コマンド:
  check                  全チェックを実行 (デフォルト)
  report                 HTMLレポートを生成
  list                   チェック項目一覧

オプション:
  -h, --help             このヘルプを表示
  -v, --version          バージョン情報を表示
  -o, --output <ファイル> レポート出力先
  --format <形式>        出力形式 (pretty|csv|json) [デフォルト: pretty]
  --category <カテゴリ>  チェックカテゴリ (ssh|kernel|users|network|services|filesystem)
  --fix                  可能な項目を自動修正 (要root)

例:
  $PROG_NAME
  $PROG_NAME check --category ssh
  $PROG_NAME report -o security_report.txt
EOF
}

check_result() {
    local category="$1"
    local name="$2"
    local status="$3"
    local detail="${4:-}"
    local fix="${5:-}"

    (( total_checks++ ))

    case "$status" in
        PASS)
            (( passed++ ))
            printf "  ${C_GREEN}[PASS]${C_RESET} %-40s\n" "$name"
            ;;
        FAIL)
            (( failed++ ))
            printf "  ${C_RED}[FAIL]${C_RESET} %-40s" "$name"
            [[ -n "$detail" ]] && printf " ${C_DIM}→ %s${C_RESET}" "$detail"
            echo ""
            [[ -n "$fix" ]] && printf "         ${C_YELLOW}修正案: %s${C_RESET}\n" "$fix"
            ;;
        WARN)
            (( warnings++ ))
            printf "  ${C_YELLOW}[WARN]${C_RESET} %-40s" "$name"
            [[ -n "$detail" ]] && printf " ${C_DIM}→ %s${C_RESET}" "$detail"
            echo ""
            [[ -n "$fix" ]] && printf "         ${C_DIM}推奨: %s${C_RESET}\n" "$fix"
            ;;
        SKIP)
            printf "  ${C_DIM}[SKIP]${C_RESET} %-40s ${C_DIM}(対象外)${C_RESET}\n" "$name"
            ;;
    esac
}

section() {
    local title="$1"
    echo ""
    printf "${C_BOLD}${C_CYAN}── %s ──${C_RESET}\n" "$title"
}

# SSHセキュリティチェック
check_ssh() {
    section "SSH設定"
    local ssh_conf="/etc/ssh/sshd_config"

    if [[ ! -f "$ssh_conf" ]]; then
        check_result "ssh" "SSH設定ファイル" "SKIP" "sshd_config が見つかりません"
        return
    fi

    local get() { grep -E "^[[:space:]]*$1" "$ssh_conf" 2>/dev/null | awk '{print $2}' | tail -1; }

    # rootログイン禁止
    local root_login
    root_login=$(get "PermitRootLogin")
    if [[ "${root_login,,}" == "no" || "${root_login,,}" == "prohibit-password" ]]; then
        check_result "ssh" "rootログイン禁止" "PASS"
    else
        check_result "ssh" "rootログイン禁止" "FAIL" "PermitRootLogin=${root_login:-yes}" \
            "PermitRootLogin no を設定"
    fi

    # パスワード認証
    local pass_auth
    pass_auth=$(get "PasswordAuthentication")
    if [[ "${pass_auth,,}" == "no" ]]; then
        check_result "ssh" "パスワード認証無効" "PASS"
    else
        check_result "ssh" "パスワード認証無効" "WARN" "PasswordAuthentication=${pass_auth:-yes}" \
            "公開鍵認証のみ使用する場合は no に設定"
    fi

    # SSHポート
    local ssh_port
    ssh_port=$(get "Port")
    if [[ "${ssh_port:-22}" != "22" ]]; then
        check_result "ssh" "デフォルトポート変更" "PASS" "Port=$ssh_port"
    else
        check_result "ssh" "デフォルトポート変更" "WARN" "Port=22" \
            "デフォルトポートは攻撃対象になりやすいです"
    fi

    # X11転送
    local x11
    x11=$(get "X11Forwarding")
    if [[ "${x11,,}" == "no" ]]; then
        check_result "ssh" "X11転送無効" "PASS"
    else
        check_result "ssh" "X11転送無効" "WARN" "X11Forwarding=${x11:-yes}" \
            "X11Forwarding no を設定"
    fi

    # MaxAuthTries
    local max_auth
    max_auth=$(get "MaxAuthTries")
    if [[ -n "$max_auth" && "$max_auth" -le 3 ]]; then
        check_result "ssh" "認証試行回数制限" "PASS" "MaxAuthTries=$max_auth"
    else
        check_result "ssh" "認証試行回数制限" "WARN" "MaxAuthTries=${max_auth:-6}" \
            "MaxAuthTries 3 を設定"
    fi

    # Protocol (SSH2のみ)
    local proto
    proto=$(get "Protocol")
    if [[ -z "$proto" || "$proto" == "2" ]]; then
        check_result "ssh" "SSH2プロトコル使用" "PASS"
    else
        check_result "ssh" "SSH2プロトコル使用" "FAIL" "Protocol=$proto" \
            "Protocol 2 を設定"
    fi
}

# カーネルパラメータチェック
check_kernel() {
    section "カーネルセキュリティ"

    sysctl_check() {
        local param="$1" expected="$2" name="$3" fix="$4"
        local val
        val=$(sysctl -n "$param" 2>/dev/null || echo "N/A")
        if [[ "$val" == "$expected" ]]; then
            check_result "kernel" "$name" "PASS" "$param=$val"
        else
            check_result "kernel" "$name" "FAIL" "$param=$val (期待値: $expected)" "$fix"
        fi
    }

    sysctl_check "net.ipv4.ip_forward" "0" "IPフォワーディング無効" \
        "net.ipv4.ip_forward=0 をsysctl.confに追加"
    sysctl_check "net.ipv4.conf.all.send_redirects" "0" "ICMPリダイレクト送信無効" \
        "net.ipv4.conf.all.send_redirects=0"
    sysctl_check "net.ipv4.conf.all.accept_redirects" "0" "ICMPリダイレクト受信無効" \
        "net.ipv4.conf.all.accept_redirects=0"
    sysctl_check "net.ipv4.conf.all.accept_source_route" "0" "ソースルーティング無効" \
        "net.ipv4.conf.all.accept_source_route=0"
    sysctl_check "net.ipv4.tcp_syncookies" "1" "SYNクッキー有効" \
        "net.ipv4.tcp_syncookies=1"
    sysctl_check "kernel.randomize_va_space" "2" "ASLR有効" \
        "kernel.randomize_va_space=2"
    sysctl_check "fs.suid_dumpable" "0" "SUIDダンプ無効" \
        "fs.suid_dumpable=0"

    # NXビット確認
    if grep -q " nx" /proc/cpuinfo 2>/dev/null; then
        check_result "kernel" "NXビット(DEP)対応CPU" "PASS"
    else
        check_result "kernel" "NXビット(DEP)対応CPU" "WARN" "CPUがNXビットをサポートしていません"
    fi
}

# ユーザー・認証チェック
check_users() {
    section "ユーザー・認証"

    # 空パスワードユーザー
    local empty_pass
    empty_pass=$(awk -F: '($2 == "" || $2 == "!") {print $1}' /etc/shadow 2>/dev/null | wc -l)
    if [[ $empty_pass -eq 0 ]]; then
        check_result "users" "空パスワードユーザーなし" "PASS"
    else
        check_result "users" "空パスワードユーザーなし" "FAIL" "${empty_pass}件のユーザーが空パスワード" \
            "passwd コマンドでパスワードを設定"
    fi

    # rootのUID=0ユーザー数
    local root_uid_count
    root_uid_count=$(awk -F: '$3 == 0 {print $1}' /etc/passwd 2>/dev/null | wc -l)
    if [[ $root_uid_count -le 1 ]]; then
        check_result "users" "UID=0はrootのみ" "PASS"
    else
        check_result "users" "UID=0はrootのみ" "FAIL" "UID=0のユーザーが${root_uid_count}件" \
            "不要なUID=0ユーザーを削除または変更"
    fi

    # パスワード有効期限ポリシー
    local max_days
    max_days=$(grep "^PASS_MAX_DAYS" /etc/login.defs 2>/dev/null | awk '{print $2}')
    if [[ -n "$max_days" && $max_days -le 90 ]]; then
        check_result "users" "パスワード有効期限設定" "PASS" "PASS_MAX_DAYS=$max_days"
    else
        check_result "users" "パスワード有効期限設定" "WARN" "PASS_MAX_DAYS=${max_days:-99999}" \
            "/etc/login.defs で PASS_MAX_DAYS 90 を設定"
    fi

    # sudoログ
    if grep -rq "logfile\|syslog" /etc/sudoers /etc/sudoers.d/ 2>/dev/null; then
        check_result "users" "sudoログ有効" "PASS"
    else
        check_result "users" "sudoログ有効" "WARN" "sudoのログ設定が見つかりません" \
            "/etc/sudoers に Defaults logfile=/var/log/sudo.log を追加"
    fi

    # ホームディレクトリのパーミッション
    local bad_home=0
    while IFS=: read -r user _ uid _ _ home _; do
        [[ $uid -lt 1000 ]] && continue
        [[ "$home" == "/dev/null" || ! -d "$home" ]] && continue
        local perm
        perm=$(stat -c "%a" "$home" 2>/dev/null || echo "")
        [[ -n "$perm" && "$perm" =~ [2367][0-9][0-9] ]] && (( bad_home++ )) || true
    done < /etc/passwd
    if [[ $bad_home -eq 0 ]]; then
        check_result "users" "ホームディレクトリの権限" "PASS"
    else
        check_result "users" "ホームディレクトリの権限" "WARN" "${bad_home}件のホームに書込権限あり" \
            "chmod 750 /home/* で適切に設定"
    fi
}

# ネットワークチェック
check_network() {
    section "ネットワーク"

    # ファイアウォール状態
    if command -v ufw &>/dev/null; then
        local ufw_status
        ufw_status=$(ufw status 2>/dev/null | head -1)
        if echo "$ufw_status" | grep -q "active"; then
            check_result "network" "UFWファイアウォール有効" "PASS"
        else
            check_result "network" "UFWファイアウォール有効" "FAIL" "$ufw_status" \
                "ufw enable を実行"
        fi
    elif command -v iptables &>/dev/null; then
        local rules_count
        rules_count=$(iptables -L 2>/dev/null | grep -vc "^Chain\|^target" || echo 0)
        if [[ $rules_count -gt 0 ]]; then
            check_result "network" "iptablesルール設定済み" "PASS" "${rules_count}件のルール"
        else
            check_result "network" "iptablesルール設定済み" "WARN" "iptablesルールが設定されていません" \
                "必要なルールを設定してください"
        fi
    else
        check_result "network" "ファイアウォール" "WARN" "ufwもiptablesも見つかりません"
    fi

    # リスニングポート確認
    local dangerous_ports=(23 513 514 2049)
    for port in "${dangerous_ports[@]}"; do
        if ss -tlnp 2>/dev/null | grep -q ":$port " || \
           netstat -tlnp 2>/dev/null | grep -q ":$port "; then
            check_result "network" "危険ポート$port(リスニング)" "FAIL" "ポート${port}が開いています" \
                "不要なサービスを停止: systemctl stop <service>"
        fi
    done
}

# サービスチェック
check_services() {
    section "サービス"

    local dangerous_services=(telnet rsh rlogin nis talk chargen daytime echo discard)
    for svc in "${dangerous_services[@]}"; do
        if systemctl is-active "$svc" &>/dev/null; then
            check_result "services" "危険サービス($svc)停止" "FAIL" "${svc}が動作中" \
                "systemctl disable --now $svc"
        fi
    done

    # 自動更新
    if systemctl is-active unattended-upgrades &>/dev/null || \
       systemctl is-active dnf-automatic &>/dev/null || \
       systemctl is-active yum-cron &>/dev/null; then
        check_result "services" "自動セキュリティ更新" "PASS"
    else
        check_result "services" "自動セキュリティ更新" "WARN" "自動更新が設定されていません" \
            "unattended-upgrades や dnf-automatic を設定"
    fi

    # NTP同期
    if timedatectl status 2>/dev/null | grep -q "synchronized: yes"; then
        check_result "services" "NTP時刻同期" "PASS"
    else
        check_result "services" "NTP時刻同期" "WARN" "時刻同期が確認できません" \
            "systemctl enable --now chronyd または ntpd"
    fi

    # auditd
    if systemctl is-active auditd &>/dev/null; then
        check_result "services" "auditd有効" "PASS"
    else
        check_result "services" "auditd有効" "WARN" "auditdが動作していません" \
            "systemctl enable --now auditd"
    fi
}

# ファイルシステムチェック
check_filesystem() {
    section "ファイルシステム"

    # SUID/SGIDファイル数
    local suid_count
    suid_count=$(find / -xdev \( -perm -4000 -o -perm -2000 \) -type f 2>/dev/null | wc -l)
    if [[ $suid_count -le 30 ]]; then
        check_result "filesystem" "SUID/SGIDファイル数" "PASS" "${suid_count}件"
    else
        check_result "filesystem" "SUID/SGIDファイル数" "WARN" "${suid_count}件のSUID/SGIDファイル" \
            "不要なSUID: chmod -s <file>"
    fi

    # /tmp のnoexec
    if mount | grep -q " /tmp " | grep -q "noexec" 2>/dev/null || \
       grep -q "^[^#].*\s/tmp\s.*noexec" /etc/fstab 2>/dev/null; then
        check_result "filesystem" "/tmp noexecマウント" "PASS"
    else
        check_result "filesystem" "/tmp noexecマウント" "WARN" "/tmpがnoexecでマウントされていません" \
            "/etc/fstab に noexec オプションを追加"
    fi

    # /etc/passwd パーミッション
    local passwd_perm
    passwd_perm=$(stat -c "%a" /etc/passwd 2>/dev/null || echo "")
    if [[ "$passwd_perm" == "644" ]]; then
        check_result "filesystem" "/etc/passwdの権限" "PASS" "644"
    else
        check_result "filesystem" "/etc/passwdの権限" "FAIL" "パーミッション: $passwd_perm" \
            "chmod 644 /etc/passwd"
    fi

    # /etc/shadow パーミッション
    local shadow_perm
    shadow_perm=$(stat -c "%a" /etc/shadow 2>/dev/null || echo "")
    if [[ "$shadow_perm" == "640" || "$shadow_perm" == "000" ]]; then
        check_result "filesystem" "/etc/shadowの権限" "PASS" "$shadow_perm"
    else
        check_result "filesystem" "/etc/shadowの権限" "WARN" "パーミッション: ${shadow_perm:-不明}" \
            "chmod 640 /etc/shadow"
    fi
}

cmd_check() {
    echo ""
    printf "${C_BOLD}${C_CYAN}╔══════════════════════════════════════════╗${C_RESET}\n"
    printf "${C_BOLD}${C_CYAN}║  Linuxセキュリティ強化チェック v%s   ║${C_RESET}\n" "$VERSION"
    printf "${C_BOLD}${C_CYAN}╚══════════════════════════════════════════╝${C_RESET}\n"
    echo ""
    printf "  ホスト: %s\n" "$(hostname)"
    printf "  実行日: %s\n\n" "$(get_timestamp)"

    local categories=("ssh" "kernel" "users" "network" "services" "filesystem")
    if [[ -n "$category_filter" ]]; then
        categories=("$category_filter")
    fi

    for cat in "${categories[@]}"; do
        case "$cat" in
            ssh)        check_ssh ;;
            kernel)     check_kernel ;;
            users)      check_users ;;
            network)    check_network ;;
            services)   check_services ;;
            filesystem) check_filesystem ;;
        esac
    done

    echo ""
    printf "${C_BOLD}═══ 結果サマリー ═══${C_RESET}\n"
    printf "  総チェック数: %d\n" "$total_checks"
    printf "  ${C_GREEN}合格 (PASS)${C_RESET}: %d\n" "$passed"
    printf "  ${C_YELLOW}警告 (WARN)${C_RESET}: %d\n" "$warnings"
    printf "  ${C_RED}不合格(FAIL)${C_RESET}: %d\n" "$failed"

    local score=0
    [[ $total_checks -gt 0 ]] && score=$(( (passed * 100) / total_checks ))

    echo ""
    printf "  セキュリティスコア: "
    if [[ $score -ge 80 ]]; then
        printf "${C_GREEN}${C_BOLD}%d%%${C_RESET} (良好)\n" "$score"
    elif [[ $score -ge 60 ]]; then
        printf "${C_YELLOW}${C_BOLD}%d%%${C_RESET} (要改善)\n" "$score"
    else
        printf "${C_RED}${C_BOLD}%d%%${C_RESET} (要対応)\n" "$score"
    fi
    echo ""
}

cmd_list() {
    printf "\n${C_BOLD}セキュリティチェック項目一覧${C_RESET}\n\n"
    printf "  ${C_CYAN}ssh${C_RESET}        : rootログイン, パスワード認証, ポート, X11転送, 認証試行数\n"
    printf "  ${C_CYAN}kernel${C_RESET}     : IPフォワーディング, ASLR, SYNクッキー, NXビット\n"
    printf "  ${C_CYAN}users${C_RESET}      : 空パスワード, UID=0確認, パスワードポリシー, sudo設定\n"
    printf "  ${C_CYAN}network${C_RESET}    : ファイアウォール, 危険ポート確認\n"
    printf "  ${C_CYAN}services${C_RESET}   : 危険サービス, 自動更新, NTP, auditd\n"
    printf "  ${C_CYAN}filesystem${C_RESET} : SUID/SGID数, /tmp noexec, /etc/passwd権限\n\n"
}

parse_arguments() {
    [[ $# -eq 0 ]] && return 0

    case "$1" in
        check|report|list)
            command_name="$1"; shift ;;
    esac

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -o|--output)
                [[ $# -lt 2 ]] && error_exit "--output には値が必要です"
                report_file="$2"; shift 2 ;;
            --format)
                [[ $# -lt 2 ]] && error_exit "--format には値が必要です"
                output_format="$2"; shift 2 ;;
            --category)
                [[ $# -lt 2 ]] && error_exit "--category には値が必要です"
                category_filter="$2"; shift 2 ;;
            --fix) fix_mode=true; shift ;;
            -*)  error_exit "不明なオプション: $1" ;;
            *)   shift ;;
        esac
    done
}

main() {
    parse_arguments "$@"

    case "$command_name" in
        check)
            if [[ -n "$report_file" ]]; then
                cmd_check | tee "$report_file"
                log_success "レポートを保存しました: $report_file"
            else
                cmd_check
            fi
            ;;
        list) cmd_list ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
