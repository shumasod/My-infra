#!/bin/bash
set -euo pipefail

#
# カラー差分ビューワー
# バージョン: 1.0
#
# diff出力を色付きで表示するビューワーツール
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare file1=""
declare file2=""
declare context_lines=3
declare mode="unified"
declare ignore_whitespace=false
declare ignore_case=false
declare word_diff=false

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション] ファイル1 ファイル2
         $PROG_NAME [オプション] - (標準入力からdiff出力を読み込む)

カラー差分ビューワー

引数:
  ファイル1 ファイル2   比較するファイル
  -                     diff出力をパイプで受け取る

オプション:
  -h, --help            このヘルプを表示
  -v, --version         バージョン情報を表示
  -c, --context NUM     コンテキスト行数 [デフォルト: 3]
  -m, --mode MODE       差分形式 (unified|side-by-side) [デフォルト: unified]
  -w, --ignore-whitespace  空白の差分を無視
  -i, --ignore-case     大文字小文字を無視
  --word                単語単位で差分表示 (unified モード時)

例:
  $PROG_NAME file1.txt file2.txt
  $PROG_NAME -m side-by-side file1.conf file2.conf
  git diff | $PROG_NAME -
  diff -u old.py new.py | $PROG_NAME -

EOF
}

colorize_unified() {
    while IFS= read -r line; do
        case "${line:0:1}" in
            "+")
                if [[ "${line:0:3}" == "+++" ]]; then
                    echo -e "${C_BOLD}${line}${C_RESET}"
                else
                    echo -e "${C_GREEN}${line}${C_RESET}"
                fi
                ;;
            "-")
                if [[ "${line:0:3}" == "---" ]]; then
                    echo -e "${C_BOLD}${line}${C_RESET}"
                else
                    echo -e "${C_RED}${line}${C_RESET}"
                fi
                ;;
            "@")
                echo -e "${C_CYAN}${line}${C_RESET}"
                ;;
            "\\")
                echo -e "${C_DIM}${line}${C_RESET}"
                ;;
            *)
                echo "$line"
                ;;
        esac
    done
}

do_unified_diff() {
    local diff_args=(-u -U "$context_lines")
    [[ "$ignore_whitespace" == true ]] && diff_args+=(-b)
    [[ "$ignore_case"       == true ]] && diff_args+=(-i)
    [[ "$word_diff"         == true ]] && diff_args+=(--word-diff)

    local result=0
    diff "${diff_args[@]}" "$file1" "$file2" | colorize_unified || result=$?

    if [[ $result -eq 0 ]]; then
        log_success "差分なし"
    elif [[ $result -ge 2 ]]; then
        log_error "diff コマンドエラー"
        return 1
    fi
}

do_side_by_side() {
    local diff_args=(--side-by-side)
    [[ "$ignore_whitespace" == true ]] && diff_args+=(-b)
    [[ "$ignore_case"       == true ]] && diff_args+=(-i)

    local term_width
    term_width=$(tput cols 2>/dev/null || echo 160)
    local col_width=$(( (term_width - 3) / 2 ))
    diff_args+=(-W "$term_width")

    printf "${C_BOLD}%-${col_width}s   %s${C_RESET}\n" "$file1" "$file2"
    printf "%s\n" "$(printf '%.0s-' $(seq 1 "$term_width"))"

    diff "${diff_args[@]}" "$file1" "$file2" | while IFS= read -r line; do
        local mid="${line:$col_width:3}"
        case "$mid" in
            " | ") echo -e "${C_YELLOW}${line}${C_RESET}" ;;
            " < ") echo -e "${C_RED}${line}${C_RESET}" ;;
            " > ") echo -e "${C_GREEN}${line}${C_RESET}" ;;
            *)     echo "$line" ;;
        esac
    done || true
}

read_stdin() {
    local tmpfile
    tmpfile=$(mktemp)
    cat > "$tmpfile"
    colorize_unified < "$tmpfile"
    rm -f "$tmpfile"
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -c|--context)
                [[ $# -lt 2 ]] && error_exit "--context には数値が必要です"
                context_lines="$2"; shift 2 ;;
            -m|--mode)
                [[ $# -lt 2 ]] && error_exit "--mode には値が必要です"
                mode="$2"; shift 2 ;;
            -w|--ignore-whitespace) ignore_whitespace=true; shift ;;
            -i|--ignore-case)       ignore_case=true; shift ;;
            --word)                 word_diff=true; shift ;;
            -*) error_exit "不明なオプション: $1" ;;
            -)
                file1="-"; shift ;;
            *)
                if [[ -z "$file1" ]]; then
                    file1="$1"
                elif [[ -z "$file2" ]]; then
                    file2="$1"
                else
                    error_exit "引数が多すぎます"
                fi
                shift ;;
        esac
    done
}

main() {
    parse_arguments "$@"

    if [[ "$file1" == "-" || (-z "$file1" && ! -t 0) ]]; then
        read_stdin
        return
    fi

    [[ -z "$file1" ]] && error_exit "比較するファイルを2つ指定してください"
    [[ -z "$file2" ]] && error_exit "2番目のファイルを指定してください"
    [[ ! -f "$file1" ]] && error_exit "ファイルが見つかりません: $file1"
    [[ ! -f "$file2" ]] && error_exit "ファイルが見つかりません: $file2"

    case "$mode" in
        unified)      do_unified_diff ;;
        side-by-side) do_side_by_side ;;
        *)            error_exit "不明なモード: $mode (unified|side-by-side)" ;;
    esac
}

main "$@"
