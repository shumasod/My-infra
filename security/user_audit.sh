#!/bin/bash
set -euo pipefail

#
# ユーザーアカウント監査ツール
# 作成日: 2026-08-25
# バージョン: 1.0
#
# システムユーザーのセキュリティ状態を監査します
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare command_name="all"
declare output_format="text"
declare warn_days=90
declare report_file=""

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション]

ユーザーアカウントのセキュリティ監査ツールです。

コマンド:
  all                    総合監査 (デフォルト)
  users                  ユーザー一覧と状態
  passwords              パスワード有効期限チェック
  sudo                   sudo権限ユーザー確認
  login                  最終ログイン履歴
  locked                 ロックアカウント一覧
  groups                 グループ所属確認

オプション:
  -h, --help             このヘルプを表示
  -v, --version          バージョン情報を表示
  -w, --warn <日数>      パスワード警告日数 [デフォルト: 90]
  -o, --output <ファイル> レポートをファイルに出力
  -f, --format <形式>    出力形式 (text|json) [デフォルト: text]

例:
  $PROG_NAME all
  $PROG_NAME users
  $PROG_NAME passwords --warn 60
  $PROG_NAME sudo
  $PROG_NAME login
EOF
}

is_system_user() {
    local uid="$1"
    (( uid < 1000 ))
}

get_account_status() {
    local user="$1"
    local status=""
    if passwd -S "$user" &>/dev/null; then
        local s
        s=$(passwd -S "$user" 2>/dev/null | awk '{print $2}')
        case "$s" in
            L|LK) status="ロック" ;;
            P)    status="有効" ;;
            NP)   status="パスワードなし" ;;
            *)    status="不明" ;;
        esac
    else
        status="N/A"
    fi
    echo "$status"
}

cmd_users() {
    log_info "ユーザーアカウント一覧"
    echo ""

    printf "${C_BOLD}【一般ユーザー (UID >= 1000)】${C_RESET}\n\n"
    printf "${C_BOLD}  %-15s %6s %-15s %-20s %s${C_RESET}\n" \
        "ユーザー名" "UID" "グループ" "ホームディレクトリ" "シェル"
    printf "  %s\n" "$(printf '%.0s─' {1..75})"

    while IFS=: read -r user _ uid gid _ home shell; do
        is_system_user "$uid" && continue
        local status
        status=$(get_account_status "$user")
        local color="$C_GREEN"
        [[ "$status" == "ロック" ]]       && color="$C_RED"
        [[ "$status" == "パスワードなし" ]] && color="$C_YELLOW"

        printf "  ${color}%-15s${C_RESET} %6s %-15s %-20s %s\n" \
            "$user" "$uid" "$gid" "${home:0:20}" "${shell}"
    done < /etc/passwd

    echo ""
    printf "${C_BOLD}【特権システムアカウント】${C_RESET}\n\n"
    printf "${C_BOLD}  %-15s %6s %-20s %s${C_RESET}\n" \
        "ユーザー名" "UID" "ホームディレクトリ" "シェル"
    printf "  %s\n" "$(printf '%.0s─' {1..60})"

    while IFS=: read -r user _ uid _ _ home shell; do
        (( uid >= 1000 )) && continue
        [[ "$shell" =~ nologin|false ]] && continue
        printf "  ${C_YELLOW}%-15s${C_RESET} %6s %-20s %s\n" \
            "$user" "$uid" "${home:0:20}" "$shell"
    done < /etc/passwd
    echo ""
}

