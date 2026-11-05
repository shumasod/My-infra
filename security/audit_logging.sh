#!/bin/bash
set -euo pipefail

#
# 監査ログ管理ツール
# 作成日: 2026-11-05
# バージョン: 1.0
#
# 脆弱性対応: 監査ログの不備・ログ改ざん防止
# CVE該当: CWE-778 (Insufficient Logging), CWE-223 (Omission of Security-relevant Information)
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare command_name="audit"
declare -r AUDIT_LOG_DIR="${AUDIT_LOG_DIR:-/var/log/audit}"
declare -r APP_LOG_DIR="${APP_LOG_DIR:-/var/log}"

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション]

監査ログの設定と品質を管理します。

コマンド:
  audit                監査ログ設定確認 (デフォルト)
  coverage             ログカバレッジ確認
  integrity            ログ整合性チェック
  retention            ログ保持期間確認
  search <パターン>    監査ログ検索
  report               監査レポート生成

オプション:
  -h, --help           このヘルプを表示
  -v, --version        バージョン情報を表示

脆弱性概要:
  CWE-778: 不十分なログ記録
  CWE-223: セキュリティ関連情報のログ省略
  対策: auditdの設定, 適切なログレベル, ログローテーション
EOF
}

cmd_audit() {
    log_info "監査ログ設定確認"
    echo ""

    # auditd確認
    printf "${C_BOLD}【auditd サービス】${C_RESET}\n\n"
    if command -v auditctl &>/dev/null; then
        if systemctl is-active --quiet auditd 2>/dev/null; then
            log_success "auditd: 実行中"
            local rule_count
            rule_count=$(auditctl -l 2>/dev/null | grep -c "^-" || echo 0)
            printf "  監査ルール数: %s\n" "$rule_count"
        else
            log_error "auditd: 停止中 (要起動)"
        fi
    else
        log_warning "auditd が見つかりません"
    fi
    echo ""

    # rsyslog/journald
    printf "${C_BOLD}【ログサービス】${C_RESET}\n\n"
    for svc in rsyslog syslog-ng journald systemd-journald; do
        if systemctl is-active --quiet "$svc" 2>/dev/null; then
            printf "  ${C_GREEN}[稼働中]${C_RESET} %s\n" "$svc"
        fi
    done
    echo ""

    # 重要なログファイル
    printf "${C_BOLD}【重要なログファイル】${C_RESET}\n\n"
    local log_files=(
        "/var/log/auth.log:認証ログ"
        "/var/log/secure:セキュリティログ"
        "/var/log/syslog:システムログ"
        "/var/log/messages:メッセージログ"
        "/var/log/kern.log:カーネルログ"
        "/var/log/audit/audit.log:auditログ"
        "/var/log/fail2ban.log:fail2ban"
        "/var/log/apache2/access.log:Apache アクセス"
        "/var/log/nginx/access.log:Nginx アクセス"
    )

    for entry in "${log_files[@]}"; do
        local file="${entry%%:*}"
        local desc="${entry##*:}"
        if [[ -f "$file" ]]; then
            local size age
            size=$(du -sh "$file" 2>/dev/null | awk '{print $1}')
            age=$(stat -c "%y" "$file" 2>/dev/null | cut -d' ' -f1)
            printf "  ${C_GREEN}[存在]${C_RESET} %-40s %s (更新: %s)\n" "$desc ($file)" "$size" "$age"
        else
            printf "  ${C_DIM}[なし]${C_RESET} %s\n" "$desc ($file)"
        fi
    done
    echo ""
}

cmd_coverage() {
    log_info "ログカバレッジ確認"
    echo ""

    printf "${C_BOLD}【監査すべきイベント確認】${C_RESET}\n\n"
    local events=(
        "ユーザー認証成功・失敗:auth.log/secure"
        "sudo実行:auth.log"
        "ファイル権限変更:auditd/kern.log"
        "ネットワーク接続:syslog"
        "プロセス起動:auditd"
        "サービス起動・停止:syslog"
        "カーネルメッセージ:kern.log"
        "cron実行:cron.log/syslog"
    )

    for event in "${events[@]}"; do
        local desc="${event%%:*}"
        local source="${event##*:}"
        printf "  %-35s -> %s\n" "$desc" "$source"
    done
    echo ""

    # スクリプト内のログ不足チェック
    printf "${C_BOLD}【スクリプトのログ記録確認 (カレントディレクトリ)】${C_RESET}\n\n"
    local no_log_count=0
    while IFS= read -r file; do
        local has_log has_error_log
        has_log=$(grep -c "log_info\|log_success\|logger\|echo.*>>" "$file" 2>/dev/null || true)
        has_error_log=$(grep -c "log_error\|log_warning\|>&2" "$file" 2>/dev/null || true)

        if [[ "$has_log" -eq 0 ]]; then
            printf "  ${C_YELLOW}[ログなし]${C_RESET} %s\n" "$file"
            (( no_log_count++ ))
        fi
    done < <(find . -maxdepth 2 -name "*.sh" -type f 2>/dev/null | sort)

    if [[ "$no_log_count" -eq 0 ]]; then
        log_success "全スクリプトにログ記録あり"
    else
        log_warning "$no_log_count 件のスクリプトにログ記録がありません"
    fi
    echo ""
}

