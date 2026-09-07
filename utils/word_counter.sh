#!/bin/bash
set -euo pipefail

#
# 文書解析ツール (ワードカウンター)
# バージョン: 1.0
#
# テキストファイルの単語・文字・行数・頻出語を分析するツール
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare -a input_files=()
declare mode="summary"
declare -i top_n=10
declare lang="auto"
declare output_file=""
declare exclude_pattern=""

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション] ファイル [ファイル...]

テキスト文書解析ツール

引数:
  ファイル              解析するテキストファイル (複数可)

モード (-m):
  summary   サマリー統計 (デフォルト)
  words     頻出単語ランキング
  chars     文字種別集計
  lines     行統計 (長さ・空行等)
  compare   複数ファイル比較

オプション:
  -h, --help            このヘルプを表示
  -v, --version         バージョン情報を表示
  -m, --mode MODE       解析モード
  -n, --top NUM         上位N件表示 [デフォルト: 10]
  -l, --lang LANG       言語 (en|ja|auto) [デフォルト: auto]
  -e, --exclude PAT     除外パターン (正規表現)
  -o, --output FILE     出力ファイル

例:
  $PROG_NAME report.txt
  $PROG_NAME -m words -n 20 essay.txt
  $PROG_NAME -m compare file1.txt file2.txt
  $PROG_NAME -m lines README.md

EOF
}

do_summary() {
    local file="$1"
    log_info "文書サマリー: $file"
    echo ""

    local lines words chars bytes
    lines=$(wc -l < "$file")
    words=$(wc -w < "$file")
    chars=$(wc -m < "$file" 2>/dev/null || wc -c < "$file")
    bytes=$(wc -c < "$file")

    local empty_lines
    empty_lines=$(grep -c "^$" "$file" || true)
    local non_empty=$(( lines - empty_lines ))
    local paragraphs
    paragraphs=$(grep -c "^$" "$file" || true)

    # 平均行長
    local avg_len=0
    [[ $non_empty -gt 0 ]] && avg_len=$(( chars / non_empty ))

    # 読了時間推定 (200語/分)
    local read_min=$(( words / 200 ))
    local read_sec=$(( (words % 200) * 60 / 200 ))

    printf "  %-20s %d\n" "行数:" "$lines"
    printf "  %-20s %d\n" "  (空行):" "$empty_lines"
    printf "  %-20s %d\n" "  (非空行):" "$non_empty"
    printf "  %-20s %d\n" "単語数:" "$words"
    printf "  %-20s %d\n" "文字数:" "$chars"
    printf "  %-20s %d bytes\n" "ファイルサイズ:" "$bytes"
    printf "  %-20s %d 文字\n" "平均行長:" "$avg_len"
    printf "  %-20s 約 %d分%d秒\n" "推定読了時間:" "$read_min" "$read_sec"
    echo ""
}

do_words() {
    local file="$1"
    log_info "頻出単語 Top${top_n}: $file"
    echo ""
    printf "  %-5s %-30s %s\n" "順位" "単語" "出現回数"
    printf "  %s\n" "$(printf '%.0s-' {1..45})"

    local rank=1
    # 英数字の単語を抽出・正規化
    local filter_cmd="cat"
    [[ -n "$exclude_pattern" ]] && filter_cmd="grep -v -E '$exclude_pattern'"

    eval "$filter_cmd '$file'" | \
    tr -cs '[:alpha:]' '\n' | \
    tr '[:upper:]' '[:lower:]' | \
    grep -v '^.$' | \
    grep -v '^[0-9]*$' | \
    sort | uniq -c | sort -rn | head -"$top_n" | \
    while read -r count word; do
        local bar_len=$(( count > 20 ? 20 : count ))
        local bar
        bar=$(printf '█%.0s' $(seq 1 $bar_len 2>/dev/null || true))
        printf "  %-5d %-30s %5d %s\n" "$rank" "$word" "$count" "$bar"
        (( rank++ )) || true
    done
    echo ""
}

do_chars() {
    local file="$1"
    log_info "文字種別統計: $file"
    echo ""

    local total_chars
    total_chars=$(wc -c < "$file")

    local alpha digits spaces punct
    alpha=$(tr -cd '[:alpha:]' < "$file" | wc -c)
    digits=$(tr -cd '[:digit:]' < "$file" | wc -c)
    spaces=$(tr -cd '[:space:]' < "$file" | wc -c)
    punct=$(tr -cd '[:punct:]' < "$file" | wc -c)

    local show_pct() {
        local count="$1"
        local total="$2"
        (( total > 0 )) && echo $(( count * 100 / total )) || echo 0
    }

    printf "  %-15s %8d  (%d%%)\n" "アルファベット:" "$alpha" "$(show_pct $alpha $total_chars)"
    printf "  %-15s %8d  (%d%%)\n" "数字:" "$digits" "$(show_pct $digits $total_chars)"
    printf "  %-15s %8d  (%d%%)\n" "空白・改行:" "$spaces" "$(show_pct $spaces $total_chars)"
    printf "  %-15s %8d  (%d%%)\n" "記号:" "$punct" "$(show_pct $punct $total_chars)"
    printf "  %-15s %8d\n" "合計 (bytes):" "$total_chars"
    echo ""
}

