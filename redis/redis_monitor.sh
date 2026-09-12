#!/bin/bash
set -euo pipefail

#
# Redisモニタリングツール
# 作成日: 2026-07-31
# バージョン: 1.0
#
# Redisサーバーのリアルタイム監視・管理を行います
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare command_name="info"
declare REDIS_HOST="${REDIS_HOST:-localhost}"
declare REDIS_PORT="${REDIS_PORT:-6379}"
declare REDIS_PASS="${REDIS_PASS:-}"
declare watch_interval=3
declare top_n=20

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション]

Redisサーバーの監視・管理ツールです。

コマンド:
  info                   サーバー情報サマリー
  stats                  統計情報
  memory                 メモリ使用状況
  clients                接続クライアント情報
  keys [パターン]        キー検索・統計
  slow                   スローログ表示
  watch                  リアルタイムダッシュボード
  flush [db]             データベースのフラッシュ (要確認)

オプション:
  -h, --help             このヘルプを表示
  -v, --version          バージョン情報を表示
  -H, --host <ホスト>    Redisホスト [デフォルト: localhost]
  -p, --port <ポート>    Redisポート [デフォルト: 6379]
  -a, --auth <パスワード> 認証パスワード
  -i, --interval <秒>    監視間隔 [デフォルト: 3]
  -n, --top <数>         表示件数 [デフォルト: 20]

環境変数:
  REDIS_HOST / REDIS_PORT / REDIS_PASS

例:
  $PROG_NAME info
  $PROG_NAME memory
  $PROG_NAME watch -i 2
  $PROG_NAME keys "user:*"
  $PROG_NAME slow
EOF
}

redis_cmd() {
    local args=(-h "$REDIS_HOST" -p "$REDIS_PORT")
    [[ -n "$REDIS_PASS" ]] && args+=(-a "$REDIS_PASS" --no-auth-warning)
    redis-cli "${args[@]}" "$@" 2>/dev/null
}

check_redis() {
    command -v redis-cli &>/dev/null || error_exit "redis-cli がインストールされていません"
    redis_cmd PING | grep -q "PONG" || error_exit "Redisサーバーに接続できません ($REDIS_HOST:$REDIS_PORT)"
}

get_info() {
    local section="${1:-all}"
    redis_cmd INFO "$section"
}

parse_info() {
    local key="$1"
    get_info | grep "^${key}:" | cut -d: -f2 | tr -d '\r'
}

format_bytes() {
    local bytes=$1
    if (( bytes >= 1073741824 )); then
        printf "%.2f GB" "$(echo "scale=2; $bytes/1073741824" | bc 2>/dev/null || echo '?')"
    elif (( bytes >= 1048576 )); then
        printf "%.2f MB" "$(echo "scale=2; $bytes/1048576" | bc 2>/dev/null || echo '?')"
    elif (( bytes >= 1024 )); then
        printf "%.2f KB" "$(echo "scale=2; $bytes/1024" | bc 2>/dev/null || echo '?')"
    else
        printf "%d B" "$bytes"
    fi
}

cmd_info() {
    log_info "Redis サーバー情報 ($REDIS_HOST:$REDIS_PORT)"
    echo ""

    local version role uptime_sec connected_clients used_memory total_cmds_processed
    version=$(parse_info "redis_version")
    role=$(parse_info "role")
    uptime_sec=$(parse_info "uptime_in_seconds")
    connected_clients=$(parse_info "connected_clients")
    used_memory=$(parse_info "used_memory")
    total_cmds_processed=$(parse_info "total_commands_processed")

    local uptime_h=$(( ${uptime_sec:-0} / 3600 ))
    local uptime_m=$(( (${uptime_sec:-0} % 3600) / 60 ))

    printf "  ${C_BOLD}バージョン${C_RESET}     : ${C_GREEN}%s${C_RESET}\n" "${version:-N/A}"
    printf "  ${C_BOLD}ロール${C_RESET}         : ${C_CYAN}%s${C_RESET}\n" "${role:-N/A}"
    printf "  ${C_BOLD}稼働時間${C_RESET}       : %dh %dm\n" "$uptime_h" "$uptime_m"
    printf "  ${C_BOLD}接続クライアント${C_RESET}: ${C_YELLOW}%s${C_RESET}\n" "${connected_clients:-0}"
    printf "  ${C_BOLD}メモリ使用量${C_RESET}   : %s\n" "$(format_bytes "${used_memory:-0}")"
    printf "  ${C_BOLD}総コマンド数${C_RESET}   : %s\n" "${total_cmds_processed:-0}"

    echo ""
    # データベース情報
    printf "${C_BOLD}【データベース】${C_RESET}\n"
    get_info keyspace | grep "^db" | while IFS= read -r line; do
        local db keys expires
        db=$(echo "$line" | cut -d: -f1)
        keys=$(echo "$line" | grep -oP 'keys=\K[0-9]+')
        expires=$(echo "$line" | grep -oP 'expires=\K[0-9]+')
        printf "  ${C_CYAN}%s${C_RESET}: %s件 (期限付き: %s)\n" "$db" "${keys:-0}" "${expires:-0}"
    done
    echo ""
}

