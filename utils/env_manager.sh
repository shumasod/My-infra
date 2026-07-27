#!/bin/bash
set -euo pipefail

#
# 環境変数管理ツール
# 作成日: 2026-07-27
# バージョン: 1.0
#
# .envファイルの作成・編集・暗号化・検証を行います
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"
readonly DEFAULT_ENV_FILE=".env"

declare command_name=""
declare env_file="$DEFAULT_ENV_FILE"
declare key_name=""
declare key_value=""
declare output_format="table"

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME <コマンド> [オプション]

.envファイルの管理ツールです。

コマンド:
  list                   変数一覧を表示
  get <KEY>              指定キーの値を取得
  set <KEY> <VALUE>      変数を設定または更新
  unset <KEY>            変数を削除
  check                  .envファイルの検証
  diff <ファイル1> <ファイル2>  2つの.envファイルを比較
  export                 export形式で出力
  template <ファイル>    テンプレートから.envを生成

オプション:
  -h, --help             このヘルプを表示
  -v, --version          バージョン情報を表示
  -f, --file <ファイル>  .envファイルのパス [デフォルト: .env]
  --format <形式>        出力形式 (table|json|raw) [デフォルト: table]

例:
  $PROG_NAME list
  $PROG_NAME set DATABASE_URL "mysql://user:pass@localhost/db"
  $PROG_NAME get API_KEY
  $PROG_NAME check
  $PROG_NAME diff .env .env.production
EOF
}

# .envファイルを読み込んで連想配列に格納
parse_env_file() {
    local file="$1"
    local -n _result=$2

    [[ ! -f "$file" ]] && return 0

    while IFS= read -r line || [[ -n "$line" ]]; do
        # 空行・コメント行をスキップ
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        # KEY=VALUE 形式のみ処理
        if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
            local k="${BASH_REMATCH[1]}"
            local v="${BASH_REMATCH[2]}"
            # クォートを除去
            v="${v%\"}"
            v="${v#\"}"
            v="${v%\'}"
            v="${v#\'}"
            _result["$k"]="$v"
        fi
    done < "$file"
}

