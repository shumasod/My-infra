#!/bin/bash
set -euo pipefail

#
# cronジョブセキュリティ検査ツール
# 作成日: 2026-11-05
# バージョン: 1.0
#
# 脆弱性対応: cronジョブの設定ミスによる権限昇格・コードインジェクション検出
# CVE該当: CWE-732 (Incorrect Permission Assignment), CWE-269 (Improper Privilege Management)
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare command_name="audit"

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション]

cronジョブのセキュリティを検査します。

コマンド:
  audit        全cronジョブの監査 (デフォルト)
  scripts      cronから実行されるスクリプトの検査
  permissions  cronファイルのパーミッション確認
  injection    cronインジェクションの検出
  users        ユーザーcrontabの確認

オプション:
  -h, --help     このヘルプを表示
  -v, --version  バージョン情報を表示

脆弱性概要:
  CWE-732: cronファイルへの不正な書き込み権限
  CWE-269: cronを介した権限昇格
  攻撃例: world-writableなcronスクリプトへの悪意コード挿入
EOF
}

cmd_audit() {
    log_info "cronジョブセキュリティ総合監査"
    echo ""
    cmd_permissions
    cmd_scripts
    cmd_injection
}

cmd_permissions() {
    log_info "cronファイルのパーミッション確認"
    echo ""

    local cron_locations=(
        "/etc/crontab"
        "/etc/cron.d"
        "/etc/cron.daily"
        "/etc/cron.hourly"
        "/etc/cron.weekly"
        "/etc/cron.monthly"
        "/var/spool/cron"
    )

    printf "${C_BOLD}【cronディレクトリ・ファイルのパーミッション】${C_RESET}\n\n"

    for location in "${cron_locations[@]}"; do
        [[ ! -e "$location" ]] && continue

        local perms owner
        perms=$(stat -c "%a" "$location" 2>/dev/null || echo "???")
        owner=$(stat -c "%U:%G" "$location" 2>/dev/null || echo "???")

        printf "  %-40s %s (%s)" "$location" "$perms" "$owner"

        # world-writableチェック
        if [[ "${perms: -1}" =~ [2367] ]]; then
            printf " ${C_RED}[CRITICAL: world-writable]${C_RESET}"
        elif [[ "${perms:1:1}" =~ [2367] ]]; then
            printf " ${C_YELLOW}[MEDIUM: group-writable]${C_RESET}"
        else
            printf " ${C_GREEN}[OK]${C_RESET}"
        fi
        echo ""

        # ディレクトリ内のファイルも確認
        if [[ -d "$location" ]]; then
            find "$location" -type f -perm -o+w 2>/dev/null | \
            while IFS= read -r f; do
                printf "    ${C_RED}[CRITICAL]${C_RESET} world-writable: %s\n" "$f"
            done
        fi
    done
    echo ""
}

