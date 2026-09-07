#!/bin/bash
set -euo pipefail

#
# PostgreSQL管理ヘルパー
# バージョン: 1.0
#
# PostgreSQLのDB管理・パフォーマンス監視・ユーザー管理を行うツール
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare pg_host="${PGHOST:-localhost}"
declare -i pg_port="${PGPORT:-5432}"
declare pg_user="${PGUSER:-postgres}"
declare pg_db="${PGDATABASE:-postgres}"
declare mode="status"
declare db_name=""
declare target_user=""
declare -i top_n=10

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション] コマンド

PostgreSQL管理ヘルパー

コマンド:
  status            サーバー状態・接続情報
  databases         データベース一覧
  tables [DB]       テーブル一覧とサイズ
  users             ユーザー/ロール一覧
  connections       現在の接続状態
  locks             ロック待ち状態
  slow              スロークエリ (pg_stat_statements必要)
  vacuum            VACUUM状態・Bloat情報
  indexes           未使用インデックス
  cache             バッファキャッシュヒット率
  size              データベースサイズ一覧
  createdb NAME     データベースを作成
  dropdb NAME       データベースを削除
  query SQL         SQLクエリを実行

オプション:
  -h, --help              このヘルプを表示
  -v, --version           バージョン情報を表示
  -H, --host HOST         PostgreSQLホスト [デフォルト: localhost]
  -p, --port PORT         ポート [デフォルト: 5432]
  -U, --user USER         ユーザー [デフォルト: postgres]
  -d, --database DB       接続先データベース [デフォルト: postgres]
  -n, --top NUM           上位N件表示 [デフォルト: 10]

環境変数: PGHOST, PGPORT, PGUSER, PGDATABASE, PGPASSWORD

例:
  $PROG_NAME status
  $PROG_NAME databases
  $PROG_NAME tables mydb
  $PROG_NAME -d mydb slow
  $PROG_NAME connections

EOF
}

psql_cmd() {
    PGPASSWORD="${PGPASSWORD:-}" psql \
        -h "$pg_host" -p "$pg_port" -U "$pg_user" -d "$pg_db" \
        -t -A -F '|' "$@" 2>/dev/null
}

psql_query() {
    psql_cmd -c "$1"
}

check_pg() {
    if ! command -v psql &>/dev/null; then
        error_exit "psqlがインストールされていません"
    fi
    if ! psql_cmd -c "SELECT 1" &>/dev/null; then
        error_exit "PostgreSQLへの接続に失敗しました: ${pg_host}:${pg_port}"
    fi
}

do_status() {
    check_pg
    log_info "PostgreSQL状態 (${pg_host}:${pg_port})"
    echo ""

    local ver
    ver=$(psql_query "SELECT version();" | head -1)
    printf "  %-25s %s\n" "バージョン:" "$ver"

    local uptime
    uptime=$(psql_query "SELECT date_trunc('second', now() - pg_postmaster_start_time());" | head -1)
    printf "  %-25s %s\n" "稼働時間:" "$uptime"

    local db_count
    db_count=$(psql_query "SELECT count(*) FROM pg_database WHERE NOT datistemplate;" | head -1)
    printf "  %-25s %s\n" "データベース数:" "$db_count"

    local conn_count max_conn
    conn_count=$(psql_query "SELECT count(*) FROM pg_stat_activity;" | head -1)
    max_conn=$(psql_query "SHOW max_connections;" | head -1)
    printf "  %-25s %s / %s\n" "接続数:" "$conn_count" "$max_conn"

    local cache_hit
    cache_hit=$(psql_query "SELECT round(100.0*sum(blks_hit)/nullif(sum(blks_hit+blks_read),0),2) FROM pg_stat_database;" | head -1)
    local cache_color="$C_GREEN"
    (( ${cache_hit%.*} < 90 )) && cache_color="$C_YELLOW"
    (( ${cache_hit%.*} < 80 )) && cache_color="$C_RED"
    printf "  %-25s ${cache_color}%s%%${C_RESET}\n" "キャッシュヒット率:" "$cache_hit"

    local total_size
    total_size=$(psql_query "SELECT pg_size_pretty(sum(pg_database_size(datname))) FROM pg_database WHERE NOT datistemplate;" | head -1)
    printf "  %-25s %s\n" "合計サイズ:" "$total_size"
    echo ""
}

