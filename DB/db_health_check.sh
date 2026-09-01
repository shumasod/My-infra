#!/bin/bash
set -euo pipefail

#
# データベースヘルスチェックツール
# 作成日: 2026-09-01
# バージョン: 1.0
#
# MySQL/PostgreSQL/Redisの接続・パフォーマンス・整合性を確認します
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare command_name="all"
declare db_type="mysql"
declare db_host="127.0.0.1"
declare db_port=""
declare db_user=""
declare db_pass=""
declare db_name=""
declare timeout=5
declare output_format="text"

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション]

データベースヘルスチェックツールです。

コマンド:
  all                  総合ヘルスチェック (デフォルト)
  connect              接続確認
  replication          レプリケーション状態
  locks                ロック状態確認
  size                 データベースサイズ
  queries              実行中クエリ確認
  config               設定確認

オプション:
  -h, --help           このヘルプを表示
  -v, --version        バージョン情報を表示
  --type <種類>        DBタイプ (mysql|postgres|redis) [デフォルト: mysql]
  -H, --host <ホスト>  DBホスト [デフォルト: 127.0.0.1]
  -P, --port <ポート>  DBポート
  -u, --user <ユーザー> DBユーザー
  -p, --pass <パスワード> DBパスワード
  -d, --db <DB名>      対象データベース
  -t, --timeout <秒>   タイムアウト [デフォルト: 5]
  -f, --format <形式>  出力形式 (text|json) [デフォルト: text]

例:
  $PROG_NAME all --type mysql -u root -p secret
  $PROG_NAME connect --type postgres -u postgres
  $PROG_NAME replication --type mysql -u root
  $PROG_NAME all --type redis -H 127.0.0.1
EOF
}

get_port() {
    case "$db_type" in
        mysql)    echo "${db_port:-3306}" ;;
        postgres) echo "${db_port:-5432}" ;;
        redis)    echo "${db_port:-6379}" ;;
        *)        echo "${db_port:-3306}" ;;
    esac
}

mysql_q() {
    local port
    port=$(get_port)
    local args=(-h "$db_host" -P "$port" --connect-timeout="$timeout" --batch --skip-column-names)
    [[ -n "$db_user" ]] && args+=(-u "$db_user")
    [[ -n "$db_pass" ]] && args+=(-p"$db_pass")
    mysql "${args[@]}" -e "$1" 2>/dev/null
}

pg_q() {
    local port
    port=$(get_port)
    local env_args=()
    [[ -n "$db_pass" ]] && env_args+=("PGPASSWORD=$db_pass")
    env "${env_args[@]}" psql \
        -h "$db_host" -p "$port" \
        ${db_user:+-U "$db_user"} \
        ${db_name:+-d "$db_name"} \
        -t -c "$1" 2>/dev/null
}

redis_q() {
    local port
    port=$(get_port)
    local args=(-h "$db_host" -p "$port" --no-auth-warning)
    [[ -n "$db_pass" ]] && args+=(-a "$db_pass")
    redis-cli "${args[@]}" "$@" 2>/dev/null
}

check_pass() {
    printf "  ${C_GREEN}[OK]${C_RESET}    %s\n" "$1"
}

check_warn() {
    printf "  ${C_YELLOW}[WARN]${C_RESET}  %s\n" "$1"
}

check_fail() {
    printf "  ${C_RED}[FAIL]${C_RESET}  %s\n" "$1"
}

check_info() {
    printf "  ${C_CYAN}[INFO]${C_RESET}  %s\n" "$1"
}