cmd_memory() {
    log_info "Redisメモリ使用状況"
    echo ""

    local info
    info=$(get_info memory)

    echo "$info" | awk -F: '
        /used_memory:/ { printf "  使用量        : %s\n", $2+0 }
        /used_memory_human/ { printf "  使用量(人向け): %s\n", $2 }
        /used_memory_peak_human/ { printf "  ピーク使用量  : %s\n", $2 }
        /maxmemory_human/ { printf "  最大メモリ    : %s\n", ($2 == "0B" ? "無制限" : $2) }
        /mem_fragmentation_ratio/ { printf "  断片化率      : %s\n", $2 }
        /maxmemory_policy/ { printf "  エビクションポリシー: %s\n", $2 }
    ' | tr -d '\r'

    echo ""
    local policy
    policy=$(parse_info "maxmemory_policy" | tr -d '\r')
    local frag
    frag=$(parse_info "mem_fragmentation_ratio" | tr -d '\r')
    local frag_int=${frag%.*}

    printf "${C_BOLD}【診断】${C_RESET}\n"
    if [[ "${policy:-noeviction}" == "noeviction" ]]; then
        log_warning "エビクションポリシーが noeviction です (OOM の可能性あり)"
        printf "  推奨: allkeys-lru または volatile-lru を設定\n"
    else
        log_success "エビクションポリシー: $policy"
    fi

    if [[ -n "${frag_int:-}" ]] && (( frag_int >= 2 )); then
        log_warning "メモリ断片化率が高いです: ${frag}"
        printf "  推奨: redis-cli MEMORY PURGE を実行\n"
    fi
    echo ""
}

cmd_clients() {
    log_info "接続クライアント情報"
    echo ""

    local clients_output
    clients_output=$(redis_cmd CLIENT LIST 2>/dev/null)

    local total
    total=$(echo "$clients_output" | wc -l)

    printf "  接続クライアント数: ${C_GREEN}%d${C_RESET}\n\n" "$total"
    printf "${C_BOLD}%-15s %8s %8s %10s %s${C_RESET}\n" "アドレス" "fd" "cmd" "age(s)" "flags"
    printf "%s\n" "$(printf '%.0s─' {1..55})"

    echo "$clients_output" | head -"$top_n" | while IFS= read -r line; do
        local addr fd cmd age flags
        addr=$(echo "$line" | grep -oP 'addr=\K[^ ]+')
        fd=$(echo "$line" | grep -oP 'fd=\K[0-9]+')
        cmd=$(echo "$line" | grep -oP 'cmd=\K[^ ]+')
        age=$(echo "$line" | grep -oP 'age=\K[0-9]+')
        flags=$(echo "$line" | grep -oP 'flags=\K[^ ]+')
        printf "  %-15s %8s %8s %10s %s\n" \
            "${addr:-?}" "${fd:-?}" "${cmd:-?}" "${age:-?}" "${flags:-?}"
    done
    echo ""
}

