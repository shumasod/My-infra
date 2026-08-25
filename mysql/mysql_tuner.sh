#!/bin/bash
set -euo pipefail

#
# MySQLパフォーマンスチューニングアドバイザー
# 作成日: 2026-08-25
# バージョン: 1.0
#
# MySQLのステータスを分析してチューニング提案を行います
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare command_name="analyze"
declare mysql_host="127.0.0.1"
declare mysql_port="3306"
declare mysql_user="root"
declare mysql_pass=""
declare mysql_socket=""

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション]

MySQLパフォーマンス分析・チューニングアドバイザーです。

コマンド:
  analyze              総合分析とチューニング提案 (デフォルト)
  status               MySQLステータス変数の表示
  variables            設定変数の表示
  slow                 スロークエリ分析
  innodb               InnoDBステータス分析
  indexes              未使用インデックスの検出

オプション:
  -h, --help           このヘルプを表示
  -v, --version        バージョン情報を表示
  -H, --host <ホスト>  MySQLホスト [デフォルト: 127.0.0.1]
  -P, --port <ポート>  MySQLポート [デフォルト: 3306]
  -u, --user <ユーザー> MySQLユーザー [デフォルト: root]
  -p, --pass <パスワード> MySQLパスワード
  -S, --socket <パス>  UNIXソケットパス

例:
  $PROG_NAME analyze
  $PROG_NAME analyze -u admin -p secret
  $PROG_NAME slow -H db.example.com
  $PROG_NAME innodb
  $PROG_NAME indexes
EOF
}

mysql_cmd() {
    local args=()
    args+=(-h "$mysql_host" -P "$mysql_port" -u "$mysql_user")
    [[ -n "$mysql_pass"   ]] && args+=(-p"$mysql_pass")
    [[ -n "$mysql_socket" ]] && args+=(--socket="$mysql_socket")
    mysql "${args[@]}" --batch --skip-column-names "$@" 2>/dev/null
}

mysql_query() {
    mysql_cmd -e "$1"
}

get_status() {
    local var="$1"
    mysql_query "SHOW GLOBAL STATUS LIKE '${var}';" | awk '{print $2}'
}

get_variable() {
    local var="$1"
    mysql_query "SHOW GLOBAL VARIABLES LIKE '${var}';" | awk '{print $2}'
}

bytes_to_human() {
    local bytes="$1"
    python3 - "$bytes" <<'PYEOF'
import sys
b = int(sys.argv[1])
if b >= 1073741824: print(f"{b/1073741824:.1f} GB")
elif b >= 1048576:  print(f"{b/1048576:.1f} MB")
elif b >= 1024:     print(f"{b/1024:.1f} KB")
else: print(f"{b} B")
PYEOF
}

check_connection() {
    if ! mysql_query "SELECT 1" &>/dev/null; then
        error_exit "MySQLに接続できません: ${mysql_host}:${mysql_port}"
    fi
}

cmd_status() {
    log_info "MySQLグローバルステータス"
    echo ""

    local uptime questions queries conns max_conns threads_connected
    uptime=$(get_status "Uptime")
    questions=$(get_status "Questions")
    queries=$(get_status "Queries")
    conns=$(get_status "Connections")
    max_conns=$(get_variable "max_connections")
    threads_connected=$(get_status "Threads_connected")

    local uptime_fmt
    uptime_fmt=$(printf "%dd %02dh %02dm" \
        $(( uptime / 86400 )) \
        $(( (uptime % 86400) / 3600 )) \
        $(( (uptime % 3600) / 60 )) 2>/dev/null || echo "${uptime}s")

    printf "${C_BOLD}【基本情報】${C_RESET}\n\n"
    local version
    version=$(mysql_query "SELECT VERSION();" | head -1)
    printf "  %-25s %s\n" "MySQLバージョン:"     "$version"
    printf "  %-25s %s\n" "稼働時間:"            "$uptime_fmt"
    printf "  %-25s %s\n" "累計クエリ数:"        "$questions"
    printf "  %-25s %s QPS\n" "平均クエリレート:" \
        "$(echo "scale=2; $questions / ($uptime > 0 ? $uptime : 1)" | bc 2>/dev/null || echo '?')"

    echo ""
    printf "${C_BOLD}【接続情報】${C_RESET}\n\n"
    local conn_pct
    conn_pct=$(echo "scale=1; $threads_connected * 100 / ($max_conns > 0 ? $max_conns : 1)" | \
        bc 2>/dev/null || echo '?')
    local conn_color="$C_GREEN"
    local cp="${conn_pct%.*}"
    (( ${cp:-0} > 70 )) && conn_color="$C_YELLOW"
    (( ${cp:-0} > 90 )) && conn_color="$C_RED"
    printf "  %-25s %s\n" "現在の接続数:"      "$threads_connected"
    printf "  %-25s %s\n" "最大接続設定:"      "$max_conns"
    printf "  %-25s ${conn_color}%s%%${C_RESET}\n" "接続使用率:"  "$conn_pct"
    printf "  %-25s %s\n" "累計接続数:"        "$conns"

    echo ""
}