cmd_connect() {
    log_info "接続確認: ${db_type}://${db_host}:$(get_port)"
    echo ""

    local start_ms
    start_ms=$(date +%s%3N)

    case "$db_type" in
        mysql)
            if mysql_q "SELECT 1" &>/dev/null; then
                local end_ms
                end_ms=$(date +%s%3N)
                check_pass "接続成功 (${db_host}:$(get_port))"
                check_info "応答時間: $(( end_ms - start_ms )) ms"
                local version
                version=$(mysql_q "SELECT VERSION()" | head -1)
                check_info "バージョン: ${version}"
            else
                check_fail "接続失敗 (${db_host}:$(get_port))"
                return 1
            fi
            ;;
        postgres)
            if pg_q "SELECT 1" &>/dev/null; then
                local end_ms
                end_ms=$(date +%s%3N)
                check_pass "接続成功 (${db_host}:$(get_port))"
                check_info "応答時間: $(( end_ms - start_ms )) ms"
                local version
                version=$(pg_q "SELECT version()" | head -1 | xargs)
                check_info "バージョン: ${version:0:60}"
            else
                check_fail "接続失敗 (${db_host}:$(get_port))"
                return 1
            fi
            ;;
        redis)
            if redis_q PING | grep -q "PONG"; then
                local end_ms
                end_ms=$(date +%s%3N)
                check_pass "接続成功 (${db_host}:$(get_port))"
                check_info "応答時間: $(( end_ms - start_ms )) ms"
                local version
                version=$(redis_q INFO server | grep "redis_version" | cut -d: -f2 | tr -d '\r')
                check_info "バージョン: ${version}"
            else
                check_fail "接続失敗 (${db_host}:$(get_port))"
                return 1
            fi
            ;;
    esac
    echo ""
}

cmd_replication() {
    log_info "レプリケーション状態確認"
    echo ""

    case "$db_type" in
        mysql)
            local slave_status
            slave_status=$(mysql_q "SHOW SLAVE STATUS\G" 2>/dev/null || \
                           mysql_q "SHOW REPLICA STATUS\G" 2>/dev/null || echo "")

            if [[ -z "$slave_status" ]]; then
                check_info "スレーブ設定なし (マスターとして稼働)"
                local bin_log
                bin_log=$(mysql_q "SHOW MASTER STATUS" | head -1 || echo "")
                if [[ -n "$bin_log" ]]; then
                    check_pass "バイナリログ有効"
                    check_info "バイナリログファイル: $(echo "$bin_log" | awk '{print $1}')"
                fi
            else
                local io_running sql_running delay
                io_running=$(echo "$slave_status" | grep "Slave_IO_Running\|Replica_IO_Running" | awk '{print $2}')
                sql_running=$(echo "$slave_status" | grep "Slave_SQL_Running\|Replica_SQL_Running" | awk '{print $2}')
                delay=$(echo "$slave_status" | grep "Seconds_Behind_Master\|Seconds_Behind_Source" | awk '{print $2}')

                [[ "$io_running"  == "Yes" ]] && check_pass "IO スレッド: 実行中"  || check_fail "IO スレッド: 停止"
                [[ "$sql_running" == "Yes" ]] && check_pass "SQL スレッド: 実行中" || check_fail "SQL スレッド: 停止"
                if [[ "$delay" =~ ^[0-9]+$ ]]; then
                    if (( delay < 10 )); then
                        check_pass "レプリケーション遅延: ${delay}秒"
                    elif (( delay < 60 )); then
                        check_warn "レプリケーション遅延: ${delay}秒"
                    else
                        check_fail "レプリケーション遅延: ${delay}秒"
                    fi
                fi
            fi
            ;;
        postgres)
            local repl_info
            repl_info=$(pg_q "SELECT client_addr, state, sent_lsn, replay_lsn FROM pg_stat_replication;" 2>/dev/null || echo "")
            if [[ -z "$repl_info" ]]; then
                check_info "スタンバイなし (プライマリとして稼働)"
                local is_recovery
                is_recovery=$(pg_q "SELECT pg_is_in_recovery();" | xargs 2>/dev/null || echo "f")
                [[ "$is_recovery" == "t" ]] && check_info "リカバリモード (スタンバイ)" || check_pass "プライマリモード"
            else
                while IFS='|' read -r addr state sent replay; do
                    [[ -z "$(echo "$addr" | xargs)" ]] && continue
                    check_pass "スタンバイ: $(echo "$addr" | xargs) [$(echo "$state" | xargs)]"
                done <<< "$repl_info"
            fi
            ;;
        redis)
            local info
            info=$(redis_q INFO replication 2>/dev/null || echo "")
            local role
            role=$(echo "$info" | grep "^role:" | cut -d: -f2 | tr -d '\r')
            check_info "ロール: ${role:-不明}"
            if [[ "$role" == "master" ]]; then
                local slaves
                slaves=$(echo "$info" | grep "^connected_slaves:" | cut -d: -f2 | tr -d '\r')
                check_info "接続スレーブ数: ${slaves:-0}"
            fi
            ;;
    esac
    echo ""
}

