#!/bin/bash
set -euo pipefail

#
# Redisヘルパーツール
# バージョン: 1.0
#
# Redisの状態確認・データ操作・メモリ分析を行うツール
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare action=""
declare host="127.0.0.1"
declare port=6379
declare db=0
declare auth=""
declare pattern="*"
declare -i key_limit=100

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME <アクション> [オプション]

Redisヘルパーツール

アクション:
  info      サーバー情報を表示
  stats     統計情報 (メモリ・接続・コマンド)
  keys      キー一覧
  memory    メモリ使用量分析
  slow      スロークエリログ表示
  monitor   リアルタイムコマンド監視
  flush     データ削除 (要確認)
  ping      接続確認

オプション:
  -h, --help            このヘルプを表示
  -v, --version         バージョン情報を表示
  -H, --host HOST       ホスト [デフォルト: 127.0.0.1]
  -p, --port PORT       ポート [デフォルト: 6379]
  -d, --db NUM          データベース番号 [デフォルト: 0]
  -a, --auth PASS       認証パスワード
  -P, --pattern PAT     キーパターン [デフォルト: *]
  -n, --limit NUM       キー表示上限 [デフォルト: 100]

例:
  $PROG_NAME info
  $PROG_NAME stats
  $PROG_NAME keys -P "user:*"
  $PROG_NAME memory
  $PROG_NAME slow
  $PROG_NAME ping

EOF
}

redis_cmd() {
    local -a args=()
    args+=(-h "$host" -p "$port" -n "$db")
    [[ -n "$auth" ]] && args+=(-a "$auth")
    redis-cli "${args[@]}" "$@"
}

check_redis() {
    if ! command -v redis-cli &>/dev/null; then
        error_exit "redis-cli が見つかりません。インストールしてください"
    fi
    if ! redis_cmd PING &>/dev/null; then
        error_exit "Redisに接続できません: ${host}:${port}"
    fi
}

do_ping() {
    if redis_cmd PING | grep -q "PONG"; then
        log_success "接続OK: ${host}:${port} (DB: $db)"
    else
        log_error "接続失敗: ${host}:${port}"
        exit 1
    fi
}

do_info() {
    log_info "Redis サーバー情報: ${host}:${port}"
    echo ""
    redis_cmd INFO server | grep -E "^(redis_version|tcp_port|uptime|config_file|executable)" | \
    while IFS=: read -r key val; do
        printf "  %-25s %s\n" "$key" "${val%$'\r'}"
    done
    echo ""
    redis_cmd INFO replication | grep -E "^(role|connected_slaves|master_host)" | \
    while IFS=: read -r key val; do
        printf "  %-25s %s\n" "$key" "${val%$'\r'}"
    done
}

do_stats() {
    log_info "Redis 統計情報: ${host}:${port}"
    echo ""

    echo -e "  ${C_CYAN}【メモリ】${C_RESET}"
    redis_cmd INFO memory | grep -E "^(used_memory_human|used_memory_peak_human|mem_fragmentation_ratio|maxmemory_human)" | \
    while IFS=: read -r key val; do
        printf "    %-35s %s\n" "$key" "${val%$'\r'}"
    done

    echo ""
    echo -e "  ${C_CYAN}【接続】${C_RESET}"
    redis_cmd INFO clients | grep -E "^(connected_clients|blocked_clients)" | \
    while IFS=: read -r key val; do
        printf "    %-35s %s\n" "$key" "${val%$'\r'}"
    done

    echo ""
    echo -e "  ${C_CYAN}【キー空間】${C_RESET}"
    redis_cmd INFO keyspace | grep -v "^#" | grep -v "^$" | \
    while IFS=: read -r key val; do
        printf "    %-35s %s\n" "$key" "${val%$'\r'}"
    done

    echo ""
    echo -e "  ${C_CYAN}【コマンド統計】${C_RESET}"
    redis_cmd INFO stats | grep -E "^(total_commands_processed|instantaneous_ops_per_sec|total_net_input_bytes|total_net_output_bytes|keyspace_hits|keyspace_misses)" | \
    while IFS=: read -r key val; do
        printf "    %-35s %s\n" "$key" "${val%$'\r'}"
    done
    echo ""
}