do_databases() {
    check_pg
    log_info "データベース一覧"
    echo ""

    printf "  ${C_BOLD}%-25s %10s %10s %-15s${C_RESET}\n" "名前" "サイズ" "接続数" "オーナー"
    printf "  %s\n" "$(printf '%.0s-' {1..65})"

    psql_query "
        SELECT d.datname,
               pg_size_pretty(pg_database_size(d.datname)),
               coalesce(c.connections, 0),
               r.rolname
        FROM pg_database d
        JOIN pg_roles r ON d.datdba = r.oid
        LEFT JOIN (
            SELECT datname, count(*) as connections
            FROM pg_stat_activity GROUP BY datname
        ) c ON d.datname = c.datname
        WHERE NOT d.datistemplate
        ORDER BY pg_database_size(d.datname) DESC;
    " | while IFS='|' read -r name size conn owner; do
        printf "  %-25s %10s %10s %-15s\n" "$name" "$size" "$conn" "$owner"
    done
    echo ""
}

do_tables() {
    local db="${db_name:-$pg_db}"
    check_pg
    log_info "テーブル一覧: $db"
    echo ""

    PGDATABASE="$db" psql_query "
        SELECT schemaname || '.' || tablename,
               pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)),
               n_live_tup,
               last_vacuum,
               last_analyze
        FROM pg_stat_user_tables
        ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
        LIMIT ${top_n};
    " | while IFS='|' read -r name size rows last_vac last_analyze; do
        printf "  %-40s %10s %12s行\n" "$name" "$size" "$rows"
    done 2>/dev/null || log_warning "テーブルが見つかりません"
    echo ""
}

do_connections() {
    check_pg
    log_info "現在の接続状態"
    echo ""

    printf "  ${C_BOLD}%-8s %-15s %-15s %-12s %-10s %s${C_RESET}\n" \
        "PID" "ユーザー" "データベース" "状態" "待機時間" "クエリ"
    printf "  %s\n" "$(printf '%.0s-' {1..85})"

    psql_query "
        SELECT pid,
               usename,
               datname,
               state,
               coalesce(date_trunc('second', now() - query_start)::text, '-'),
               left(query, 50)
        FROM pg_stat_activity
        WHERE pid <> pg_backend_pid()
        ORDER BY query_start;
    " | while IFS='|' read -r pid user db state wait query; do
        local state_color="$C_RESET"
        case "$state" in
            active)   state_color="$C_GREEN" ;;
            idle)     state_color="$C_DIM" ;;
            "idle in transaction") state_color="$C_YELLOW" ;;
            waiting)  state_color="$C_RED" ;;
        esac
        printf "  %-8s %-15s %-15s ${state_color}%-12s${C_RESET} %-10s %s\n" \
            "$pid" "${user:0:14}" "${db:0:14}" "$state" "$wait" "$query"
    done
    echo ""
}

do_locks() {
    check_pg
    log_info "ロック待ち状態"
    echo ""

    local lock_count
    lock_count=$(psql_query "SELECT count(*) FROM pg_locks WHERE NOT granted;" | head -1)

    if [[ "$lock_count" == "0" ]]; then
        log_success "ロック待ちはありません"
        echo ""
        return 0
    fi

    printf "  ${C_YELLOW}ロック待ち: %s 件${C_RESET}\n\n" "$lock_count"

    psql_query "
        SELECT l.pid,
               a.usename,
               l.relation::regclass,
               l.locktype,
               l.mode,
               date_trunc('second', now() - a.query_start)
        FROM pg_locks l
        JOIN pg_stat_activity a ON l.pid = a.pid
        WHERE NOT l.granted
        ORDER BY a.query_start;
    " | while IFS='|' read -r pid user rel type mode wait; do
        printf "  ${C_RED}%-8s${C_RESET} %-15s %-20s %-10s %-15s %s\n" \
            "$pid" "$user" "$rel" "$type" "$mode" "$wait"
    done
    echo ""
}

