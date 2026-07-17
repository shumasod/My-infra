#!/bin/bash
set -euo pipefail

#
# ユーザーアカウント管理ヘルパー
# バージョン: 1.0
#
# Linuxユーザーアカウントの作成・削除・一覧・情報表示ツール
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare action=""
declare -a USERS=()
declare group=""
declare shell="/bin/bash"
declare home_base="/home"
declare no_home=false
declare sudo_access=false

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME <アクション> [オプション] [ユーザー名...]

Linuxユーザーアカウント管理ツール

アクション:
  list      ユーザー一覧を表示
  info      ユーザー詳細情報を表示
  add       ユーザーを追加
  remove    ユーザーを削除
  lock      ユーザーをロック
  unlock    ユーザーをアンロック
  groups    ユーザーのグループ一覧

オプション:
  -h, --help            このヘルプを表示
  -v, --version         バージョン情報を表示
  -g, --group GROUP     グループ指定 (addアクション用)
  -s, --shell SHELL     ログインシェル [デフォルト: /bin/bash]
  --no-home             ホームディレクトリを作成しない
  --sudo                sudoグループに追加

例:
  $PROG_NAME list
  $PROG_NAME info username
  $PROG_NAME add -g developers --sudo newuser
  $PROG_NAME lock baduser
  $PROG_NAME groups username

EOF
}

require_root() {
    if [[ $EUID -ne 0 ]]; then
        error_exit "このアクションはroot権限が必要です (sudo で実行してください)"
    fi
}

do_list() {
    log_info "システムユーザー一覧"
    echo ""
    printf "  %-20s %-6s %-6s %-25s %s\n" "ユーザー名" "UID" "GID" "ホームディレクトリ" "シェル"
    printf "  %s\n" "$(printf '%.0s-' {1..80})"

    while IFS=: read -r name _ uid gid _ home sh; do
        if (( uid >= 1000 && uid < 65534 )); then
            local locked=""
            if passwd -S "$name" 2>/dev/null | grep -q " L "; then
                locked="${C_RED}[LOCKED]${C_RESET}"
            fi
            printf "  %-20s %-6s %-6s %-25s %s %b\n" \
                "$name" "$uid" "$gid" "$home" "$sh" "$locked"
        fi
    done < /etc/passwd
    echo ""
}

do_info() {
    local username="$1"
    if ! id "$username" &>/dev/null; then
        error_exit "ユーザーが存在しません: $username"
    fi

    local uid gid home_dir sh
    uid=$(id -u "$username")
    gid=$(id -g "$username")
    home_dir=$(getent passwd "$username" | cut -d: -f6)
    sh=$(getent passwd "$username" | cut -d: -f7)

    echo ""
    log_info "ユーザー情報: $username"
    printf "  UID:      %s\n" "$uid"
    printf "  GID:      %s\n" "$gid"
    printf "  グループ: %s\n" "$(id -Gn "$username" | tr ' ' ',')"
    printf "  ホーム:   %s\n" "$home_dir"
    printf "  シェル:   %s\n" "$sh"

    local lock_status
    lock_status=$(passwd -S "$username" 2>/dev/null | awk '{print $2}' || echo "unknown")
    printf "  状態:     %s\n" "$lock_status"

    if [[ -f "/var/log/lastlog" ]]; then
        local last_login
        last_login=$(lastlog -u "$username" 2>/dev/null | tail -1 | awk '{print $4, $5, $6, $7, $8}' || echo "不明")
        printf "  最終ログイン: %s\n" "$last_login"
    fi
    echo ""
}

do_add() {
    local username="$1"
    require_root

    if id "$username" &>/dev/null; then
        error_exit "ユーザーは既に存在します: $username"
    fi

    local useradd_args=("-s" "$shell")
    [[ -n "$group" ]] && useradd_args+=("-g" "$group")
    [[ "$no_home" == false ]] && useradd_args+=("-m" "-d" "${home_base}/${username}")
    useradd_args+=("$username")

    log_info "ユーザー追加: $username"
    useradd "${useradd_args[@]}"

    if [[ "$sudo_access" == true ]]; then
        usermod -aG sudo "$username"
        log_success "sudoグループに追加: $username"
    fi

    log_success "ユーザー作成完了: $username"
    do_info "$username"
}

do_remove() {
    local username="$1"
    require_root

    if ! id "$username" &>/dev/null; then
        error_exit "ユーザーが存在しません: $username"
    fi

    log_warning "ユーザー削除: $username"
    printf "本当に削除しますか? [y/N]: "
    local ans; read -r ans
    [[ "$ans" =~ ^[yY]$ ]] || { log_info "キャンセルしました"; return; }

    userdel -r "$username" 2>/dev/null || userdel "$username"
    log_success "ユーザー削除完了: $username"
}

do_lock() {
    local username="$1"
    require_root
    ! id "$username" &>/dev/null && error_exit "ユーザーが存在しません: $username"
    passwd -l "$username"
    log_success "ユーザーをロックしました: $username"
}

do_unlock() {
    local username="$1"
    require_root
    ! id "$username" &>/dev/null && error_exit "ユーザーが存在しません: $username"
    passwd -u "$username"
    log_success "ユーザーのロックを解除しました: $username"
}

do_groups() {
    local username="$1"
    ! id "$username" &>/dev/null && error_exit "ユーザーが存在しません: $username"
    log_info "${username} のグループ:"
    id -Gn "$username" | tr ' ' '\n' | while read -r g; do
        local gid
        gid=$(getent group "$g" | cut -d: -f3)
        printf "  %-20s (GID: %s)\n" "$g" "$gid"
    done
    echo ""
}

parse_arguments() {
    [[ $# -eq 0 ]] && { show_usage; exit 0; }
    action="$1"; shift

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -g|--group)
                [[ $# -lt 2 ]] && error_exit "--group には値が必要です"
                group="$2"; shift 2 ;;
            -s|--shell)
                [[ $# -lt 2 ]] && error_exit "--shell には値が必要です"
                shell="$2"; shift 2 ;;
            --no-home)  no_home=true; shift ;;
            --sudo)     sudo_access=true; shift ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  USERS+=("$1"); shift ;;
        esac
    done
}

main() {
    parse_arguments "$@"

    case "$action" in
        list)
            do_list ;;
        info)
            [[ ${#USERS[@]} -eq 0 ]] && error_exit "ユーザー名を指定してください"
            for u in "${USERS[@]}"; do do_info "$u"; done ;;
        add)
            [[ ${#USERS[@]} -eq 0 ]] && error_exit "ユーザー名を指定してください"
            for u in "${USERS[@]}"; do do_add "$u"; done ;;
        remove)
            [[ ${#USERS[@]} -eq 0 ]] && error_exit "ユーザー名を指定してください"
            for u in "${USERS[@]}"; do do_remove "$u"; done ;;
        lock)
            [[ ${#USERS[@]} -eq 0 ]] && error_exit "ユーザー名を指定してください"
            for u in "${USERS[@]}"; do do_lock "$u"; done ;;
        unlock)
            [[ ${#USERS[@]} -eq 0 ]] && error_exit "ユーザー名を指定してください"
            for u in "${USERS[@]}"; do do_unlock "$u"; done ;;
        groups)
            [[ ${#USERS[@]} -eq 0 ]] && error_exit "ユーザー名を指定してください"
            for u in "${USERS[@]}"; do do_groups "$u"; done ;;
        *)
            error_exit "不明なアクション: $action。--help を参照してください" ;;
    esac
}

main "$@"
