#!/bin/bash
set -euo pipefail

#
# Journaldログ解析ツール
# バージョン: 1.0
#
# systemd journalのログを解析・集計・レポートするツール
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare mode="summary"
declare target_unit=""
declare target_priority="3"
declare -i since_hours=24
declare -i top_n=10
declare output_file=""
declare grep_pattern=""

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション] コマンド

Journaldログ解析ツール

コマンド:
  summary           ログサマリー (デフォルト)
  errors            エラー/クリティカルログ一覧
  units             ユニット別ログ量ランキング
  timeline          時間帯別ログ量分布
  boots             起動履歴一覧
  search PATTERN    パターン検索
  follow UNIT       リアルタイム追跡

オプション:
  -h, --help              このヘルプを表示
  -v, --version           バージョン情報を表示
  -u, --unit UNIT         対象ユニット名
  -p, --priority NUM      優先度フィルタ (0=emerg 〜 7=debug)
  -s, --since HOURS       過去N時間のログ [デフォルト: 24]
  -n, --top NUM           上位N件表示 [デフォルト: 10]
  -o, --output FILE       出力ファイル
  -g, --grep PATTERN      追加フィルタパターン

優先度:
  0=emerg  1=alert  2=crit  3=err  4=warning  5=notice  6=info  7=debug

例:
  $PROG_NAME summary
  $PROG_NAME errors -s 1
  $PROG_NAME -u nginx errors
  $PROG_NAME units -n 20
  $PROG_NAME timeline
  $PROG_NAME boots
  $PROG_NAME search "OOM"

EOF
}

check_journalctl() {
    if ! command -v journalctl &>/dev/null; then
        error_exit "journalctlが見つかりません (systemdが必要です)"
    fi
}

journal_opts() {
    local opts=("--since=${since_hours} hours ago" "--no-pager")
    [[ -n "$target_unit" ]] && opts+=("-u" "$target_unit")
    echo "${opts[@]}"
}

priority_name() {
    case "$1" in
        0) echo "EMERG" ;;
        1) echo "ALERT" ;;
        2) echo "CRIT" ;;
        3) echo "ERR" ;;
        4) echo "WARNING" ;;
        5) echo "NOTICE" ;;
        6) echo "INFO" ;;
        7) echo "DEBUG" ;;
        *) echo "UNKNOWN" ;;
    esac
}

priority_color() {
    case "$1" in
        0|1|2) echo "$C_RED" ;;
        3)     echo "$C_YELLOW" ;;
        4)     echo "$C_YELLOW" ;;
        5|6)   echo "$C_RESET" ;;
        7)     echo "$C_DIM" ;;
        *)     echo "$C_RESET" ;;
    esac
}

do_summary() {
    check_journalctl
    log_info "ジャーナルサマリー (過去${since_hours}時間)"
    echo ""

    local journal_args
    read -ra journal_args <<< "$(journal_opts)"

    # 総ログ数
    local total
    total=$(journalctl "${journal_args[@]}" -o short 2>/dev/null | wc -l || echo 0)
    printf "  %-25s %d 件\n" "総ログ数:" "$total"

    # 優先度別集計
    echo ""
    log_info "優先度別ログ数:"
    printf "  ${C_BOLD}%-12s %-10s %s${C_RESET}\n" "優先度" "件数" "グラフ"
    printf "  %s\n" "$(printf '%.0s-' {1..50})"

    for p in 0 1 2 3 4 5 6; do
        local count
        count=$(journalctl "${journal_args[@]}" -p "$p".."$p" -o short 2>/dev/null | wc -l || echo 0)
        (( count == 0 )) && continue

        local color
        color=$(priority_color "$p")
        local pname
        pname=$(priority_name "$p")
        local bar_len=$(( count > 40 ? 40 : count ))
        local bar=""
        (( bar_len > 0 )) && bar=$(printf '█%.0s' $(seq 1 $bar_len))

        printf "  ${color}%-12s %-10d %s${C_RESET}\n" "$pname" "$count" "$bar"
    done

    echo ""

    # ディスク使用量
    local disk_usage
    disk_usage=$(journalctl --disk-usage 2>/dev/null | grep -oE '[0-9.]+ [KMG]B' | head -1 || echo "unknown")
    printf "  %-25s %s\n" "ジャーナル使用量:" "$disk_usage"

    # 最初と最後のエントリ
    local first_entry last_entry
    first_entry=$(journalctl "${journal_args[@]}" -o short -n 0 --since "$(date -d "${since_hours} hours ago" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo '24 hours ago')" 2>/dev/null | head -2 | tail -1 | awk '{print $1,$2,$3}' || echo "unknown")
    last_entry=$(journalctl "${journal_args[@]}" -o short -n 1 2>/dev/null | tail -1 | awk '{print $1,$2,$3}' || echo "unknown")
    printf "  %-25s %s\n" "最初のエントリ:" "$first_entry"
    printf "  %-25s %s\n" "最新のエントリ:" "$last_entry"
    echo ""
}