cmd_analyze() {
    log_info "MySQLパフォーマンス分析"
    echo ""

    cmd_status

    printf "${C_BOLD}【チューニング提案】${C_RESET}\n\n"

    local suggestions=0

    # バッファプールサイズ確認
    local bp_size bp_size_h
    bp_size=$(get_variable "innodb_buffer_pool_size")
    bp_size_h=$(bytes_to_human "$bp_size")
    local mem_total
    mem_total=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2 * 1024}' || echo 0)
    local recommended_bp=$(( mem_total * 70 / 100 ))
    if (( bp_size < recommended_bp && mem_total > 0 )); then
        local rec_h
        rec_h=$(bytes_to_human "$recommended_bp")
        printf "  ${C_YELLOW}[WARNING]${C_RESET} innodb_buffer_pool_size が小さい可能性があります\n"
        printf "    現在: %s  推奨: %s (空きメモリの70%%)\n" "$bp_size_h" "$rec_h"
        (( suggestions++ ))
    else
        printf "  ${C_GREEN}[OK]${C_RESET} innodb_buffer_pool_size: %s\n" "$bp_size_h"
    fi

    # クエリキャッシュ (MySQL 5.x)
    local qc_type
    qc_type=$(get_variable "query_cache_type" 2>/dev/null || echo "N/A")
    if [[ "$qc_type" == "ON" || "$qc_type" == "1" ]]; then
        printf "  ${C_YELLOW}[WARNING]${C_RESET} query_cache_type が有効です (MySQL 8.0では廃止)\n"
        (( suggestions++ ))
    fi

    # スロークエリログ
    local slow_log
    slow_log=$(get_variable "slow_query_log")
    if [[ "$slow_log" != "ON" && "$slow_log" != "1" ]]; then
        printf "  ${C_YELLOW}[WARNING]${C_RESET} slow_query_log が無効です\n"
        printf "    推奨: slow_query_log = ON, long_query_time = 1\n"
        (( suggestions++ ))
    else
        printf "  ${C_GREEN}[OK]${C_RESET} slow_query_log が有効です\n"
    fi

    # スレッドキャッシュ
    local thread_cache tc_hit_rate
    thread_cache=$(get_variable "thread_cache_size")
    local threads_created conns_total
    threads_created=$(get_status "Threads_created")
    conns_total=$(get_status "Connections")
    if (( conns_total > 0 )); then
        tc_hit_rate=$(echo "scale=1; (1 - $threads_created / $conns_total) * 100" | bc 2>/dev/null || echo '?')
        local tc_int="${tc_hit_rate%.*}"
        if (( ${tc_int:-100} < 90 )); then
            printf "  ${C_YELLOW}[WARNING]${C_RESET} スレッドキャッシュ効率が低い: %s%% (thread_cache_size=%s)\n" \
                "$tc_hit_rate" "$thread_cache"
            (( suggestions++ ))
        else
            printf "  ${C_GREEN}[OK]${C_RESET} スレッドキャッシュ効率: %s%%\n" "$tc_hit_rate"
        fi
    fi

    # テーブルオープンキャッシュ
    local open_tables_pct
    local opened_tables table_open_cache
    opened_tables=$(get_status "Opened_tables")
    table_open_cache=$(get_variable "table_open_cache")
    local uptime
    uptime=$(get_status "Uptime")
    if (( uptime > 0 )); then
        local open_rate=$(( opened_tables / uptime ))
        if (( open_rate > 10 )); then
            printf "  ${C_YELLOW}[WARNING]${C_RESET} テーブルオープン率が高い: %d/秒 (table_open_cache=%s)\n" \
                "$open_rate" "$table_open_cache"
            (( suggestions++ ))
        else
            printf "  ${C_GREEN}[OK]${C_RESET} テーブルオープン率: %d/秒\n" "$open_rate"
        fi
    fi

    # InnoDB ログファイルサイズ
    local log_size log_size_h
    log_size=$(get_variable "innodb_log_file_size")
    log_size_h=$(bytes_to_human "$log_size")
    if (( log_size < 134217728 )); then
        printf "  ${C_YELLOW}[WARNING]${C_RESET} innodb_log_file_size が小さい: %s (推奨: 128MB以上)\n" "$log_size_h"
        (( suggestions++ ))
    else
        printf "  ${C_GREEN}[OK]${C_RESET} innodb_log_file_size: %s\n" "$log_size_h"
    fi

    echo ""
    if (( suggestions == 0 )); then
        log_success "チューニング提案なし。設定は良好です。"
    else
        log_warning "改善提案: ${suggestions}件"
    fi
    echo ""
}

