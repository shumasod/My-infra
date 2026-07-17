#!/bin/bash
set -euo pipefail

#
# データベースヘルスチェックツール
# バージョン: 1.0
#
# MySQL/PostgreSQL の接続・パフォーマンス・容量をチェックするツール
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare db_type="mysql"
declare db_host="localhost"
declare db_port=""
declare db_user=""
declare db_pass=""
declare db_name=""
declare -i warn_conn=80
declare -i warn_slow_query=10
declare output_file=""

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション]

MySQL/PostgreSQLのヘルスチェックツール

オプション:
  -h, --help            このヘルプを表示
  -v, --version         バージョン情報を表示
  -t, --type TYPE       DBタイプ (mysql|postgres) [デフォルト: mysql]
  -H, --host HOST       ホスト名 [デフォルト: localhost]
  -P, --port PORT       ポート番号
  -u, --user USER       ユーザー名
  -p, --pass PASS       パスワード (非推奨: MYSQL_PWD/PGPASSWORD環境変数を使用)
  -d, --database DB     データベース名
  --warn-conn PCT       接続数警告閾値% [デフォルト: 80]
  --warn-slow NUM       スロークエリ警告閾値数 [デフォルト: 10]
  -o, --output FILE     結果をファイルに保存

例:
  $PROG_NAME -t mysql -u root -d mydb
  $PROG_NAME -t postgres -H db.example.com -u admin -d appdb
  MYSQL_PWD=secret $PROG_NAME -t mysql -u root

EOF
}

mysql_check() {
    local mysql_cmd=(mysql -h "$db_host" -u "${db_user:-root}" --batch --skip-column-names)
    [[ -n "$db_port"   ]] && mysql_cmd+=(-P "$db_port")
    [[ -n "$db_pass"   ]] && mysql_cmd+=(-p"$db_pass")
    [[ -n "$db_name"   ]] && mysql_cmd+=("$db_name")

    log_info "MySQL ヘルスチェック: ${db_host}"
    echo ""

    # 接続確認
    if ! "${mysql_cmd[@]}" -e "SELECT 1" &>/dev/null; then
        log_error "接続失敗"
        return 1
    fi
    log_success "接続: OK"

    # バージョン
    local version
    version=$("${mysql_cmd[@]}" -e "SELECT VERSION()")
    printf "  バージョン: %s\n" "$version"

    # 接続数チェック
    local max_conn curr_conn conn_pct
    max_conn=$("${mysql_cmd[@]}" -e "SHOW VARIABLES LIKE 'max_connections'" | awk '{print $2}')
    curr_conn=$("${mysql_cmd[@]}" -e "SHOW STATUS LIKE 'Threads_connected'" | awk '{print $2}')
    conn_pct=$(( curr_conn * 100 / max_conn ))

    local conn_status="${C_GREEN}正常${C_RESET}"
    (( conn_pct >= warn_conn )) && conn_status="${C_RED}警告${C_RESET}"

    printf "  接続数: %d/%d (%d%%) %b\n" "$curr_conn" "$max_conn" "$conn_pct" "$conn_status"

    # スロークエリ
    local slow_queries
    slow_queries=$("${mysql_cmd[@]}" -e "SHOW STATUS LIKE 'Slow_queries'" | awk '{print $2}')
    local slow_status="${C_GREEN}正常${C_RESET}"
    (( slow_queries >= warn_slow_query )) && slow_status="${C_RED}警告${C_RESET}"
    printf "  スロークエリ: %d件 %b\n" "$slow_queries" "$slow_status"

    # データベースサイズ
    if [[ -n "$db_name" ]]; then
        local db_size
        db_size=$("${mysql_cmd[@]}" -e "
            SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 1)
            FROM information_schema.tables
            WHERE table_schema = '${db_name}'" 2>/dev/null || echo "N/A")
        printf "  DB サイズ: %s MB\n" "$db_size"
    fi

    # Innodb バッファプール
    local buffer_pool_hit
    local reads
    local read_requests
    reads=$("${mysql_cmd[@]}" -e "SHOW STATUS LIKE 'Innodb_buffer_pool_reads'" | awk '{print $2}')
    read_requests=$("${mysql_cmd[@]}" -e "SHOW STATUS LIKE 'Innodb_buffer_pool_read_requests'" | awk '{print $2}')
    if (( read_requests > 0 )); then
        buffer_pool_hit=$(( (read_requests - reads) * 100 / read_requests ))
        printf "  バッファプールヒット率: %d%%\n" "$buffer_pool_hit"
    fi

    echo ""
}