do_lines() {
    local file="$1"
    log_info "行統計: $file"
    echo ""

    local max_len=0 min_len=99999 sum_len=0 count=0 empty_count=0

    while IFS= read -r line; do
        local len=${#line}
        if [[ $len -eq 0 ]]; then
            (( empty_count++ )) || true
            continue
        fi
        (( count++ )) || true
        (( sum_len += len )) || true
        (( len > max_len )) && max_len=$len
        (( len < min_len )) && min_len=$len
    done < "$file"

    local avg_len=0
    [[ $count -gt 0 ]] && avg_len=$(( sum_len / count ))
    [[ $count -eq 0 ]] && min_len=0

    printf "  %-20s %d\n" "最長行:" "$max_len"
    printf "  %-20s %d\n" "最短行:" "$min_len"
    printf "  %-20s %d\n" "平均行長:" "$avg_len"
    printf "  %-20s %d\n" "非空行数:" "$count"
    printf "  %-20s %d\n" "空行数:" "$empty_count"
    echo ""

    # 行長分布
    log_info "行長分布:"
    local -A dist
    while IFS= read -r line; do
        local len=${#line}
        local bucket=$(( len / 20 * 20 ))
        dist[$bucket]=$(( ${dist[$bucket]:-0} + 1 ))
    done < "$file"

    for bucket in $(echo "${!dist[@]}" | tr ' ' '\n' | sort -n); do
        local cnt="${dist[$bucket]}"
        local next=$(( bucket + 19 ))
        local bar
        bar=$(printf '█%.0s' $(seq 1 $(( cnt > 30 ? 30 : cnt )) 2>/dev/null || true))
        printf "  %3d-%3d文字: %4d %s\n" "$bucket" "$next" "$cnt" "$bar"
    done
    echo ""
}

do_compare() {
    log_info "ファイル比較"
    echo ""
    printf "  %-30s %8s %8s %8s\n" "ファイル" "行数" "単語数" "文字数"
    printf "  %s\n" "$(printf '%.0s-' {1..58})"

    for file in "${input_files[@]}"; do
        [[ ! -f "$file" ]] && continue
        local lines words chars
        lines=$(wc -l < "$file")
        words=$(wc -w < "$file")
        chars=$(wc -m < "$file" 2>/dev/null || wc -c < "$file")
        printf "  %-30s %8d %8d %8d\n" "$(basename "$file")" "$lines" "$words" "$chars"
    done
    echo ""
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -m|--mode)    [[ $# -lt 2 ]] && error_exit "--mode には値が必要です"; mode="$2"; shift 2 ;;
            -n|--top)     [[ $# -lt 2 ]] && error_exit "--top には数値が必要です"; top_n="$2"; shift 2 ;;
            -l|--lang)    [[ $# -lt 2 ]] && error_exit "--lang には値が必要です"; lang="$2"; shift 2 ;;
            -e|--exclude) [[ $# -lt 2 ]] && error_exit "--exclude には値が必要です"; exclude_pattern="$2"; shift 2 ;;
            -o|--output)  [[ $# -lt 2 ]] && error_exit "--output には値が必要です"; output_file="$2"; shift 2 ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  input_files+=("$1"); shift ;;
        esac
    done
}

main() {
    parse_arguments "$@"
    [[ ${#input_files[@]} -eq 0 ]] && error_exit "ファイルを指定してください"

    local output
    output=$(
        if [[ "$mode" == "compare" ]]; then
            do_compare
        else
            for file in "${input_files[@]}"; do
                [[ ! -f "$file" ]] && { log_warning "見つかりません: $file"; continue; }
                case "$mode" in
                    summary) do_summary "$file" ;;
                    words)   do_words "$file" ;;
                    chars)   do_chars "$file" ;;
                    lines)   do_lines "$file" ;;
                    *)       error_exit "不明なモード: $mode" ;;
                esac
            done
        fi
    )

    if [[ -n "$output_file" ]]; then
        echo "$output" | sed 's/\x1b\[[0-9;]*m//g' > "$output_file"
        log_success "保存: $output_file"
    fi
    echo "$output"
}

main "$@"
