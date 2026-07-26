#!/bin/bash
set -euo pipefail

#
# ファイル変更監視ツール
# バージョン: 1.0
#
# ディレクトリ・ファイルの変更を監視し、コマンドを自動実行するツール
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare -a watch_paths=()
declare -i interval=2
declare exec_cmd=""
declare filter_pattern=""
declare exclude_pattern="\.git|\.swp|~$"
declare log_file=""
declare recursive=true
declare show_content=false
declare -i max_events=0

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション] パス [パス...]

ファイル変更監視ツール

引数:
  パス              監視するファイルまたはディレクトリ

オプション:
  -h, --help              このヘルプを表示
  -v, --version           バージョン情報を表示
  -i, --interval SEC      チェック間隔秒数 [デフォルト: 2]
  -e, --exec CMD          変更検知時に実行するコマンド
  -f, --filter PAT        監視対象フィルタ(正規表現)
  -x, --exclude PAT       除外パターン [デフォルト: .git/.swp/~]
  -o, --output FILE       イベントログ出力ファイル
  -n, --max-events NUM    最大イベント数 (0=無限)
  --no-recursive          サブディレクトリを監視しない
  --show-content          変更ファイルの差分を表示

例:
  $PROG_NAME src/
  $PROG_NAME -e "make build" -f "\.go$" ./
  $PROG_NAME -i 1 -x "node_modules|\.pyc" -e "npm test" ./src
  $PROG_NAME --show-content -o changes.log ./config

EOF
}

get_snapshot() {
    local path="$1"
    if $recursive; then
        find "$path" -type f 2>/dev/null | sort | while read -r f; do
            local mtime size
            mtime=$(stat -c '%Y' "$f" 2>/dev/null || echo 0)
            size=$(stat -c '%s' "$f" 2>/dev/null || echo 0)
            echo "${mtime}:${size}:${f}"
        done
    else
        find "$path" -maxdepth 1 -type f 2>/dev/null | sort | while read -r f; do
            local mtime size
            mtime=$(stat -c '%Y' "$f" 2>/dev/null || echo 0)
            size=$(stat -c '%s' "$f" 2>/dev/null || echo 0)
            echo "${mtime}:${size}:${f}"
        done
    fi
}

filter_paths() {
    local input="$1"
    if [[ -n "$filter_pattern" ]]; then
        echo "$input" | grep -E "$filter_pattern" || true
    else
        echo "$input"
    fi

    if [[ -n "$exclude_pattern" ]]; then
        echo "$input" | grep -vE "$exclude_pattern" || true
    fi
}

detect_changes() {
    local prev_snapshot="$1"
    local curr_snapshot="$2"

    local added modified deleted

    # 追加されたファイル
    added=$(comm -13 \
        <(echo "$prev_snapshot" | awk -F: '{print $3}' | sort) \
        <(echo "$curr_snapshot" | awk -F: '{print $3}' | sort) 2>/dev/null || true)

    # 削除されたファイル
    deleted=$(comm -23 \
        <(echo "$prev_snapshot" | awk -F: '{print $3}' | sort) \
        <(echo "$curr_snapshot" | awk -F: '{print $3}' | sort) 2>/dev/null || true)

    # 変更されたファイル (mtime/size変化)
    local prev_map curr_map
    prev_map=$(echo "$prev_snapshot" | awk -F: '{print $3, $1":"$2}')
    curr_map=$(echo "$curr_snapshot" | awk -F: '{print $3, $1":"$2}')

    modified=$(comm -12 \
        <(echo "$prev_snapshot" | awk -F: '{print $3}' | sort) \
        <(echo "$curr_snapshot" | awk -F: '{print $3}' | sort) 2>/dev/null | \
        while read -r f; do
            local prev_stat curr_stat
            prev_stat=$(echo "$prev_snapshot" | grep ":${f}$" | cut -d: -f1,2 || true)
            curr_stat=$(echo "$curr_snapshot" | grep ":${f}$" | cut -d: -f1,2 || true)
            [[ "$prev_stat" != "$curr_stat" ]] && echo "$f"
        done || true)

    echo "ADDED:$added"
    echo "MODIFIED:$modified"
    echo "DELETED:$deleted"
}

