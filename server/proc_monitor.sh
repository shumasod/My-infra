#!/bin/bash
set -euo pipefail

#
# プロセス監視ツール
# バージョン: 1.0
#
# プロセスの監視・アラート・自動再起動を行うツール
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"
readonly STATE_DIR="${HOME}/.proc_monitor"
readonly WATCH_CONFIG="${STATE_DIR}/watch.conf"

declare mode="list"
declare proc_pattern=""
declare -i cpu_threshold=80
declare -i mem_threshold=80
declare -i interval=5
declare -i max_restarts=3
declare restart_cmd=""
declare alert_cmd=""
declare watch_name=""
declare output_format="table"

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション] コマンド

プロセス監視ツール

コマンド:
  list [PATTERN]    プロセス一覧(パターンフィルタ可)
  top               リソース使用量上位プロセス
  watch             監視設定一覧
  add               監視対象を追加
  remove NAME       監視対象を削除
  run               監視ループ開始
  kill PATTERN      パターンマッチするプロセスを終了
  info PID          プロセス詳細情報

オプション:
  -h, --help              このヘルプを表示
  -v, --version           バージョン情報を表示
  -p, --pattern PAT       プロセス名パターン
  -n, --name NAME         監視設定名
  -c, --cpu THRESHOLD     CPU使用率閾値 [デフォルト: 80]
  -m, --mem THRESHOLD     メモリ使用率閾値 [デフォルト: 80]
  -i, --interval SEC      監視間隔秒数 [デフォルト: 5]
  -r, --restart CMD       再起動コマンド
  -a, --alert CMD         アラートコマンド
  -f, --format FMT        出力形式 (table|csv)
  --max-restarts NUM      最大再起動回数 [デフォルト: 3]

例:
  $PROG_NAME list
  $PROG_NAME list nginx
  $PROG_NAME top
  $PROG_NAME info 1234
  $PROG_NAME add -n nginx -p "nginx" -c 90 -m 50 -r "systemctl restart nginx"
  $PROG_NAME run

EOF
}

init_dirs() {
    mkdir -p "$STATE_DIR"
    [[ -f "$WATCH_CONFIG" ]] || touch "$WATCH_CONFIG"
}

do_list() {
    local pattern="${proc_pattern:-}"

    log_info "プロセス一覧${pattern:+ (フィルタ: $pattern)}"
    echo ""

    if [[ "$output_format" == "csv" ]]; then
        echo "PID,USER,CPU%,MEM%,RSS(MB),コマンド"
    else
        printf "  ${C_BOLD}%-8s %-12s %6s %6s %8s %s${C_RESET}\n" \
            "PID" "ユーザー" "CPU%" "MEM%" "RSS(MB)" "コマンド"
        printf "  %s\n" "$(printf '%.0s-' {1..70})"
    fi

    ps aux --sort=-%cpu | tail -n +2 | while read -r user pid cpu mem vsz rss tty stat start time cmd; do
        if [[ -n "$pattern" ]] && ! echo "$cmd $proc_pattern" | grep -qi "$pattern"; then
            continue
        fi

        local rss_mb=$(( rss / 1024 ))
        local cmd_short="${cmd:0:40}"

        local cpu_color="$C_RESET"
        (( ${cpu%.*} >= cpu_threshold )) 2>/dev/null && cpu_color="$C_RED"

        local mem_color="$C_RESET"
        (( ${mem%.*} >= mem_threshold )) 2>/dev/null && mem_color="$C_RED"

        if [[ "$output_format" == "csv" ]]; then
            echo "${pid},${user},${cpu},${mem},${rss_mb},${cmd_short}"
        else
            printf "  %-8s %-12s ${cpu_color}%6s${C_RESET} ${mem_color}%6s${C_RESET} %8d %s\n" \
                "$pid" "${user:0:12}" "$cpu" "$mem" "$rss_mb" "$cmd_short"
        fi
    done | head -50
    echo ""
}

