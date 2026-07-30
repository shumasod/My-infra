#!/bin/bash
set -euo pipefail

#
# Dockerコンテナ統計ダッシュボード
# 作成日: 2026-07-30
# バージョン: 1.0
#
# Dockerコンテナのリソース使用状況をリアルタイムで表示します
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare command_name="dashboard"
declare watch_interval=3
declare container_filter=""
declare show_all=false
declare output_format="table"

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション]

Dockerコンテナの統計ダッシュボードです。

コマンド:
  dashboard              リアルタイムダッシュボード (デフォルト)
  stats                  現在の統計スナップショット
  ps                     コンテナ一覧 (拡張)
  logs <コンテナ>        コンテナのログ
  top <コンテナ>         コンテナ内プロセス
  inspect <コンテナ>     コンテナ詳細情報
  cleanup                停止コンテナ・未使用イメージの削除

オプション:
  -h, --help             このヘルプを表示
  -v, --version          バージョン情報を表示
  -i, --interval <秒>    更新間隔 [デフォルト: 3]
  -f, --filter <名前>    コンテナ名でフィルタ
  -a, --all              停止中のコンテナも表示
  --format <形式>        出力形式 (table|json) [デフォルト: table]

例:
  $PROG_NAME
  $PROG_NAME stats
  $PROG_NAME ps -a
  $PROG_NAME logs my-container
  $PROG_NAME cleanup
EOF
}

check_docker() {
    if ! command -v docker &>/dev/null; then
        error_exit "Docker がインストールされていません"
    fi
    if ! docker info &>/dev/null; then
        error_exit "Docker デーモンに接続できません"
    fi
}

parse_cpu() {
    local stats_json="$1"
    echo "$stats_json" | python3 -c "
import json, sys
data = json.load(sys.stdin)
cpu = data.get('cpu_stats', {})
pre = data.get('precpu_stats', {})
cpu_delta = cpu.get('cpu_usage', {}).get('total_usage', 0) - pre.get('cpu_usage', {}).get('total_usage', 0)
sys_delta = cpu.get('system_cpu_usage', 0) - pre.get('system_cpu_usage', 0)
n_cpu = cpu.get('online_cpus', 1) or len(cpu.get('cpu_usage', {}).get('percpu_usage', [1]))
pct = (cpu_delta / sys_delta) * n_cpu * 100.0 if sys_delta > 0 else 0
print(f'{pct:.1f}')
" 2>/dev/null || echo "0.0"
}

parse_mem() {
    local stats_json="$1"
    echo "$stats_json" | python3 -c "
import json, sys
data = json.load(sys.stdin)
mem = data.get('memory_stats', {})
usage = mem.get('usage', 0)
cache = mem.get('stats', {}).get('cache', 0)
limit = mem.get('limit', 1)
real = usage - cache
pct = real * 100.0 / limit if limit > 0 else 0
print(f'{real//1024//1024} {limit//1024//1024} {pct:.1f}')
" 2>/dev/null || echo "0 0 0.0"
}

mini_bar() {
    local pct=${1%.*}
    local width=15
    local filled=$(( pct * width / 100 ))
    local color="$C_GREEN"
    (( pct >= 70 )) && color="$C_YELLOW"
    (( pct >= 90 )) && color="$C_RED"
    printf "${color}"
    printf '%0.s█' $(seq 1 $filled 2>/dev/null) || true
    printf "${C_RESET}"
    printf '%0.s░' $(seq 1 $(( width - filled )) 2>/dev/null) || true
}