cmd_list() {
    if [[ ! -f "$env_file" ]]; then
        log_warning "$env_file が見つかりません"
        return 0
    fi

    declare -A vars
    parse_env_file "$env_file" vars

    if [[ ${#vars[@]} -eq 0 ]]; then
        log_info "変数が定義されていません"
        return 0
    fi

    case "$output_format" in
        table)
            printf "\n${C_BOLD}%-30s %s${C_RESET}\n" "KEY" "VALUE"
            printf "%s\n" "$(printf '%.0s─' {1..60})"
            for k in $(echo "${!vars[@]}" | tr ' ' '\n' | sort); do
                local v="${vars[$k]}"
                # 長い値は省略表示
                if [[ ${#v} -gt 40 ]]; then
                    v="${v:0:37}..."
                fi
                # パスワード系キーはマスク
                if [[ "$k" =~ (PASSWORD|SECRET|TOKEN|KEY|PASS) ]]; then
                    v="****"
                fi
                printf "  ${C_CYAN}%-28s${C_RESET} %s\n" "$k" "$v"
            done
            printf "\n合計: ${C_GREEN}%d${C_RESET} 変数\n\n" "${#vars[@]}"
            ;;
        json)
            echo "{"
            local first=true
            for k in $(echo "${!vars[@]}" | tr ' ' '\n' | sort); do
                $first || echo ","
                printf '  "%s": "%s"' "$k" "${vars[$k]}"
                first=false
            done
            echo ""
            echo "}"
            ;;
        raw)
            for k in $(echo "${!vars[@]}" | tr ' ' '\n' | sort); do
                echo "$k=${vars[$k]}"
            done
            ;;
    esac
}

cmd_get() {
    [[ -z "$key_name" ]] && error_exit "KEYを指定してください"
    [[ ! -f "$env_file" ]] && error_exit "$env_file が見つかりません"

    declare -A vars
    parse_env_file "$env_file" vars

    if [[ -n "${vars[$key_name]+_}" ]]; then
        echo "${vars[$key_name]}"
    else
        log_error "$key_name が見つかりません"
        exit 1
    fi
}

cmd_set() {
    [[ -z "$key_name" ]] && error_exit "KEYを指定してください"

    # ファイルが存在しない場合は作成
    if [[ ! -f "$env_file" ]]; then
        touch "$env_file"
        log_info "$env_file を作成しました"
    fi

    # 既存のキーを更新または追加
    if grep -q "^${key_name}=" "$env_file" 2>/dev/null; then
        # 値にスラッシュが含まれる場合を考慮して@区切りを使用
        local escaped_value="${key_value//&/\\&}"
        sed -i "s@^${key_name}=.*@${key_name}=${escaped_value}@" "$env_file"
        log_success "$key_name を更新しました"
    else
        echo "${key_name}=${key_value}" >> "$env_file"
        log_success "$key_name を追加しました"
    fi
}

cmd_unset() {
    [[ -z "$key_name" ]] && error_exit "KEYを指定してください"
    [[ ! -f "$env_file" ]] && error_exit "$env_file が見つかりません"

    if grep -q "^${key_name}=" "$env_file" 2>/dev/null; then
        sed -i "/^${key_name}=/d" "$env_file"
        log_success "$key_name を削除しました"
    else
        log_warning "$key_name は定義されていません"
    fi
}

cmd_check() {
    if [[ ! -f "$env_file" ]]; then
        log_error "$env_file が見つかりません"
        exit 1
    fi

    log_info "$env_file を検証中..."
    echo ""

    local errors=0
    local warnings=0
    local line_num=0

    while IFS= read -r line || [[ -n "$line" ]]; do
        ((line_num++))
        # 空行・コメントはスキップ
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

        if ! [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)= ]]; then
            printf "  ${C_RED}[ERROR]${C_RESET} 行%d: 無効な形式: %s\n" "$line_num" "$line"
            ((errors++))
            continue
        fi

        local k="${BASH_REMATCH[1]}"
        local v="${line#*=}"

        # 値が空の場合は警告
        if [[ -z "$v" ]]; then
            printf "  ${C_YELLOW}[WARN]${C_RESET}  行%d: %s の値が空です\n" "$line_num" "$k"
            ((warnings++))
        fi

        # クォートが不正な場合
        if [[ "$v" == '"'* && "$v" != *'"' ]] || [[ "$v" == "'"* && "$v" != *"'" ]]; then
            printf "  ${C_RED}[ERROR]${C_RESET} 行%d: %s のクォートが閉じられていません\n" "$line_num" "$k"
            ((errors++))
        fi

    done < "$env_file"

    echo ""
    if [[ $errors -eq 0 && $warnings -eq 0 ]]; then
        log_success "検証完了: 問題は見つかりませんでした"
    else
        [[ $errors -gt 0 ]]   && log_error   "エラー: ${errors}件"
        [[ $warnings -gt 0 ]] && log_warning "警告: ${warnings}件"
        [[ $errors -gt 0 ]] && exit 1
    fi
}

cmd_diff() {
    local f1="${ARGS[0]:-}"
    local f2="${ARGS[1]:-}"
    [[ -z "$f1" || -z "$f2" ]] && error_exit "2つのファイルを指定してください"
    [[ ! -f "$f1" ]] && error_exit "ファイルが見つかりません: $f1"
    [[ ! -f "$f2" ]] && error_exit "ファイルが見つかりません: $f2"

    declare -A vars1 vars2
    parse_env_file "$f1" vars1
    parse_env_file "$f2" vars2

    local all_keys
    all_keys=$(echo "${!vars1[@]} ${!vars2[@]}" | tr ' ' '\n' | sort -u)

    printf "\n${C_BOLD}%-30s %-20s %s${C_RESET}\n" "KEY" "$f1" "$f2"
    printf "%s\n" "$(printf '%.0s─' {1..70})"

    local has_diff=false
    while IFS= read -r k; do
        local v1="${vars1[$k]:-}"
        local v2="${vars2[$k]:-}"
        if [[ -n "${vars1[$k]+_}" && -z "${vars2[$k]+_}" ]]; then
            printf "${C_RED}  %-28s %-20s <削除>${C_RESET}\n" "$k" "$v1"
            has_diff=true
        elif [[ -z "${vars1[$k]+_}" && -n "${vars2[$k]+_}" ]]; then
            printf "${C_GREEN}  %-28s %-20s %s${C_RESET}\n" "$k" "<追加>" "$v2"
            has_diff=true
        elif [[ "$v1" != "$v2" ]]; then
            printf "${C_YELLOW}  %-28s${C_RESET} ${C_RED}%-20s${C_RESET} ${C_GREEN}%s${C_RESET}\n" "$k" "$v1" "$v2"
            has_diff=true
        fi
    done <<< "$all_keys"

    echo ""
    if $has_diff; then
        log_warning "差分があります"
    else
        log_success "ファイルは同一です"
    fi
}

cmd_export() {
    [[ ! -f "$env_file" ]] && error_exit "$env_file が見つかりません"

    declare -A vars
    parse_env_file "$env_file" vars

    for k in $(echo "${!vars[@]}" | tr ' ' '\n' | sort); do
        printf 'export %s="%s"\n' "$k" "${vars[$k]}"
    done
}

cmd_template() {
    local tmpl="${ARGS[0]:-}"
    [[ -z "$tmpl" ]] && error_exit "テンプレートファイルを指定してください"
    [[ ! -f "$tmpl" ]] && error_exit "テンプレートが見つかりません: $tmpl"

    log_info "テンプレートから $env_file を生成中..."
    cp "$tmpl" "$env_file"

    # #REQUIRED コメントの次の行に空値を設定
    sed -i 's/^#REQUIRED:/# REQUIRED:/g' "$env_file"
    log_success "$env_file を生成しました"
    log_info "必要な変数を設定してください: $PROG_NAME set KEY VALUE"
}

declare -a ARGS=()

parse_arguments() {
    [[ $# -eq 0 ]] && { show_usage; exit 0; }

    command_name="$1"
    shift

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_usage
                exit 0
                ;;
            -v|--version)
                echo "$PROG_NAME version $VERSION"
                exit 0
                ;;
            -f|--file)
                [[ $# -lt 2 ]] && error_exit "--file には値が必要です"
                env_file="$2"
                shift 2
                ;;
            --format)
                [[ $# -lt 2 ]] && error_exit "--format には値が必要です"
                output_format="$2"
                shift 2
                ;;
            -*)
                error_exit "不明なオプション: $1"
                ;;
            *)
                ARGS+=("$1")
                shift
                ;;
        esac
    done

    # コマンドに応じた引数設定
    case "$command_name" in
        get|unset)
            key_name="${ARGS[0]:-}"
            ;;
        set)
            key_name="${ARGS[0]:-}"
            key_value="${ARGS[1]:-}"
            [[ -z "$key_name" ]]  && error_exit "KEYを指定してください"
            [[ -z "$key_value" ]] && error_exit "VALUEを指定してください"
            ;;
    esac
}

main() {
    parse_arguments "$@"

    case "$command_name" in
        list)     cmd_list ;;
        get)      cmd_get ;;
        set)      cmd_set ;;
        unset)    cmd_unset ;;
        check)    cmd_check ;;
        diff)     cmd_diff ;;
        export)   cmd_export ;;
        template) cmd_template ;;
        *)
            error_exit "不明なコマンド: $command_name"
            ;;
    esac
}

main "$@"
