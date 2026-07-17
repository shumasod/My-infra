#!/bin/bash
set -euo pipefail

#
# JSONフォーマッター & バリデーター
# バージョン: 1.0
#
# JSONの整形、バリデーション、フィールド抽出ツール
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare input_file=""
declare output_file=""
declare query=""
declare mode="format"
declare indent=2

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション] [ファイル]

JSONの整形・検証・クエリ実行ツール

引数:
  [ファイル]            処理するJSONファイル (省略時は標準入力)

オプション:
  -h, --help            このヘルプを表示
  -v, --version         バージョン情報を表示
  -m, --mode MODE       実行モード (format|validate|query|minify) [デフォルト: format]
  -q, --query QUERY     jqクエリ式 (modeがqueryの場合)
  -i, --indent NUM      インデント幅 [デフォルト: 2]
  -o, --output FILE     出力ファイル (省略時は標準出力)

モード:
  format    JSON整形 (デフォルト)
  validate  JSON検証のみ
  query     jqクエリ実行
  minify    JSON圧縮

例:
  $PROG_NAME data.json
  $PROG_NAME -m validate data.json
  $PROG_NAME -m query -q '.users[].name' data.json
  echo '{"a":1}' | $PROG_NAME
  $PROG_NAME -m minify data.json -o output.json

EOF
}

check_jq() {
    if ! command -v jq &>/dev/null; then
        error_exit "jqコマンドが必要です。インストールしてください: apt install jq"
    fi
}

get_input() {
    if [[ -n "$input_file" ]]; then
        [[ ! -f "$input_file" ]] && error_exit "ファイルが見つかりません: $input_file"
        cat "$input_file"
    else
        cat
    fi
}

do_format() {
    local json
    json=$(get_input)
    local result
    if ! result=$(echo "$json" | jq --indent "$indent" . 2>&1); then
        log_error "JSON解析エラー: $result"
        exit 1
    fi
    if [[ -n "$output_file" ]]; then
        echo "$result" > "$output_file"
        log_success "整形完了: $output_file"
    else
        echo "$result"
    fi
}

do_validate() {
    local json
    json=$(get_input)
    local src="${input_file:-標準入力}"
    if echo "$json" | jq . >/dev/null 2>&1; then
        log_success "有効なJSON: $src"
        local keys
        keys=$(echo "$json" | jq 'if type == "object" then keys | length else (if type == "array" then length else 0 end) end' 2>/dev/null || echo "0")
        local type
        type=$(echo "$json" | jq -r type 2>/dev/null || echo "unknown")
        echo "  型: $type"
        echo "  要素数: $keys"
    else
        log_error "無効なJSON: $src"
        echo "$json" | jq . 2>&1 | head -5
        exit 1
    fi
}

do_query() {
    [[ -z "$query" ]] && error_exit "-q オプションでクエリを指定してください"
    local json
    json=$(get_input)
    local result
    if ! result=$(echo "$json" | jq -r "$query" 2>&1); then
        log_error "クエリエラー: $result"
        exit 1
    fi
    if [[ -n "$output_file" ]]; then
        echo "$result" > "$output_file"
        log_success "クエリ結果を保存: $output_file"
    else
        echo "$result"
    fi
}

do_minify() {
    local json
    json=$(get_input)
    local result
    if ! result=$(echo "$json" | jq -c . 2>&1); then
        log_error "JSON解析エラー: $result"
        exit 1
    fi
    if [[ -n "$output_file" ]]; then
        echo "$result" > "$output_file"
        log_success "圧縮完了: $output_file"
    else
        echo "$result"
    fi
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -m|--mode)
                [[ $# -lt 2 ]] && error_exit "--mode には値が必要です"
                mode="$2"; shift 2 ;;
            -q|--query)
                [[ $# -lt 2 ]] && error_exit "--query には値が必要です"
                query="$2"; shift 2 ;;
            -i|--indent)
                [[ $# -lt 2 ]] && error_exit "--indent には値が必要です"
                if ! [[ "$2" =~ ^[0-9]+$ ]]; then
                    error_exit "インデントは数値で指定してください"
                fi
                indent="$2"; shift 2 ;;
            -o|--output)
                [[ $# -lt 2 ]] && error_exit "--output には値が必要です"
                output_file="$2"; shift 2 ;;
            -*)  error_exit "不明なオプション: $1" ;;
            *)   input_file="$1"; shift ;;
        esac
    done
}

main() {
    parse_arguments "$@"
    check_jq

    case "$mode" in
        format)   do_format ;;
        validate) do_validate ;;
        query)    do_query ;;
        minify)   do_minify ;;
        *)        error_exit "不明なモード: $mode (format|validate|query|minify)" ;;
    esac
}

main "$@"