cmd_keys() {
    local pattern="${ARGS[0]:-*}"
    log_info "キー検索: $pattern"
    echo ""

    local count
    count=$(redis_cmd DBSIZE)
    printf "  総キー数: ${C_GREEN}%s${C_RESET}\n\n" "$count"

    if [[ "$pattern" != "*" || ${count:-0} -le 100 ]]; then
        printf "${C_BOLD}%-40s %-10s %s${C_RESET}\n" "キー名" "型" "TTL(秒)"
        printf "%s\n" "$(printf '%.0s─' {1..60})"

        redis_cmd SCAN 0 MATCH "$pattern" COUNT "$top_n" 2>/dev/null | tail -n +2 | \
        while IFS= read -r key; do
            [[ -z "$key" ]] && continue
            local type ttl
            type=$(redis_cmd TYPE "$key" 2>/dev/null || echo "?")
            ttl=$(redis_cmd TTL "$key" 2>/dev/null || echo "?")
            local ttl_display
            [[ "$ttl" == "-1" ]] && ttl_display="${C_DIM}永続${C_RESET}" || \
            [[ "$ttl" == "-2" ]] && ttl_display="${C_RED}期限切れ${C_RESET}" || \
            ttl_display="$ttl"

            local type_color="$C_RESET"
            case "$type" in
                string) type_color="$C_GREEN" ;;
                hash)   type_color="$C_YELLOW" ;;
                list)   type_color="$C_CYAN" ;;
                set)    type_color="$C_MAGENTA" ;;
                zset)   type_color="$C_BLUE" ;;
            esac
            printf "  %-38s ${type_color}%-10s${C_RESET} %b\n" \
                "${key:0:38}" "$type" "$ttl_display"
        done
    else
        log_warning "キーが多すぎます。パターンを指定してください (例: 'user:*')"
    fi
    echo ""
}

cmd_slow() {
    log_info "Redisスローログ"
    echo ""

    local slow_len
    slow_len=$(redis_cmd SLOWLOG LEN 2>/dev/null)
    printf "  スローログ件数: ${C_YELLOW}%s${C_RESET}\n\n" "$slow_len"

    if [[ "${slow_len:-0}" -eq 0 ]]; then
        log_success "スローログはありません"
        return
    fi

    printf "${C_BOLD}%-12s %-15s %s${C_RESET}\n" "実行時間(μs)" "時刻" "コマンド"
    printf "%s\n" "$(printf '%.0s─' {1..60})"

    redis_cmd SLOWLOG GET "$top_n" 2>/dev/null | python3 -c "
import sys
lines = [l.strip() for l in sys.stdin]
i = 0
entries = []
while i < len(lines):
    if lines[i].isdigit() and i+3 < len(lines):
        entry_id = lines[i]
        i += 1
        timestamp = lines[i]; i += 1
        duration = lines[i]; i += 1
        cmd_parts = []
        i += 1  # skip count
        while i < len(lines) and not lines[i].isdigit():
            cmd_parts.append(lines[i]); i += 1
        from datetime import datetime
        try:
            ts = datetime.fromtimestamp(int(timestamp)).strftime('%Y-%m-%d %H:%M')
        except:
            ts = timestamp
        cmd = ' '.join(cmd_parts[:4])
        color = '\033[1;31m' if int(duration) > 100000 else '\033[1;33m' if int(duration) > 10000 else ''
        print(f'  {color}{int(duration):>12,}\033[0m  {ts:<15} {cmd[:40]}')
    else:
        i += 1
" 2>/dev/null || redis_cmd SLOWLOG GET "$top_n"
    echo ""
}

