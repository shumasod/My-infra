#!/bin/bash
set -euo pipefail

#
# ファイル監視ツール
# 作成日: 2026-07-14
# バージョン: 1.0
#
# 指定ディレクトリのファイル変更をポーリングで監視し通知する
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare -i INTERVAL=5
declare WATCH_DIR="."
declare PATTERN="*"
declare LOG_FILE=""
declare -i MAX_EVENTS=0

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション] [監視ディレクトリ]

ファイルの変更を監視して通知します。

引数:
  [監視ディレクトリ]  監視するディレクトリ（デフォルト: カレント）

オプション:
  -h, --help          このヘルプを表示
  -v, --version       バージョン情報を表示
  -i, --interval N    ポーリング間隔（秒、デフォルト: 5）
  -p, --pattern PAT   監視するファイルパターン（デフォルト: *）
  -l, --log FILE      ログファイルに記録
  -n, --count N       N件イベント後に終了（0=無制限）

例:
  $PROG_NAME /var/log
  $PROG_NAME -i 10 -p "*.log" /var/log
  $PROG_NAME -l watch.log /etc
EOF
}

declare -A FILE_MTIMES
declare -A FILE_SIZES

snapshot_dir() {
    local dir="$1"
    local pat="$2"

    FILE_MTIMES=()
    FILE_SIZES=()

    while IFS= read -r -d '' file; do
        local mtime size
        mtime=$(stat -c "%Y" "$file" 2>/dev/null || echo "0")
        size=$(stat -c "%s" "$file" 2>/dev/null || echo "0")
        FILE_MTIMES["$file"]="$mtime"
        FILE_SIZES["$file"]="$size"
    done < <(find "$dir" -maxdepth 3 -name "$pat" -type f -print0 2>/dev/null)
}

detect_changes() {
    local dir="$1"
    local pat="$2"
    local -i event_count=0

    declare -A new_mtimes
    declare -A new_sizes
    declare -A new_seen

    while IFS= read -r -d '' file; do
        local mtime size
        mtime=$(stat -c "%Y" "$file" 2>/dev/null || echo "0")
        size=$(stat -c "%s" "$file" 2>/dev/null || echo "0")
        new_mtimes["$file"]="$mtime"
        new_sizes["$file"]="$size"
        new_seen["$file"]=1

        if [[ -z "${FILE_MTIMES[$file]+x}" ]]; then
            report_event "CREATE" "$file" "$size"
            (( event_count++ ))
        elif [[ "${FILE_MTIMES[$file]}" != "$mtime" ]]; then
            local old_size="${FILE_SIZES[$file]}"
            local diff=$(( size - old_size ))
            local diff_str
            if (( diff > 0 )); then
                diff_str="+${diff}B"
            else
                diff_str="${diff}B"
            fi
            report_event "MODIFY" "$file" "$size ($diff_str)"
            (( event_count++ ))
        fi
    done < <(find "$dir" -maxdepth 3 -name "$pat" -type f -print0 2>/dev/null)

    for file in "${!FILE_MTIMES[@]}"; do
        if [[ -z "${new_seen[$file]+x}" ]]; then
            report_event "DELETE" "$file" "-"
            (( event_count++ ))
        fi
    done

    FILE_MTIMES=()
    FILE_SIZES=()
    for k in "${!new_mtimes[@]}"; do
        FILE_MTIMES["$k"]="${new_mtimes[$k]}"
        FILE_SIZES["$k"]="${new_sizes[$k]}"
    done

    echo "$event_count"
}

report_event() {
    local event="$1"
    local file="$2"
    local size="$3"
    local ts
    ts=$(get_timestamp)

    local color
    case "$event" in
        CREATE) color="$C_GREEN" ;;
        MODIFY) color="$C_YELLOW" ;;
        DELETE) color="$C_RED" ;;
        *)      color="$C_RESET" ;;
    esac

    local line
    line=$(printf "${color}[%s]${C_RESET} %-8s %s ${C_DIM}(%s bytes)${C_RESET}" \
        "$ts" "$event" "$file" "$size")
    echo -e "$line"

    if [[ -n "$LOG_FILE" ]]; then
        printf "[%s] %-8s %s (%s bytes)\n" "$ts" "$event" "$file" "$size" >> "$LOG_FILE"
    fi
}

cleanup() {
    echo ""
    log_info "監視を終了しました"
}
trap cleanup EXIT INT TERM

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)      show_usage; exit 0 ;;
            -v|--version)   echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -i|--interval)
                [[ $# -lt 2 ]] && error_exit "--interval には秒数が必要です"
                INTERVAL="$2"; shift 2 ;;
            -p|--pattern)
                [[ $# -lt 2 ]] && error_exit "--pattern にはパターンが必要です"
                PATTERN="$2"; shift 2 ;;
            -l|--log)
                [[ $# -lt 2 ]] && error_exit "--log にはファイル名が必要です"
                LOG_FILE="$2"; shift 2 ;;
            -n|--count)
                [[ $# -lt 2 ]] && error_exit "--count には件数が必要です"
                MAX_EVENTS="$2"; shift 2 ;;
            -*)  error_exit "不明なオプション: $1" ;;
            *)   WATCH_DIR="$1"; shift ;;
        esac
    done

    if [[ ! -d "$WATCH_DIR" ]]; then
        error_exit "ディレクトリが見つかりません: $WATCH_DIR"
    fi

    echo ""
    print_center "ファイル監視ツール" 0 "${C_BOLD}${C_CYAN}"
    echo ""
    log_info "監視ディレクトリ: ${WATCH_DIR}"
    log_info "パターン: ${PATTERN}  インターバル: ${INTERVAL}秒"
    [[ -n "$LOG_FILE" ]] && log_info "ログ: $LOG_FILE"
    echo -e "  ${C_DIM}Ctrl+C で終了${C_RESET}"
    echo ""

    snapshot_dir "$WATCH_DIR" "$PATTERN"
    log_success "初回スナップショット取得完了（${#FILE_MTIMES[@]}件）"
    echo ""

    declare -i total_events=0
    while true; do
        sleep "$INTERVAL"
        local count
        count=$(detect_changes "$WATCH_DIR" "$PATTERN")
        total_events=$(( total_events + count ))

        if (( MAX_EVENTS > 0 && total_events >= MAX_EVENTS )); then
            log_info "指定件数（${MAX_EVENTS}件）に達しました"
            break
        fi
    done
}

main "$@"
