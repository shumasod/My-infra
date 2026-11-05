#!/bin/bash
set -euo pipefail

#
# 権限昇格脆弱性チェックツール
# 作成日: 2026-11-02
# バージョン: 1.0
#
# 脆弱性対応: 権限昇格に繋がる設定・コードの検出
# CVE該当: CWE-269 (Improper Privilege Management), CWE-250 (Execution with Unnecessary Privileges)
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare command_name="check"

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション]

権限昇格脆弱性を検出します。

コマンド:
  check                権限昇格脆弱性チェック (デフォルト)
  sudo-misconfig       sudo設定ミスの検出
  suid-scan            危険なSUID/SGIDビット検出
  cron-check           cron設定の権限確認
  env-path             環境変数PATHのハイジャック確認
  writable-paths       書き込み可能なシステムパス検出

オプション:
  -h, --help           このヘルプを表示
  -v, --version        バージョン情報を表示

脆弱性概要:
  CWE-269: 不適切な権限管理
  CWE-250: 不必要な権限での実行
  CWE-732: 不正なパーミッション設定
EOF
}

cmd_check() {
    log_info "権限昇格脆弱性チェック"
    echo ""

    printf "${C_BOLD}【現在のユーザー権限】${C_RESET}\n\n"
    local current_user current_groups
    current_user=$(whoami)
    current_groups=$(id)
    printf "  %s\n\n" "$current_groups"

    # sudo 権限確認
    printf "${C_BOLD}【sudo権限】${C_RESET}\n\n"
    if sudo -l 2>/dev/null | grep -q "NOPASSWD"; then
        local nopasswd_cmds
        nopasswd_cmds=$(sudo -l 2>/dev/null | grep "NOPASSWD" || true)
        printf "  ${C_YELLOW}[警告] NOPASSWDの権限があります:\n${C_RESET}"
        echo "$nopasswd_cmds" | while IFS= read -r line; do
            printf "    %s\n" "$line"
        done
    elif sudo -l 2>/dev/null | grep -q "(ALL)"; then
        printf "  ${C_RED}[危険] ALL権限のsudoが設定されています${C_RESET}\n"
    else
        printf "  ${C_GREEN}[正常] 制限されたsudo権限${C_RESET}\n"
    fi
    echo ""

    # 書き込み可能なcron
    printf "${C_BOLD}【crontab権限】${C_RESET}\n\n"
    for cron_dir in /etc/cron.d /etc/cron.daily /etc/cron.hourly /etc/cron.weekly; do
        if [[ -d "$cron_dir" ]]; then
            local perms
            perms=$(stat -c "%a %U:%G" "$cron_dir" 2>/dev/null || echo "???")
            printf "  %-30s %s\n" "$cron_dir" "$perms"
        fi
    done
    echo ""

    # PATH ハイジャック確認
    printf "${C_BOLD}【PATH設定確認】${C_RESET}\n\n"
    IFS=: read -ra path_dirs <<< "$PATH"
    for dir in "${path_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            local perms
            perms=$(stat -c "%a %U:%G" "$dir" 2>/dev/null || echo "???")
            if [[ -w "$dir" && "$dir" != "/usr/"* && "$dir" != "/bin" && "$dir" != "/sbin" ]]; then
                printf "  ${C_RED}[危険]${C_RESET} %-30s %s\n" "$dir" "$perms"
            else
                printf "  ${C_DIM}[OK]${C_RESET} %-30s %s\n" "$dir" "$perms"
            fi
        fi
    done
    echo ""
}

cmd_sudo_misconfig() {
    log_info "sudo設定ミス検出"
    echo ""

    if [[ ! -f /etc/sudoers ]]; then
        log_warning "/etc/sudoers が見つかりません"
        return
    fi

    python3 - <<'PYEOF'
import subprocess, re

RED    = "\033[1;31m"
YELLOW = "\033[1;33m"
GREEN  = "\033[1;32m"
RESET  = "\033[0m"
BOLD   = "\033[1m"

try:
    result = subprocess.run(['sudo', '-l'], capture_output=True, text=True, timeout=5)
    output = result.stdout
except:
    output = ""

dangerous_patterns = [
    (r'\(ALL\)\s+ALL',                     "すべてのコマンドを実行可能", "CRITICAL"),
    (r'NOPASSWD:\s+ALL',                   "パスワードなしで全コマンド実行", "CRITICAL"),
    (r'NOPASSWD.*(?:bash|sh|zsh|fish)',    "パスワードなしでシェル実行", "CRITICAL"),
    (r'NOPASSWD.*(?:vim|nano|less|more)',  "パスワードなしでエディタ実行", "HIGH"),
    (r'NOPASSWD.*(?:find|awk|python|perl)', "パスワードなしでスクリプト実行", "HIGH"),
    (r'NOPASSWD.*(?:chmod|chown)',          "パスワードなしでパーミッション変更", "HIGH"),
    (r'NOPASSWD.*(?:wget|curl)',            "パスワードなしでファイルダウンロード", "MEDIUM"),
    (r'!authenticate',                      "認証バイパス (!authenticate)", "HIGH"),
]

findings = []
for line in output.splitlines():
    for pat, desc, sev in dangerous_patterns:
        if re.search(pat, line, re.IGNORECASE):
            findings.append((line.strip(), desc, sev))
            break

if findings:
    print(f"  {BOLD}【危険なsudo設定を検出】{RESET}\n")
    for line, desc, sev in findings:
        color = "\033[1;35m" if sev == "CRITICAL" else (RED if sev == "HIGH" else YELLOW)
        print(f"  {color}[{sev}]{RESET} {desc}")
        print(f"    設定: {line}")
        print()
else:
    print(f"  {GREEN}危険なsudo設定は検出されませんでした{RESET}")
PYEOF
    echo ""
}