cmd_watch() {
    local cleanup_done=false
    cleanup_watch() {
        $cleanup_done && return
        cleanup_done=true
        show_cursor
        printf '\033[?1049l'
    }
    trap cleanup_watch EXIT INT TERM
    printf '\033[?1049h'
    hide_cursor

    while true; do
        clear_screen
        update_terminal_size
        print_center "Redis モニタリングダッシュボード" 1 "$C_RED"
        draw_separator 2
        move_cursor 3 2
        printf "${C_DIM}%s:%d  更新: %s  q=終了${C_RESET}" \
            "$REDIS_HOST" "$REDIS_PORT" "$(get_timestamp)"

        local info
        info=$(get_info all 2>/dev/null) || { move_cursor 5 2; printf "${C_RED}接続エラー${C_RESET}"; sleep 2; continue; }

        get_val() { echo "$info" | grep "^$1:" | cut -d: -f2 | tr -d '\r '; }

        move_cursor 5 2
        printf "${C_BOLD}接続: ${C_GREEN}%s${C_RESET}  メモリ: ${C_YELLOW}%s${C_RESET}  コマンド/秒: ${C_CYAN}%s${C_RESET}" \
            "$(get_val connected_clients)" \
            "$(get_val used_memory_human)" \
            "$(get_val instantaneous_ops_per_sec)"

        move_cursor 7 2; printf "${C_BOLD}【キャッシュヒット率】${C_RESET}"
        local hits=$(get_val keyspace_hits)
        local misses=$(get_val keyspace_misses)
        local total=$(( ${hits:-0} + ${misses:-0} ))
        local hit_rate=0
        [[ $total -gt 0 ]] && hit_rate=$(( hits * 100 / total ))
        move_cursor 8 2
        draw_progress_bar "$hit_rate" 100 30
        printf " %d%% (hits=%s misses=%s)" "$hit_rate" "${hits:-0}" "${misses:-0}"

        move_cursor 10 2; printf "${C_BOLD}【接続統計】${C_RESET}"
        move_cursor 11 2; printf "接続済: %-8s  拒否数: %-8s" \
            "$(get_val connected_clients)" "$(get_val rejected_connections)"
        move_cursor 12 2; printf "入力: %-12s  出力: %-12s" \
            "$(get_val total_net_input_bytes)" "$(get_val total_net_output_bytes)"

        move_cursor 14 2; printf "${C_BOLD}【複製】${C_RESET}"
        move_cursor 15 2; printf "ロール: ${C_CYAN}%s${C_RESET}  接続スレーブ: %s" \
            "$(get_val role)" "$(get_val connected_slaves)"

        if read -rsn1 -t "$watch_interval" key 2>/dev/null; then
            [[ "$key" == "q" || "$key" == "Q" ]] && break
        fi
    done
}

cmd_flush() {
    local db="${ARGS[0]:-}"

    if [[ -n "$db" ]]; then
        log_warning "DB ${db} をフラッシュします"
        if confirm "本当に実行しますか？ (元に戻せません)" "n"; then
            redis_cmd SELECT "$db" &>/dev/null
            redis_cmd FLUSHDB
            log_success "DB ${db} をフラッシュしました"
        fi
    else
        log_warning "全データベースをフラッシュします"
        if confirm "本当に実行しますか？ (元に戻せません)" "n"; then
            redis_cmd FLUSHALL
            log_success "全データベースをフラッシュしました"
        fi
    fi
}

declare -a ARGS=()

parse_arguments() {
    [[ $# -eq 0 ]] && return 0
    case "$1" in
        info|stats|memory|clients|keys|slow|watch|flush)
            command_name="$1"; shift ;;
    esac

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -H|--host)    [[ $# -lt 2 ]] && error_exit "--host には値が必要です"; REDIS_HOST="$2"; shift 2 ;;
            -p|--port)    [[ $# -lt 2 ]] && error_exit "--port には値が必要です"; REDIS_PORT="$2"; shift 2 ;;
            -a|--auth)    [[ $# -lt 2 ]] && error_exit "--auth には値が必要です"; REDIS_PASS="$2"; shift 2 ;;
            -i|--interval) [[ $# -lt 2 ]] && error_exit "--interval には値が必要です"; watch_interval="$2"; shift 2 ;;
            -n|--top)     [[ $# -lt 2 ]] && error_exit "--top には値が必要です"; top_n="$2"; shift 2 ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  ARGS+=("$1"); shift ;;
        esac
    done
}

main() {
    parse_arguments "$@"
    check_redis
    case "$command_name" in
        info)    cmd_info ;;
        memory)  cmd_memory ;;
        clients) cmd_clients ;;
        keys)    cmd_keys ;;
        slow)    cmd_slow ;;
        watch)   cmd_watch ;;
        flush)   cmd_flush ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
