#!/bin/bash
set -euo pipefail

#
# CSVプロセッサー
# バージョン: 1.0
#
# CSVファイルの表示・フィルター・集計・変換を行うツール
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare input_file=""
declare output_file=""
declare mode="view"
declare delimiter=","
declare -i col_num=0
declare filter_col=""
declare filter_val=""
declare sort_col=""
declare sort_order="asc"
declare no_header=false

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション] <CSVファイル>

CSVファイル処理ツール

引数:
  CSVファイル           処理するCSVファイル

モード (-m):
  view      整形表示 (デフォルト)
  stats     統計情報 (行数・列数・列ごとの値)
  filter    フィルター (-F COL -V VALUE)
  sort      ソート (-k COL)
  count     値の集計 (-k COL)
  cut       列抽出 (-k COL1,COL2,...)

オプション:
  -h, --help            このヘルプを表示
  -v, --version         バージョン情報を表示
  -m, --mode MODE       実行モード
  -d, --delimiter CHAR  区切り文字 [デフォルト: ,]
  -k, --col COL         対象列番号 (1始まり)
  -F, --filter-col COL  フィルター列番号
  -V, --filter-val VAL  フィルター値
  -s, --sort COL        ソート列番号
  --desc                降順ソート
  --no-header           ヘッダー行なし
  -o, --output FILE     出力ファイル

例:
  $PROG_NAME data.csv
  $PROG_NAME -m stats data.csv
  $PROG_NAME -m filter -F 2 -V "東京" data.csv
  $PROG_NAME -m sort -s 3 --desc data.csv
  $PROG_NAME -m count -k 2 data.csv

EOF
}

read_csv() {
    local file="$1"
    local sep="$2"
    awk -F"$sep" '{
        for (i=1; i<=NF; i++) {
            gsub(/^[ \t]+|[ \t]+$/, "", $i)
            printf "%s", $i
            if (i < NF) printf "\t"
        }
        print ""
    }' "$file"
}

