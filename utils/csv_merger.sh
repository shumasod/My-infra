#!/bin/bash
set -euo pipefail

#
# CSV結合・変換ツール
# 作成日: 2026-07-30
# バージョン: 1.0
#
# 複数のCSVファイルを結合・変換・フィルタリングします
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare command_name="merge"
declare -a input_files=()
declare output_file=""
declare delimiter=","
declare no_header=false
declare filter_col=""
declare filter_val=""
declare select_cols=""
declare sort_col=""
declare sort_reverse=false

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME <コマンド> [オプション] <ファイル...>

CSVファイルの結合・変換・フィルタリングツールです。

コマンド:
  merge <ファイル...>    複数CSVを縦方向に結合
  join <ファイル1> <ファイル2>  2つのCSVを横方向に結合
  filter <ファイル>      条件でフィルタリング
  select <ファイル>      列を選択
  stats <ファイル>       統計情報を表示
  convert <ファイル>     区切り文字を変換

オプション:
  -h, --help             このヘルプを表示
  -v, --version          バージョン情報を表示
  -o, --output <ファイル> 出力ファイル (省略時は標準出力)
  -d, --delimiter <文字> 区切り文字 [デフォルト: ,]
  --no-header            ヘッダー行なし
  --filter-col <列番号>  フィルタ対象列 (1始まり)
  --filter-val <値>      フィルタ値
  --select <列番号,...>  選択する列 (例: 1,3,5)
  --sort-col <列番号>    ソート対象列
  --sort-reverse         逆順ソート

例:
  $PROG_NAME merge a.csv b.csv c.csv -o merged.csv
  $PROG_NAME filter data.csv --filter-col 2 --filter-val "東京"
  $PROG_NAME select data.csv --select 1,3,5
  $PROG_NAME stats data.csv
EOF
}

output_result() {
    if [[ -n "$output_file" ]]; then
        cat > "$output_file"
        log_success "結果を保存しました: $output_file"
    else
        cat
    fi
}