do_errors() {
    check_journalctl
    log_info "エラー/クリティカルログ (過去${since_hours}時間)"
    echo ""

    local journal_args
    read -ra journal_args <<< "$(journal_opts)"

    local -i shown=0
    journalctl "${journal_args[@]}" -p 0..3 -o short 2>/dev/null | tail -n +2 | \
    while IFS= read -r line; do
        (( shown >= top_n )) && break
        [[ -n "$grep_pattern" ]] && ! echo "$line" | grep -qi "$grep_pattern" && continue

        local p_color="$C_RED"
        echo "$line" | grep -qi "crit\|emerg\|alert" && p_color="${C_RED}${C_BOLD}"

        printf "  ${p_color}%s${C_RESET}\n" "$line"
        (( shown++ )) || true
    done

    if (( shown == 0 )); then
        log_success "エラーログはありません"
    fi
    echo ""
}

do_units() {
    check_journalctl
    log_info "ユニット別ログ量 Top${top_n} (過去${since_hours}時間)"
    echo ""

    printf "  ${C_BOLD}%-35s %8s${C_RESET}\n" "ユニット" "件数"
    printf "  %s\n" "$(printf '%.0s-' {1..46})"

    local journal_args
    read -ra journal_args <<< "$(journal_opts)"

    journalctl "${journal_args[@]}" -o json 2>/dev/null | \
    python3 -c "
import sys, json
from collections import Counter
counts = Counter()
for line in sys.stdin:
    try:
        obj = json.loads(line)
        unit = obj.get('_SYSTEMD_UNIT', obj.get('SYSLOG_IDENTIFIER', 'kernel'))
        counts[unit] += 1
    except: pass
for unit, count in counts.most_common(${top_n}):
    print(f'{unit}|{count}')
" 2>/dev/null | while IFS='|' read -r unit count; do
        local bar_len=$(( count > 30 ? 30 : count / 10 ))
        local bar=""
        (( bar_len > 0 )) && bar=$(printf '█%.0s' $(seq 1 $bar_len))
        printf "  %-35s %8d %s\n" "${unit:0:34}" "$count" "$bar"
    done
    echo ""
}

do_timeline() {
    check_journalctl
    log_info "時間帯別ログ量 (過去${since_hours}時間)"
    echo ""

    local journal_args
    read -ra journal_args <<< "$(journal_opts)"

    journalctl "${journal_args[@]}" -o short 2>/dev/null | tail -n +2 | \
    awk '{
        if (match($3, /^([0-9]+):/, arr)) {
            hour = arr[1]
            counts[hour]++
        }
    }
    END {
        for (h in counts) {
            printf "%02d|%d\n", h, counts[h]
        }
    }' | sort -n | while IFS='|' read -r hour count; do
        local bar_len=$(( count > 50 ? 50 : count / 5 + 1 ))
        local bar
        bar=$(printf '█%.0s' $(seq 1 $bar_len))
        printf "  %s:00 %6d %s\n" "$hour" "$count" "$bar"
    done
    echo ""
}