cmd_passwords() {
    log_info "パスワード有効期限チェック"
    echo ""

    if [[ ! -r /etc/shadow ]]; then
        log_warning "/etc/shadow が読めません。rootで実行してください"
        return 1
    fi

    printf "${C_BOLD}  %-15s %-12s %-12s %-12s %s${C_RESET}\n" \
        "ユーザー" "最終変更" "有効期限" "残り日数" "状態"
    printf "  %s\n" "$(printf '%.0s─' {1..65})"

    local today_days
    today_days=$(( $(date +%s) / 86400 ))

    while IFS=: read -r user pw last_change min_days max_days warn_d inactive expire; do
        [[ "$pw" == "!" || "$pw" == "*" || "$pw" == "!!" ]] && continue
        [[ -z "$user" ]] && continue

        local uid
        uid=$(id -u "$user" 2>/dev/null || echo 0)
        is_system_user "$uid" && continue

        local changed_date="N/A" expire_date="N/A" remaining="N/A" status_str="有効" color="$C_GREEN"

        if [[ -n "$last_change" && "$last_change" != "0" && "$last_change" =~ ^[0-9]+$ ]]; then
            changed_date=$(date -d "@$(( last_change * 86400 ))" "+%Y-%m-%d" 2>/dev/null || echo "N/A")
        fi

        if [[ -n "$max_days" && "$max_days" != "99999" && "$max_days" =~ ^[0-9]+$ && \
              -n "$last_change" && "$last_change" =~ ^[0-9]+$ ]]; then
            local expire_day=$(( last_change + max_days ))
            expire_date=$(date -d "@$(( expire_day * 86400 ))" "+%Y-%m-%d" 2>/dev/null || echo "N/A")
            remaining=$(( expire_day - today_days ))
            if (( remaining < 0 )); then
                status_str="期限切れ"; color="$C_RED"
            elif (( remaining < critical_days )); then
                status_str="危険"; color="$C_RED"
            elif (( remaining < warn_days )); then
                status_str="警告"; color="$C_YELLOW"
            fi
        fi

        printf "  ${color}%-15s${C_RESET} %-12s %-12s " "$user" "$changed_date" "$expire_date"
        if [[ "$remaining" =~ ^-?[0-9]+$ ]]; then
            printf "${color}%12d日${C_RESET} %s\n" "$remaining" "$status_str"
        else
            printf "%12s %s\n" "N/A" "$status_str"
        fi
    done < /etc/shadow
    echo ""
}

declare -i critical_days=7