cmd_merge() {
    [[ ${#input_files[@]} -lt 2 ]] && error_exit "2つ以上のファイルを指定してください"

    local first=true
    for f in "${input_files[@]}"; do
        [[ ! -f "$f" ]] && error_exit "ファイルが見つかりません: $f"
        if $first; then
            cat "$f"
            first=false
        else
            if $no_header; then
                cat "$f"
            else
                tail -n +2 "$f"
            fi
        fi
    done | output_result
    log_info "結合完了: ${#input_files[@]}ファイル"
}

cmd_join() {
    [[ ${#input_files[@]} -lt 2 ]] && error_exit "2つのファイルを指定してください"
    local f1="${input_files[0]}"
    local f2="${input_files[1]}"
    [[ ! -f "$f1" ]] && error_exit "ファイルが見つかりません: $f1"
    [[ ! -f "$f2" ]] && error_exit "ファイルが見つかりません: $f2"

    paste -d"$delimiter" "$f1" "$f2" | output_result
}

cmd_filter() {
    [[ ${#input_files[@]} -lt 1 ]] && error_exit "ファイルを指定してください"
    [[ -z "$filter_col" || -z "$filter_val" ]] && error_exit "--filter-col と --filter-val を指定してください"
    local f="${input_files[0]}"
    [[ ! -f "$f" ]] && error_exit "ファイルが見つかりません: $f"

    awk -F"$delimiter" -v col="$filter_col" -v val="$filter_val" -v no_hdr="$no_header" '
        NR==1 && no_hdr=="false" { print; next }
        $col ~ val { print }
    ' "$f" | output_result
}

cmd_select() {
    [[ ${#input_files[@]} -lt 1 ]] && error_exit "ファイルを指定してください"
    [[ -z "$select_cols" ]] && error_exit "--select で列番号を指定してください"
    local f="${input_files[0]}"
    [[ ! -f "$f" ]] && error_exit "ファイルが見つかりません: $f"

    local awk_cols
    awk_cols=$(echo "$select_cols" | tr ',' ' ' | awk '{for(i=1;i<=NF;i++) printf "$%s%s",$i,(i<NF?OFS:"\n")}')

    awk -F"$delimiter" -v OFS="$delimiter" "{print $awk_cols}" "$f" | output_result
}

cmd_stats() {
    [[ ${#input_files[@]} -lt 1 ]] && error_exit "ファイルを指定してください"
    local f="${input_files[0]}"
    [[ ! -f "$f" ]] && error_exit "ファイルが見つかりません: $f"

    log_info "CSVファイルを解析中: $f"
    echo ""

    local total_rows col_count
    total_rows=$(wc -l < "$f")
    col_count=$(head -1 "$f" | awk -F"$delimiter" '{print NF}')

    printf "  ${C_BOLD}ファイル${C_RESET}   : %s\n" "$f"
    printf "  ${C_BOLD}総行数${C_RESET}     : ${C_GREEN}%d${C_RESET} (ヘッダー含む)\n" "$total_rows"
    printf "  ${C_BOLD}列数${C_RESET}       : ${C_CYAN}%d${C_RESET}\n" "$col_count"
    echo ""

    if ! $no_header; then
        printf "${C_BOLD}【列情報】${C_RESET}\n"
        head -1 "$f" | awk -F"$delimiter" '{
            for(i=1;i<=NF;i++) printf "  %2d: %s\n", i, $i
        }'
        echo ""
    fi

    printf "${C_BOLD}【列ごとの統計 (数値列)】${C_RESET}\n"
    local data_rows=$(( total_rows - ($no_header && true || false ? 0 : 1) ))
    printf "  データ行数: %d\n" "$data_rows"

    # 各列の空値数をカウント
    printf "\n${C_BOLD}%-5s %-20s %8s %8s${C_RESET}\n" "列" "ヘッダー" "空値数" "空値率"
    printf "%s\n" "$(printf '%.0s─' {1..45})"
    awk -F"$delimiter" -v no_hdr="$no_header" '
        NR==1 && no_hdr=="false" {
            for(i=1;i<=NF;i++) header[i]=$i
            cols=NF; next
        }
        {
            if(cols==0) cols=NF
            for(i=1;i<=NF;i++) {
                total[i]++
                if($i=="") empty[i]++
            }
        }
        END {
            for(i=1;i<=cols;i++) {
                pct = total[i]>0 ? empty[i]*100/total[i] : 0
                printf "  %3d  %-20s %8d %7.1f%%\n", i, substr(header[i],1,20), empty[i]+0, pct
            }
        }
    ' "$f"
    echo ""
}

cmd_convert() {
    [[ ${#input_files[@]} -lt 1 ]] && error_exit "ファイルを指定してください"
    local f="${input_files[0]}"
    [[ ! -f "$f" ]] && error_exit "ファイルが見つかりません: $f"

    local new_delim="${2:-\t}"
    sed "s/$delimiter/$new_delim/g" "$f" | output_result
}

parse_arguments() {
    [[ $# -eq 0 ]] && { show_usage; exit 0; }

    case "$1" in
        merge|join|filter|select|stats|convert)
            command_name="$1"
            shift
            ;;
    esac

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -o|--output)
                [[ $# -lt 2 ]] && error_exit "--output には値が必要です"
                output_file="$2"; shift 2 ;;
            -d|--delimiter)
                [[ $# -lt 2 ]] && error_exit "--delimiter には値が必要です"
                delimiter="$2"; shift 2 ;;
            --no-header)   no_header=true; shift ;;
            --filter-col)
                [[ $# -lt 2 ]] && error_exit "--filter-col には値が必要です"
                filter_col="$2"; shift 2 ;;
            --filter-val)
                [[ $# -lt 2 ]] && error_exit "--filter-val には値が必要です"
                filter_val="$2"; shift 2 ;;
            --select)
                [[ $# -lt 2 ]] && error_exit "--select には値が必要です"
                select_cols="$2"; shift 2 ;;
            --sort-col)
                [[ $# -lt 2 ]] && error_exit "--sort-col には値が必要です"
                sort_col="$2"; shift 2 ;;
            --sort-reverse) sort_reverse=true; shift ;;
            -*)  error_exit "不明なオプション: $1" ;;
            *)   input_files+=("$1"); shift ;;
        esac
    done
}

main() {
    parse_arguments "$@"
    case "$command_name" in
        merge)   cmd_merge ;;
        join)    cmd_join ;;
        filter)  cmd_filter ;;
        select)  cmd_select ;;
        stats)   cmd_stats ;;
        convert) cmd_convert ;;
        *)       error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