cmd_slow() {
    log_info "スロークエリ分析"
    echo ""

    local slow_log_file
    slow_log_file=$(get_variable "slow_query_log_file")
    local slow_enabled
    slow_enabled=$(get_variable "slow_query_log")
    local long_time
    long_time=$(get_variable "long_query_time")

    printf "  %-25s %s\n" "スロークエリログ:" "${slow_enabled}"
    printf "  %-25s %s 秒\n" "閾値(long_query_time):" "${long_time}"
    printf "  %-25s %s\n" "ログファイル:" "${slow_log_file:-N/A}"
    echo ""

    local slow_count
    slow_count=$(get_status "Slow_queries")
    local total_queries
    total_queries=$(get_status "Questions")
    printf "  %-25s %s\n" "スロークエリ累計:" "$slow_count"
    if (( total_queries > 0 )); then
        local pct
        pct=$(echo "scale=3; $slow_count * 100 / $total_queries" | bc 2>/dev/null || echo '?')
        printf "  %-25s %s%%\n" "スロークエリ率:" "$pct"
    fi

    echo ""
    if [[ -n "$slow_log_file" && -f "$slow_log_file" && -r "$slow_log_file" ]]; then
        printf "${C_BOLD}【スロークエリログ (最新10件)】${C_RESET}\n\n"
        grep "^# Query_time" "$slow_log_file" 2>/dev/null | \
            tail -10 | while IFS= read -r line; do
            printf "  ${C_YELLOW}%s${C_RESET}\n" "$line"
        done
    else
        log_warning "スロークエリログファイルが読めません: ${slow_log_file:-未設定}"
    fi
    echo ""
}