do_view() {
    log_info "CSV表示: $input_file"
    echo ""

    local data
    data=$(read_csv "$input_file" "$delimiter")

    local -i col_count
    col_count=$(echo "$data" | head -1 | awk -F'\t' '{print NF}')

    local -a widths=()
    for (( i=0; i<col_count; i++ )); do
        widths[$i]=0
    done

    while IFS=$'\t' read -ra fields; do
        for (( i=0; i<${#fields[@]}; i++ )); do
            local len=${#fields[$i]}
            if (( len > widths[$i] )); then
                widths[$i]=$len
            fi
        done
    done <<< "$data"

    local is_header=true
    while IFS=$'\t' read -ra fields; do
        printf "  "
        for (( i=0; i<${#fields[@]}; i++ )); do
            local w=$(( widths[$i] + 2 ))
            if [[ "$is_header" == true ]]; then
                printf "${C_CYAN}%-${w}s${C_RESET}" "${fields[$i]}"
            else
                printf "%-${w}s" "${fields[$i]}"
            fi
        done
        echo ""
        if [[ "$is_header" == true && "$no_header" == false ]]; then
            printf "  "
            for (( i=0; i<col_count; i++ )); do
                printf "%s" "$(printf '%.0s-' $(seq 1 $(( widths[$i] + 2 ))))"
            done
            echo ""
            is_header=false
        fi
    done <<< "$data"

    echo ""
    local row_count
    row_count=$(echo "$data" | wc -l)
    [[ "$no_header" == false ]] && (( row_count-- )) || true
    printf "  %d行 × %d列\n\n" "$row_count" "$col_count"
}

do_stats() {
    log_info "CSV統計: $input_file"
    echo ""

    local data
    data=$(read_csv "$input_file" "$delimiter")
    local row_count
    row_count=$(echo "$data" | wc -l)
    local col_count
    col_count=$(echo "$data" | head -1 | awk -F'\t' '{print NF}')

    [[ "$no_header" == false ]] && (( row_count-- )) || true
    printf "  行数: %d  列数: %d\n\n" "$row_count" "$col_count"

    if [[ "$no_header" == false ]]; then
        local header
        header=$(echo "$data" | head -1)
        local -a headers=()
        IFS=$'\t' read -ra headers <<< "$header"

        for (( i=0; i<col_count; i++ )); do
            local col_data
            col_data=$(echo "$data" | tail -n +2 | awk -F'\t' -v col="$((i+1))" '{print $col}')
            local unique_count
            unique_count=$(echo "$col_data" | sort -u | wc -l)
            local empty_count
            empty_count=$(echo "$col_data" | grep -c "^$" || true)

            printf "  ${C_CYAN}列%d: %s${C_RESET}\n" "$((i+1))" "${headers[$i]:-}"
            printf "    ユニーク値: %d  空白: %d\n" "$unique_count" "$empty_count"
        done
    fi
    echo ""
}

do_filter() {
    [[ -z "$filter_col" || -z "$filter_val" ]] && \
        error_exit "フィルターには -F (列番号) と -V (値) が必要です"

    local data
    data=$(read_csv "$input_file" "$delimiter")

    local result=""
    local first=true
    while IFS= read -r line; do
        if [[ "$first" == true && "$no_header" == false ]]; then
            result+="$line"$'\n'
            first=false
            continue
        fi
        first=false
        local field
        field=$(echo "$line" | awk -F'\t' -v col="$filter_col" '{print $col}')
        if [[ "$field" == *"$filter_val"* ]]; then
            result+="$line"$'\n'
        fi
    done <<< "$data"

    if [[ -n "$output_file" ]]; then
        echo "$result" | awk -F'\t' 'BEGIN{OFS=","} {$1=$1; print}' > "$output_file"
        log_success "保存: $output_file"
    else
        echo "$result" | column -t -s $'\t'
    fi
}

do_count() {
    [[ -z "$sort_col" ]] && error_exit "集計列を -s で指定してください"

    local data
    data=$(read_csv "$input_file" "$delimiter")

    log_info "列${sort_col}の値集計"
    echo ""
    printf "  %-30s %s\n" "値" "件数"
    printf "  %s\n" "$(printf '%.0s-' {1..40})"

    echo "$data" | tail -n +2 | \
    awk -F'\t' -v col="$sort_col" '{print $col}' | \
    sort | uniq -c | sort -rn | \
    while read -r count val; do
        printf "  %-30s %d\n" "$val" "$count"
    done
    echo ""
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -m|--mode)    [[ $# -lt 2 ]] && error_exit "--mode には値が必要です"; mode="$2"; shift 2 ;;
            -d|--delimiter) [[ $# -lt 2 ]] && error_exit "--delimiter には値が必要です"; delimiter="$2"; shift 2 ;;
            -k|--col)     [[ $# -lt 2 ]] && error_exit "--col には数値が必要です"; col_num="$2"; shift 2 ;;
            -F|--filter-col) [[ $# -lt 2 ]] && error_exit "--filter-col には値が必要です"; filter_col="$2"; shift 2 ;;
            -V|--filter-val) [[ $# -lt 2 ]] && error_exit "--filter-val には値が必要です"; filter_val="$2"; shift 2 ;;
            -s|--sort)    [[ $# -lt 2 ]] && error_exit "--sort には列番号が必要です"; sort_col="$2"; shift 2 ;;
            --desc)       sort_order="desc"; shift ;;
            --no-header)  no_header=true; shift ;;
            -o|--output)  [[ $# -lt 2 ]] && error_exit "--output には値が必要です"; output_file="$2"; shift 2 ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  input_file="$1"; shift ;;
        esac
    done
}

main() {
    parse_arguments "$@"
    [[ -z "$input_file" ]] && error_exit "CSVファイルを指定してください"
    [[ ! -f "$input_file" ]] && error_exit "ファイルが見つかりません: $input_file"

    case "$mode" in
        view)   do_view ;;
        stats)  do_stats ;;
        filter) do_filter ;;
        count)  do_count ;;
        *)      error_exit "不明なモード: $mode" ;;
    esac
}

main "$@"
