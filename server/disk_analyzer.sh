#!/bin/bash
set -euo pipefail

#
# ディスク使用量分析ツール
# 作成日: 2026-07-31
# バージョン: 1.0
#
# ディスク使用量を可視化し、大容量ファイル・ディレクトリを検出します
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare command_name="overview"
declare target_path="${1:-.}"
declare top_n=20
declare depth=2
declare min_size="1M"
declare watch_interval=10
declare warn_threshold=80
declare critical_threshold=90

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション] [パス]

ディスク使用量の分析ツールです。

コマンド:
  overview [パス]        ディスク全体の概要
  large [パス]           大容量ファイル・ディレクトリを検索
  tree [パス]            ディレクトリツリーと使用量
  watch                  リアルタイム監視
  old [パス]             古いファイルを検索
  dupes [パス]           重複ファイルを検出

オプション:
  -h, --help             このヘルプを表示
  -v, --version          バージョン情報を表示
  -n, --top <数>         上位表示件数 [デフォルト: 20]
  -d, --depth <数>       ディレクトリ深さ [デフォルト: 2]
  --min <サイズ>         最小サイズ (例: 1M, 100K) [デフォルト: 1M]
  -i, --interval <秒>    監視間隔 [デフォルト: 10]
  --warn <数>            警告閾値% [デフォルト: 80]
  --critical <数>        危険閾値% [デフォルト: 90]

例:
  $PROG_NAME overview
  $PROG_NAME large /var -n 30
  $PROG_NAME tree /home --depth 3
  $PROG_NAME old /tmp --min 10M
  $PROG_NAME dupes /home/user
EOF
}

format_size() {
    local kb=$1
    if (( kb >= 1048576 )); then
        printf "%.1f GB" "$(echo "scale=1; $kb/1048576" | bc 2>/dev/null || echo '?')"
    elif (( kb >= 1024 )); then
        printf "%.1f MB" "$(echo "scale=1; $kb/1024" | bc 2>/dev/null || echo '?')"
    else
        printf "%d KB" "$kb"
    fi
}

bar() {
    local pct=$1 width=${2:-25}
    local filled=$(( pct * width / 100 ))
    local color="$C_GREEN"
    (( pct >= warn_threshold ))     && color="$C_YELLOW"
    (( pct >= critical_threshold )) && color="$C_RED"
    printf "${color}"
    printf '%0.s█' $(seq 1 $filled 2>/dev/null) || true
    printf "${C_RESET}"
    printf '%0.s░' $(seq 1 $(( width - filled )) 2>/dev/null) || true
}

cmd_overview() {
    log_info "ディスク使用量概要"
    echo ""

    printf "${C_BOLD}【マウントポイント別使用量】${C_RESET}\n\n"
    printf "${C_BOLD}%-20s %8s %8s %8s %6s %s${C_RESET}\n" \
        "マウントポイント" "合計" "使用" "空き" "使用率" "グラフ"
    printf "%s\n" "$(printf '%.0s─' {1..75})"

    df -h --output=target,size,used,avail,pcent 2>/dev/null | tail -n +2 | \
    grep -v "^tmpfs\|^devtmpfs\|^udev" | sort | \
    while IFS= read -r line; do
        local mount size used avail pct
        read -r mount size used avail pct <<< "$line"
        local pct_num="${pct%\%}"
        local color="$C_GREEN"
        (( ${pct_num:-0} >= warn_threshold ))     && color="$C_YELLOW"
        (( ${pct_num:-0} >= critical_threshold )) && color="$C_RED"

        printf "  ${C_CYAN}%-18s${C_RESET} %8s %8s %8s  ${color}%5s${C_RESET}  " \
            "${mount:0:18}" "$size" "$used" "$avail" "$pct"
        bar "${pct_num:-0}" 20
        echo ""
    done

    echo ""
    printf "${C_BOLD}【iノード使用量】${C_RESET}\n\n"
    printf "${C_BOLD}%-20s %10s %10s %6s${C_RESET}\n" "マウントポイント" "使用iノード" "最大iノード" "使用率"
    printf "%s\n" "$(printf '%.0s─' {1..55})"

    df -i --output=target,iused,iavail,ipcent 2>/dev/null | tail -n +2 | \
    grep -v "^tmpfs\|^devtmpfs\|^udev" | \
    while IFS= read -r line; do
        local mount iused iavail ipct
        read -r mount iused iavail ipct <<< "$line"
        local pct_num="${ipct%\%}"
        local color="$C_GREEN"
        (( ${pct_num:-0} >= 80 )) && color="$C_YELLOW"
        (( ${pct_num:-0} >= 90 )) && color="$C_RED"
        printf "  ${C_CYAN}%-18s${C_RESET} %10s %10s ${color}%6s${C_RESET}\n" \
            "${mount:0:18}" "$iused" "$iavail" "$ipct"
    done
    echo ""
}

