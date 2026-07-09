#!/bin/bash
set -euo pipefail

#
# ログ解析ツール
# 作成日: 2026-07-04
# バージョン: 1.0
#
# アプリケーションログを解析してエラー統計・トレンドを表示する
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション] <ログファイル>

ログファイルを解析してエラー統計を表示します。

引数:
  <ログファイル>  解析対象のログファイル（- で標準入力）

オプション:
  -h, --help          このヘルプを表示
  -v, --version       バージョン情報を表示
  -l, --level LEVEL   フィルタするログレベル (ERROR/WARN/INFO)
  -n, --top N         上位 N 件のエラーを表示（デフォルト: 10）
  -f, --format FMT    ログフォーマット (auto/apache/nginx/syslog/json)
  -o, --output FILE   レポートをファイルに保存
  --since TIME        指定時刻以降のログを解析 (YYYY-MM-DD)
  --errors-only       ERROR レベルのみ表示

例:
  $PROG_NAME /var/log/app.log
  $PROG_NAME -l ERROR -n 20 /var/log/syslog
  $PROG_NAME --since 2026-07-01 -o report.txt /var/log/app.log
EOF
}

detect_format() {
    local sample="$1"
    if echo "$sample" | grep -qE '^\{.*"level"'; then
        echo "json"
    elif echo "$sample" | grep -qE '^[0-9]{1,3}\.[0-9]{1,3}'; then
        echo "apache"
    elif echo "$sample" | grep -qE '^[A-Za-z]{3}\s+[0-9]'; then
        echo "syslog"
    else
        echo "generic"
    fi
}

extract_level() {
    local line="$1"
    local format="$2"
    if echo "$line" | grep -qiE '\b(ERROR|FATAL|CRITICAL)\b'; then
        echo "ERROR"
    elif echo "$line" | grep -qiE '\b(WARN|WARNING)\b'; then
        echo "WARN"
    elif echo "$line" | grep -qiE '\bINFO\b'; then
        echo "INFO"
    elif echo "$line" | grep -qiE '\bDEBUG\b'; then
        echo "DEBUG"
    else
        echo "OTHER"
    fi
}

