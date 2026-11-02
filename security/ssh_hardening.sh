#!/bin/bash
set -euo pipefail

#
# SSH強化ツール
# 作成日: 2026-11-02
# バージョン: 1.0
#
# 脆弱性対応: SSH設定の脆弱性検出・強化
# CVE該当: CWE-521 (Weak Password), CWE-284 (Improper Access Control)
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare command_name="audit"
declare fix_mode=0
readonly SSHD_CONFIG="${SSHD_CONFIG:-/etc/ssh/sshd_config}"

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション]

SSH設定のセキュリティ強化ツールです。

コマンド:
  audit                SSH設定の脆弱性監査 (デフォルト)
  keys                 SSHキーの監査
  authorized           authorized_keysの検査
  brute-force          ブルートフォース攻撃の痕跡確認
  config-fix           sshd_config の修正提案
  report               総合セキュリティレポート

オプション:
  -h, --help           このヘルプを表示
  -v, --version        バージョン情報を表示
  --fix                自動修正モード (要root)

脆弱性概要:
  - パスワード認証の有効化
  - rootログインの許可
  - 弱い暗号アルゴリズムの使用
  - 認証試行回数の制限なし
EOF
}

check_sshd_setting() {
    local key="$1"
    local config="${SSHD_CONFIG}"

    if [[ ! -f "$config" ]]; then
        echo "N/A"
        return
    fi

    local val
    val=$(grep -iE "^\s*${key}\s+" "$config" 2>/dev/null | tail -1 | awk '{print $2}' || echo "")
    echo "${val:-default}"
}

cmd_audit() {
    log_info "SSH設定セキュリティ監査"
    echo ""

    if [[ ! -f "$SSHD_CONFIG" ]]; then
        log_warning "sshd_config が見つかりません: $SSHD_CONFIG"
        echo ""
    fi

    printf "${C_BOLD}【重要なSSH設定】${C_RESET}\n\n"

    local checks=(
        "PermitRootLogin:no:rootログイン禁止:HIGH"
        "PasswordAuthentication:no:パスワード認証無効化:HIGH"
        "PermitEmptyPasswords:no:空パスワード禁止:CRITICAL"
        "ChallengeResponseAuthentication:no:チャレンジレスポンス無効:MEDIUM"
        "UsePAM:yes:PAM認証使用:MEDIUM"
        "X11Forwarding:no:X11フォワーディング無効:MEDIUM"
        "MaxAuthTries:3:最大認証試行回数:HIGH"
        "LoginGraceTime:30:ログイン猶予時間:MEDIUM"
        "Protocol:2:SSHプロトコルバージョン:CRITICAL"
        "AllowTcpForwarding:no:TCPフォワーディング制限:LOW"
        "ClientAliveInterval:300:クライアント生存確認:LOW"
        "IgnoreRhosts:yes:rhosts無視:HIGH"
        "HostbasedAuthentication:no:ホストベース認証無効:HIGH"
    )

    for check in "${checks[@]}"; do
        local key expected desc sev
        key=$(echo "$check" | cut -d: -f1)
        expected=$(echo "$check" | cut -d: -f2)
        desc=$(echo "$check" | cut -d: -f3)
        sev=$(echo "$check" | cut -d: -f4)

        local actual
        actual=$(check_sshd_setting "$key")

        printf "  %-30s " "$desc ($key):"
        if [[ "${actual,,}" == "${expected,,}" ]]; then
            printf "${C_GREEN}[OK] %s${C_RESET}\n" "$actual"
        elif [[ "$actual" == "default" || "$actual" == "N/A" ]]; then
            printf "${C_DIM}[未設定] デフォルト値${C_RESET}\n"
        else
            local color
            case "$sev" in
                CRITICAL) color="$C_MAGENTA" ;;
                HIGH)     color="$C_RED" ;;
                *)        color="$C_YELLOW" ;;
            esac
            printf "${color}[${sev}] %s (推奨: %s)${C_RESET}\n" "$actual" "$expected"
        fi
    done
    echo ""

    # 暗号アルゴリズム確認
    printf "${C_BOLD}【暗号アルゴリズム】${C_RESET}\n\n"
    local weak_ciphers=("arcfour" "blowfish" "cast128" "3des" "des")
    local ciphers_line
    ciphers_line=$(grep -iE "^\s*Ciphers\s+" "$SSHD_CONFIG" 2>/dev/null || echo "")

    if [[ -n "$ciphers_line" ]]; then
        for weak in "${weak_ciphers[@]}"; do
            if echo "$ciphers_line" | grep -qi "$weak"; then
                printf "  ${C_RED}[CRITICAL] 弱い暗号アルゴリズム検出: %s${C_RESET}\n" "$weak"
            fi
        done
    else
        printf "  ${C_DIM}Ciphers 設定なし (デフォルトを使用)${C_RESET}\n"
    fi
    echo ""
}

