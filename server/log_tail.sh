#!/bin/bash
set -euo pipefail

#
# カラーログビューワー (tail -f 強化版)
# 作成日: 2026-07-30
# バージョン: 1.0
#
# ログファイルをカラー表示・フィルタリングしながらリアルタイムで追跡します
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare -a log_files=()
declare follow_mode=false
declare lines=50
declare filter_pattern=""
declare exclude_pattern=""
declare highlight_pattern=""
declare log_format="auto"
declare show_stats=false
declare since_time=""

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション] <ログファイル...>

ログファイルをカラー表示するビューワーです。

オプション:
  -h, --help             このヘルプを表示
  -v, --version          バージョン情報を表示
  -f, --follow           リアルタイム追跡 (tail -f)
  -n, --lines <行数>     表示行数 [デフォルト: 50]
  -g, --grep <パターン>  表示するパターン (grep -E)
  -e, --exclude <パターン> 除外するパターン
  -H, --highlight <パターン>  ハイライトするパターン
  --format <形式>        ログ形式 (auto|nginx|apache|syslog|json|plain)
  --stats                統計情報を表示
  --since <時間>         指定時間以降 (例: "1 hour ago", "2025-01-01")

例:
  $PROG_NAME /var/log/nginx/access.log
  $PROG_NAME -f /var/log/syslog -g "ERROR|WARN"
  $PROG_NAME -n 100 --stats /var/log/app.log
  $PROG_NAME -f --exclude "health_check" /var/log/access.log
EOF
}

colorize_level() {
    local line="$1"
    if [[ "$line" =~ (EMERG|EMERGENCY|FATAL|CRITICAL) ]]; then
        printf "${C_BG_RED}${C_WHITE}%s${C_RESET}" "$line"
    elif [[ "$line" =~ (ERROR|ERR|SEVERE) ]]; then
        printf "${C_RED}%s${C_RESET}" "$line"
    elif [[ "$line" =~ (WARN|WARNING) ]]; then
        printf "${C_YELLOW}%s${C_RESET}" "$line"
    elif [[ "$line" =~ (INFO|NOTICE) ]]; then
        printf "${C_GREEN}%s${C_RESET}" "$line"
    elif [[ "$line" =~ (DEBUG|TRACE|VERBOSE) ]]; then
        printf "${C_DIM}%s${C_RESET}" "$line"
    else
        printf "%s" "$line"
    fi
}

colorize_nginx() {
    local line="$1"
    # IPアドレスを青色で
    line=$(echo "$line" | sed 's/\([0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\)/\x1b[1;34m\1\x1b[0m/g')
    # HTTPステータスコードを色分け
    if [[ "$line" =~ [[:space:]]([45][0-9][0-9])[[:space:]] ]]; then
        local code="${BASH_REMATCH[1]}"
        if [[ "${code:0:1}" == "5" ]]; then
            line="${line/$code/$'\033[1;31m'${code}$'\033[0m'}"
        else
            line="${line/$code/$'\033[1;33m'${code}$'\033[0m'}"
        fi
    elif [[ "$line" =~ [[:space:]]([23][0-9][0-9])[[:space:]] ]]; then
        local code="${BASH_REMATCH[1]}"
        line="${line/$code/$'\033[1;32m'${code}$'\033[0m'}"
    fi
    echo "$line"
}

colorize_json() {
    local line="$1"
    if command -v python3 &>/dev/null; then
        echo "$line" | python3 -c "
import json, sys
try:
    data = json.loads(sys.stdin.read())
    level = str(data.get('level', data.get('severity', data.get('lvl', '')))).upper()
    msg = data.get('message', data.get('msg', data.get('text', str(data))))
    ts = data.get('timestamp', data.get('time', data.get('ts', '')))

    colors = {
        'ERROR': '\033[1;31m', 'FATAL': '\033[41;37m',
        'WARN': '\033[1;33m', 'WARNING': '\033[1;33m',
        'INFO': '\033[1;32m', 'DEBUG': '\033[2m',
    }
    color = colors.get(level, '')
    reset = '\033[0m'
    ts_str = f'[\033[2m{ts}\033[0m] ' if ts else ''
    level_str = f'{color}[{level}]{reset} ' if level else ''
    print(f'{ts_str}{level_str}{msg}')
except:
    print(sys.argv[1] if len(sys.argv) > 1 else '')
" "$line" 2>/dev/null || echo "$line"
    else
        echo "$line"
    fi
}

detect_format() {
    local file="$1"
    local sample
    sample=$(head -5 "$file" 2>/dev/null || echo "")

    if echo "$sample" | grep -qE '^\{.*"(level|severity|msg|message)"'; then
        echo "json"
    elif echo "$sample" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ - -'; then
        echo "nginx"
    elif echo "$sample" | grep -qE '^[A-Z][a-z]{2} [0-9]{1,2} [0-9]{2}:[0-9]{2}:[0-9]{2}'; then
        echo "syslog"
    else
        echo "plain"
    fi
}

