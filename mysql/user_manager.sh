#!/bin/bash
set -euo pipefail

#
# MySQLユーザー管理ツール
# バージョン: 1.0
#
# MySQLのユーザー作成・権限管理・一覧表示を行うツール
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare action=""
declare mysql_host="localhost"
declare mysql_port="3306"
declare mysql_root_user="root"
declare mysql_root_pass="${MYSQL_PWD:-}"
declare target_user=""
declare target_host="%"
declare target_pass=""
declare target_db=""
declare -a privileges=()

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME <アクション> [オプション]

MySQLユーザー管理ツール

アクション:
  list      ユーザー一覧と権限を表示
  create    ユーザーを作成
  drop      ユーザーを削除
  grant     権限を付与
  revoke    権限を削除
  passwd    パスワードを変更
  info      ユーザーの詳細情報

オプション:
  -h, --help            このヘルプを表示
  -v, --version         バージョン情報を表示
  -H, --host HOST       MySQLホスト [デフォルト: localhost]
  -P, --port PORT       ポート [デフォルト: 3306]
  -u, --user USER       root相当ユーザー [デフォルト: root]
  -p, --pass PASS       パスワード (MYSQL_PWD環境変数推奨)
  -U, --target-user USR 操作対象ユーザー名
  -A, --target-host HST 対象ホスト [デフォルト: %]
  -w, --password PASS   新規パスワード
  -d, --database DB     対象データベース
  -G, --privileges PRV  権限 (カンマ区切り, デフォルト: SELECT)

例:
  $PROG_NAME list
  $PROG_NAME create -U appuser -w securepass -d mydb
  $PROG_NAME grant -U appuser -d mydb -G SELECT,INSERT,UPDATE
  $PROG_NAME info -U appuser

EOF
}

mysql_exec() {
    local query="$1"
    local -a args=(-h "$mysql_host" -P "$mysql_port" -u "$mysql_root_user" --batch --silent)
    [[ -n "$mysql_root_pass" ]] && args+=(-p"$mysql_root_pass")
    mysql "${args[@]}" -e "$query" 2>/dev/null
}

do_list() {
    log_info "MySQLユーザー一覧: ${mysql_host}:${mysql_port}"
    echo ""
    printf "  %-25s %-20s %s\n" "ユーザー" "ホスト" "プラグイン"
    printf "  %s\n" "$(printf '%.0s-' {1..60})"

    mysql_exec "SELECT User, Host, plugin FROM mysql.user ORDER BY User, Host;" | \
    while IFS=$'\t' read -r user host plugin; do
        local color="$C_RESET"
        [[ "$user" == "root" ]] && color="$C_YELLOW"
        printf "  %b%-25s%b %-20s %s\n" "$color" "$user" "$C_RESET" "$host" "$plugin"
    done
    echo ""
}