cmd_keys() {
    log_info "SSHキー監査"
    echo ""

    printf "${C_BOLD}【ホストキー確認】${C_RESET}\n\n"
    local key_files=("/etc/ssh/ssh_host_rsa_key" "/etc/ssh/ssh_host_ed25519_key" "/etc/ssh/ssh_host_ecdsa_key")
    for key in "${key_files[@]}"; do
        if [[ -f "$key" ]]; then
            local perms
            perms=$(stat -c "%a" "$key" 2>/dev/null || echo "???")
            local key_type
            key_type=$(ssh-keygen -l -f "$key" 2>/dev/null | awk '{print $1, $4}' || echo "N/A")
            printf "  %-40s " "$key"
            if [[ "$perms" == "600" ]]; then
                printf "${C_GREEN}[%s OK] %s${C_RESET}\n" "$perms" "$key_type"
            else
                printf "${C_RED}[%s 危険! 要600] %s${C_RESET}\n" "$perms" "$key_type"
            fi
        fi
    done
    echo ""

    printf "${C_BOLD}【RSAキー強度確認 (2048bit以上推奨)】${C_RESET}\n\n"
    find /home /root -name "id_rsa.pub" -o -name "*.pub" 2>/dev/null | head -20 | \
    while IFS= read -r pubkey; do
        local bits
        bits=$(ssh-keygen -l -f "$pubkey" 2>/dev/null | awk '{print $1}' || echo "0")
        printf "  %-50s " "$pubkey"
        if [[ "$bits" -ge 2048 ]] 2>/dev/null; then
            printf "${C_GREEN}[%s bit OK]${C_RESET}\n" "$bits"
        elif [[ "$bits" -gt 0 ]] 2>/dev/null; then
            printf "${C_RED}[%s bit 弱い!]${C_RESET}\n" "$bits"
        else
            printf "${C_DIM}[解析不可]${C_RESET}\n"
        fi
    done
    echo ""
}

cmd_authorized() {
    log_info "authorized_keys 検査"
    echo ""

    local count=0
    while IFS= read -r auth_file; do
        (( count++ ))
        local owner
        owner=$(stat -c "%U" "$auth_file" 2>/dev/null || echo "unknown")
        local perms
        perms=$(stat -c "%a" "$auth_file" 2>/dev/null || echo "???")
        local lines
        lines=$(wc -l < "$auth_file" 2>/dev/null || echo "0")

        printf "${C_BOLD}%s${C_RESET}\n" "$auth_file"
        printf "  所有者: %s, パーミッション: %s, 登録キー数: %s\n" "$owner" "$perms" "$lines"

        if [[ "$perms" != "600" && "$perms" != "640" ]]; then
            printf "  ${C_RED}[危険] パーミッションが不適切 (推奨: 600)${C_RESET}\n"
        fi

        # command= オプションの確認
        local restricted
        restricted=$(grep -c "^command=" "$auth_file" 2>/dev/null || true)
        if [[ "$restricted" -gt 0 ]]; then
            printf "  ${C_GREEN}[良好] %s キーにコマンド制限あり${C_RESET}\n" "$restricted"
        fi
        echo ""
    done < <(find /home /root -name "authorized_keys" 2>/dev/null)

    [[ "$count" -eq 0 ]] && printf "  ${C_DIM}authorized_keys ファイルが見つかりません${C_RESET}\n\n"
}

cmd_brute_force() {
    log_info "SSHブルートフォース攻撃痕跡確認"
    echo ""

    local auth_log=""
    for log in /var/log/auth.log /var/log/secure /var/log/messages; do
        [[ -f "$log" ]] && auth_log="$log" && break
    done

    if [[ -z "$auth_log" ]]; then
        log_warning "認証ログが見つかりません"
        return
    fi

    printf "${C_BOLD}【失敗ログイン試行 (上位10 IP)】${C_RESET}\n\n"
    grep "Failed password" "$auth_log" 2>/dev/null | \
    grep -oE "from [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | \
    sort | uniq -c | sort -rn | head -10 | \
    while IFS= read -r line; do
        local count ip
        count=$(echo "$line" | awk '{print $1}')
        ip=$(echo "$line" | awk '{print $2}')
        local bar
        bar=$(printf '%0.s█' $(seq 1 $((count > 20 ? 20 : count))))
        printf "  ${C_RED}%-18s${C_RESET}  %4s回  ${C_RED}%s${C_RESET}\n" "$ip" "$count" "$bar"
    done

    echo ""
    local total_failed
    total_failed=$(grep -c "Failed password" "$auth_log" 2>/dev/null || echo 0)
    printf "  合計失敗試行数: ${C_RED}%s${C_RESET}\n" "$total_failed"
    echo ""
}

cmd_config_fix() {
    log_info "sshd_config 推奨設定"
    echo ""

    cat <<'RECOMMENDED_CONFIG'
# SSHセキュリティ強化設定 (推奨)
# /etc/ssh/sshd_config に追記または変更してください

# プロトコルバージョン
Protocol 2

# rootログイン禁止
PermitRootLogin no

# パスワード認証無効化 (公開鍵認証を使用)
PasswordAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no

# 認証試行回数制限
MaxAuthTries 3
LoginGraceTime 30

# セッション管理
ClientAliveInterval 300
ClientAliveCountMax 3
MaxStartups 10:30:60

# 不要機能の無効化
X11Forwarding no
AllowTcpForwarding no
GatewayPorts no
PermitUserEnvironment no
IgnoreRhosts yes
HostbasedAuthentication no

# 強力な暗号アルゴリズム
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org

# ログ設定
LogLevel VERBOSE
SyslogFacility AUTH

RECOMMENDED_CONFIG

    log_success "設定を適用後: systemctl restart sshd"
    echo ""
}

parse_arguments() {
    [[ $# -eq 0 ]] && return 0
    case "$1" in
        audit|keys|authorized|brute-force|config-fix|report)
            command_name="$1"; shift ;;
    esac

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            --fix)        fix_mode=1; shift ;;
            -*) error_exit "不明なオプション: $1" ;;
            *) shift ;;
        esac
    done
}

main() {
    parse_arguments "$@"
    case "$command_name" in
        audit)      cmd_audit ;;
        keys)       cmd_keys ;;
        authorized) cmd_authorized ;;
        brute-force) cmd_brute_force ;;
        config-fix) cmd_config_fix ;;
        report)
            cmd_audit
            cmd_keys
            cmd_brute_force
            ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