postgres_check() {
    local pg_cmd=(psql -h "$db_host" -U "${db_user:-postgres}" -t -A)
    [[ -n "$db_port" ]] && pg_cmd+=(-p "$db_port")
    [[ -n "$db_name" ]] && pg_cmd+=(-d "$db_name")
    [[ -n "$db_pass" ]] && export PGPASSWORD="$db_pass"

    log_info "PostgreSQL ヘルスチェック: ${db_host}"
    echo ""

    if ! "${pg_cmd[@]}" -c "SELECT 1" &>/dev/null; then
        log_error "接続失敗"
        return 1
    fi
    log_success "接続: OK"

    local version
    version=$("${pg_cmd[@]}" -c "SELECT version()" | head -1 | cut -d' ' -f1-3)
    printf "  バージョン: %s\n" "$version"

    local max_conn curr_conn conn_pct
    max_conn=$("${pg_cmd[@]}" -c "SHOW max_connections")
    curr_conn=$("${pg_cmd[@]}" -c "SELECT count(*) FROM pg_stat_activity WHERE state = 'active'")
    conn_pct=$(( curr_conn * 100 / max_conn ))

    local conn_status="${C_GREEN}正常${C_RESET}"
    (( conn_pct >= warn_conn )) && conn_status="${C_RED}警告${C_RESET}"
    printf "  接続数: %d/%d (%d%%) %b\n" "$curr_conn" "$max_conn" "$conn_pct" "$conn_status"

    # DB サイズ
    if [[ -n "$db_name" ]]; then
        local db_size
        db_size=$("${pg_cmd[@]}" -c "SELECT pg_size_pretty(pg_database_size('${db_name}'))")
        printf "  DB サイズ: %s\n" "$db_size"
    fi

    # ロック待ち
    local locks
    locks=$("${pg_cmd[@]}" -c "SELECT count(*) FROM pg_locks WHERE NOT granted")
    printf "  ロック待ち: %s件\n" "$locks"

    echo ""
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -t|--type)
                [[ $# -lt 2 ]] && error_exit "--type には値が必要です"
                db_type="$2"; shift 2 ;;
            -H|--host)
                [[ $# -lt 2 ]] && error_exit "--host には値が必要です"
                db_host="$2"; shift 2 ;;
            -P|--port)
                [[ $# -lt 2 ]] && error_exit "--port には値が必要です"
                db_port="$2"; shift 2 ;;
            -u|--user)
                [[ $# -lt 2 ]] && error_exit "--user には値が必要です"
                db_user="$2"; shift 2 ;;
            -p|--pass)
                [[ $# -lt 2 ]] && error_exit "--pass には値が必要です"
                db_pass="$2"; shift 2 ;;
            -d|--database)
                [[ $# -lt 2 ]] && error_exit "--database には値が必要です"
                db_name="$2"; shift 2 ;;
            --warn-conn)
                [[ $# -lt 2 ]] && error_exit "--warn-conn には数値が必要です"
                warn_conn="$2"; shift 2 ;;
            --warn-slow)
                [[ $# -lt 2 ]] && error_exit "--warn-slow には数値が必要です"
                warn_slow_query="$2"; shift 2 ;;
            -o|--output)
                [[ $# -lt 2 ]] && error_exit "--output には値が必要です"
                output_file="$2"; shift 2 ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  error_exit "不明な引数: $1" ;;
        esac
    done
}

main() {
    parse_arguments "$@"

    local result
    case "$db_type" in
        mysql)    mysql_check ;;
        postgres) postgres_check ;;
        *)        error_exit "不明なDBタイプ: $db_type (mysql|postgres)" ;;
    esac
}

main "$@"