cmd_large() {
    log_info "大容量ファイル・ディレクトリを検索中: $target_path"
    echo ""

    printf "${C_BOLD}【大容量ディレクトリ TOP${top_n}】${C_RESET}\n"
    printf "%s\n" "$(printf '%.0s─' {1..55})"

    du -x --max-depth="$depth" "$target_path" 2>/dev/null | \
    sort -rn | head -"$top_n" | \
    while read -r size_kb dir; do
        local size_str
        size_str=$(format_size "$size_kb")
        local color="$C_WHITE"
        (( size_kb >= 1048576 )) && color="$C_RED"    # 1GB以上
        (( size_kb >= 102400 && size_kb < 1048576 )) && color="$C_YELLOW"  # 100MB以上
        printf "  ${color}%10s${C_RESET}  %s\n" "$size_str" "$dir"
    done

    echo ""
    printf "${C_BOLD}【大容量ファイル TOP${top_n}】${C_RESET}\n"
    printf "%s\n" "$(printf '%.0s─' {1..55})"

    find "$target_path" -xdev -type f -size "+${min_size}" 2>/dev/null | \
    xargs -I{} stat -c "%s %n" {} 2>/dev/null | \
    sort -rn | head -"$top_n" | \
    awk '{
        size=$1
        $1=""
        name=$0
        if (size >= 1073741824) printf "  %10.1f GB  %s\n", size/1073741824, name
        else if (size >= 1048576) printf "  %10.1f MB  %s\n", size/1048576, name
        else printf "  %10.1f KB  %s\n", size/1024, name
    }' | while IFS= read -r line; do
        printf "${C_YELLOW}%s${C_RESET}\n" "$line"
    done
    echo ""
}

cmd_tree() {
    log_info "ディレクトリツリー: $target_path"
    echo ""

    du -x --max-depth="$depth" "$target_path" 2>/dev/null | \
    sort -rn | python3 - "$target_path" "$depth" <<'PYEOF'
import sys, os
from collections import defaultdict

lines = [l.strip().split('\t') for l in sys.stdin if '\t' in l]
base = sys.argv[1].rstrip('/')
max_depth = int(sys.argv[2])

total = 0
entries = {}
for size_kb, path in [(int(l[0]), l[1]) for l in lines if len(l)==2]:
    entries[path] = size_kb
    if path == base:
        total = size_kb

def fmt(kb):
    if kb >= 1048576: return f'{kb/1048576:.1f}G'
    if kb >= 1024: return f'{kb/1024:.1f}M'
    return f'{kb}K'

CYAN = '\033[1;36m'
GREEN = '\033[1;32m'
YELLOW = '\033[1;33m'
RED = '\033[1;31m'
DIM = '\033[2m'
RESET = '\033[0m'

def print_tree(path, prefix='', depth=0):
    if depth > max_depth: return
    size = entries.get(path, 0)
    pct = size*100//total if total > 0 else 0
    color = RED if pct >= 50 else YELLOW if pct >= 20 else CYAN
    name = os.path.basename(path) or path
    print(f'{prefix}{color}{name}/{RESET}  {fmt(size)} ({pct}%)')

    children = sorted(
        [(p,s) for p,s in entries.items()
         if os.path.dirname(p)==path and p!=path],
        key=lambda x: -x[1]
    )
    for i, (child, _) in enumerate(children[:10]):
        is_last = (i == len(children)-1 or i == 9)
        new_prefix = prefix + ('└── ' if is_last else '├── ')
        next_prefix = prefix + ('    ' if is_last else '│   ')
        print_tree(child, new_prefix, depth+1)

print_tree(base)
PYEOF
    echo ""
}