cmd_integrity() {
    log_info "ログ整合性チェック"
    echo ""

    # ログファイルのパーミッション
    printf "${C_BOLD}【ログファイルパーミッション】${C_RESET}\n\n"
    while IFS= read -r logfile; do
        local perms owner
        perms=$(stat -c "%a" "$logfile" 2>/dev/null || echo "???")
        owner=$(stat -c "%U:%G" "$logfile" 2>/dev/null || echo "???")

        # world-writable ログ = 改ざん可能
        if [[ "${perms: -1}" =~ [2367] ]]; then
            printf "  ${C_RED}[危険]${C_RESET} %-50s %s (%s) - 誰でも書き込み可能\n" \
                "$logfile" "$perms" "$owner"
        else
            printf "  ${C_GREEN}[OK]${C_RESET} %-50s %s (%s)\n" "$logfile" "$perms" "$owner"
        fi
    done < <(find /var/log -maxdepth 2 -name "*.log" -type f 2>/dev/null | head -20)
    echo ""
}

cmd_retention() {
    log_info "ログ保持期間確認"
    echo ""

    printf "${C_BOLD}【ログローテーション設定】${C_RESET}\n\n"
    if [[ -f /etc/logrotate.conf ]]; then
        local rotate_count compress_enabled
        rotate_count=$(grep -E "^rotate" /etc/logrotate.conf 2>/dev/null | awk '{print $2}' || echo "未設定")
        compress_enabled=$(grep -c "compress" /etc/logrotate.conf 2>/dev/null || true)

        printf "  %-30s %s\n" "ローテーション世代数:" "$rotate_count"
        printf "  %-30s " "圧縮:"
        [[ "$compress_enabled" -gt 0 ]] && printf "${C_GREEN}有効${C_RESET}\n" || printf "${C_YELLOW}無効${C_RESET}\n"
    else
        log_warning "/etc/logrotate.conf が見つかりません"
    fi

    echo ""
    printf "${C_BOLD}【古いログファイル (90日以上)】${C_RESET}\n\n"
    local old_count=0
    while IFS= read -r file; do
        (( old_count++ ))
        local size
        size=$(du -sh "$file" 2>/dev/null | awk '{print $1}')
        printf "  %-60s %s\n" "$file" "$size"
    done < <(find /var/log -mtime +90 -name "*.log*" -type f 2>/dev/null | head -10)

    if [[ "$old_count" -eq 0 ]]; then
        log_success "90日以上の古いログなし"
    else
        log_warning "$old_count 件の古いログファイルあり"
    fi
    echo ""
}

cmd_search() {
    local pattern="${1:-}"
    [[ -z "$pattern" ]] && error_exit "検索パターンを指定してください"

    log_info "監査ログ検索: $pattern"
    echo ""

    local found=0
    for logfile in /var/log/auth.log /var/log/secure /var/log/syslog /var/log/messages; do
        [[ ! -f "$logfile" ]] && continue
        local matches
        matches=$(grep -n "$pattern" "$logfile" 2>/dev/null | tail -20 || true)
        if [[ -n "$matches" ]]; then
            printf "${C_BOLD}%s${C_RESET}\n" "$logfile"
            echo "$matches" | while IFS= read -r line; do
                if echo "$line" | grep -qi "fail\|error\|invalid"; then
                    printf "  ${C_RED}%s${C_RESET}\n" "$line"
                else
                    printf "  %s\n" "$line"
                fi
            done
            echo ""
            (( found++ ))
        fi
    done

    [[ "$found" -eq 0 ]] && printf "  ${C_DIM}マッチなし${C_RESET}\n\n"
}

parse_arguments() {
    [[ $# -eq 0 ]] && return 0
    case "$1" in
        audit|coverage|integrity|retention|search|report)
            command_name="$1"; shift ;;
    esac
    local positional=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
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
        audit)     cmd_audit ;;
        coverage)  cmd_coverage ;;
        integrity) cmd_integrity ;;
        retention) cmd_retention ;;
        search)    cmd_search    "${POSITIONAL[0]:-}" ;;
        report)
            cmd_audit
            cmd_coverage
            cmd_integrity
            ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