cmd_sudo() {
    log_info "sudo権限ユーザー確認"
    echo ""

    printf "${C_BOLD}【sudoグループメンバー】${C_RESET}\n\n"
    local sudo_group
    sudo_group=$(getent group sudo wheel 2>/dev/null | head -1 || true)
    if [[ -n "$sudo_group" ]]; then
        local gname members
        gname=$(echo "$sudo_group" | cut -d: -f1)
        members=$(echo "$sudo_group" | cut -d: -f4)
        printf "  グループ: ${C_YELLOW}%s${C_RESET}\n" "$gname"
        IFS=',' read -ra member_arr <<< "$members"
        for m in "${member_arr[@]}"; do
            [[ -z "$m" ]] && continue
            printf "  - ${C_CYAN}%s${C_RESET}\n" "$m"
        done
    fi

    echo ""
    printf "${C_BOLD}【sudoersファイル設定】${C_RESET}\n\n"
    if [[ -r /etc/sudoers ]]; then
        grep -v '^#\|^$\|^Defaults' /etc/sudoers 2>/dev/null | \
        while IFS= read -r line; do
            if echo "$line" | grep -q "ALL"; then
                printf "  ${C_YELLOW}%s${C_RESET}\n" "$line"
            else
                printf "  ${C_DIM}%s${C_RESET}\n" "$line"
            fi
        done
    else
        log_warning "/etc/sudoers が読めません"
    fi

    echo ""
    printf "${C_BOLD}【sudoers.d/】${C_RESET}\n\n"
    if [[ -d /etc/sudoers.d ]]; then
        for f in /etc/sudoers.d/*; do
            [[ -f "$f" ]] || continue
            printf "  ${C_YELLOW}%s${C_RESET}\n" "$(basename "$f")"
            grep -v '^#\|^$' "$f" 2>/dev/null | head -3 | while IFS= read -r line; do
                printf "    ${C_DIM}%s${C_RESET}\n" "$line"
            done
        done
    fi
    echo ""
}

cmd_login() {
    log_info "最終ログイン履歴"
    echo ""

    printf "${C_BOLD}【最近のログイン】${C_RESET}\n\n"
    last -n 20 2>/dev/null | head -25 | while IFS= read -r line; do
        if echo "$line" | grep -q "still logged in"; then
            printf "${C_GREEN}%s${C_RESET}\n" "$line"
        elif echo "$line" | grep -q "FAILED\|failure"; then
            printf "${C_RED}%s${C_RESET}\n" "$line"
        else
            printf "${C_DIM}%s${C_RESET}\n" "$line"
        fi
    done

    echo ""
    printf "${C_BOLD}【ユーザー別最終ログイン】${C_RESET}\n\n"
    printf "${C_BOLD}  %-15s %-20s %s${C_RESET}\n" "ユーザー" "最終ログイン" "ホスト"
    printf "  %s\n" "$(printf '%.0s─' {1..55})"

    lastlog 2>/dev/null | tail -n +2 | while IFS= read -r line; do
        local user date_str
        user=$(echo "$line" | awk '{print $1}')
        if echo "$line" | grep -q "Never logged in"; then
            uid=$(id -u "$user" 2>/dev/null || echo 0)
            is_system_user "$uid" && continue
            printf "  ${C_DIM}%-15s %-20s${C_RESET}\n" "$user" "ログインなし"
        else
            uid=$(id -u "$user" 2>/dev/null || echo 0)
            is_system_user "$uid" && continue
            local from_host
            from_host=$(echo "$line" | awk '{print $3}')
            date_str=$(echo "$line" | awk '{print $4" "$5" "$6" "$7" "$8}')
            printf "  ${C_CYAN}%-15s${C_RESET} %-20s %s\n" "$user" "$date_str" "$from_host"
        fi
    done
    echo ""
}

cmd_locked() {
    log_info "ロックアカウント一覧"
    echo ""

    printf "${C_BOLD}  %-15s %6s %s${C_RESET}\n" "ユーザー" "UID" "状態"
    printf "  %s\n" "$(printf '%.0s─' {1..35})"

    while IFS=: read -r user _ uid _; do
        is_system_user "$uid" && continue
        local status
        status=$(get_account_status "$user")
        if [[ "$status" == "ロック" || "$status" == "パスワードなし" ]]; then
            local color="$C_RED"
            [[ "$status" == "パスワードなし" ]] && color="$C_YELLOW"
            printf "  ${color}%-15s${C_RESET} %6s %s\n" "$user" "$uid" "$status"
        fi
    done < /etc/passwd

    echo ""
}

cmd_groups() {
    log_info "グループ所属確認"
    echo ""

    printf "${C_BOLD}【重要グループのメンバー】${C_RESET}\n\n"
    local important_groups=("root" "sudo" "wheel" "adm" "docker" "staff" "admin")
    for grp in "${important_groups[@]}"; do
        local members
        members=$(getent group "$grp" 2>/dev/null | cut -d: -f4 || true)
        [[ -z "$members" ]] && continue
        printf "  ${C_YELLOW}%-12s${C_RESET} %s\n" "${grp}:" "$members"
    done

    echo ""
    printf "${C_BOLD}【ユーザー別グループ所属】${C_RESET}\n\n"
    while IFS=: read -r user _ uid _; do
        is_system_user "$uid" && continue
        local groups
        groups=$(id -Gn "$user" 2>/dev/null | tr ' ' ',' || true)
        printf "  ${C_CYAN}%-15s${C_RESET} %s\n" "$user" "$groups"
    done < /etc/passwd
    echo ""
}

cmd_all() {
    cmd_users
    cmd_sudo
    cmd_login
    cmd_locked
    log_success "監査完了"
}

parse_arguments() {
    [[ $# -eq 0 ]] && return 0
    case "$1" in
        all|users|passwords|sudo|login|locked|groups)
            command_name="$1"; shift ;;
    esac

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -w|--warn)    [[ $# -lt 2 ]] && error_exit "--warn には値が必要です"; warn_days="$2"; shift 2 ;;
            -o|--output)  [[ $# -lt 2 ]] && error_exit "--output には値が必要です"; report_file="$2"; shift 2 ;;
            -f|--format)  [[ $# -lt 2 ]] && error_exit "--format には値が必要です"; output_format="$2"; shift 2 ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  shift ;;
        esac
    done
}

main() {
    parse_arguments "$@"

    if [[ -n "$report_file" ]]; then
        exec > >(tee -a "$report_file") 2>&1
        log_info "レポート出力先: $report_file"
    fi

    case "$command_name" in
        all)       cmd_all ;;
        users)     cmd_users ;;
        passwords) cmd_passwords ;;
        sudo)      cmd_sudo ;;
        login)     cmd_login ;;
        locked)    cmd_locked ;;
        groups)    cmd_groups ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
