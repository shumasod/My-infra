#!/bin/bash
set -euo pipefail

#
# SSH設定マネージャー
# 作成日: 2026-07-14
# バージョン: 1.0
#
# ~/.ssh/config のホスト一覧表示・追加・削除・接続テストを管理する
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"
readonly SSH_CONFIG="${HOME}/.ssh/config"
readonly SSH_CONFIG_BACKUP="${HOME}/.ssh/config.bak"

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション] [コマンド]

SSH設定（~/.ssh/config）を管理します。

コマンド:
  list              ホスト一覧を表示
  show HOST         指定ホストの設定を表示
  add               新規ホストを追加
  remove HOST       指定ホストを削除
  test HOST         接続テスト
  backup            設定ファイルをバックアップ
  restore           バックアップから復元

オプション:
  -h, --help        このヘルプを表示
  -v, --version     バージョン情報を表示

例:
  $PROG_NAME list
  $PROG_NAME show myserver
  $PROG_NAME add
  $PROG_NAME test webserver
EOF
}

ensure_ssh_dir() {
    local ssh_dir="${HOME}/.ssh"
    if [[ ! -d "$ssh_dir" ]]; then
        mkdir -p "$ssh_dir"
        chmod 700 "$ssh_dir"
        log_info "~/.ssh ディレクトリを作成しました"
    fi
    if [[ ! -f "$SSH_CONFIG" ]]; then
        touch "$SSH_CONFIG"
        chmod 600 "$SSH_CONFIG"
        log_info "~/.ssh/config を新規作成しました"
    fi
}