cmd_innodb() {
    log_info "InnoDBステータス分析"
    echo ""

    local bp_size bp_hit_rate
    bp_size=$(get_variable "innodb_buffer_pool_size")
    local bp_reads bp_read_requests
    bp_reads=$(get_status "Innodb_buffer_pool_reads")
    bp_read_requests=$(get_status "Innodb_buffer_pool_read_requests")
    if (( bp_read_requests > 0 )); then
        bp_hit_rate=$(echo "scale=2; (1 - $bp_reads / $bp_read_requests) * 100" | bc 2>/dev/null || echo '?')
    else
        bp_hit_rate="N/A"
    fi

    printf "${C_BOLD}【バッファプール】${C_RESET}\n\n"
    printf "  %-30s %s\n" "サイズ:" "$(bytes_to_human "$bp_size")"
    local hit_color="$C_GREEN"
    local hr="${bp_hit_rate%.*}"
    (( ${hr:-100} < 95 )) && hit_color="$C_YELLOW"
    (( ${hr:-100} < 90 )) && hit_color="$C_RED"
    printf "  %-30s ${hit_color}%s%%${C_RESET}\n" "ヒット率:" "$bp_hit_rate"

    echo ""
    printf "${C_BOLD}【I/O統計】${C_RESET}\n\n"
    local pages_read pages_written
    pages_read=$(get_status "Innodb_pages_read")
    pages_written=$(get_status "Innodb_pages_written")
    printf "  %-30s %s ページ\n" "累計読み込みページ数:" "$pages_read"
    printf "  %-30s %s ページ\n" "累計書き込みページ数:" "$pages_written"

    echo ""
    printf "${C_BOLD}【トランザクション】${C_RESET}\n\n"
    local trx_count
    trx_count=$(mysql_query "SELECT COUNT(*) FROM information_schema.INNODB_TRX;" 2>/dev/null || echo "N/A")
    printf "  %-30s %s\n" "アクティブトランザクション:" "$trx_count"
    echo ""
}

cmd_indexes() {
    log_info "未使用インデックス検出"
    echo ""

    log_warning "注意: この情報はperformance_schemaのデータに基づきます"
    echo ""

    local ps_enabled
    ps_enabled=$(get_variable "performance_schema")
    if [[ "$ps_enabled" != "ON" && "$ps_enabled" != "1" ]]; then
        log_warning "performance_schemaが無効です。有効にしてください"
        return
    fi

    printf "${C_BOLD}【未使用インデックス候補】${C_RESET}\n\n"
    mysql_query "
        SELECT
            t.TABLE_SCHEMA,
            t.TABLE_NAME,
            s.INDEX_NAME,
            s.COLUMN_NAME
        FROM information_schema.TABLES t
        JOIN information_schema.STATISTICS s
            ON t.TABLE_SCHEMA = s.TABLE_SCHEMA
            AND t.TABLE_NAME = s.TABLE_NAME
        WHERE t.TABLE_SCHEMA NOT IN ('mysql','information_schema','performance_schema','sys')
            AND s.INDEX_NAME != 'PRIMARY'
        ORDER BY t.TABLE_SCHEMA, t.TABLE_NAME, s.INDEX_NAME
        LIMIT 30;
    " 2>/dev/null | while IFS=$'\t' read -r schema table idx col; do
        printf "  ${C_YELLOW}%s.%s${C_RESET}  インデックス: ${C_CYAN}%s${C_RESET}  カラム: %s\n" \
            "$schema" "$table" "$idx" "$col"
    done || log_warning "インデックス情報を取得できませんでした"
    echo ""
}

parse_arguments() {
    [[ $# -eq 0 ]] && return 0
    case "$1" in
        analyze|status|slow|innodb|indexes)
            command_name="$1"; shift ;;
    esac

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -H|--host)    [[ $# -lt 2 ]] && error_exit "--host には値が必要です"; mysql_host="$2"; shift 2 ;;
            -P|--port)    [[ $# -lt 2 ]] && error_exit "--port には値が必要です"; mysql_port="$2"; shift 2 ;;
            -u|--user)    [[ $# -lt 2 ]] && error_exit "--user には値が必要です"; mysql_user="$2"; shift 2 ;;
            -p|--pass)    [[ $# -lt 2 ]] && error_exit "--pass には値が必要です"; mysql_pass="$2"; shift 2 ;;
            -S|--socket)  [[ $# -lt 2 ]] && error_exit "--socket には値が必要です"; mysql_socket="$2"; shift 2 ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  shift ;;
        esac
    done
}

main() {
    parse_arguments "$@"

    if ! command -v mysql &>/dev/null; then
        error_exit "mysql クライアントが見つかりません"
    fi

    check_connection

    case "$command_name" in
        analyze)  cmd_analyze ;;
        status)   cmd_status ;;
        slow)     cmd_slow ;;
        innodb)   cmd_innodb ;;
        indexes)  cmd_indexes ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