cmd_suid_scan() {
    log_info "危険なSUID/SGIDファイル検出"
    echo ""

    # 正当なSUIDファイルリスト
    local legitimate=(
        "/usr/bin/sudo" "/usr/bin/passwd" "/usr/bin/su"
        "/usr/bin/ping" "/usr/bin/mount" "/usr/bin/umount"
        "/usr/lib/openssh/ssh-keysign" "/usr/bin/newgrp"
        "/usr/bin/chfn" "/usr/bin/chsh" "/usr/bin/gpasswd"
    )

    printf "${C_BOLD}【非標準SUIDファイル】${C_RESET}\n\n"
    local suspicious=0
    while IFS= read -r file; do
        local is_legit=0
        for legit in "${legitimate[@]}"; do
            [[ "$file" == "$legit" ]] && is_legit=1 && break
        done

        if (( ! is_legit )); then
            local owner perms
            owner=$(stat -c "%U:%G" "$file" 2>/dev/null || echo "???")
            perms=$(stat -c "%a" "$file" 2>/dev/null || echo "???")
            printf "  ${C_RED}[要確認]${C_RESET} %-45s %s (%s)\n" "$file" "$perms" "$owner"
            (( suspicious++ ))
        fi
    done < <(find / -type f \( -perm -4000 -o -perm -2000 \) 2>/dev/null | sort)

    if [[ "$suspicious" -eq 0 ]]; then
        log_success "非標準SUIDファイルなし"
    else
        log_warning "$suspicious 件の非標準SUIDファイルを検出"
    fi
    echo ""
}

cmd_cron_check() {
    log_info "cron設定権限確認"
    echo ""

    printf "${C_BOLD}【crontabファイル確認】${C_RESET}\n\n"

    # システムcrontab
    for cron_file in /etc/crontab /etc/cron.d/*; do
        [[ ! -f "$cron_file" ]] && continue
        local perms owner
        perms=$(stat -c "%a" "$cron_file" 2>/dev/null || echo "???")
        owner=$(stat -c "%U:%G" "$cron_file" 2>/dev/null || echo "???")
        printf "  %-45s %s (%s)\n" "$cron_file" "$perms" "$owner"

        # world-writable チェック
        if [[ "${perms: -1}" =~ [2367] ]]; then
            printf "  ${C_RED}[危険] world-writableなcron設定ファイル${C_RESET}\n"
        fi
    done

    echo ""
    printf "${C_BOLD}【cronジョブ内の危険なパターン】${C_RESET}\n\n"

    grep -rn "chmod\|chown\|bash.*-i\|nc\|ncat\|socat" /etc/cron* 2>/dev/null | \
    while IFS= read -r line; do
        printf "  ${C_YELLOW}[要確認]${C_RESET} %s\n" "$line"
    done || printf "  ${C_GREEN}危険なパターンなし${C_RESET}\n"
    echo ""
}

cmd_env_path() {
    log_info "PATH環境変数ハイジャック確認"
    echo ""

    printf "${C_BOLD}【PATH ディレクトリ書き込み権限確認】${C_RESET}\n\n"

    # 相対パスの確認
    if echo "$PATH" | grep -q "^\.\|:\."; then
        printf "  ${C_RED}[CRITICAL] PATH に相対パス(.)が含まれています${C_RESET}\n"
    fi

    # 書き込み可能パス確認
    IFS=: read -ra path_dirs <<< "$PATH"
    local writable=0
    for dir in "${path_dirs[@]}"; do
        if [[ -d "$dir" && -w "$dir" ]]; then
            printf "  ${C_RED}[危険]${C_RESET} 書き込み可能: %s\n" "$dir"
            (( writable++ ))
        fi
    done

    if [[ "$writable" -eq 0 ]]; then
        log_success "書き込み可能なPATHディレクトリなし"
    else
        log_warning "$writable 件の書き込み可能PATHディレクトリ"
    fi
    echo ""
}

cmd_writable_paths() {
    log_info "書き込み可能なシステムパス検出"
    echo ""

    local system_dirs=("/etc" "/usr/bin" "/usr/sbin" "/bin" "/sbin" "/lib" "/usr/lib")

    for dir in "${system_dirs[@]}"; do
        [[ ! -d "$dir" ]] && continue
        local writable_count
        writable_count=$(find "$dir" -maxdepth 1 -writable 2>/dev/null | wc -l)
        if [[ "$writable_count" -gt 0 ]]; then
            printf "  ${C_RED}[危険]${C_RESET} %-20s 書き込み可能ファイル: %s\n" "$dir" "$writable_count"
            find "$dir" -maxdepth 1 -writable 2>/dev/null | head -5 | \
            while IFS= read -r f; do
                printf "    %s\n" "$f"
            done
        else
            printf "  ${C_GREEN}[OK]${C_RESET} %s\n" "$dir"
        fi
    done
    echo ""
}

parse_arguments() {
    [[ $# -eq 0 ]] && return 0
    case "$1" in
        check|sudo-misconfig|suid-scan|cron-check|env-path|writable-paths)
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
        check)           cmd_check ;;
        sudo-misconfig)  cmd_sudo_misconfig ;;
        suid-scan)       cmd_suid_scan ;;
        cron-check)      cmd_cron_check ;;
        env-path)        cmd_env_path ;;
        writable-paths)  cmd_writable_paths ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