cmd_old() {
    log_info "古いファイルを検索中: $target_path"
    echo ""

    printf "${C_BOLD}【90日以上未アクセスのファイル】${C_RESET}\n"
    printf "%s\n" "$(printf '%.0s─' {1..60})"

    find "$target_path" -xdev -type f -size "+${min_size}" -atime +90 2>/dev/null | \
    xargs -I{} stat -c "%X %s %n" {} 2>/dev/null | \
    sort -n | head -"$top_n" | \
    awk '{
        ts=$1; size=$2; $1=""; $2=""; name=$0
        if (size >= 1073741824) sz = sprintf("%.1f GB", size/1073741824)
        else if (size >= 1048576) sz = sprintf("%.1f MB", size/1048576)
        else sz = sprintf("%.1f KB", size/1024)
        cmd = "date -d @" ts " +\"%Y-%m-%d\""
        cmd | getline dt
        close(cmd)
        printf "  %-12s %-12s %s\n", dt, sz, name
    }' | while IFS= read -r line; do
        printf "${C_DIM}%s${C_RESET}\n" "$line"
    done
    echo ""
    log_info "これらのファイルは長期間アクセスされていません"
}

cmd_dupes() {
    log_info "重複ファイルを検索中: $target_path (時間がかかります)"
    echo ""

    find "$target_path" -xdev -type f -size "+10k" 2>/dev/null | \
    xargs -I{} md5sum {} 2>/dev/null | \
    sort | awk '{
        hash=$1; $1=""; file=$0
        if (hash == prev_hash) {
            if (!printed[hash]) {
                printf "%s\n", prev_file
                printed[hash]=1
            }
            printf "%s\n", file
        }
        prev_hash=hash; prev_file=file
    }' | head -$(( top_n * 3 )) | while IFS= read -r file; do
        local size
        size=$(stat -c%s "$file" 2>/dev/null || echo 0)
        local size_str
        if (( size >= 1048576 )); then
            size_str=$(printf "%.1f MB" "$(echo "scale=1; $size/1048576" | bc)")
        else
            size_str=$(printf "%d KB" "$(( size / 1024 ))")
        fi
        printf "  ${C_YELLOW}%10s${C_RESET} %s\n" "$size_str" "$file"
    done
    echo ""
}

cmd_watch() {
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
        print_center "ディスク監視ダッシュボード" 1 "$C_CYAN"
        draw_separator 2
        move_cursor 3 2
        printf "${C_DIM}更新: $(get_timestamp)  間隔: ${watch_interval}s  q=終了${C_RESET}"

        local row=5
        df -h --output=target,size,used,avail,pcent 2>/dev/null | tail -n +2 | \
        grep -v "^tmpfs\|^devtmpfs\|^udev" | \
        while IFS= read -r line; do
            local mount size used avail pct
            read -r mount size used avail pct <<< "$line"
            local pct_num="${pct%\%}"
            move_cursor $row 2
            printf "${C_CYAN}%-20s${C_RESET} " "${mount:0:20}"
            bar "${pct_num:-0}" 25
            printf " ${C_BOLD}%5s${C_RESET} (%s/%s)" "$pct" "$used" "$size"
            (( row++ ))
        done

        if read -rsn1 -t "$watch_interval" key 2>/dev/null; then
            [[ "$key" == "q" || "$key" == "Q" ]] && break
        fi
    done
}

parse_arguments() {
    [[ $# -eq 0 ]] && return 0
    case "$1" in
        overview|large|tree|watch|old|dupes)
            command_name="$1"; shift ;;
    esac

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -n|--top)     [[ $# -lt 2 ]] && error_exit "--top には値が必要です"; top_n="$2"; shift 2 ;;
            -d|--depth)   [[ $# -lt 2 ]] && error_exit "--depth には値が必要です"; depth="$2"; shift 2 ;;
            --min)        [[ $# -lt 2 ]] && error_exit "--min には値が必要です"; min_size="$2"; shift 2 ;;
            -i|--interval) [[ $# -lt 2 ]] && error_exit "--interval には値が必要です"; watch_interval="$2"; shift 2 ;;
            --warn)       [[ $# -lt 2 ]] && error_exit "--warn には値が必要です"; warn_threshold="$2"; shift 2 ;;
            --critical)   [[ $# -lt 2 ]] && error_exit "--critical には値が必要です"; critical_threshold="$2"; shift 2 ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  target_path="$1"; shift ;;
        esac
    done
}

main() {
    parse_arguments "$@"
    case "$command_name" in
        overview) cmd_overview ;;
        large)    cmd_large ;;
        tree)     cmd_tree ;;
        watch)    cmd_watch ;;
        old)      cmd_old ;;
        dupes)    cmd_dupes ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