do_top() {
    log_info "リソース使用量 Top 20"
    echo ""

    printf "  ${C_BOLD}%-8s %-12s %6s %6s %8s %s${C_RESET}\n" \
        "PID" "ユーザー" "CPU%" "MEM%" "RSS(MB)" "コマンド"
    printf "  %s\n" "$(printf '%.0s-' {1..70})"

    ps aux --sort=-%cpu | tail -n +2 | head -20 | while read -r user pid cpu mem vsz rss tty stat start time cmd; do
        local rss_mb=$(( rss / 1024 ))
        local cmd_short="${cmd:0:40}"

        local cpu_int="${cpu%.*}"
        local cpu_color="$C_RESET"
        (( cpu_int >= 70 )) && cpu_color="$C_RED"
        (( cpu_int >= 30 && cpu_int < 70 )) && cpu_color="$C_YELLOW"

        local bar_len=$(( cpu_int > 20 ? 20 : cpu_int ))
        local bar=""
        (( bar_len > 0 )) && bar=$(printf '█%.0s' $(seq 1 $bar_len))

        printf "  %-8s %-12s ${cpu_color}%6s${C_RESET} %6s %8d %s ${cpu_color}%s${C_RESET}\n" \
            "$pid" "${user:0:12}" "$cpu" "$mem" "$rss_mb" "$cmd_short" "$bar"
    done
    echo ""

    # システムサマリー
    local cpu_idle
    cpu_idle=$(vmstat 1 2 | tail -1 | awk '{print $15}')
    local cpu_used=$(( 100 - cpu_idle ))

    local mem_total mem_free mem_used
    mem_total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    mem_free=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    mem_used=$(( (mem_total - mem_free) * 100 / mem_total ))

    printf "  ${C_BOLD}システム全体:${C_RESET} "
    printf "CPU ${C_CYAN}%d%%${C_RESET}  " "$cpu_used"
    printf "メモリ ${C_CYAN}%d%%${C_RESET}  " "$mem_used"
    printf "プロセス数 ${C_CYAN}%d${C_RESET}\n" "$(ps aux | wc -l)"
    echo ""
}

do_info() {
    local pid="${proc_pattern:-}"
    [[ -z "$pid" ]] && error_exit "PIDを指定してください"
    [[ ! -d "/proc/$pid" ]] && error_exit "プロセスが見つかりません: $pid"

    log_info "プロセス詳細: PID $pid"
    echo ""

    local comm
    comm=$(cat "/proc/$pid/comm" 2>/dev/null || echo "unknown")
    local status_file="/proc/$pid/status"
    local cmdline
    cmdline=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null || echo "unknown")

    local vm_rss vm_peak threads ppid
    vm_rss=$(grep VmRSS "$status_file" 2>/dev/null | awk '{print $2}' || echo 0)
    vm_peak=$(grep VmPeak "$status_file" 2>/dev/null | awk '{print $2}' || echo 0)
    threads=$(grep Threads "$status_file" 2>/dev/null | awk '{print $2}' || echo 1)
    ppid=$(grep PPid "$status_file" 2>/dev/null | awk '{print $2}' || echo 0)

    local start_time
    start_time=$(ps -p "$pid" -o lstart= 2>/dev/null || echo "unknown")

    printf "  %-20s %s\n" "プロセス名:" "$comm"
    printf "  %-20s %s\n" "PID:" "$pid"
    printf "  %-20s %s\n" "親PID:" "$ppid"
    printf "  %-20s %s\n" "スレッド数:" "$threads"
    printf "  %-20s %d MB\n" "メモリ使用量:" "$(( vm_rss / 1024 ))"
    printf "  %-20s %d MB\n" "ピークメモリ:" "$(( vm_peak / 1024 ))"
    printf "  %-20s %s\n" "起動時刻:" "$start_time"
    printf "  %-20s %s\n" "コマンドライン:" "${cmdline:0:60}"
    echo ""

    # オープンファイル数
    local fd_count
    fd_count=$(ls "/proc/$pid/fd" 2>/dev/null | wc -l || echo 0)
    printf "  %-20s %d\n" "オープンFD数:" "$fd_count"
    echo ""
}