process_line() {
    local line="$1"
    local fmt="${2:-plain}"

    # フィルタリング
    [[ -n "$filter_pattern" ]] && ! echo "$line" | grep -qE "$filter_pattern" && return
    [[ -n "$exclude_pattern" ]] && echo "$line" | grep -qE "$exclude_pattern" && return

    # 色付け
    local colored
    case "$fmt" in
        nginx|apache) colored=$(colorize_nginx "$line") ;;
        json)         colored=$(colorize_json "$line") ;;
        syslog|plain|*) colored=$(colorize_level "$line") ;;
    esac

    # ハイライト
    if [[ -n "$highlight_pattern" ]]; then
        colored=$(echo "$colored" | sed "s/\($highlight_pattern\)/$(printf '\033[1;43m')\1$(printf '\033[0m')/gI")
    fi

    echo "$colored"
}

show_header() {
    local file="$1"
    local fmt="$2"
    echo ""
    printf "${C_BOLD}${C_CYAN}=== %s ===${C_RESET}\n" "$file"
    printf "${C_DIM}形式: %s  " "$fmt"
    [[ -f "$file" ]] && printf "サイズ: %s" "$(du -sh "$file" 2>/dev/null | awk '{print $1}')"
    printf "${C_RESET}\n\n"
}

show_file_stats() {
    local file="$1"
    [[ ! -f "$file" ]] && return

    echo ""
    printf "${C_BOLD}【統計情報: %s】${C_RESET}\n" "$file"

    local total_lines
    total_lines=$(wc -l < "$file")
    printf "  総行数: %d\n" "$total_lines"

    for level in ERROR WARN INFO DEBUG; do
        local count
        count=$(grep -cE "$level" "$file" 2>/dev/null || echo 0)
        [[ $count -gt 0 ]] && printf "  %-8s: %d 行\n" "$level" "$count"
    done

    echo ""
    printf "  【最近のエラー (上位5件)】\n"
    grep -iE "error|critical|fatal" "$file" 2>/dev/null | tail -5 | \
        while IFS= read -r line; do
            printf "    ${C_RED}%s${C_RESET}\n" "${line:0:100}"
        done || true
    echo ""
}

cmd_view() {
    local fmt="$log_format"

    for file in "${log_files[@]}"; do
        if [[ "$file" == "-" ]]; then
            # 標準入力
            fmt="plain"
            while IFS= read -r line; do
                process_line "$line" "$fmt"
            done
            continue
        fi

        [[ ! -f "$file" ]] && { log_error "ファイルが見つかりません: $file"; continue; }

        [[ "$fmt" == "auto" ]] && fmt=$(detect_format "$file")
        show_header "$file" "$fmt"

        local tail_args=(-n "$lines")
        [[ -n "$since_time" ]] && tail_args=()

        if $follow_mode; then
            tail -f "${tail_args[@]}" "$file" | while IFS= read -r line; do
                process_line "$line" "$fmt"
            done
        else
            tail "${tail_args[@]}" "$file" | while IFS= read -r line; do
                process_line "$line" "$fmt"
            done
        fi

        $show_stats && show_file_stats "$file"
    done
}

parse_arguments() {
    [[ $# -eq 0 ]] && { show_usage; exit 0; }

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -f|--follow)  follow_mode=true; shift ;;
            -n|--lines)
                [[ $# -lt 2 ]] && error_exit "--lines には値が必要です"
                lines="$2"; shift 2 ;;
            -g|--grep)
                [[ $# -lt 2 ]] && error_exit "--grep には値が必要です"
                filter_pattern="$2"; shift 2 ;;
            -e|--exclude)
                [[ $# -lt 2 ]] && error_exit "--exclude には値が必要です"
                exclude_pattern="$2"; shift 2 ;;
            -H|--highlight)
                [[ $# -lt 2 ]] && error_exit "--highlight には値が必要です"
                highlight_pattern="$2"; shift 2 ;;
            --format)
                [[ $# -lt 2 ]] && error_exit "--format には値が必要です"
                log_format="$2"; shift 2 ;;
            --stats)  show_stats=true; shift ;;
            --since)
                [[ $# -lt 2 ]] && error_exit "--since には値が必要です"
                since_time="$2"; shift 2 ;;
            -*)  error_exit "不明なオプション: $1" ;;
            *)   log_files+=("$1"); shift ;;
        esac
    done

    [[ ${#log_files[@]} -eq 0 ]] && log_files=("-")
}

main() {
    parse_arguments "$@"
    cmd_view
}

main "$@"