do_boots() {
    check_journalctl
    log_info "起動履歴"
    echo ""

    printf "  ${C_BOLD}%-5s %-30s %-30s %s${C_RESET}\n" "ID" "起動時刻" "停止時刻" "稼働時間"
    printf "  %s\n" "$(printf '%.0s-' {1..80})"

    journalctl --list-boots --no-pager 2>/dev/null | while IFS= read -r line; do
        local id boot_time
        id=$(echo "$line" | awk '{print $1}')
        boot_time=$(echo "$line" | awk '{print $3, $4, $5, $6}')
        printf "  %-5s %-30s\n" "$id" "$boot_time"
    done | head -20
    echo ""
}

do_search() {
    check_journalctl
    [[ -z "$grep_pattern" ]] && error_exit "検索パターンを -g で指定してください"

    log_info "ログ検索: '$grep_pattern' (過去${since_hours}時間)"
    echo ""

    local journal_args
    read -ra journal_args <<< "$(journal_opts)"

    local count=0
    journalctl "${journal_args[@]}" -o short 2>/dev/null | \
    grep -i "$grep_pattern" | head -"$top_n" | while IFS= read -r line; do
        printf "  %s\n" "$line"
        (( count++ )) || true
    done

    echo ""
}

do_follow() {
    check_journalctl
    local unit="${target_unit:-}"
    [[ -z "$unit" ]] && error_exit "ユニット名を -u で指定してください"

    log_info "リアルタイム追跡: $unit (Ctrl+C で停止)"
    echo ""

    journalctl -fu "$unit" --no-pager 2>/dev/null | while IFS= read -r line; do
        if echo "$line" | grep -qiE "error|crit|emerg|fail"; then
            printf "${C_RED}%s${C_RESET}\n" "$line"
        elif echo "$line" | grep -qiE "warn"; then
            printf "${C_YELLOW}%s${C_RESET}\n" "$line"
        else
            printf "%s\n" "$line"
        fi
    done
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -u|--unit)    [[ $# -lt 2 ]] && error_exit "-u には値が必要です"; target_unit="$2"; shift 2 ;;
            -p|--priority) [[ $# -lt 2 ]] && error_exit "-p には値が必要です"; target_priority="$2"; shift 2 ;;
            -s|--since)   [[ $# -lt 2 ]] && error_exit "-s には値が必要です"; since_hours="$2"; shift 2 ;;
            -n|--top)     [[ $# -lt 2 ]] && error_exit "-n には値が必要です"; top_n="$2"; shift 2 ;;
            -o|--output)  [[ $# -lt 2 ]] && error_exit "-o には値が必要です"; output_file="$2"; shift 2 ;;
            -g|--grep)    [[ $# -lt 2 ]] && error_exit "-g には値が必要です"; grep_pattern="$2"; shift 2 ;;
            summary|errors|units|timeline|boots|follow) mode="$1"; shift ;;
            search)
                mode="search"
                [[ $# -ge 2 && ! "$2" =~ ^- ]] && { grep_pattern="$2"; shift; }
                shift
                ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  shift ;;
        esac
    done
}

main() {
    parse_arguments "$@"

    local result
    result=$(case "$mode" in
        summary)  do_summary ;;
        errors)   do_errors ;;
        units)    do_units ;;
        timeline) do_timeline ;;
        boots)    do_boots ;;
        search)   do_search ;;
        follow)   do_follow ;;
        *)        error_exit "不明なコマンド: $mode" ;;
    esac)

    if [[ -n "$output_file" ]]; then
        echo "$result" | sed 's/\x1b\[[0-9;]*m//g' > "$output_file"
        log_success "保存: $output_file"
    fi
    echo "$result"
}

main "$@"
