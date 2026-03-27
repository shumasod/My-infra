#!/bin/bash
set -euo pipefail

#
# DBパラメータ適正値調査スクリプト
# 作成日: 2026-03-27
# バージョン: 1.0
#
# MySQL / PostgreSQL のパラメータ現在値を取得し、
# システムリソースに基づいた推奨値と比較して評価します。
#

# 共通ライブラリの読み込み
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

# ===== 設定（定数） =====
readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

# ステータス表示用
readonly STATUS_OK="OK"
readonly STATUS_WARN="WARN"
readonly STATUS_CRIT="CRIT"
readonly STATUS_INFO="INFO"

# ===== グローバル変数 =====
declare db_type="mysql"
declare db_host="localhost"
declare db_port=""
declare db_user="root"
declare db_pass=""
declare db_name=""
declare output_format="table"   # table / csv / json
declare report_file=""
declare verbose=0

# システムリソース（後で取得）
declare -i total_ram_mb=0
declare -i cpu_cores=0

# ===== ヘルパー関数 =====

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション]

MySQL / PostgreSQL のパラメータ現在値を取得し、推奨値と比較評価します。

オプション:
  -h, --help                このヘルプを表示
  -v, --version             バージョン情報を表示
  -t, --type <db>           DB種別: mysql (デフォルト) または postgresql
  -H, --host <ホスト>       接続ホスト (デフォルト: localhost)
  -P, --port <ポート>       接続ポート (MySQL:3306 / PostgreSQL:5432)
  -u, --user <ユーザー>     DBユーザー (デフォルト: root / postgres)
  -p, --pass <パスワード>   DBパスワード
  -d, --database <DB名>     接続DB名 (PostgreSQL用)
  -f, --format <形式>       出力形式: table (デフォルト) / csv / json
  -o, --output <ファイル>   結果をファイルに保存
      --verbose             詳細モード

例:
  $PROG_NAME -t mysql -u root -p secret
  $PROG_NAME -t postgresql -H db.example.com -u postgres -p secret -d mydb
  $PROG_NAME -t mysql -u root -p secret -f csv -o report.csv
EOF
}

show_version() {
    echo "$PROG_NAME version $VERSION"
}

# システムリソースの取得
get_system_resources() {
    total_ram_mb=$(free -m 2>/dev/null | awk 'NR==2{print $2}' || echo 4096)
    cpu_cores=$(nproc 2>/dev/null || echo 4)
    log_info "システムリソース: RAM ${total_ram_mb}MB, CPU ${cpu_cores}コア"
}

# ステータスの色付き表示
format_status() {
    local status="$1"
    case "$status" in
        "$STATUS_OK")   echo -e "${C_GREEN}[ OK ]${C_RESET}" ;;
        "$STATUS_WARN") echo -e "${C_YELLOW}[WARN]${C_RESET}" ;;
        "$STATUS_CRIT") echo -e "${C_RED}[CRIT]${C_RESET}" ;;
        "$STATUS_INFO") echo -e "${C_CYAN}[INFO]${C_RESET}" ;;
        *)              echo "[ -- ]" ;;
    esac
}

# バイト単位の値を人間が読みやすい形式に変換
human_readable() {
    local value="$1"
    if [[ "$value" =~ ^[0-9]+$ ]]; then
        if   (( value >= 1073741824 )); then printf "%.1fGB" "$(echo "scale=1; $value/1073741824" | bc)"
        elif (( value >= 1048576   )); then printf "%.1fMB" "$(echo "scale=1; $value/1048576"   | bc)"
        elif (( value >= 1024      )); then printf "%.1fKB" "$(echo "scale=1; $value/1024"      | bc)"
        else printf "%dB" "$value"
        fi
    else
        echo "$value"
    fi
}

# MB値をバイトに変換
mb_to_bytes() {
    echo $(( $1 * 1048576 ))
}

# ===== 結果出力バッファ =====
declare -a result_rows=()

# 評価行を追加
add_result() {
    local param="$1"
    local current="$2"
    local recommended="$3"
    local status="$4"
    local comment="$5"
    result_rows+=("${param}||${current}||${recommended}||${status}||${comment}")
}

# ===== MySQL 接続・パラメータ取得 =====

# MySQL に接続してパラメータ値を取得
mysql_get_var() {
    local var_name="$1"
    local port_opt=""
    [[ -n "$db_port" ]] && port_opt="--port=${db_port}"

    mysql \
        --host="${db_host}" \
        ${port_opt} \
        --user="${db_user}" \
        --password="${db_pass}" \
        --batch --skip-column-names \
        --execute="SHOW GLOBAL VARIABLES LIKE '${var_name}';" \
        2>/dev/null | awk '{print $2}'
}