do_keys() {
    log_info "キー一覧 (パターン: $pattern, 上限: $key_limit)"
    echo ""

    local count=0
    redis_cmd --scan --pattern "$pattern" --count 100 | head -"$key_limit" | \
    while read -r key; do
        local type ttl
        type=$(redis_cmd TYPE "$key" 2>/dev/null || echo "unknown")
        ttl=$(redis_cmd TTL "$key" 2>/dev/null || echo "-1")

        local ttl_str="永続"
        (( ttl >= 0 )) && ttl_str="${ttl}秒"

        local type_color
        case "$type" in
            string) type_color="$C_GREEN" ;;
            hash)   type_color="$C_YELLOW" ;;
            list)   type_color="$C_BLUE" ;;
            set)    type_color="$C_CYAN" ;;
            zset)   type_color="$C_MAGENTA" ;;
            *)      type_color="$C_DIM" ;;
        esac

        printf "  %b%-10s%b %-15s %s\n" "$type_color" "$type" "$C_RESET" "[$ttl_str]" "$key"
        (( count++ )) || true
    done

    echo ""
}

do_memory() {
    log_info "メモリ使用量分析: ${host}:${port}"
    echo ""

    local used peak frag
    used=$(redis_cmd INFO memory | grep "^used_memory_human" | cut -d: -f2 | tr -d $'\r ')
    peak=$(redis_cmd INFO memory | grep "^used_memory_peak_human" | cut -d: -f2 | tr -d $'\r ')
    frag=$(redis_cmd INFO memory | grep "^mem_fragmentation_ratio" | cut -d: -f2 | tr -d $'\r ')

    printf "  現在の使用量:   %s\n" "$used"
    printf "  ピーク使用量:   %s\n" "$peak"
    printf "  断片化率:       %s\n" "$frag"

    local frag_int
    frag_int=$(echo "$frag" | cut -d. -f1)
    if (( frag_int >= 2 )); then
        log_warning "断片化率が高い ($frag) - MEMORY PURGE を検討してください"
    fi

    echo ""
    log_info "大きいキー Top10:"
    redis_cmd --bigkeys 2>/dev/null | grep -E "^\-\-\- (Biggest|Largest)" | head -10 || \
        log_info "  データなし"
    echo ""
}

do_slow() {
    log_info "スロークエリログ: ${host}:${port}"
    echo ""

    local threshold
    threshold=$(redis_cmd CONFIG GET slowlog-log-slower-than | tail -1 | tr -d $'\r ')
    printf "  記録閾値: %sマイクロ秒\n\n" "$threshold"

    redis_cmd SLOWLOG GET 10 | paste - - - - - - | \
    while IFS=$'\t' read -r id ts duration cmd rest; do
        printf "  ID: %-6s 時間: %-12s 実行時間: %sμs\n" \
            "${id#\*}" "${ts#\*}" "${duration#\*}"
        printf "  コマンド: %s\n\n" "${cmd#\*}"
    done || log_info "  スロークエリなし"
}

do_monitor() {
    log_info "リアルタイム監視 (Ctrl+C で終了)"
    redis_cmd MONITOR
}

do_flush() {
    log_warning "DB $db の全データを削除します"
    printf "本当に削除しますか? [yes/NO]: "
    local ans; read -r ans
    [[ "$ans" != "yes" ]] && { log_info "キャンセルしました"; return; }
    redis_cmd FLUSHDB
    log_success "DB $db をフラッシュしました"
}

parse_arguments() {
    [[ $# -eq 0 ]] && { show_usage; exit 0; }
    action="$1"; shift

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -H|--host)    [[ $# -lt 2 ]] && error_exit "--host には値が必要です"; host="$2"; shift 2 ;;
            -p|--port)    [[ $# -lt 2 ]] && error_exit "--port には値が必要です"; port="$2"; shift 2 ;;
            -d|--db)      [[ $# -lt 2 ]] && error_exit "--db には数値が必要です"; db="$2"; shift 2 ;;
            -a|--auth)    [[ $# -lt 2 ]] && error_exit "--auth には値が必要です"; auth="$2"; shift 2 ;;
            -P|--pattern) [[ $# -lt 2 ]] && error_exit "--pattern には値が必要です"; pattern="$2"; shift 2 ;;
            -n|--limit)   [[ $# -lt 2 ]] && error_exit "--limit には数値が必要です"; key_limit="$2"; shift 2 ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  error_exit "不明な引数: $1" ;;
        esac
    done
}

main() {
    parse_arguments "$@"

    [[ "$action" != "ping" ]] && check_redis

    case "$action" in
        ping)    do_ping ;;
        info)    do_info ;;
        stats)   do_stats ;;
        keys)    do_keys ;;
        memory)  do_memory ;;
        slow)    do_slow ;;
        monitor) do_monitor ;;
        flush)   do_flush ;;
        *)       error_exit "不明なアクション: $action。--help を参照してください" ;;
    esac
}

main "$@"
