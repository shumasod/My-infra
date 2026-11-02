#!/bin/bash
set -euo pipefail

#
# ファイルパーミッション監査ツール
# 作成日: 2026-11-02
# バージョン: 1.0
#
# 脆弱性対応: 不適切なファイルパーミッション検出・修正
# CVE該当: CWE-732 (Incorrect Permission Assignment), CWE-276 (Incorrect Default Permissions)
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare command_name="audit"
declare target_path="."
declare fix_mode=0

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション]

ファイルパーミッションの脆弱性を監査・修正します。

コマンド:
  audit <パス>         パーミッション監査 (デフォルト)
  world-writable       world-writableファイル検出
  suid-sgid            SUID/SGIDファイル検出
  sensitive            機密ファイルのパーミッション確認
  scripts              スクリプトのパーミッション確認
  fix <パス>           危険なパーミッションを修正

オプション:
  -h, --help           このヘルプを表示
  -v, --version        バージョン情報を表示
  --fix                自動修正モード
EOF
}

cmd_audit() {
    local path="${1:-$target_path}"
    log_info "ファイルパーミッション監査: $path"
    echo ""

    local ww_count suid_count sgid_count no_owner
    ww_count=$(find "$path" -perm -o+w -not -type l 2>/dev/null | wc -l)
    suid_count=$(find "$path" -perm -4000 2>/dev/null | wc -l)
    sgid_count=$(find "$path" -perm -2000 2>/dev/null | wc -l)
    no_owner=$(find "$path" -nouser -o -nogroup 2>/dev/null | wc -l)

    printf "${C_BOLD}【パーミッション統計】${C_RESET}\n\n"
    printf "  %-30s " "world-writable ファイル:"
    [[ "$ww_count" -gt 0 ]] && printf "${C_RED}%s${C_RESET}\n" "$ww_count" || printf "${C_GREEN}0${C_RESET}\n"

    printf "  %-30s " "SUID ファイル:"
    [[ "$suid_count" -gt 0 ]] && printf "${C_YELLOW}%s${C_RESET}\n" "$suid_count" || printf "${C_GREEN}0${C_RESET}\n"

    printf "  %-30s " "SGID ファイル:"
    [[ "$sgid_count" -gt 0 ]] && printf "${C_YELLOW}%s${C_RESET}\n" "$sgid_count" || printf "${C_GREEN}0${C_RESET}\n"

    printf "  %-30s " "オーナー不明ファイル:"
    [[ "$no_owner" -gt 0 ]] && printf "${C_RED}%s${C_RESET}\n" "$no_owner" || printf "${C_GREEN}0${C_RESET}\n"
    echo ""

    if [[ "$ww_count" -gt 0 ]]; then
        printf "${C_BOLD}${C_RED}【world-writable ファイル (上位10件)】${C_RESET}\n\n"
        find "$path" -perm -o+w -not -type l 2>/dev/null | head -10 | \
        while IFS= read -r f; do
            local perms owner
            perms=$(stat -c "%a" "$f" 2>/dev/null || echo "???")
            owner=$(stat -c "%U:%G" "$f" 2>/dev/null || echo "???")
            printf "  ${C_RED}[%s]${C_RESET} %s (%s)\n" "$perms" "$f" "$owner"
        done
        echo ""
    fi
}

cmd_world_writable() {
    log_info "world-writableファイル検出"
    echo ""

    local count=0
    while IFS= read -r file; do
        (( count++ ))
        local perms owner
        perms=$(stat -c "%a %A" "$file" 2>/dev/null || echo "???")
        owner=$(stat -c "%U:%G" "$file" 2>/dev/null || echo "???")
        printf "  ${C_RED}[危険]${C_RESET} %-50s %s %s\n" "$file" "$perms" "$owner"

        if (( fix_mode )); then
            chmod o-w "$file" && printf "    ${C_GREEN}→ 修正完了 (o-w)${C_RESET}\n"
        fi
    done < <(find "${1:-.}" -perm -o+w -not -type l -not -type d 2>/dev/null)

    if [[ "$count" -eq 0 ]]; then
        log_success "world-writableファイルなし"
    else
        log_warning "$count 件の world-writableファイルを検出"
        (( fix_mode )) || log_info "--fix オプションで自動修正できます"
    fi
    echo ""
}

