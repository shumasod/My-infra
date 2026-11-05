#!/bin/bash
set -euo pipefail

#
# バックアップ整合性・暗号化検証ツール
# 作成日: 2026-11-05
# バージョン: 1.0
#
# 脆弱性対応: 暗号化されていないバックアップ・整合性未検証バックアップの検出
# CVE該当: CWE-311 (Missing Encryption of Sensitive Data), CWE-326 (Inadequate Encryption Strength)
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare command_name="audit"
declare backup_dir="${BACKUP_DIR:-/var/backup}"
declare max_age_days=30

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション]

バックアップのセキュリティ・整合性を検証します。

コマンド:
  audit        バックアップ総合監査 (デフォルト)
  verify       バックアップファイルの整合性検証
  encrypt-check  暗号化状態の確認
  age-check    バックアップの経過日数確認
  permissions  バックアップのパーミッション確認
  report       セキュリティレポート生成

オプション:
  -h, --help          このヘルプを表示
  -v, --version       バージョン情報を表示
  -d, --dir <パス>    バックアップディレクトリ [デフォルト: /var/backup]
  --max-age <日数>    最大保存日数 [デフォルト: 30]

脆弱性概要:
  CWE-311: 機密データの暗号化欠如
  CWE-326: 不十分な暗号強度
  対策: バックアップの暗号化とチェックサム検証
EOF
}

cmd_audit() {
    log_info "バックアップセキュリティ総合監査"
    echo ""
    cmd_encrypt_check
    cmd_age_check
    cmd_permissions
}

cmd_verify() {
    log_info "バックアップ整合性検証: $backup_dir"
    echo ""

    if [[ ! -d "$backup_dir" ]]; then
        log_warning "バックアップディレクトリが見つかりません: $backup_dir"
        return
    fi

    local verified=0 failed=0 no_checksum=0

    while IFS= read -r backup_file; do
        local checksum_file="${backup_file}.sha256"
        local md5_file="${backup_file}.md5"

        printf "  %-50s " "$(basename "$backup_file")"

        if [[ -f "$checksum_file" ]]; then
            if sha256sum -c "$checksum_file" &>/dev/null 2>&1; then
                printf "${C_GREEN}[SHA256 OK]${C_RESET}\n"
                (( verified++ ))
            else
                printf "${C_RED}[SHA256 MISMATCH - 改ざん検出!]${C_RESET}\n"
                (( failed++ ))
            fi
        elif [[ -f "$md5_file" ]]; then
            if md5sum -c "$md5_file" &>/dev/null 2>&1; then
                printf "${C_YELLOW}[MD5 OK (SHA256推奨)]${C_RESET}\n"
                (( verified++ ))
            else
                printf "${C_RED}[MD5 MISMATCH - 改ざん検出!]${C_RESET}\n"
                (( failed++ ))
            fi
        else
            printf "${C_YELLOW}[チェックサムなし]${C_RESET}\n"
            (( no_checksum++ ))
        fi
    done < <(find "$backup_dir" -maxdepth 2 -type f \
        \( -name "*.sql" -o -name "*.tar" -o -name "*.tar.gz" -o -name "*.tar.bz2" \
           -o -name "*.dump" -o -name "*.bak" \) 2>/dev/null | sort)

    echo ""
    printf "  検証済み: ${C_GREEN}%d${C_RESET}  失敗: ${C_RED}%d${C_RESET}  チェックサムなし: ${C_YELLOW}%d${C_RESET}\n\n" \
        "$verified" "$failed" "$no_checksum"

    if [[ "$failed" -gt 0 ]]; then
        log_error "整合性エラー: $failed 件のバックアップが改ざんされている可能性"
    fi
}