do_watch_list() {
    if [[ ! -s "$WATCH_CONFIG" ]]; then
        log_warning "監視設定がありません"
        echo "  $PROG_NAME add で監視対象を追加してください"
        echo ""
        return 0
    fi

    log_info "監視設定一覧"
    echo ""
    printf "  ${C_BOLD}%-15s %-20s %8s %8s %s${C_RESET}\n" "名前" "パターン" "CPU閾値" "MEM閾値" "再起動コマンド"
    printf "  %s\n" "$(printf '%.0s-' {1..70})"

    while IFS='|' read -r name pattern cpu mem restarts restart alert; do
        [[ -z "$name" || "$name" =~ ^# ]] && continue
        local cmd_short="${restart:0:25}"
        printf "  %-15s %-20s %8s%% %8s%% %s\n" "$name" "$pattern" "$cpu" "$mem" "$cmd_short"
    done < "$WATCH_CONFIG"
    echo ""
}

do_add_watch() {
    [[ -z "$watch_name" ]] && error_exit "監視名を -n で指定してください"
    [[ -z "$proc_pattern" ]] && error_exit "プロセスパターンを -p で指定してください"

    if grep -q "^${watch_name}|" "$WATCH_CONFIG" 2>/dev/null; then
        error_exit "監視設定 '$watch_name' はすでに存在します"
    fi

    echo "${watch_name}|${proc_pattern}|${cpu_threshold}|${mem_threshold}|${max_restarts}|${restart_cmd}|${alert_cmd}" >> "$WATCH_CONFIG"
    log_success "監視設定を追加しました: $watch_name"
}

do_remove_watch() {
    local name="${watch_name:-$1}"
    [[ -z "$name" ]] && error_exit "監視名を指定してください"

    sed -i "/^${name}|/d" "$WATCH_CONFIG"
    log_success "監視設定を削除しました: $name"
}

do_run() {
    [[ ! -s "$WATCH_CONFIG" ]] && error_exit "監視設定がありません。$PROG_NAME add で追加してください"

    log_info "プロセス監視開始 (Ctrl+C で停止)"
    echo ""

    local restart_counts_file
    restart_counts_file=$(mktemp)
    trap "rm -f '$restart_counts_file'" EXIT

    while true; do
        local timestamp
        timestamp=$(get_timestamp)

        while IFS='|' read -r name pattern cpu mem max_restart restart alert; do
            [[ -z "$name" || "$name" =~ ^# ]] && continue

            local procs
            procs=$(pgrep -f "$pattern" 2>/dev/null || true)

            if [[ -z "$procs" ]]; then
                log_warning "[$timestamp] プロセスなし: $name ($pattern)"

                local count
                count=$(grep "^${name}=" "$restart_counts_file" 2>/dev/null | cut -d= -f2 || echo 0)
                if (( count < max_restart )) && [[ -n "$restart" ]]; then
                    log_info "[$timestamp] 再起動試行: $name"
                    eval "$restart" && {
                        (( count++ )) || true
                        sed -i "/^${name}=/d" "$restart_counts_file" 2>/dev/null || true
                        echo "${name}=${count}" >> "$restart_counts_file"
                        log_success "[$timestamp] 再起動成功: $name (${count}/${max_restart})"
                    }
                fi
                continue
            fi

            # CPU/MEM チェック
            for pid in $procs; do
                local cpu_pct mem_pct
                cpu_pct=$(ps -p "$pid" -o %cpu= 2>/dev/null | tr -d ' ' || echo 0)
                mem_pct=$(ps -p "$pid" -o %mem= 2>/dev/null | tr -d ' ' || echo 0)

                local cpu_int="${cpu_pct%.*}"
                local mem_int="${mem_pct%.*}"

                if (( cpu_int >= cpu )); then
                    log_warning "[$timestamp] CPU高負荷: $name (PID:$pid) ${cpu_pct}% >= ${cpu}%"
                    [[ -n "$alert" ]] && eval "$alert" || true
                fi

                if (( mem_int >= mem )); then
                    log_warning "[$timestamp] MEM高使用: $name (PID:$pid) ${mem_pct}% >= ${mem}%"
                    [[ -n "$alert" ]] && eval "$alert" || true
                fi
            done

        done < "$WATCH_CONFIG"

        sleep "$interval"
    done
}

do_kill_proc() {
    local pattern="${proc_pattern:-}"
    [[ -z "$pattern" ]] && error_exit "パターンを -p で指定してください"

    local pids
    pids=$(pgrep -f "$pattern" 2>/dev/null || true)

    if [[ -z "$pids" ]]; then
        log_warning "パターンにマッチするプロセスがありません: $pattern"
        return 0
    fi

    echo "終了対象プロセス:"
    for pid in $pids; do
        local cmd
        cmd=$(ps -p "$pid" -o cmd= 2>/dev/null || echo "unknown")
        echo "  PID $pid: $cmd"
    done

    confirm "上記のプロセスを終了しますか?" "n" || { log_info "キャンセル"; return 0; }

    for pid in $pids; do
        kill "$pid" 2>/dev/null && log_success "終了: PID $pid" || log_error "終了失敗: PID $pid"
    done
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -p|--pattern) [[ $# -lt 2 ]] && error_exit "-p には値が必要です"; proc_pattern="$2"; shift 2 ;;
            -n|--name)    [[ $# -lt 2 ]] && error_exit "-n には値が必要です"; watch_name="$2"; shift 2 ;;
            -c|--cpu)     [[ $# -lt 2 ]] && error_exit "-c には値が必要です"; cpu_threshold="$2"; shift 2 ;;
            -m|--mem)     [[ $# -lt 2 ]] && error_exit "-m には値が必要です"; mem_threshold="$2"; shift 2 ;;
            -i|--interval) [[ $# -lt 2 ]] && error_exit "-i には値が必要です"; interval="$2"; shift 2 ;;
            -r|--restart) [[ $# -lt 2 ]] && error_exit "-r には値が必要です"; restart_cmd="$2"; shift 2 ;;
            -a|--alert)   [[ $# -lt 2 ]] && error_exit "-a には値が必要です"; alert_cmd="$2"; shift 2 ;;
            -f|--format)  [[ $# -lt 2 ]] && error_exit "-f には値が必要です"; output_format="$2"; shift 2 ;;
            --max-restarts) [[ $# -lt 2 ]] && error_exit "--max-restarts には値が必要です"; max_restarts="$2"; shift 2 ;;
            list|top|run) mode="$1"; shift ;;
            watch) mode="watch_list"; shift ;;
            add)   mode="add_watch"; shift ;;
            remove)
                mode="remove_watch"
                [[ $# -ge 2 && ! "$2" =~ ^- ]] && { watch_name="$2"; shift; }
                shift
                ;;
            kill)
                mode="kill_proc"
                [[ $# -ge 2 && ! "$2" =~ ^- ]] && { proc_pattern="$2"; shift; }
                shift
                ;;
            info)
                mode="info"
                [[ $# -ge 2 && ! "$2" =~ ^- ]] && { proc_pattern="$2"; shift; }
                shift
                ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)
                [[ "$mode" == "list" ]] && proc_pattern="$1"
                shift
                ;;
        esac
    done
}

main() {
    init_dirs
    parse_arguments "$@"

    case "$mode" in
        list)        do_list ;;
        top)         do_top ;;
        info)        do_info ;;
        watch_list)  do_watch_list ;;
        add_watch)   do_add_watch ;;
        remove_watch) do_remove_watch ;;
        run)         do_run ;;
        kill_proc)   do_kill_proc ;;
        *)           error_exit "不明なコマンド: $mode" ;;
    esac
}

main "$@"
