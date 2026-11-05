#!/bin/bash
set -euo pipefail

#
# シークレット・ローテーション管理ツール
# 作成日: 2026-11-05
# バージョン: 1.0
#
# 脆弱性対応: 長期間未更新のシークレット・証明書の検出
# CVE該当: CWE-324 (Use of a Key Past its Expiration Date), CWE-321 (Use of Hard-coded Cryptographic Key)
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare command_name="audit"

# ローテーション推奨期間 (日数)
readonly SSH_KEY_MAX_AGE=365
readonly CERT_WARNING_DAYS=30
readonly API_KEY_MAX_AGE=90
readonly PASSWORD_MAX_AGE=90

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション]

シークレット・証明書のローテーション状態を管理します。

コマンド:
  audit        全シークレットの期限・使用状況監査 (デフォルト)
  ssh-keys     SSHキーの期限確認
  certs        SSL/TLS証明書の有効期限確認
  check-age    シークレットファイルの経過日数確認
  generate     新しいSSHキー・パスワード生成
  report       ローテーションレポート生成

オプション:
  -h, --help     このヘルプを表示
  -v, --version  バージョン情報を表示

脆弱性概要:
  CWE-324: 有効期限切れキーの使用
  CWE-321: ハードコードされた暗号鍵
  推奨: 定期的なシークレットのローテーション
EOF
}

days_since_modified() {
    local file="$1"
    local mod_time
    mod_time=$(stat -c "%Y" "$file" 2>/dev/null || echo 0)
    local now
    now=$(date +%s)
    echo $(( (now - mod_time) / 86400 ))
}

format_age_status() {
    local age="$1"
    local max_age="$2"

    if (( age > max_age )); then
        printf "${C_RED}%d日 (期限超過: %d日以内推奨)${C_RESET}" "$age" "$max_age"
    elif (( age > max_age * 8 / 10 )); then
        printf "${C_YELLOW}%d日 (要更新: %d日以内推奨)${C_RESET}" "$age" "$max_age"
    else
        printf "${C_GREEN}%d日 (正常)${C_RESET}" "$age"
    fi
}

cmd_audit() {
    log_info "シークレット・ローテーション総合監査"
    echo ""
    cmd_ssh_keys
    cmd_certs
    cmd_check_age
}

cmd_ssh_keys() {
    log_info "SSHキーのローテーション状態確認"
    echo ""

    printf "${C_BOLD}【SSHキーの経過日数】${C_RESET}\n\n"

    local found=0
    while IFS= read -r key_file; do
        [[ "$key_file" == *.pub ]] && continue
        local age
        age=$(days_since_modified "$key_file")
        local pub_file="${key_file}.pub"
        local key_type="unknown"
        [[ -f "$pub_file" ]] && key_type=$(ssh-keygen -l -f "$pub_file" 2>/dev/null | awk '{print $4}' || echo "unknown")

        printf "  %-45s %s (%s)\n" "$key_file" "$(format_age_status "$age" "$SSH_KEY_MAX_AGE")" "$key_type"
        (( found++ ))
    done < <(find /home /root /etc/ssh -name "id_*" -o -name "ssh_host_*_key" 2>/dev/null | grep -v "\.pub$" | sort)

    [[ "$found" -eq 0 ]] && printf "  ${C_DIM}SSHキーが見つかりません${C_RESET}\n"
    echo ""
}

cmd_certs() {
    log_info "SSL/TLS証明書の有効期限確認"
    echo ""

    if ! command -v openssl &>/dev/null; then
        log_warning "opensslが見つかりません"
        return
    fi

    printf "${C_BOLD}【証明書の有効期限】${C_RESET}\n\n"

    local found=0
    while IFS= read -r cert_file; do
        local expiry_str expiry_epoch days_remaining
        expiry_str=$(openssl x509 -noout -enddate -in "$cert_file" 2>/dev/null | cut -d= -f2 || echo "")
        [[ -z "$expiry_str" ]] && continue

        expiry_epoch=$(date -d "$expiry_str" +%s 2>/dev/null || date -j -f "%b %d %T %Y %Z" "$expiry_str" +%s 2>/dev/null || echo 0)
        local now
        now=$(date +%s)
        days_remaining=$(( (expiry_epoch - now) / 86400 ))

        local subject
        subject=$(openssl x509 -noout -subject -in "$cert_file" 2>/dev/null | sed 's/subject=//' | tr -d ' ' | cut -c1-40 || echo "N/A")

        printf "  %-45s " "$cert_file"
        if (( days_remaining < 0 )); then
            printf "${C_RED}[期限切れ: %d日前]${C_RESET}" "$(( -days_remaining ))"
        elif (( days_remaining < CERT_WARNING_DAYS )); then
            printf "${C_RED}[残り%d日: 要更新]${C_RESET}" "$days_remaining"
        elif (( days_remaining < CERT_WARNING_DAYS * 3 )); then
            printf "${C_YELLOW}[残り%d日: 要確認]${C_RESET}" "$days_remaining"
        else
            printf "${C_GREEN}[残り%d日]${C_RESET}" "$days_remaining"
        fi
        echo ""
        (( found++ ))
    done < <(find /etc/ssl /etc/nginx /etc/apache2 /etc/letsencrypt -name "*.pem" -o -name "*.crt" 2>/dev/null | sort)

    [[ "$found" -eq 0 ]] && printf "  ${C_DIM}証明書ファイルが見つかりません${C_RESET}\n"
    echo ""
}

