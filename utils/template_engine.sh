#!/bin/bash
set -euo pipefail

#
# テンプレートエンジン
# バージョン: 1.0
#
# テキストテンプレートへの変数置換・条件分岐・繰り返しを行うツール
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare template_file=""
declare vars_file=""
declare output_file=""
declare -A template_vars=()
declare mode="render"
declare strict_mode=false
declare -i list_vars=0

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション] テンプレートファイル

テンプレートエンジン

引数:
  テンプレートファイル    処理するテンプレートファイル

テンプレート構文:
  \${{VAR}}             変数置換
  \${{VAR:-default}}   デフォルト値付き変数置換
  \${{#if VAR}}...     条件ブロック (変数が空でなければ表示)
  \${{/if}}            条件ブロック終了
  \${{#each ITEMS}}... 繰り返しブロック (\${{ITEM}}で各要素参照)
  \${{/each}}          繰り返しブロック終了
  \${{DATE}}           現在日付 (自動変数)
  \${{TIMESTAMP}}      現在タイムスタンプ (自動変数)
  \${{HOSTNAME}}       ホスト名 (自動変数)

オプション:
  -h, --help              このヘルプを表示
  -v, --version           バージョン情報を表示
  -f, --vars-file FILE    変数定義ファイル (KEY=VALUE形式)
  -s, --set KEY=VALUE     変数を直接指定 (複数可)
  -o, --output FILE       出力ファイル
  -l, --list-vars         テンプレート内の変数一覧を表示
  --strict                未定義変数をエラーとして扱う

例:
  $PROG_NAME template.txt -s NAME=太郎 -s DATE=2026-01-01
  $PROG_NAME -f vars.env template.txt -o output.txt
  $PROG_NAME -l template.txt
  $PROG_NAME --strict template.txt -f production.env

vars.envの形式:
  APP_NAME=MyApp
  VERSION=1.2.3
  AUTHOR=開発太郎

EOF
}

load_auto_vars() {
    template_vars["DATE"]=$(date '+%Y-%m-%d')
    template_vars["TIMESTAMP"]=$(date '+%Y-%m-%d %H:%M:%S')
    template_vars["HOSTNAME"]=$(hostname)
    template_vars["USER"]="${USER:-unknown}"
    template_vars["PWD"]="$(pwd)"
}

load_vars_file() {
    local file="$1"
    [[ ! -f "$file" ]] && error_exit "変数ファイルが見つかりません: $file"

    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" || "$line" =~ ^# ]] && continue
        if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local val="${BASH_REMATCH[2]}"
            val="${val%\"}"
            val="${val#\"}"
            val="${val%\'}"
            val="${val#\'}"
            template_vars["$key"]="$val"
        fi
    done < "$file"
}

list_template_vars() {
    local file="$1"
    log_info "テンプレート変数一覧: $file"
    echo ""

    local -a found_vars=()
    while IFS= read -r line; do
        while [[ "$line" =~ \$\{\{([A-Za-z_][A-Za-z0-9_:-]*)\}\} ]]; do
            local var="${BASH_REMATCH[1]%%:-*}"
            var="${var#\#}"
            var="${var#/}"
            [[ "$var" =~ ^(if|each|end)$ ]] && { line="${line/\$\{\{${BASH_REMATCH[1]}\}\}/}"; continue; }
            local already=false
            for v in "${found_vars[@]:-}"; do
                [[ "$v" == "$var" ]] && already=true && break
            done
            $already || found_vars+=("$var")
            line="${line/\$\{\{${BASH_REMATCH[1]}\}\}/}"
        done
    done < "$file"

    local auto_vars=("DATE" "TIMESTAMP" "HOSTNAME" "USER" "PWD")

    printf "  ${C_BOLD}%-25s %-12s %s${C_RESET}\n" "変数名" "種別" "現在値"
    printf "  %s\n" "$(printf '%.0s-' {1..60})"

    for var in "${found_vars[@]:-}"; do
        local is_auto=false
        for av in "${auto_vars[@]}"; do
            [[ "$var" == "$av" ]] && is_auto=true && break
        done

        local val="${template_vars[$var]:-}"
        local kind="ユーザー定義"
        $is_auto && kind="自動"

        if [[ -n "$val" ]]; then
            printf "  ${C_GREEN}%-25s${C_RESET} %-12s %s\n" "$var" "$kind" "${val:0:30}"
        else
            printf "  ${C_YELLOW}%-25s${C_RESET} %-12s ${C_DIM}(未設定)${C_RESET}\n" "$var" "$kind"
        fi
    done
    echo ""
}

render_template() {
    local file="$1"
    [[ ! -f "$file" ]] && error_exit "テンプレートが見つかりません: $file"

    local content
    content=$(cat "$file")

    local output=""
    local in_if_block=false
    local if_condition=true
    local in_each_block=false
    local each_var=""
    local each_items=""
    local each_template=""

    while IFS= read -r line || [[ -n "$line" ]]; do
        # 条件ブロック開始
        if [[ "$line" =~ \$\{\{#if[[:space:]]+([A-Za-z_][A-Za-z0-9_]*)\}\} ]]; then
            local cond_var="${BASH_REMATCH[1]}"
            in_if_block=true
            local cond_val="${template_vars[$cond_var]:-}"
            [[ -n "$cond_val" ]] && if_condition=true || if_condition=false
            continue
        fi

        # 条件ブロック終了
        if [[ "$line" =~ \$\{\{/if\}\} ]]; then
            in_if_block=false
            if_condition=true
            continue
        fi

        # 条件ブロック内でfalseならスキップ
        if $in_if_block && ! $if_condition; then
            continue
        fi

        # eachブロック開始
        if [[ "$line" =~ \$\{\{#each[[:space:]]+([A-Za-z_][A-Za-z0-9_]*)\}\} ]]; then
            each_var="${BASH_REMATCH[1]}"
            each_items="${template_vars[$each_var]:-}"
            in_each_block=true
            each_template=""
            continue
        fi

        # eachブロック終了
        if [[ "$line" =~ \$\{\{/each\}\} ]]; then
            in_each_block=false
            IFS=',' read -ra items <<< "$each_items"
            for item in "${items[@]}"; do
                item="${item#"${item%%[![:space:]]*}"}"
                item="${item%"${item##*[![:space:]]}"}"
                local rendered_line="$each_template"
                rendered_line="${rendered_line//\$\{\{ITEM\}\}/$item}"
                output+="${rendered_line}"$'\n'
            done
            each_template=""
            continue
        fi

        if $in_each_block; then
            each_template+="$line"$'\n'
            continue
        fi

        # 変数置換
        local processed_line="$line"

        # デフォルト値付き変数 ${{VAR:-default}}
        while [[ "$processed_line" =~ \$\{\{([A-Za-z_][A-Za-z0-9_]*):-([^}]*)\}\} ]]; do
            local var="${BASH_REMATCH[1]}"
            local default="${BASH_REMATCH[2]}"
            local val="${template_vars[$var]:-$default}"
            processed_line="${processed_line/\$\{\{${var}:-${default}\}\}/$val}"
        done

        # 通常の変数 ${{VAR}}
        while [[ "$processed_line" =~ \$\{\{([A-Za-z_][A-Za-z0-9_]*)\}\} ]]; do
            local var="${BASH_REMATCH[1]}"
            if [[ -v "template_vars[$var]" ]]; then
                local val="${template_vars[$var]}"
                processed_line="${processed_line/\$\{\{${var}\}\}/$val}"
            else
                if $strict_mode; then
                    error_exit "未定義変数: $var"
                fi
                processed_line="${processed_line/\$\{\{${var}\}\}/}"
            fi
        done

        output+="${processed_line}"$'\n'
    done <<< "$content"

    # 末尾改行を1つに
    output="${output%$'\n'}"

    echo "$output"
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -f|--vars-file) [[ $# -lt 2 ]] && error_exit "-f には値が必要です"; vars_file="$2"; shift 2 ;;
            -o|--output)    [[ $# -lt 2 ]] && error_exit "-o には値が必要です"; output_file="$2"; shift 2 ;;
            -s|--set)
                [[ $# -lt 2 ]] && error_exit "-s には KEY=VALUE が必要です"
                if [[ "$2" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
                    template_vars["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
                else
                    error_exit "無効な変数指定: $2 (形式: KEY=VALUE)"
                fi
                shift 2
                ;;
            -l|--list-vars) list_vars=1; shift ;;
            --strict) strict_mode=true; shift ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  template_file="$1"; shift ;;
        esac
    done
}

main() {
    parse_arguments "$@"
    [[ -z "$template_file" ]] && error_exit "テンプレートファイルを指定してください"

    load_auto_vars
    [[ -n "$vars_file" ]] && load_vars_file "$vars_file"

    if (( list_vars )); then
        list_template_vars "$template_file"
        return 0
    fi

    local result
    result=$(render_template "$template_file")

    if [[ -n "$output_file" ]]; then
        echo "$result" > "$output_file"
        log_success "出力完了: $output_file"
    else
        echo "$result"
    fi
}

main "$@"