cmd_stats() {
    log_info "コンテナ統計を取得中..."
    echo ""

    local filter_args=()
    $show_all && filter_args+=("-a")
    [[ -n "$container_filter" ]] && filter_args+=(--filter "name=$container_filter")

    local containers
    containers=$(docker ps "${filter_args[@]}" --format "{{.ID}}|{{.Names}}|{{.Status}}|{{.Image}}" 2>/dev/null)

    if [[ -z "$containers" ]]; then
        log_info "実行中のコンテナがありません"
        return
    fi

    printf "${C_BOLD}%-15s %-20s %16s %16s %12s %s${C_RESET}\n" \
        "コンテナ名" "イメージ" "CPU%" "メモリ" "状態" ""
    printf "%s\n" "$(printf '%.0s─' {1..80})"

    while IFS='|' read -r cid name status image; do
        local stats_json
        stats_json=$(docker stats --no-stream --format '{{json .}}' "$cid" 2>/dev/null) || continue

        local cpu_pct mem_pct mem_usage mem_limit
        cpu_pct=$(echo "$stats_json" | python3 -c "
import json,sys; d=json.load(sys.stdin); print(d.get('CPUPerc','0%').rstrip('%'))
" 2>/dev/null || echo "0")
        mem_pct=$(echo "$stats_json" | python3 -c "
import json,sys; d=json.load(sys.stdin); print(d.get('MemPerc','0%').rstrip('%'))
" 2>/dev/null || echo "0")
        mem_usage=$(echo "$stats_json" | python3 -c "
import json,sys; d=json.load(sys.stdin); print(d.get('MemUsage','N/A').split('/')[0].strip())
" 2>/dev/null || echo "N/A")

        local cpu_bar mem_bar
        cpu_bar=$(mini_bar "${cpu_pct%.*}")
        mem_bar=$(mini_bar "${mem_pct%.*}")

        local status_color="$C_GREEN"
        echo "$status" | grep -qi "up" || status_color="$C_RED"

        printf "  ${C_CYAN}%-13s${C_RESET} %-20s %b %5s%% %b %8s  ${status_color}%s${C_RESET}\n" \
            "${name:0:13}" "${image:0:20}" "$cpu_bar" "$cpu_pct" "$mem_bar" "$mem_usage" "Up"
    done <<< "$containers"
    echo ""
}

cmd_dashboard() {
    local cleanup_done=false
    cleanup() {
        $cleanup_done && return
        cleanup_done=true
        show_cursor
        printf '\033[?1049l'
    }
    trap cleanup EXIT INT TERM

    printf '\033[?1049h'
    hide_cursor

    while true; do
        clear_screen
        update_terminal_size

        print_center "Docker コンテナダッシュボード" 1 "$C_CYAN"
        draw_separator 2
        move_cursor 3 2
        printf "${C_DIM}更新: $(get_timestamp)  間隔: ${watch_interval}s  q=終了${C_RESET}"

        local filter_args=()
        $show_all && filter_args+=("-a")
        [[ -n "$container_filter" ]] && filter_args+=(--filter "name=$container_filter")

        local containers
        containers=$(docker ps "${filter_args[@]}" --format "{{.ID}}|{{.Names}}|{{.Status}}|{{.Image}}" 2>/dev/null)

        local row=5
        move_cursor $row 2
        printf "${C_BOLD}%-15s %-18s %13s %13s %s${C_RESET}" \
            "コンテナ名" "イメージ" "CPU%" "メモリ%" "状態"
        (( row += 2 ))

        if [[ -z "$containers" ]]; then
            move_cursor $row 4
            printf "${C_DIM}実行中のコンテナがありません${C_RESET}"
        else
            while IFS='|' read -r cid name status image; do
                [[ $row -ge $(( TERM_ROWS - 5 )) ]] && break

                local stats_json
                stats_json=$(docker stats --no-stream --format '{{json .}}' "$cid" 2>/dev/null) || continue

                local cpu_pct mem_pct mem_usage
                cpu_pct=$(echo "$stats_json" | python3 -c "
import json,sys; d=json.load(sys.stdin); print(d.get('CPUPerc','0%').rstrip('%'))
" 2>/dev/null || echo "0")
                mem_pct=$(echo "$stats_json" | python3 -c "
import json,sys; d=json.load(sys.stdin); print(d.get('MemPerc','0%').rstrip('%'))
" 2>/dev/null || echo "0")
                mem_usage=$(echo "$stats_json" | python3 -c "
import json,sys; d=json.load(sys.stdin); print(d.get('MemUsage','N/A').split('/')[0].strip())
" 2>/dev/null || echo "N/A")

                move_cursor $row 2
                printf "${C_CYAN}%-13s${C_RESET} %-18s " "${name:0:13}" "${image:0:18}"
                mini_bar "${cpu_pct%.*}"
                printf " %4s%%  " "$cpu_pct"
                mini_bar "${mem_pct%.*}"
                printf " %4s%%  ${C_DIM}%s${C_RESET}" "$mem_pct" "$mem_usage"
                (( row++ ))
            done <<< "$containers"
        fi

        # Docker全体情報
        local total_row=$(( TERM_ROWS - 4 ))
        draw_separator $total_row
        move_cursor $(( total_row + 1 )) 2

        local running stopped images
        running=$(docker ps -q | wc -l)
        stopped=$(docker ps -aq | wc -l)
        images=$(docker images -q | wc -l)
        printf "  実行中: ${C_GREEN}%d${C_RESET}  停止中: ${C_DIM}%d${C_RESET}  イメージ: ${C_CYAN}%d${C_RESET}" \
            "$running" "$(( stopped - running ))" "$images"

        if read -rsn1 -t "$watch_interval" key 2>/dev/null; then
            [[ "$key" == "q" || "$key" == "Q" ]] && break
        fi
    done
}

cmd_ps() {
    local filter_args=()
    $show_all && filter_args+=("-a")
    [[ -n "$container_filter" ]] && filter_args+=(--filter "name=$container_filter")

    echo ""
    docker ps "${filter_args[@]}" \
        --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}\t{{.Size}}" \
        2>/dev/null | while IFS= read -r line; do
        if [[ "$line" == NAMES* ]]; then
            printf "${C_BOLD}%s${C_RESET}\n" "$line"
        elif echo "$line" | grep -qi "up"; then
            printf "${C_GREEN}%s${C_RESET}\n" "$line"
        else
            printf "${C_DIM}%s${C_RESET}\n" "$line"
        fi
    done
    echo ""
}

cmd_cleanup() {
    log_info "Dockerリソースをクリーンアップします"
    echo ""

    local stopped_count
    stopped_count=$(docker ps -aq --filter status=exited | wc -l)
    local dangling_images
    dangling_images=$(docker images -q --filter dangling=true | wc -l)
    local unused_volumes
    unused_volumes=$(docker volume ls -q --filter dangling=true | wc -l)

    printf "  停止コンテナ: %d件\n" "$stopped_count"
    printf "  未使用イメージ: %d件\n" "$dangling_images"
    printf "  未使用ボリューム: %d件\n\n" "$unused_volumes"

    if [[ $(( stopped_count + dangling_images + unused_volumes )) -eq 0 ]]; then
        log_success "クリーンアップ不要です"
        return
    fi

    if ! confirm "クリーンアップを実行しますか？" "n"; then
        log_info "キャンセルしました"
        return
    fi

    [[ $stopped_count -gt 0 ]]    && docker container prune -f && log_success "停止コンテナを削除しました"
    [[ $dangling_images -gt 0 ]]  && docker image prune -f && log_success "未使用イメージを削除しました"
    [[ $unused_volumes -gt 0 ]]   && docker volume prune -f && log_success "未使用ボリュームを削除しました"
    echo ""
}

declare -a ARGS=()

parse_arguments() {
    [[ $# -eq 0 ]] && return 0

    case "$1" in
        dashboard|stats|ps|logs|top|inspect|cleanup)
            command_name="$1"; shift ;;
    esac

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -i|--interval)
                [[ $# -lt 2 ]] && error_exit "--interval には値が必要です"
                watch_interval="$2"; shift 2 ;;
            -f|--filter)
                [[ $# -lt 2 ]] && error_exit "--filter には値が必要です"
                container_filter="$2"; shift 2 ;;
            -a|--all)  show_all=true; shift ;;
            --format)
                [[ $# -lt 2 ]] && error_exit "--format には値が必要です"
                output_format="$2"; shift 2 ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  ARGS+=("$1"); shift ;;
        esac
    done
}

main() {
    parse_arguments "$@"
    check_docker

    case "$command_name" in
        dashboard) cmd_dashboard ;;
        stats)     cmd_stats ;;
        ps)        cmd_ps ;;
        logs)
            local cname="${ARGS[0]:-}"
            [[ -z "$cname" ]] && error_exit "コンテナ名を指定してください"
            docker logs --tail 50 "$cname" 2>&1 ;;
        top)
            local cname="${ARGS[0]:-}"
            [[ -z "$cname" ]] && error_exit "コンテナ名を指定してください"
            docker top "$cname" ;;
        inspect)
            local cname="${ARGS[0]:-}"
            [[ -z "$cname" ]] && error_exit "コンテナ名を指定してください"
            docker inspect "$cname" | python3 -m json.tool 2>/dev/null ;;
        cleanup)   cmd_cleanup ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