cmd_encrypt_check() {
    log_info "バックアップの暗号化状態確認"
    echo ""

    if [[ ! -d "$backup_dir" ]]; then
        log_warning "バックアップディレクトリが見つかりません: $backup_dir"
        return
    fi

    local encrypted=0 unencrypted=0

    while IFS= read -r backup_file; do
        local fname
        fname=$(basename "$backup_file")
        local is_encrypted=0

        # 暗号化拡張子確認
        if [[ "$fname" =~ \.(gpg|asc|enc|age)$ ]]; then
            is_encrypted=1
        fi

        # GPGヘッダー確認
        if [[ "$is_encrypted" -eq 0 ]] && command -v file &>/dev/null; then
            if file "$backup_file" 2>/dev/null | grep -q "PGP\|GPG"; then
                is_encrypted=1
            fi
        fi

        # OpenSSLヘッダー確認
        if [[ "$is_encrypted" -eq 0 ]]; then
            if head -c 8 "$backup_file" 2>/dev/null | grep -q "Salted__"; then
                is_encrypted=1
            fi
        fi

        local size
        size=$(stat -c "%s" "$backup_file" 2>/dev/null || echo 0)
        local size_human
        size_human=$(python3 -c "
s=$size
for u in ['B','KB','MB','GB']:
    if s<1024: print(f'{s:.0f}{u}'); break
    s/=1024
")

        printf "  %-45s %-8s " "$fname" "$size_human"
        if (( is_encrypted )); then
            printf "${C_GREEN}[暗号化済み]${C_RESET}\n"
            (( encrypted++ ))
        else
            printf "${C_RED}[平文 - 暗号化推奨]${C_RESET}\n"
            (( unencrypted++ ))
        fi
    done < <(find "$backup_dir" -maxdepth 2 -type f -not -name "*.sha256" -not -name "*.md5" 2>/dev/null | sort)

    echo ""
    printf "  暗号化済み: ${C_GREEN}%d${C_RESET}  平文: ${C_RED}%d${C_RESET}\n" "$encrypted" "$unencrypted"

    if [[ "$unencrypted" -gt 0 ]]; then
        echo ""
        printf "  ${C_CYAN}暗号化方法:${C_RESET}\n"
        printf "    GPG: gpg --cipher-algo AES256 --compress-algo none -c backup.tar.gz\n"
        printf "    OpenSSL: openssl enc -aes-256-cbc -salt -pbkdf2 -in backup.tar.gz -out backup.tar.gz.enc\n"
    fi
    echo ""
}

cmd_age_check() {
    log_info "バックアップ経過日数確認"
    echo ""

    if [[ ! -d "$backup_dir" ]]; then
        log_warning "バックアップディレクトリが見つかりません: $backup_dir"
        return
    fi

    local now
    now=$(date +%s)

    while IFS= read -r backup_file; do
        local mod_time
        mod_time=$(stat -c "%Y" "$backup_file" 2>/dev/null || echo 0)
        local age_days=$(( (now - mod_time) / 86400 ))
        local fname
        fname=$(basename "$backup_file")

        printf "  %-45s " "$fname"
        if (( age_days > max_age_days )); then
            printf "${C_RED}%d日前 (最大%d日: 要確認)${C_RESET}\n" "$age_days" "$max_age_days"
        elif (( age_days > max_age_days * 7 / 10 )); then
            printf "${C_YELLOW}%d日前 (要確認)${C_RESET}\n" "$age_days"
        else
            printf "${C_GREEN}%d日前 (正常)${C_RESET}\n" "$age_days"
        fi
    done < <(find "$backup_dir" -maxdepth 2 -type f \
        \( -name "*.sql*" -o -name "*.tar*" -o -name "*.dump*" -o -name "*.bak*" \) 2>/dev/null | sort)

    # 最新バックアップ確認
    local latest
    latest=$(find "$backup_dir" -maxdepth 2 -type f 2>/dev/null | xargs ls -t 2>/dev/null | head -1)
    if [[ -n "$latest" ]]; then
        local latest_mod
        latest_mod=$(stat -c "%Y" "$latest" 2>/dev/null || echo 0)
        local latest_age=$(( (now - latest_mod) / 86400 ))
        echo ""
        printf "  最新バックアップ: "
        if (( latest_age > 1 )); then
            printf "${C_YELLOW}%d日前${C_RESET}\n" "$latest_age"
        else
            printf "${C_GREEN}本日${C_RESET}\n"
        fi
    fi
    echo ""
}

cmd_permissions() {
    log_info "バックアップファイルのパーミッション確認"
    echo ""

    if [[ ! -d "$backup_dir" ]]; then
        log_warning "バックアップディレクトリが見つかりません: $backup_dir"
        return
    fi

    while IFS= read -r backup_file; do
        local perms owner
        perms=$(stat -c "%a" "$backup_file" 2>/dev/null || echo "???")
        owner=$(stat -c "%U:%G" "$backup_file" 2>/dev/null || echo "???")

        printf "  %-45s %s (%s) " "$(basename "$backup_file")" "$perms" "$owner"

        if [[ "${perms: -1}" -gt 0 ]] 2>/dev/null; then
            printf "${C_RED}[other読み取り可能]${C_RESET}\n"
        elif [[ "${perms:1:1}" =~ [4567] ]] 2>/dev/null; then
            printf "${C_YELLOW}[group読み取り可能]${C_RESET}\n"
        else
            printf "${C_GREEN}[OK]${C_RESET}\n"
        fi
    done < <(find "$backup_dir" -maxdepth 2 -type f 2>/dev/null | sort)
    echo ""
}

parse_arguments() {
    [[ $# -eq 0 ]] && return 0
    case "$1" in
        audit|verify|encrypt-check|age-check|permissions|report)
            command_name="$1"; shift ;;
    esac
    local positional=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -d|--dir)     [[ $# -lt 2 ]] && error_exit "--dir には値が必要です"; backup_dir="$2"; shift 2 ;;
            --max-age)    [[ $# -lt 2 ]] && error_exit "--max-age には値が必要です"; max_age_days="$2"; shift 2 ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  positional+=("$1"); shift ;;
        esac
    done
    POSITIONAL=("${positional[@]+"${positional[@]}"}")
}

declare -a POSITIONAL=()

main() {
    parse_arguments "$@"
    case "$command_name" in
        audit)         cmd_audit ;;
        verify)        cmd_verify ;;
        encrypt-check) cmd_encrypt_check ;;
        age-check)     cmd_age_check ;;
        permissions)   cmd_permissions ;;
        report)        cmd_audit ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