cmd_check_age() {
    log_info "シークレットファイルの経過日数確認"
    echo ""

    local secret_locations=(
        "/etc/shadow"
        "/root/.aws/credentials"
        "$HOME/.aws/credentials"
        "$HOME/.ssh"
        "/etc/ssl/private"
    )

    printf "${C_BOLD}【シークレット関連ファイルの更新日時】${C_RESET}\n\n"

    for location in "${secret_locations[@]}"; do
        [[ ! -e "$location" ]] && continue
        local age
        age=$(days_since_modified "$location")
        local max_age=90

        printf "  %-40s " "$location"
        printf "%s\n" "$(format_age_status "$age" "$max_age")"
    done

    # ~/.env, .envrcの確認
    while IFS= read -r envfile; do
        local age
        age=$(days_since_modified "$envfile")
        printf "  %-40s " "$envfile"
        printf "%s\n" "$(format_age_status "$age" "$API_KEY_MAX_AGE")"
    done < <(find "$HOME" -maxdepth 2 -name ".env" -o -name ".envrc" 2>/dev/null)
    echo ""
}

cmd_generate() {
    log_info "新しいシークレット生成"
    echo ""

    printf "${C_BOLD}【ランダムパスワード生成】${C_RESET}\n\n"
    for len in 16 24 32; do
        local passwd
        passwd=$(openssl rand -base64 "$len" 2>/dev/null | tr -d '/' | head -c "$len" || \
                 cat /dev/urandom | tr -dc 'A-Za-z0-9!@#$%^&*' | head -c "$len")
        printf "  %2d文字: %s\n" "$len" "$passwd"
    done

    echo ""
    printf "${C_BOLD}【SSHキーペア生成コマンド】${C_RESET}\n\n"
    cat <<'SSHGEN'
  # Ed25519 (推奨 - より安全でコンパクト)
  ssh-keygen -t ed25519 -C "$(whoami)@$(hostname)-$(date +%Y%m%d)" -f ~/.ssh/id_ed25519_new

  # RSA 4096bit (互換性が必要な場合)
  ssh-keygen -t rsa -b 4096 -C "$(whoami)@$(hostname)-$(date +%Y%m%d)" -f ~/.ssh/id_rsa_new
SSHGEN

    echo ""
    printf "${C_BOLD}【APIキー生成 (ランダム)】${C_RESET}\n\n"
    printf "  32バイト hex: %s\n" "$(openssl rand -hex 32 2>/dev/null)"
    printf "  32バイト b64: %s\n" "$(openssl rand -base64 32 2>/dev/null | tr -d '=\n')"
    echo ""
}

cmd_report() {
    log_info "ローテーションレポート生成"
    echo ""

    local report_date
    report_date=$(date '+%Y-%m-%d %H:%M:%S')

    printf "${C_BOLD}=== シークレット・ローテーションレポート ===${C_RESET}\n"
    printf "生成日時: %s\n" "$report_date"
    printf "ホスト: %s\n\n" "$(hostname)"

    cmd_audit
}

parse_arguments() {
    [[ $# -eq 0 ]] && return 0
    case "$1" in
        audit|ssh-keys|certs|check-age|generate|report)
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
        audit)     cmd_audit ;;
        ssh-keys)  cmd_ssh_keys ;;
        certs)     cmd_certs ;;
        check-age) cmd_check_age ;;
        generate)  cmd_generate ;;
        report)    cmd_report ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