cmd_suid_sgid() {
    log_info "SUID/SGIDファイル検出"
    echo ""

    local known_suid=("/usr/bin/sudo" "/usr/bin/passwd" "/usr/bin/su" "/usr/bin/ping")

    printf "${C_BOLD}SUID ファイル:${C_RESET}\n"
    while IFS= read -r file; do
        local is_known=0
        for k in "${known_suid[@]}"; do
            [[ "$file" == "$k" ]] && is_known=1 && break
        done
        local perms owner
        perms=$(stat -c "%a" "$file" 2>/dev/null || echo "???")
        owner=$(stat -c "%U" "$file" 2>/dev/null || echo "???")
        if (( is_known )); then
            printf "  ${C_GREEN}[既知]${C_RESET} %-40s %s (%s)\n" "$file" "$perms" "$owner"
        else
            printf "  ${C_YELLOW}[要確認]${C_RESET} %-40s %s (%s)\n" "$file" "$perms" "$owner"
        fi
    done < <(find / -perm -4000 2>/dev/null | head -30)

    echo ""
    printf "${C_BOLD}SGID ファイル:${C_RESET}\n"
    find / -perm -2000 2>/dev/null | head -20 | while IFS= read -r file; do
        local perms owner
        perms=$(stat -c "%a" "$file" 2>/dev/null || echo "???")
        owner=$(stat -c "%G" "$file" 2>/dev/null || echo "???")
        printf "  ${C_YELLOW}[SGID]${C_RESET} %-40s %s (%s)\n" "$file" "$perms" "$owner"
    done
    echo ""
}

cmd_sensitive() {
    log_info "機密ファイルのパーミッション確認"
    echo ""

    local sensitive_files=(
        "/etc/passwd:644:ユーザーデータベース"
        "/etc/shadow:640:パスワードハッシュ"
        "/etc/sudoers:440:sudo設定"
        "/etc/ssh/sshd_config:600:SSH設定"
        "/root/.ssh:700:rootのSSHディレクトリ"
        "/root/.ssh/authorized_keys:600:SSH認証済みキー"
        "/etc/ssl/private:700:SSL秘密鍵ディレクトリ"
    )

    for entry in "${sensitive_files[@]}"; do
        local fpath="${entry%%:*}"
        local rest="${entry#*:}"
        local expected_perm="${rest%%:*}"
        local desc="${rest##*:}"

        [[ ! -e "$fpath" ]] && continue

        local actual_perm
        actual_perm=$(stat -c "%a" "$fpath" 2>/dev/null || echo "???")

        printf "  %-35s " "$fpath ($desc)"
        if [[ "$actual_perm" == "$expected_perm" ]]; then
            printf "${C_GREEN}[%s OK]${C_RESET}\n" "$actual_perm"
        elif [[ "$actual_perm" -le "$expected_perm" ]] 2>/dev/null; then
            printf "${C_GREEN}[%s (期待値:%s)]${C_RESET}\n" "$actual_perm" "$expected_perm"
        else
            printf "${C_RED}[%s 危険! 期待値:%s]${C_RESET}\n" "$actual_perm" "$expected_perm"
        fi
    done
    echo ""
}

cmd_scripts() {
    local path="${1:-.}"
    log_info "スクリプトパーミッション確認: $path"
    echo ""

    local issues=0
    while IFS= read -r file; do
        local perms
        perms=$(stat -c "%a" "$file" 2>/dev/null || echo "???")
        local perm_num="${perms: -3}"

        # other-writable スクリプト
        if [[ "${perm_num:2:1}" =~ [2367] ]]; then
            printf "  ${C_RED}[o+w]${C_RESET} %s (%s)\n" "$file" "$perms"
            (( issues++ ))
        fi
        # group-writable スクリプト
        if [[ "${perm_num:1:1}" =~ [2367] ]]; then
            printf "  ${C_YELLOW}[g+w]${C_RESET} %s (%s)\n" "$file" "$perms"
            (( issues++ ))
        fi
    done < <(find "$path" -name "*.sh" -type f 2>/dev/null)

    if [[ "$issues" -eq 0 ]]; then
        log_success "スクリプトのパーミッションは適切です"
    else
        log_warning "$issues 件のスクリプトに不適切なパーミッション"
    fi
    echo ""
}

cmd_fix() {
    local path="${1:-.}"
    fix_mode=1
    log_info "危険なパーミッション自動修正: $path"
    echo ""

    if ! confirm "world-writableファイルのパーミッションを修正しますか？"; then
        log_info "キャンセルしました"
        return
    fi

    local fixed=0
    while IFS= read -r file; do
        chmod o-w "$file" 2>/dev/null && {
            printf "  ${C_GREEN}[修正]${C_RESET} %s\n" "$file"
            (( fixed++ ))
        }
    done < <(find "$path" -perm -o+w -not -type l -not -type d 2>/dev/null)

    log_success "$fixed 件のファイルを修正しました"
    echo ""
}

parse_arguments() {
    [[ $# -eq 0 ]] && return 0
    case "$1" in
        audit|world-writable|suid-sgid|sensitive|scripts|fix)
            command_name="$1"; shift ;;
    esac

    local positional=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            --fix)        fix_mode=1; shift ;;
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
        audit)          cmd_audit         "${POSITIONAL[0]:-$target_path}" ;;
        world-writable) cmd_world_writable "${POSITIONAL[0]:-$target_path}" ;;
        suid-sgid)      cmd_suid_sgid ;;
        sensitive)      cmd_sensitive ;;
        scripts)        cmd_scripts       "${POSITIONAL[0]:-$target_path}" ;;
        fix)            cmd_fix           "${POSITIONAL[0]:-$target_path}" ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