do_cache() {
    check_pg
    log_info "バッファキャッシュヒット率"
    echo ""

    printf "  ${C_BOLD}%-30s %10s %10s %8s${C_RESET}\n" "データベース" "ヒット" "リード" "ヒット率"
    printf "  %s\n" "$(printf '%.0s-' {1..62})"

    psql_query "
        SELECT datname,
               blks_hit,
               blks_read,
               round(100.0*blks_hit/nullif(blks_hit+blks_read,0),2)
        FROM pg_stat_database
        WHERE datname NOT IN ('template0','template1')
        ORDER BY blks_hit+blks_read DESC;
    " | while IFS='|' read -r db hit read rate; do
        local color="$C_GREEN"
        (( ${rate%.*} < 90 )) && color="$C_YELLOW"
        (( ${rate%.*} < 80 )) && color="$C_RED"
        printf "  %-30s %10s %10s ${color}%8s%%${C_RESET}\n" "$db" "$hit" "$read" "$rate"
    done
    echo ""
}

do_size() {
    check_pg
    log_info "データベースサイズ一覧"
    echo ""

    printf "  ${C_BOLD}%-30s %12s${C_RESET}\n" "データベース" "サイズ"
    printf "  %s\n" "$(printf '%.0s-' {1..45})"

    psql_query "
        SELECT datname, pg_size_pretty(pg_database_size(datname))
        FROM pg_database
        WHERE NOT datistemplate
        ORDER BY pg_database_size(datname) DESC;
    " | while IFS='|' read -r db size; do
        printf "  %-30s %12s\n" "$db" "$size"
    done
    echo ""
}

do_vacuum() {
    check_pg
    log_info "VACUUM状態"
    echo ""

    printf "  ${C_BOLD}%-35s %10s %10s %-20s %-20s${C_RESET}\n" \
        "テーブル" "DeadRows" "LiveRows" "最終Vacuum" "最終Analyze"
    printf "  %s\n" "$(printf '%.0s-' {1..95})"

    psql_query "
        SELECT schemaname||'.'||relname,
               n_dead_tup,
               n_live_tup,
               coalesce(last_vacuum::text, 'never'),
               coalesce(last_analyze::text, 'never')
        FROM pg_stat_user_tables
        ORDER BY n_dead_tup DESC
        LIMIT ${top_n};
    " | while IFS='|' read -r table dead live vac analyze; do
        local dead_color="$C_RESET"
        (( dead > 10000 )) && dead_color="$C_YELLOW"
        (( dead > 100000 )) && dead_color="$C_RED"
        printf "  %-35s ${dead_color}%10s${C_RESET} %10s %-20s %-20s\n" \
            "$table" "$dead" "$live" "${vac:0:19}" "${analyze:0:19}"
    done
    echo ""
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -H|--host)    [[ $# -lt 2 ]] && error_exit "-H には値が必要です"; pg_host="$2"; shift 2 ;;
            -p|--port)    [[ $# -lt 2 ]] && error_exit "-p には値が必要です"; pg_port="$2"; shift 2 ;;
            -U|--user)    [[ $# -lt 2 ]] && error_exit "-U には値が必要です"; pg_user="$2"; shift 2 ;;
            -d|--database) [[ $# -lt 2 ]] && error_exit "-d には値が必要です"; pg_db="$2"; shift 2 ;;
            -n|--top)     [[ $# -lt 2 ]] && error_exit "-n には値が必要です"; top_n="$2"; shift 2 ;;
            status|databases|users|connections|locks|cache|size|vacuum|indexes) mode="$1"; shift ;;
            tables)
                mode="tables"
                [[ $# -ge 2 && ! "$2" =~ ^- ]] && { db_name="$2"; shift; }
                shift
                ;;
            query)
                mode="query"
                [[ $# -ge 2 ]] && { db_name="$2"; shift; }
                shift
                ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  shift ;;
        esac
    done
}

main() {
    parse_arguments "$@"

    case "$mode" in
        status)      do_status ;;
        databases)   do_databases ;;
        tables)      do_tables ;;
        connections) do_connections ;;
        locks)       do_locks ;;
        cache)       do_cache ;;
        size)        do_size ;;
        vacuum)      do_vacuum ;;
        *)           error_exit "不明なコマンド: $mode" ;;
    esac
}

main "$@"