do_create() {
    [[ -z "$target_user" ]] && error_exit "--target-user でユーザー名を指定してください"
    [[ -z "$target_pass" ]] && error_exit "--password でパスワードを指定してください"

    log_info "ユーザー作成: '${target_user}'@'${target_host}'"

    mysql_exec "CREATE USER IF NOT EXISTS '${target_user}'@'${target_host}' IDENTIFIED BY '${target_pass}';"
    log_success "ユーザー作成完了"

    if [[ -n "$target_db" ]]; then
        local privs="SELECT"
        [[ ${#privileges[@]} -gt 0 ]] && privs=$(IFS=','; echo "${privileges[*]}")
        mysql_exec "GRANT ${privs} ON \`${target_db}\`.* TO '${target_user}'@'${target_host}';"
        mysql_exec "FLUSH PRIVILEGES;"
        log_success "権限付与完了: ${privs} ON ${target_db}"
    fi
}

do_drop() {
    [[ -z "$target_user" ]] && error_exit "--target-user でユーザー名を指定してください"

    log_warning "ユーザー削除: '${target_user}'@'${target_host}'"
    printf "削除しますか? [yes/NO]: "
    local ans; read -r ans
    [[ "$ans" != "yes" ]] && { log_info "キャンセルしました"; return; }

    mysql_exec "DROP USER IF EXISTS '${target_user}'@'${target_host}';"
    mysql_exec "FLUSH PRIVILEGES;"
    log_success "削除完了"
}

do_grant() {
    [[ -z "$target_user" ]] && error_exit "--target-user でユーザー名を指定してください"
    [[ -z "$target_db"   ]] && error_exit "--database でデータベースを指定してください"

    local privs="SELECT"
    [[ ${#privileges[@]} -gt 0 ]] && privs=$(IFS=','; echo "${privileges[*]}")

    log_info "権限付与: ${privs} ON ${target_db}.* TO '${target_user}'@'${target_host}'"
    mysql_exec "GRANT ${privs} ON \`${target_db}\`.* TO '${target_user}'@'${target_host}';"
    mysql_exec "FLUSH PRIVILEGES;"
    log_success "権限付与完了"
}

do_revoke() {
    [[ -z "$target_user" ]] && error_exit "--target-user でユーザー名を指定してください"
    [[ -z "$target_db"   ]] && error_exit "--database でデータベースを指定してください"

    local privs="ALL PRIVILEGES"
    [[ ${#privileges[@]} -gt 0 ]] && privs=$(IFS=','; echo "${privileges[*]}")

    log_warning "権限削除: ${privs} ON ${target_db}.* FROM '${target_user}'@'${target_host}'"
    mysql_exec "REVOKE ${privs} ON \`${target_db}\`.* FROM '${target_user}'@'${target_host}';"
    mysql_exec "FLUSH PRIVILEGES;"
    log_success "権限削除完了"
}

do_passwd() {
    [[ -z "$target_user" ]] && error_exit "--target-user でユーザー名を指定してください"
    [[ -z "$target_pass" ]] && error_exit "--password で新しいパスワードを指定してください"

    log_info "パスワード変更: '${target_user}'@'${target_host}'"
    mysql_exec "ALTER USER '${target_user}'@'${target_host}' IDENTIFIED BY '${target_pass}';"
    mysql_exec "FLUSH PRIVILEGES;"
    log_success "パスワード変更完了"
}

do_info() {
    [[ -z "$target_user" ]] && error_exit "--target-user でユーザー名を指定してください"

    log_info "ユーザー情報: '${target_user}'@'${target_host}'"
    echo ""

    printf "  ${C_CYAN}【アカウント情報】${C_RESET}\n"
    mysql_exec "SELECT User, Host, plugin, password_expired, account_locked
        FROM mysql.user WHERE User='${target_user}' AND Host='${target_host}';" | \
    while IFS=$'\t' read -r user host plugin expired locked; do
        printf "  ユーザー:           %s\n" "$user"
        printf "  ホスト:             %s\n" "$host"
        printf "  認証プラグイン:     %s\n" "$plugin"
        printf "  パスワード期限切れ: %s\n" "$expired"
        printf "  アカウントロック:   %s\n" "$locked"
    done

    echo ""
    printf "  ${C_CYAN}【権限】${C_RESET}\n"
    mysql_exec "SHOW GRANTS FOR '${target_user}'@'${target_host}';" | \
    while read -r grant; do
        printf "  %s\n" "$grant"
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
            -H|--host)    [[ $# -lt 2 ]] && error_exit "--host には値が必要です"; mysql_host="$2"; shift 2 ;;
            -P|--port)    [[ $# -lt 2 ]] && error_exit "--port には値が必要です"; mysql_port="$2"; shift 2 ;;
            -u|--user)    [[ $# -lt 2 ]] && error_exit "--user には値が必要です"; mysql_root_user="$2"; shift 2 ;;
            -p|--pass)    [[ $# -lt 2 ]] && error_exit "--pass には値が必要です"; mysql_root_pass="$2"; shift 2 ;;
            -U|--target-user) [[ $# -lt 2 ]] && error_exit "--target-user には値が必要です"; target_user="$2"; shift 2 ;;
            -A|--target-host) [[ $# -lt 2 ]] && error_exit "--target-host には値が必要です"; target_host="$2"; shift 2 ;;
            -w|--password)    [[ $# -lt 2 ]] && error_exit "--password には値が必要です"; target_pass="$2"; shift 2 ;;
            -d|--database)    [[ $# -lt 2 ]] && error_exit "--database には値が必要です"; target_db="$2"; shift 2 ;;
            -G|--privileges)  [[ $# -lt 2 ]] && error_exit "--privileges には値が必要です"; IFS=',' read -ra privileges <<< "$2"; shift 2 ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  error_exit "不明な引数: $1" ;;
        esac
    done
}

main() {
    parse_arguments "$@"
    case "$action" in
        list)   do_list ;;
        create) do_create ;;
        drop)   do_drop ;;
        grant)  do_grant ;;
        revoke) do_revoke ;;
        passwd) do_passwd ;;
        info)   do_info ;;
        *)      error_exit "不明なアクション: $action。--help を参照してください" ;;
    esac
}

main "$@"
