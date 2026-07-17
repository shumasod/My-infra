#!/bin/bash
set -euo pipefail

#
# 環境変数チェッカー
# バージョン: 1.0
#
# 必須環境変数の存在確認・値検証・レポート生成ツール
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare config_file=""
declare mode="check"
declare -i fail_count=0
declare -i pass_count=0

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション]

環境変数の存在確認・検証ツール

オプション:
  -h, --help            このヘルプを表示
  -v, --version         バージョン情報を表示
  -f, --file FILE       設定ファイルを指定 (省略時は組み込みセットを使用)
  -m, --mode MODE       モード (check|list|export) [デフォルト: check]

モード:
  check   環境変数の検証 (デフォルト)
  list    現在の環境変数を一覧表示
  export  未設定変数の export スニペット生成

設定ファイル形式:
  # コメント
  VAR_NAME                    # 存在確認のみ
  VAR_NAME=default_value      # 未設定時のデフォルト値
  VAR_NAME~^[0-9]+\$          # 正規表現でバリデーション

例:
  $PROG_NAME
  $PROG_NAME -f .env.required
  $PROG_NAME -m list | grep AWS
  $PROG_NAME -m export > .env.template

EOF
}

declare -A VAR_DEFAULTS
declare -A VAR_PATTERNS
declare -a VAR_NAMES

load_builtin_vars() {
    VAR_NAMES=(
        HOME USER SHELL LANG PATH
        TERM EDITOR PAGER
    )
    VAR_DEFAULTS[EDITOR]="vi"
    VAR_DEFAULTS[PAGER]="less"
    VAR_PATTERNS[USER]="^[a-zA-Z0-9_-]+$"
}

load_config_file() {
    local file="$1"
    [[ ! -f "$file" ]] && error_exit "設定ファイルが見つかりません: $file"

    VAR_NAMES=()
    while IFS= read -r line; do
        [[ -z "$line" || "$line" == \#* ]] && continue
        if [[ "$line" == *~* ]]; then
            local name="${line%%~*}"
            local pattern="${line#*~}"
            VAR_NAMES+=("$name")
            VAR_PATTERNS["$name"]="$pattern"
        elif [[ "$line" == *=* ]]; then
            local name="${line%%=*}"
            local default="${line#*=}"
            VAR_NAMES+=("$name")
            VAR_DEFAULTS["$name"]="$default"
        else
            VAR_NAMES+=("$line")
        fi
    done < "$file"
}

check_var() {
    local name="$1"
    local value="${!name:-}"
    local has_default=false
    local default_val=""

    if [[ -v VAR_DEFAULTS[$name] ]]; then
        has_default=true
        default_val="${VAR_DEFAULTS[$name]}"
    fi

    if [[ -z "$value" ]]; then
        if [[ "$has_default" == true ]]; then
            printf "  ${C_YELLOW}DEFAULT${C_RESET}  %-30s = %s\n" "$name" "$default_val"
            (( pass_count++ )) || true
        else
            printf "  ${C_RED}MISSING${C_RESET}  %s\n" "$name"
            (( fail_count++ )) || true
        fi
        return
    fi

    if [[ -v VAR_PATTERNS[$name] ]]; then
        local pattern="${VAR_PATTERNS[$name]}"
        if ! [[ "$value" =~ $pattern ]]; then
            printf "  ${C_RED}INVALID${C_RESET}  %-30s = %s (パターン: %s)\n" "$name" "$value" "$pattern"
            (( fail_count++ )) || true
            return
        fi
    fi

    local display_val="$value"
    if [[ ${#value} -gt 40 ]]; then
        display_val="${value:0:37}..."
    fi
    printf "  ${C_GREEN}OK     ${C_RESET}  %-30s = %s\n" "$name" "$display_val"
    (( pass_count++ )) || true
}

do_check() {
    log_info "環境変数チェック"
    echo ""

    for name in "${VAR_NAMES[@]}"; do
        check_var "$name"
    done

    echo ""
    local total=$(( pass_count + fail_count ))
    echo "結果: ${pass_count}/${total} 項目OK"
    if [[ $fail_count -gt 0 ]]; then
        log_warning "${fail_count}個の問題が見つかりました"
        return 1
    else
        log_success "すべての環境変数が設定されています"
    fi
}

do_list() {
    log_info "現在の環境変数一覧"
    echo ""
    env | sort | while IFS='=' read -r name value; do
        printf "  %-35s = %s\n" "$name" "${value:0:60}"
    done
}

do_export() {
    echo "# 未設定/デフォルト値の環境変数テンプレート"
    echo "# 生成日時: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    for name in "${VAR_NAMES[@]}"; do
        local value="${!name:-}"
        if [[ -z "$value" ]]; then
            local default_val="${VAR_DEFAULTS[$name]:-}"
            echo "export ${name}=\"${default_val}\""
        fi
    done
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -f|--file)
                [[ $# -lt 2 ]] && error_exit "--file にはパスが必要です"
                config_file="$2"; shift 2 ;;
            -m|--mode)
                [[ $# -lt 2 ]] && error_exit "--mode には値が必要です"
                mode="$2"; shift 2 ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  error_exit "不明な引数: $1" ;;
        esac
    done
}

main() {
    parse_arguments "$@"

    if [[ -n "$config_file" ]]; then
        load_config_file "$config_file"
    else
        load_builtin_vars
    fi

    case "$mode" in
        check)  do_check ;;
        list)   do_list ;;
        export) do_export ;;
        *)      error_exit "不明なモード: $mode (check|list|export)" ;;
    esac
}

main "$@"