# MySQLステータス値の取得
mysql_get_status() {
    local var_name="$1"
    local port_opt=""
    [[ -n "$db_port" ]] && port_opt="--port=${db_port}"

    mysql \
        --host="${db_host}" \
        ${port_opt} \
        --user="${db_user}" \
        --password="${db_pass}" \
        --batch --skip-column-names \
        --execute="SHOW GLOBAL STATUS LIKE '${var_name}';" \
        2>/dev/null | awk '{print $2}'
}

# MySQL接続確認
mysql_check_connection() {
    local port_opt=""
    [[ -n "$db_port" ]] && port_opt="--port=${db_port}"

    mysql \
        --host="${db_host}" \
        ${port_opt} \
        --user="${db_user}" \
        --password="${db_pass}" \
        --batch --skip-column-names \
        --execute="SELECT VERSION();" \
        2>/dev/null | head -1
}

# ===== MySQL パラメータ評価 =====

analyze_mysql() {
    log_info "MySQL パラメータを取得・評価中..."

    local version
    version=$(mysql_check_connection) || {
        log_error "MySQL に接続できませんでした"
        return 1
    }
    log_success "接続成功: MySQL $version"
    echo ""

    local rec_bytes current_val current_int rec_int status comment

    # ---- innodb_buffer_pool_size ----
    # 推奨: 総RAM の 50〜80%（専用DBサーバーなら 75%）
    rec_int=$(( total_ram_mb * 75 / 100 ))
    rec_bytes=$(mb_to_bytes "$rec_int")
    current_val=$(mysql_get_var "innodb_buffer_pool_size")
    current_int="${current_val:-0}"
    if   (( current_int >= rec_bytes * 50 / 100 && current_int <= rec_bytes * 160 / 100 )); then
        status="$STATUS_OK"; comment="RAM の$(( current_int * 100 / (total_ram_mb * 1048576) ))% (推奨 50〜80%)"
    elif (( current_int < rec_bytes * 50 / 100 )); then
        status="$STATUS_WARN"; comment="小さすぎます。RAM の 50〜75% を推奨"
    else
        status="$STATUS_WARN"; comment="大きすぎる可能性。RAM の 75% 以下を推奨"
    fi
    add_result "innodb_buffer_pool_size" "$(human_readable "$current_int")" "$(human_readable "$rec_bytes") (RAM×75%)" "$status" "$comment"

    # ---- max_connections ----
    # 推奨: CPUコア数 × 50〜150（過大はメモリ圧迫）
    local rec_max_conn=$(( cpu_cores * 100 ))
    current_val=$(mysql_get_var "max_connections")
    current_int="${current_val:-0}"
    if   (( current_int >= cpu_cores * 50 && current_int <= cpu_cores * 200 )); then
        status="$STATUS_OK"; comment="CPUコア数に対して適切な範囲"
    elif (( current_int < cpu_cores * 50 )); then
        status="$STATUS_WARN"; comment="少ない可能性。推奨: ${rec_max_conn}"
    else
        status="$STATUS_WARN"; comment="多すぎる可能性。メモリ不足に注意"
    fi
    add_result "max_connections" "$current_int" "$rec_max_conn (CPU×100)" "$status" "$comment"

    # ---- innodb_log_file_size ----
    # 推奨: buffer_pool_size の 25% 程度（最低 128MB）
    local buf_pool
    buf_pool=$(mysql_get_var "innodb_buffer_pool_size")
    local rec_log=$(( ${buf_pool:-268435456} / 4 ))
    (( rec_log < 134217728 )) && rec_log=134217728
    current_val=$(mysql_get_var "innodb_log_file_size")
    current_int="${current_val:-0}"
    if   (( current_int >= rec_log * 75 / 100 && current_int <= rec_log * 200 / 100 )); then
        status="$STATUS_OK"; comment="buffer_pool_size に対して適切"
    else
        status="$STATUS_WARN"; comment="buffer_pool_size の 25% 程度を推奨"
    fi
    add_result "innodb_log_file_size" "$(human_readable "$current_int")" "$(human_readable "$rec_log") (BP÷4)" "$status" "$comment"

    # ---- innodb_flush_log_at_trx_commit ----
    # 1=完全ACID(推奨), 2=クラッシュ時1秒分消失, 0=最速だが危険
    current_val=$(mysql_get_var "innodb_flush_log_at_trx_commit")
    case "${current_val:-0}" in
        1) status="$STATUS_OK";   comment="完全ACID準拠（推奨）" ;;
        2) status="$STATUS_WARN"; comment="クラッシュ時に最大1秒のデータ消失リスク" ;;
        0) status="$STATUS_CRIT"; comment="クラッシュ時データ消失リスクが高い" ;;
        *) status="$STATUS_INFO"; comment="不明な値" ;;
    esac
    add_result "innodb_flush_log_at_trx_commit" "${current_val:--}" "1 (ACID準拠)" "$status" "$comment"

    # ---- slow_query_log ----
    current_val=$(mysql_get_var "slow_query_log")
    if [[ "${current_val,,}" == "on" || "$current_val" == "1" ]]; then
        status="$STATUS_OK"; comment="スロークエリログが有効"
    else
        status="$STATUS_WARN"; comment="有効化を推奨（パフォーマンス分析に必要）"
    fi
    add_result "slow_query_log" "${current_val:--}" "ON" "$status" "$comment"

    # ---- long_query_time ----
    current_val=$(mysql_get_var "long_query_time")
    local lqt_float="${current_val:-10}"
    if   (( $(echo "$lqt_float <= 2" | bc -l) )); then
        status="$STATUS_OK"; comment="適切なスロークエリしきい値"
    elif (( $(echo "$lqt_float <= 5" | bc -l) )); then
        status="$STATUS_WARN"; comment="1〜2秒に設定を推奨"
    else
        status="$STATUS_CRIT"; comment="値が大きすぎます。1秒以下を推奨"
    fi
    add_result "long_query_time" "${current_val:--}秒" "1秒以下" "$status" "$comment"

    # ---- tmp_table_size / max_heap_table_size ----
    current_val=$(mysql_get_var "tmp_table_size")
    current_int="${current_val:-0}"
    local rec_tmp=$(mb_to_bytes 64)
    if   (( current_int >= mb_to_bytes 16 && current_int <= mb_to_bytes 256 )); then
        status="$STATUS_OK"; comment="適切な範囲 (16MB〜256MB)"
    else
        status="$STATUS_WARN"; comment="16MB〜64MB を推奨"
    fi
    add_result "tmp_table_size" "$(human_readable "$current_int")" "64MB" "$status" "$comment"

    # ---- thread_cache_size ----
    current_val=$(mysql_get_var "thread_cache_size")
    current_int="${current_val:-0}"
    local rec_thread=$(( cpu_cores * 4 ))
    (( rec_thread < 8  )) && rec_thread=8
    (( rec_thread > 64 )) && rec_thread=64
    if   (( current_int >= 8 && current_int <= 64 )); then
        status="$STATUS_OK"; comment="適切な範囲"
    else
        status="$STATUS_WARN"; comment="推奨値: ${rec_thread}"
    fi
    add_result "thread_cache_size" "$current_int" "$rec_thread (CPU×4)" "$status" "$comment"

    # ---- table_open_cache ----
    current_val=$(mysql_get_var "table_open_cache")
    current_int="${current_val:-0}"
    if   (( current_int >= 2000 )); then
        status="$STATUS_OK"; comment="十分なキャッシュサイズ"
    else
        status="$STATUS_WARN"; comment="2000以上を推奨（テーブル数が多い場合はさらに増加）"
    fi
    add_result "table_open_cache" "$current_int" "2000以上" "$status" "$comment"

    # ---- innodb_io_capacity ----
    current_val=$(mysql_get_var "innodb_io_capacity")
    current_int="${current_val:-0}"
    comment="SSD: 2000〜10000, HDD: 200〜400"
    if   (( current_int >= 200 )); then
        status="$STATUS_INFO"
    else
        status="$STATUS_WARN"; comment="デフォルト200 (SSDなら2000以上を推奨)"
    fi
    add_result "innodb_io_capacity" "$current_int" "SSD:2000 / HDD:200" "$status" "$comment"

    # ---- sync_binlog ----
    current_val=$(mysql_get_var "sync_binlog")
    current_int="${current_val:-0}"
    case "$current_int" in
        1) status="$STATUS_OK";   comment="最も安全（推奨）" ;;
        0) status="$STATUS_WARN"; comment="クラッシュ時のバイナリログ損失リスクあり" ;;
        *) status="$STATUS_INFO"; comment="N件毎の同期 (N=${current_int})" ;;
    esac
    add_result "sync_binlog" "$current_int" "1 (最安全)" "$status" "$comment"

    # ---- Connections 使用率（ステータス） ----
    local max_used
    max_used=$(mysql_get_status "Max_used_connections")
    local max_conn
    max_conn=$(mysql_get_var "max_connections")
    if [[ -n "$max_used" && -n "$max_conn" && "$max_conn" -gt 0 ]]; then
        local usage_pct=$(( max_used * 100 / max_conn ))
        if   (( usage_pct <= 70 )); then
            status="$STATUS_OK"
        elif (( usage_pct <= 90 )); then
            status="$STATUS_WARN"
        else
            status="$STATUS_CRIT"
        fi
        comment="ピーク時使用率 ${usage_pct}% (${max_used}/${max_conn})"
        add_result "Max_used_connections (実績)" "$max_used" "max_connections の 80% 以下" "$status" "$comment"
    fi
}