list_hosts() {
    ensure_ssh_dir

    echo ""
    print_center "SSH ホスト一覧" 0 "${C_BOLD}${C_CYAN}"
    echo ""

    local hosts=()
    while IFS= read -r line; do
        if [[ "$line" =~ ^[Hh]ost[[:space:]]+(.+)$ ]]; then
            local host="${BASH_REMATCH[1]}"
            [[ "$host" != "*" ]] && hosts+=("$host")
        fi
    done < "$SSH_CONFIG"

    if [[ ${#hosts[@]} -eq 0 ]]; then
        echo -e "  ${C_DIM}設定されているホストがありません${C_RESET}"
        echo ""
        return
    fi

    printf "  ${C_BOLD}%-20s %-20s %-8s %-15s${C_RESET}\n" "ホスト名" "ホスト/IP" "ポート" "ユーザー"
    echo -e "  ${C_DIM}$(printf '%.0s─' {1..60})${C_RESET}"

    local current_host=""
    local hostname="" port="22" user=""

    while IFS= read -r line; do
        line="${line#"${line%%[![:space:]]*}"}"

        if [[ "$line" =~ ^[Hh]ost[[:space:]]+(.+)$ ]]; then
            if [[ -n "$current_host" ]] && [[ "$current_host" != "*" ]]; then
                printf "  ${C_GREEN}%-20s${C_RESET} %-20s %-8s %-15s\n" \
                    "$current_host" "${hostname:-N/A}" "${port:-22}" "${user:-N/A}"
            fi
            current_host="${BASH_REMATCH[1]}"
            hostname=""; port="22"; user=""
        elif [[ "$line" =~ ^[Hh]ost[Nn]ame[[:space:]]+(.+)$ ]]; then
            hostname="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^[Pp]ort[[:space:]]+(.+)$ ]]; then
            port="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^[Uu]ser[[:space:]]+(.+)$ ]]; then
            user="${BASH_REMATCH[1]}"
        fi
    done < "$SSH_CONFIG"

    if [[ -n "$current_host" ]] && [[ "$current_host" != "*" ]]; then
        printf "  ${C_GREEN}%-20s${C_RESET} %-20s %-8s %-15s\n" \
            "$current_host" "${hostname:-N/A}" "${port:-22}" "${user:-N/A}"
    fi
    echo ""
}

show_host() {
    local target="$1"
    ensure_ssh_dir

    local in_block=false
    local found=false

    echo ""
    echo -e "  ${C_BOLD}${C_CYAN}ホスト設定: ${target}${C_RESET}"
    echo ""

    while IFS= read -r line; do
        if [[ "$line" =~ ^[Hh]ost[[:space:]]+(.+)$ ]]; then
            if "$in_block"; then
                break
            fi
            if [[ "${BASH_REMATCH[1]}" == "$target" ]]; then
                in_block=true
                found=true
                echo -e "  ${C_YELLOW}Host ${target}${C_RESET}"
            fi
        elif "$in_block"; then
            echo -e "  ${C_GREEN}${line}${C_RESET}"
        fi
    done < "$SSH_CONFIG"

    if ! "$found"; then
        log_warning "ホスト '$target' が見つかりません"
    fi
    echo ""
}

add_host() {
    ensure_ssh_dir

    echo ""
    print_center "SSH ホストを追加" 0 "${C_BOLD}${C_CYAN}"
    echo ""

    echo -n "  ホスト名（エイリアス）: "
    read -r alias_name
    [[ -z "$alias_name" ]] && error_exit "ホスト名は必須です"

    echo -n "  ホスト/IPアドレス: "
    read -r hostname
    [[ -z "$hostname" ]] && error_exit "ホスト/IPは必須です"

    echo -n "  ポート番号 [22]: "
    read -r port
    port="${port:-22}"

    echo -n "  ユーザー名 [${USER}]: "
    read -r user
    user="${user:-$USER}"

    echo -n "  秘密鍵ファイル（省略可）: "
    read -r identity

    echo ""
    echo -e "  ${C_BOLD}追加する設定:${C_RESET}"
    echo -e "  ${C_YELLOW}Host ${alias_name}${C_RESET}"
    echo -e "  ${C_GREEN}  HostName ${hostname}${C_RESET}"
    echo -e "  ${C_GREEN}  Port ${port}${C_RESET}"
    echo -e "  ${C_GREEN}  User ${user}${C_RESET}"
    [[ -n "$identity" ]] && echo -e "  ${C_GREEN}  IdentityFile ${identity}${C_RESET}"

    echo ""
    if ! confirm "この設定を追加しますか？" "y"; then
        log_info "キャンセルしました"
        return
    fi

    {
        echo ""
        echo "Host ${alias_name}"
        echo "  HostName ${hostname}"
        echo "  Port ${port}"
        echo "  User ${user}"
        [[ -n "$identity" ]] && echo "  IdentityFile ${identity}"
    } >> "$SSH_CONFIG"

    log_success "ホスト '${alias_name}' を追加しました"
}

remove_host() {
    local target="$1"
    ensure_ssh_dir

    local found=false
    while IFS= read -r line; do
        if [[ "$line" =~ ^[Hh]ost[[:space:]]+(.+)$ ]] && [[ "${BASH_REMATCH[1]}" == "$target" ]]; then
            found=true
            break
        fi
    done < "$SSH_CONFIG"

    if ! "$found"; then
        error_exit "ホスト '$target' が見つかりません"
    fi

    echo ""
    if ! confirm "${C_RED}ホスト '${target}' を削除しますか？${C_RESET}" "n"; then
        log_info "キャンセルしました"
        return
    fi

    cp "$SSH_CONFIG" "${SSH_CONFIG}.tmp"

    local in_block=false
    local skip=false
    while IFS= read -r line; do
        if [[ "$line" =~ ^[Hh]ost[[:space:]]+(.+)$ ]]; then
            skip=false
            if [[ "${BASH_REMATCH[1]}" == "$target" ]]; then
                skip=true
                in_block=true
                continue
            fi
            in_block=false
        fi
        "$skip" || echo "$line"
    done < "${SSH_CONFIG}.tmp" > "$SSH_CONFIG"

    rm -f "${SSH_CONFIG}.tmp"
    log_success "ホスト '${target}' を削除しました"
}

test_connection() {
    local target="$1"

    echo ""
    log_info "接続テスト: $target"

    if ssh -o "ConnectTimeout=5" -o "BatchMode=yes" -o "StrictHostKeyChecking=no" \
        "$target" "echo 'OK'" &>/dev/null 2>&1; then
        log_success "接続成功: $target"
    else
        log_warning "接続失敗（タイムアウトまたは認証エラー）: $target"
    fi
    echo ""
}

backup_config() {
    ensure_ssh_dir
    cp "$SSH_CONFIG" "$SSH_CONFIG_BACKUP"
    log_success "バックアップ: $SSH_CONFIG_BACKUP"
}

restore_config() {
    if [[ ! -f "$SSH_CONFIG_BACKUP" ]]; then
        error_exit "バックアップファイルが見つかりません: $SSH_CONFIG_BACKUP"
    fi
    if confirm "バックアップから復元しますか？現在の設定は上書きされます" "n"; then
        cp "$SSH_CONFIG_BACKUP" "$SSH_CONFIG"
        log_success "復元完了"
    fi
}

main() {
    local command=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            list|add|backup|restore) command="$1"; shift ;;
            show|remove|test)
                command="$1"
                shift
                [[ $# -lt 1 ]] && error_exit "$command にはホスト名が必要です"
                ;;
            *) error_exit "不明なコマンド: $1" ;;
        esac
    done

    [[ -z "$command" ]] && { show_usage; exit 0; }

    case "$command" in
        list)    list_hosts ;;
        show)    show_host "$1" ;;
        add)     add_host ;;
        remove)  remove_host "$1" ;;
        test)    test_connection "$1" ;;
        backup)  backup_config ;;
        restore) restore_config ;;
    esac
}

main "$@"