do_monitor() {
    local -A prev_snapshots
    local -i event_count=0

    for path in "${watch_paths[@]}"; do
        if [[ ! -e "$path" ]]; then
            log_error "パスが存在しません: $path"
            continue
        fi
        prev_snapshots["$path"]=$(get_snapshot "$path")
    done

    log_info "ファイル監視開始 (Ctrl+C で停止)"
    log_info "監視対象: ${watch_paths[*]}"
    [[ -n "$filter_pattern" ]] && log_info "フィルタ: $filter_pattern"
    [[ -n "$exec_cmd" ]] && log_info "実行コマンド: $exec_cmd"
    echo ""

    local cleanup_called=false
    cleanup_monitor() {
        $cleanup_called && return
        cleanup_called=true
        echo ""
        log_info "監視を終了しました (イベント数: ${event_count})"
    }
    trap cleanup_monitor EXIT INT TERM

    while true; do
        (( max_events > 0 && event_count >= max_events )) && break

        for path in "${watch_paths[@]}"; do
            [[ ! -e "$path" ]] && continue

            local curr_snapshot
            curr_snapshot=$(get_snapshot "$path")

            local prev_snapshot="${prev_snapshots[$path]:-}"

            if [[ "$curr_snapshot" == "$prev_snapshot" ]]; then
                continue
            fi

            local timestamp
            timestamp=$(get_timestamp)

            local added_files modified_files deleted_files

            added_files=$(comm -13 \
                <(echo "$prev_snapshot" | awk -F: '{print $3}' | sort) \
                <(echo "$curr_snapshot" | awk -F: '{print $3}' | sort) 2>/dev/null || true)

            deleted_files=$(comm -23 \
                <(echo "$prev_snapshot" | awk -F: '{print $3}' | sort) \
                <(echo "$curr_snapshot" | awk -F: '{print $3}' | sort) 2>/dev/null || true)

            modified_files=$(comm -12 \
                <(echo "$prev_snapshot" | awk -F: '{print $3}' | sort) \
                <(echo "$curr_snapshot" | awk -F: '{print $3}' | sort) 2>/dev/null | \
                while read -r f; do
                    local ps cs
                    ps=$(echo "$prev_snapshot" | grep ":${f}$" | cut -d: -f1,2 2>/dev/null || true)
                    cs=$(echo "$curr_snapshot" | grep ":${f}$" | cut -d: -f1,2 2>/dev/null || true)
                    [[ "$ps" != "$cs" ]] && echo "$f"
                done || true)

            local event_triggered=false

            while IFS= read -r f; do
                [[ -z "$f" ]] && continue
                [[ -n "$filter_pattern" ]] && ! echo "$f" | grep -qE "$filter_pattern" && continue
                [[ -n "$exclude_pattern" ]] && echo "$f" | grep -qE "$exclude_pattern" && continue
                printf "${C_GREEN}[追加] ${C_RESET}%s %s\n" "$timestamp" "$f"
                [[ -n "$log_file" ]] && echo "ADDED|${timestamp}|${f}" >> "$log_file"
                event_triggered=true
                (( event_count++ )) || true
            done <<< "$added_files"

            while IFS= read -r f; do
                [[ -z "$f" ]] && continue
                [[ -n "$filter_pattern" ]] && ! echo "$f" | grep -qE "$filter_pattern" && continue
                [[ -n "$exclude_pattern" ]] && echo "$f" | grep -qE "$exclude_pattern" && continue
                printf "${C_YELLOW}[変更] ${C_RESET}%s %s\n" "$timestamp" "$f"
                [[ -n "$log_file" ]] && echo "MODIFIED|${timestamp}|${f}" >> "$log_file"
                $show_content && diff <(echo "") "$f" 2>/dev/null | head -10 | sed 's/^/  /' || true
                event_triggered=true
                (( event_count++ )) || true
            done <<< "$modified_files"

            while IFS= read -r f; do
                [[ -z "$f" ]] && continue
                [[ -n "$filter_pattern" ]] && ! echo "$f" | grep -qE "$filter_pattern" && continue
                [[ -n "$exclude_pattern" ]] && echo "$f" | grep -qE "$exclude_pattern" && continue
                printf "${C_RED}[削除] ${C_RESET}%s %s\n" "$timestamp" "$f"
                [[ -n "$log_file" ]] && echo "DELETED|${timestamp}|${f}" >> "$log_file"
                event_triggered=true
                (( event_count++ )) || true
            done <<< "$deleted_files"

            if $event_triggered && [[ -n "$exec_cmd" ]]; then
                log_info "実行: $exec_cmd"
                eval "$exec_cmd" 2>&1 | sed 's/^/  /' || true
                echo ""
            fi

            prev_snapshots["$path"]="$curr_snapshot"
        done

        sleep "$interval"
    done
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -i|--interval) [[ $# -lt 2 ]] && error_exit "-i には値が必要です"; interval="$2"; shift 2 ;;
            -e|--exec)    [[ $# -lt 2 ]] && error_exit "-e には値が必要です"; exec_cmd="$2"; shift 2 ;;
            -f|--filter)  [[ $# -lt 2 ]] && error_exit "-f には値が必要です"; filter_pattern="$2"; shift 2 ;;
            -x|--exclude) [[ $# -lt 2 ]] && error_exit "-x には値が必要です"; exclude_pattern="$2"; shift 2 ;;
            -o|--output)  [[ $# -lt 2 ]] && error_exit "-o には値が必要です"; log_file="$2"; shift 2 ;;
            -n|--max-events) [[ $# -lt 2 ]] && error_exit "-n には値が必要です"; max_events="$2"; shift 2 ;;
            --no-recursive) recursive=false; shift ;;
            --show-content) show_content=true; shift ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  watch_paths+=("$1"); shift ;;
        esac
    done
}

main() {
    parse_arguments "$@"
    [[ ${#watch_paths[@]} -eq 0 ]] && error_exit "監視するパスを指定してください"
    do_monitor
}

main "$@"
