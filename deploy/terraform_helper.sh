#!/bin/bash
set -euo pipefail

#
# Terraformヘルパーツール
# バージョン: 1.0
#
# Terraform の操作を簡略化するラッパーツール
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare action=""
declare tf_dir="."
declare workspace="default"
declare -a tf_vars=()
declare auto_approve=false
declare target=""
declare plan_file="/tmp/tfplan_$$"

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME <アクション> [オプション]

Terraformラッパーツール

アクション:
  init      terraform init を実行
  plan      実行計画を表示
  apply     インフラを適用
  destroy   インフラを削除
  validate  設定ファイルを検証
  fmt       コードフォーマット
  output    出力値を表示
  state     ステート操作 (list|show)
  workspace ワークスペース管理 (list|new|select)

オプション:
  -h, --help            このヘルプを表示
  -v, --version         バージョン情報を表示
  -d, --dir DIR         Terraformディレクトリ [デフォルト: .]
  -w, --workspace WS    ワークスペース名 [デフォルト: default]
  -V, --var KEY=VAL     変数指定 (複数可)
  --target RESOURCE     特定リソースのみ対象
  --auto-approve        apply/destroy の確認をスキップ

例:
  $PROG_NAME plan
  $PROG_NAME apply -w staging
  $PROG_NAME apply --auto-approve -V env=prod
  $PROG_NAME destroy --target aws_instance.web
  $PROG_NAME state list

EOF
}

check_terraform() {
    if ! command -v terraform &>/dev/null; then
        error_exit "terraform コマンドが見つかりません"
    fi
    local tf_ver
    tf_ver=$(terraform version -json 2>/dev/null | jq -r '.terraform_version' 2>/dev/null || terraform version | head -1)
    log_info "Terraform: $tf_ver"
}

build_tf_args() {
    local -a args=()
    for v in "${tf_vars[@]}"; do
        args+=(-var "$v")
    done
    [[ -n "$target" ]] && args+=(-target="$target")
    echo "${args[@]:-}"
}

do_init() {
    log_info "terraform init: $tf_dir"
    cd "$tf_dir"
    terraform init
    if [[ "$workspace" != "default" ]]; then
        terraform workspace select "$workspace" 2>/dev/null || \
            terraform workspace new "$workspace"
        log_success "ワークスペース: $workspace"
    fi
}

do_plan() {
    log_info "terraform plan: $tf_dir (workspace: $workspace)"
    cd "$tf_dir"
    [[ "$workspace" != "default" ]] && terraform workspace select "$workspace" &>/dev/null

    local extra_args
    read -ra extra_args <<< "$(build_tf_args)" 2>/dev/null || extra_args=()

    terraform plan -out="$plan_file" "${extra_args[@]:-}"
    log_success "プランを保存: $plan_file"
}

do_apply() {
    log_info "terraform apply: $tf_dir (workspace: $workspace)"
    cd "$tf_dir"
    [[ "$workspace" != "default" ]] && terraform workspace select "$workspace" &>/dev/null

    local extra_args
    read -ra extra_args <<< "$(build_tf_args)" 2>/dev/null || extra_args=()

    if [[ "$auto_approve" == true ]]; then
        extra_args+=(-auto-approve)
    fi

    if [[ -f "$plan_file" ]]; then
        log_info "保存済みプランを適用"
        terraform apply "$plan_file"
    else
        terraform apply "${extra_args[@]:-}"
    fi
}

do_destroy() {
    log_warning "terraform destroy を実行します (workspace: $workspace)"

    if [[ "$auto_approve" != true ]]; then
        printf "本当に削除しますか? [yes/NO]: "
        local ans; read -r ans
        [[ "$ans" != "yes" ]] && { log_info "キャンセルしました"; return; }
    fi

    cd "$tf_dir"
    [[ "$workspace" != "default" ]] && terraform workspace select "$workspace" &>/dev/null

    local extra_args
    read -ra extra_args <<< "$(build_tf_args)" 2>/dev/null || extra_args=()
    [[ "$auto_approve" == true ]] && extra_args+=(-auto-approve)

    terraform destroy "${extra_args[@]:-}"
}

do_validate() {
    log_info "terraform validate: $tf_dir"
    cd "$tf_dir"
    if terraform validate; then
        log_success "設定ファイルは有効です"
    else
        log_error "検証エラーあり"
        exit 1
    fi
}

do_fmt() {
    log_info "terraform fmt: $tf_dir"
    cd "$tf_dir"
    terraform fmt -recursive
    log_success "フォーマット完了"
}

do_output() {
    cd "$tf_dir"
    [[ "$workspace" != "default" ]] && terraform workspace select "$workspace" &>/dev/null
    log_info "terraform output (workspace: $workspace)"
    terraform output
}

do_state() {
    local subcmd="${1:-list}"
    cd "$tf_dir"
    [[ "$workspace" != "default" ]] && terraform workspace select "$workspace" &>/dev/null

    case "$subcmd" in
        list) terraform state list ;;
        show)
            [[ -z "$target" ]] && error_exit "表示するリソースを --target で指定してください"
            terraform state show "$target" ;;
        *) error_exit "不明なサブコマンド: $subcmd (list|show)" ;;
    esac
}

do_workspace() {
    local subcmd="${1:-list}"
    cd "$tf_dir"
    case "$subcmd" in
        list)   terraform workspace list ;;
        new)    terraform workspace new "$workspace" ;;
        select) terraform workspace select "$workspace" ;;
        *) error_exit "不明なサブコマンド: $subcmd (list|new|select)" ;;
    esac
}

parse_arguments() {
    [[ $# -eq 0 ]] && { show_usage; exit 0; }
    action="$1"; shift

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -d|--dir)
                [[ $# -lt 2 ]] && error_exit "--dir には値が必要です"
                tf_dir="$2"; shift 2 ;;
            -w|--workspace)
                [[ $# -lt 2 ]] && error_exit "--workspace には値が必要です"
                workspace="$2"; shift 2 ;;
            -V|--var)
                [[ $# -lt 2 ]] && error_exit "--var には KEY=VALUE が必要です"
                tf_vars+=("$2"); shift 2 ;;
            --target)
                [[ $# -lt 2 ]] && error_exit "--target には値が必要です"
                target="$2"; shift 2 ;;
            --auto-approve) auto_approve=true; shift ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  break ;;
        esac
    done
    remaining_args=("$@")
}

declare -a remaining_args=()

main() {
    parse_arguments "$@"
    check_terraform

    case "$action" in
        init)      do_init ;;
        plan)      do_plan ;;
        apply)     do_apply ;;
        destroy)   do_destroy ;;
        validate)  do_validate ;;
        fmt)       do_fmt ;;
        output)    do_output ;;
        state)     do_state "${remaining_args[0]:-list}" ;;
        workspace) do_workspace "${remaining_args[0]:-list}" ;;
        *)         error_exit "不明なアクション: $action。--help を参照してください" ;;
    esac
}

main "$@"