analyze_log() {
    local log_file="$1"
    local filter_level="$2"
    local top_n="$3"
    local output_file="$4"
    local since_date="$5"

    local -i total=0 errors=0 warns=0 infos=0 others=0

    local sample
    sample=$(head -5 "$log_file" 2>/dev/null || true)
    local format
    format=$(detect_format "$sample")

    print_center "ログ解析レポート" 0 "${C_BOLD}${C_CYAN}"
    print_center "$(get_timestamp)" 0 "$C_DIM"
    echo ""
    echo -e "  ${C_BOLD}ファイル:${C_RESET} ${log_file}"
    echo -e "  ${C_BOLD}形式:${C_RESET}     ${format}"
    echo ""

    local tmp_errors
    tmp_errors=$(mktemp)
    trap 'rm -f "$tmp_errors"' RETURN

    while IFS= read -r line; do
        [ -z "$line" ] && continue

        if [ -n "$since_date" ]; then
            echo "$line" | grep -q "$since_date" || continue
        fi

        total=$(( total + 1 ))
        local level
        level=$(extract_level "$line" "$format")

        case "$level" in
            ERROR) errors=$(( errors + 1 ))
                   echo "$line" >> "$tmp_errors" ;;
            WARN)  warns=$(( warns + 1 )) ;;
            INFO)  infos=$(( infos + 1 )) ;;
            *)     others=$(( others + 1 )) ;;
        esac
    done < "$log_file"

    echo -e "  ${C_BOLD}=== ログレベル統計 ===${C_RESET}"
    echo ""

    local total_nonzero=$(( total > 0 ? total : 1 ))

    local e_bar w_bar i_bar
    e_bar=$(draw_progress_bar "$errors" "$total_nonzero" 25)
    w_bar=$(draw_progress_bar "$warns"  "$total_nonzero" 25)
    i_bar=$(draw_progress_bar "$infos"  "$total_nonzero" 25)

    printf "  ${C_RED}ERROR${C_RESET}  %s ${C_RED}%d${C_RESET} (%.1f%%)\n" \
        "$e_bar" "$errors" "$(awk "BEGIN{printf \"%.1f\", $errors/$total_nonzero*100}")"
    printf "  ${C_YELLOW}WARN${C_RESET}   %s ${C_YELLOW}%d${C_RESET} (%.1f%%)\n" \
        "$w_bar" "$warns"  "$(awk "BEGIN{printf \"%.1f\", $warns/$total_nonzero*100}")"
    printf "  ${C_GREEN}INFO${C_RESET}   %s ${C_GREEN}%d${C_RESET} (%.1f%%)\n" \
        "$i_bar" "$infos"  "$(awk "BEGIN{printf \"%.1f\", $infos/$total_nonzero*100}")"
    printf "  ${C_DIM}OTHER${C_RESET}  %s ${C_DIM}%d${C_RESET}\n" \
        "$(draw_progress_bar "$others" "$total_nonzero" 25)" "$others"
    echo ""
    printf "  ${C_BOLD}合計:${C_RESET} %d行\n" "$total"
    echo ""

    if [ "$errors" -gt 0 ] && [ -s "$tmp_errors" ]; then
        echo -e "  ${C_BOLD}=== 頻出エラー TOP ${top_n} ===${C_RESET}"
        echo ""
        sort "$tmp_errors" | uniq -c | sort -rn | head -n "$top_n" | \
        while IFS= read -r eline; do
            local cnt msg
            cnt=$(echo "$eline" | awk '{print $1}')
            msg=$(echo "$eline" | cut -c$((${#cnt}+2))-)
            printf "  ${C_RED}%4d回${C_RESET}  %s\n" "$cnt" "${msg:0:80}"
        done
        echo ""
    fi

    if [ -n "$output_file" ]; then
        {
            echo "# ログ解析レポート"
            echo "# 生成日時: $(get_timestamp)"
            echo "# ファイル: ${log_file}"
            echo "# 合計行数: ${total}"
            echo "# ERROR: ${errors}  WARN: ${warns}  INFO: ${infos}"
        } > "$output_file"
        log_success "レポートを保存しました: $output_file"
    fi

    if [ "$errors" -gt 0 ]; then
        local err_rate
        err_rate=$(awk "BEGIN{printf \"%.1f\", $errors/$total_nonzero*100}")
        if awk "BEGIN{exit ($err_rate < 10)}"; then
            log_error "エラー率が高い状態です: ${err_rate}%"
        elif awk "BEGIN{exit ($err_rate < 5)}"; then
            log_warning "エラー率に注意: ${err_rate}%"
        else
            log_success "エラー率は正常範囲内です: ${err_rate}%"
        fi
    fi
}

main() {
    local log_file=""
    local filter_level=""
    local top_n=10
    local output_file=""
    local since_date=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -l|--level)
                [[ $# -lt 2 ]] && error_exit "--level には ERROR/WARN/INFO が必要です"
                filter_level="${2^^}"; shift 2 ;;
            -n|--top)
                [[ $# -lt 2 ]] && error_exit "--top には数値が必要です"
                top_n="$2"; shift 2 ;;
            -o|--output)
                [[ $# -lt 2 ]] && error_exit "--output にはファイル名が必要です"
                output_file="$2"; shift 2 ;;
            --since)
                [[ $# -lt 2 ]] && error_exit "--since には日付が必要です"
                since_date="$2"; shift 2 ;;
            --errors-only) filter_level="ERROR"; shift ;;
            -*)
                error_exit "不明なオプション: $1" ;;
            *)
                log_file="$1"; shift ;;
        esac
    done

    [ -z "$log_file" ] && error_exit "ログファイルを指定してください"
    [ ! -f "$log_file" ] && error_exit "ファイルが見つかりません: $log_file"

    echo ""
    analyze_log "$log_file" "$filter_level" "$top_n" "$output_file" "$since_date"
}

main "$@"