cmd_scripts() {
    log_info "cronから実行されるスクリプトのパーミッション検査"
    echo ""

    # cronファイルからスクリプトパスを抽出
    local script_paths=()
    while IFS= read -r line; do
        # コメントと空行を除外
        [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
        # コマンド部分を抽出（cron形式: min hour day month dow command）
        local cmd
        cmd=$(echo "$line" | awk '{for(i=6;i<=NF;i++) printf $i" "; print ""}' | tr -d ' ')
        # スクリプトパスを抽出
        local script
        script=$(echo "$cmd" | grep -oE '/[a-zA-Z0-9/_.-]+\.sh' | head -1)
        [[ -n "$script" ]] && script_paths+=("$script")
    done < <(cat /etc/crontab /etc/cron.d/* 2>/dev/null)

    if [[ ${#script_paths[@]} -eq 0 ]]; then
        printf "  ${C_DIM}cronから実行されるスクリプトが見つかりません${C_RESET}\n\n"
        return
    fi

    printf "${C_BOLD}【cronスクリプトのパーミッション・内容確認】${C_RESET}\n\n"
    for script in "${script_paths[@]}"; do
        [[ ! -f "$script" ]] && continue
        local perms owner
        perms=$(stat -c "%a" "$script" 2>/dev/null || echo "???")
        owner=$(stat -c "%U:%G" "$script" 2>/dev/null || echo "???")

        printf "  %-45s %s (%s)" "$script" "$perms" "$owner"

        if [[ "${perms: -1}" =~ [2367] ]]; then
            printf " ${C_RED}[CRITICAL: world-writable]${C_RESET}"
        elif [[ "${perms:1:1}" =~ [2367] ]]; then
            printf " ${C_YELLOW}[MEDIUM: group-writable]${C_RESET}"
        else
            printf " ${C_GREEN}[OK]${C_RESET}"
        fi
        echo ""
    done
    echo ""
}

cmd_injection() {
    log_info "cronインジェクションパターン検出"
    echo ""

    python3 - <<'PYEOF'
import os, re, sys

RED    = "\033[1;31m"
YELLOW = "\033[1;33m"
GREEN  = "\033[1;32m"
RESET  = "\033[0m"
BOLD   = "\033[1m"

cron_files = []
for d in ['/etc/cron.d', '/etc/cron.daily', '/etc/cron.hourly', '/etc/cron.weekly', '/etc/cron.monthly']:
    if os.path.isdir(d):
        for f in os.listdir(d):
            fp = os.path.join(d, f)
            if os.path.isfile(fp):
                cron_files.append(fp)
if os.path.isfile('/etc/crontab'):
    cron_files.append('/etc/crontab')

dangerous_patterns = [
    (r'(?:bash|sh|zsh)\s+-[ci]\s+',         "インタラクティブシェル実行",        "CRITICAL"),
    (r'(?:nc|ncat|netcat)\s+',               "netcatコマンド",                    "HIGH"),
    (r'(?:wget|curl)\s+.*\|\s*(?:bash|sh)',  "パイプでの遠隔コード実行",           "CRITICAL"),
    (r'base64\s+-d\s*\|',                    "Base64デコードしてパイプ実行",        "HIGH"),
    (r'(?:rm|mv|cp)\s+-rf?\s+/',             "ルートからの危険なファイル操作",      "HIGH"),
    (r'chmod\s+(?:777|a\+rwx)',              "全権限付与",                         "HIGH"),
    (r'>/dev/tcp/',                           "/dev/tcpによるネットワーク接続",     "HIGH"),
    (r'\$\(.*\)',                             "コマンド置換",                      "MEDIUM"),
    (r'`[^`]+`',                             "バッククォートコマンド置換",          "MEDIUM"),
    (r'PATH=.*:/tmp|PATH=\.',               "PATHへの危険なディレクトリ追加",     "HIGH"),
]

findings = []
for cron_file in cron_files:
    try:
        with open(cron_file) as f:
            lines = f.readlines()
    except:
        continue
    for i, line in enumerate(lines, 1):
        s = line.rstrip()
        if s.lstrip().startswith('#') or not s.strip():
            continue
        for pat, desc, sev in dangerous_patterns:
            if re.search(pat, s):
                findings.append((cron_file, i, s.strip(), desc, sev))
                break

if findings:
    for fpath, lineno, line, desc, sev in findings:
        color = "\033[1;35m" if sev == "CRITICAL" else (RED if sev == "HIGH" else YELLOW)
        print(f"  {color}[{sev}]{RESET} {fpath}:{lineno} - {desc}")
        print(f"    {BOLD}{line[:80]}{RESET}")
        print()
else:
    print(f"  {GREEN}cronインジェクションパターンなし{RESET}")
PYEOF
    echo ""
}

cmd_users() {
    log_info "ユーザーcrontabの確認"
    echo ""

    if [[ $EUID -ne 0 ]]; then
        log_warning "root権限がないため、全ユーザーのcrontabは確認できません"
        printf "\n  現在のユーザーのcrontab:\n"
        crontab -l 2>/dev/null || printf "  ${C_DIM}(設定なし)${C_RESET}\n"
        echo ""
        return
    fi

    while IFS=: read -r user _ uid _; do
        (( uid < 1000 )) && continue  # システムユーザーをスキップ
        local user_cron
        user_cron=$(crontab -u "$user" -l 2>/dev/null || true)
        if [[ -n "$user_cron" ]]; then
            printf "  ${C_BOLD}%s のcrontab:${C_RESET}\n" "$user"
            echo "$user_cron" | grep -v "^#" | head -10 | \
            while IFS= read -r line; do
                printf "    %s\n" "$line"
            done
            echo ""
        fi
    done < /etc/passwd
}

parse_arguments() {
    [[ $# -eq 0 ]] && return 0
    case "$1" in
        audit|scripts|permissions|injection|users)
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
        scripts)     cmd_scripts ;;
        permissions) cmd_permissions ;;
        injection)   cmd_injection ;;
        users)       cmd_users ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