cmd_locks() {
    log_info "ロック状態確認"
    echo ""

    case "$db_type" in
        mysql)
            local locks
            locks=$(mysql_q "SELECT * FROM information_schema.INNODB_LOCKS;" 2>/dev/null || echo "")
            if [[ -z "$locks" ]]; then
                check_pass "デッドロックなし"
            else
                check_warn "アクティブなロック検出"
                local count
                count=$(echo "$locks" | wc -l)
                check_info "ロック数: $count"
            fi

            local waits
            waits=$(mysql_q "SELECT * FROM information_schema.INNODB_LOCK_WAITS;" 2>/dev/null || echo "")
            if [[ -z "$waits" ]]; then
                check_pass "ロック待ちなし"
            else
                check_warn "ロック待ちあり"
            fi

            local long_running
            long_running=$(mysql_q "SELECT COUNT(*) FROM information_schema.PROCESSLIST WHERE TIME > 60 AND COMMAND != 'Sleep';" 2>/dev/null | head -1 || echo "0")
            if (( ${long_running:-0} > 0 )); then
                check_warn "60秒以上の実行中クエリ: ${long_running}件"
            else
                check_pass "長時間クエリなし"
            fi
            ;;
        postgres)
            local lock_count
            lock_count=$(pg_q "SELECT COUNT(*) FROM pg_locks WHERE granted=false;" | xargs 2>/dev/null || echo "0")
            if (( ${lock_count:-0} > 0 )); then
                check_warn "ロック待ち: ${lock_count}件"
            else
                check_pass "ロック待ちなし"
            fi
            ;;
        redis)
            check_info "Redisはロック機能なし"
            ;;
    esac
    echo ""
}

cmd_size() {
    log_info "データベースサイズ確認"
    echo ""

    case "$db_type" in
        mysql)
            mysql_q "
                SELECT table_schema AS 'データベース',
                    ROUND(SUM(data_length + index_length) / 1024 / 1024, 1) AS 'サイズ(MB)'
                FROM information_schema.tables
                WHERE table_schema NOT IN ('information_schema','performance_schema','mysql','sys')
                GROUP BY table_schema
                ORDER BY SUM(data_length + index_length) DESC;" 2>/dev/null | \
            while IFS=$'\t' read -r db sz; do
                printf "  %-30s %s MB\n" "$db" "$sz"
            done
            ;;
        postgres)
            pg_q "SELECT datname, pg_size_pretty(pg_database_size(datname)) FROM pg_database ORDER BY pg_database_size(datname) DESC;" 2>/dev/null | \
            while IFS='|' read -r db sz; do
                [[ -z "$(echo "$db" | xargs)" ]] && continue
                printf "  %-30s %s\n" "$(echo "$db" | xargs)" "$(echo "$sz" | xargs)"
            done
            ;;
        redis)
            local mem
            mem=$(redis_q INFO memory | grep "used_memory_human:" | cut -d: -f2 | tr -d '\r')
            check_info "使用メモリ: ${mem}"
            local keys
            keys=$(redis_q DBSIZE)
            check_info "総キー数: ${keys}"
            ;;
    esac
    echo ""
}

cmd_queries() {
    log_info "実行中クエリ確認"
    echo ""

    case "$db_type" in
        mysql)
            printf "${C_BOLD}  %-6s %-15s %-8s %s${C_RESET}\n" "ID" "ユーザー" "時間" "クエリ"
            printf "  %s\n" "$(printf '%.0s─' {1..60})"
            mysql_q "SELECT ID, USER, TIME, INFO FROM information_schema.PROCESSLIST WHERE COMMAND != 'Sleep' AND TIME > 0 ORDER BY TIME DESC LIMIT 10;" 2>/dev/null | \
            while IFS=$'\t' read -r id user time query; do
                local color="$C_GREEN"
                (( ${time:-0} > 10 )) && color="$C_YELLOW"
                (( ${time:-0} > 60 )) && color="$C_RED"
                printf "  %-6s %-15s ${color}%8ss${C_RESET} %s\n" \
                    "$id" "${user:0:15}" "$time" "${query:0:40}"
            done
            ;;
        postgres)
            printf "${C_BOLD}  %-6s %-15s %-10s %s${C_RESET}\n" "PID" "ユーザー" "期間" "クエリ"
            printf "  %s\n" "$(printf '%.0s─' {1..60})"
            pg_q "SELECT pid, usename, EXTRACT(EPOCH FROM query_start - now())::integer AS dur, query
                  FROM pg_stat_activity
                  WHERE state='active' AND query NOT LIKE '%pg_stat_activity%'
                  ORDER BY dur LIMIT 10;" 2>/dev/null | \
            while IFS='|' read -r pid user dur query; do
                [[ -z "$(echo "$pid" | xargs)" ]] && continue
                printf "  %-6s %-15s %10ss %s\n" \
                    "$(echo "$pid" | xargs)" "$(echo "$user" | xargs)" \
                    "$(echo "${dur:-0}" | xargs)" "$(echo "$query" | xargs | cut -c1-40)"
            done
            ;;
        redis)
            local clients
            clients=$(redis_q CLIENT LIST 2>/dev/null | wc -l)
            check_info "接続クライアント数: $clients"
            local slowlog
            slowlog=$(redis_q SLOWLOG LEN 2>/dev/null)
            check_info "スロークエリ数: ${slowlog:-0}"
            ;;
    esac
    echo ""
}

cmd_config() {
    log_info "設定確認"
    echo ""

    case "$db_type" in
        mysql)
            local vars=("max_connections" "innodb_buffer_pool_size" "slow_query_log" "long_query_time" "character_set_server" "transaction_isolation")
            for v in "${vars[@]}"; do
                local val
                val=$(mysql_q "SHOW GLOBAL VARIABLES LIKE '${v}';" | awk '{print $2}')
                printf "  %-35s %s\n" "$v:" "${val:-N/A}"
            done
            ;;
        postgres)
            local params=("max_connections" "shared_buffers" "work_mem" "log_slow_statement" "log_min_duration_statement")
            for p in "${params[@]}"; do
                local val
                val=$(pg_q "SHOW $p;" | xargs 2>/dev/null || echo "N/A")
                printf "  %-35s %s\n" "$p:" "${val:-N/A}"
            done
            ;;
        redis)
            local keys=("maxmemory" "maxmemory-policy" "save" "appendonly" "requirepass")
            for k in "${keys[@]}"; do
                local val
                val=$(redis_q CONFIG GET "$k" 2>/dev/null | tail -1 || echo "N/A")
                printf "  %-35s %s\n" "${k}:" "${val:-N/A}"
            done
            ;;
    esac
    echo ""
}

cmd_all() {
    cmd_connect || return 1
    cmd_replication
    cmd_locks
    cmd_size
    cmd_queries
    log_success "ヘルスチェック完了"
}

parse_arguments() {
    [[ $# -eq 0 ]] && return 0
    case "$1" in
        all|connect|replication|locks|size|queries|config)
            command_name="$1"; shift ;;
    esac

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            --type)       [[ $# -lt 2 ]] && error_exit "--type には値が必要です"; db_type="$2"; shift 2 ;;
            -H|--host)    [[ $# -lt 2 ]] && error_exit "--host には値が必要です"; db_host="$2"; shift 2 ;;
            -P|--port)    [[ $# -lt 2 ]] && error_exit "--port には値が必要です"; db_port="$2"; shift 2 ;;
            -u|--user)    [[ $# -lt 2 ]] && error_exit "--user には値が必要です"; db_user="$2"; shift 2 ;;
            -p|--pass)    [[ $# -lt 2 ]] && error_exit "--pass には値が必要です"; db_pass="$2"; shift 2 ;;
            -d|--db)      [[ $# -lt 2 ]] && error_exit "--db には値が必要です"; db_name="$2"; shift 2 ;;
            -t|--timeout) [[ $# -lt 2 ]] && error_exit "--timeout には値が必要です"; timeout="$2"; shift 2 ;;
            -f|--format)  [[ $# -lt 2 ]] && error_exit "--format には値が必要です"; output_format="$2"; shift 2 ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  shift ;;
        esac
    done
}

main() {
    parse_arguments "$@"
    case "$command_name" in
        all)         cmd_all ;;
        connect)     cmd_connect ;;
        replication) cmd_replication ;;
        locks)       cmd_locks ;;
        size)        cmd_size ;;
        queries)     cmd_queries ;;
        config)      cmd_config ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
