#!/bin/bash
set -euo pipefail

#
# EC2インスタンス管理ツール
# バージョン: 1.0
#
# AWS EC2インスタンスの一覧・起動・停止・接続を管理するツール
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"
readonly DEFAULT_REGION="${AWS_DEFAULT_REGION:-ap-northeast-1}"

declare action=""
declare region="$DEFAULT_REGION"
declare instance_id=""
declare tag_filter=""
declare key_path="${EC2_KEY_PATH:-~/.ssh/id_rsa}"
declare ssh_user="ec2-user"
declare -i wait_timeout=300

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME <アクション> [オプション]

AWS EC2インスタンス管理ツール

アクション:
  list      インスタンス一覧
  start     インスタンス起動
  stop      インスタンス停止
  ssh       SSHで接続
  info      インスタンス詳細情報
  cost      インスタンスの概算コスト

オプション:
  -h, --help            このヘルプを表示
  -v, --version         バージョン情報を表示
  -r, --region REGION   AWSリージョン [デフォルト: $DEFAULT_REGION]
  -i, --id ID           インスタンスID
  -t, --tag TAG=VAL     タグフィルター (例: Name=webserver)
  -k, --key FILE        SSH秘密鍵パス [デフォルト: ~/.ssh/id_rsa]
  -u, --user USER       SSHユーザー [デフォルト: ec2-user]
  -w, --wait SEC        起動待機タイムアウト秒 [デフォルト: 300]

例:
  $PROG_NAME list
  $PROG_NAME list -t Name=web*
  $PROG_NAME start -i i-1234567890abcdef0
  $PROG_NAME ssh -i i-1234567890abcdef0
  $PROG_NAME info -i i-1234567890abcdef0

EOF
}

check_aws() {
    if ! command -v aws &>/dev/null; then
        error_exit "AWS CLI が見つかりません"
    fi
    if ! aws sts get-caller-identity --region "$region" &>/dev/null; then
        error_exit "AWS認証情報が設定されていません"
    fi
}

get_state_color() {
    case "$1" in
        running)         echo "$C_GREEN" ;;
        stopped)         echo "$C_RED" ;;
        pending|stopping) echo "$C_YELLOW" ;;
        *)               echo "$C_DIM" ;;
    esac
}

do_list() {
    log_info "EC2インスタンス一覧 (リージョン: $region)"
    echo ""
    printf "  %-22s %-15s %-12s %-15s %-20s %s\n" \
        "インスタンスID" "IP" "状態" "タイプ" "Name" "起動時刻"
    printf "  %s\n" "$(printf '%.0s-' {1..100})"

    local filter_args=()
    if [[ -n "$tag_filter" ]]; then
        local tag_key="${tag_filter%%=*}"
        local tag_val="${tag_filter#*=}"
        filter_args+=(--filters "Name=tag:${tag_key},Values=${tag_val}")
    fi

    aws ec2 describe-instances \
        --region "$region" \
        "${filter_args[@]:-}" \
        --query 'Reservations[].Instances[].[InstanceId,PublicIpAddress,State.Name,InstanceType,Tags[?Key==`Name`]|[0].Value,LaunchTime]' \
        --output text 2>/dev/null | \
    while IFS=$'\t' read -r id ip state type name launch; do
        local color
        color=$(get_state_color "$state")
        local ip_str="${ip:-N/A}"
        local name_str="${name:-N/A}"
        local launch_str
        launch_str=$(echo "${launch:-}" | cut -c1-19)
        printf "  %-22s %-15s %b%-12s%b %-15s %-20s %s\n" \
            "$id" "$ip_str" "$color" "$state" "$C_RESET" \
            "$type" "${name_str:0:18}" "$launch_str"
    done

    echo ""
}

do_start() {
    [[ -z "$instance_id" ]] && error_exit "インスタンスIDを --id で指定してください"

    log_info "インスタンス起動: $instance_id"
    aws ec2 start-instances --region "$region" --instance-ids "$instance_id" \
        --query 'StartingInstances[].{ID:InstanceId,From:PreviousState.Name,To:CurrentState.Name}' \
        --output table 2>/dev/null

    log_info "起動待機中..."
    aws ec2 wait instance-running \
        --region "$region" \
        --instance-ids "$instance_id" 2>/dev/null && \
        log_success "インスタンス起動完了: $instance_id" || \
        log_warning "タイムアウトしました"
}

do_stop() {
    [[ -z "$instance_id" ]] && error_exit "インスタンスIDを --id で指定してください"

    log_warning "インスタンス停止: $instance_id"
    printf "停止しますか? [y/N]: "
    local ans; read -r ans
    [[ ! "$ans" =~ ^[yY]$ ]] && { log_info "キャンセルしました"; return; }

    aws ec2 stop-instances --region "$region" --instance-ids "$instance_id" \
        --query 'StoppingInstances[].{ID:InstanceId,From:PreviousState.Name,To:CurrentState.Name}' \
        --output table 2>/dev/null
    log_success "停止リクエスト送信完了"
}

do_ssh() {
    [[ -z "$instance_id" ]] && error_exit "インスタンスIDを --id で指定してください"

    local public_ip
    public_ip=$(aws ec2 describe-instances \
        --region "$region" \
        --instance-ids "$instance_id" \
        --query 'Reservations[].Instances[].PublicIpAddress' \
        --output text 2>/dev/null)

    [[ -z "$public_ip" || "$public_ip" == "None" ]] && \
        error_exit "パブリックIPが見つかりません。インスタンスが起動しているか確認してください"

    log_info "SSH接続: ${ssh_user}@${public_ip}"
    ssh -i "$key_path" -o StrictHostKeyChecking=no "${ssh_user}@${public_ip}"
}

do_info() {
    [[ -z "$instance_id" ]] && error_exit "インスタンスIDを --id で指定してください"

    log_info "インスタンス詳細: $instance_id"
    echo ""

    aws ec2 describe-instances \
        --region "$region" \
        --instance-ids "$instance_id" \
        --query 'Reservations[].Instances[].[InstanceId,InstanceType,State.Name,PublicIpAddress,PrivateIpAddress,VpcId,SubnetId,KeyName,ImageId,LaunchTime]' \
        --output text 2>/dev/null | \
    while IFS=$'\t' read -r id type state pub_ip priv_ip vpc subnet key ami launch; do
        printf "  %-22s %s\n" "インスタンスID:" "$id"
        printf "  %-22s %s\n" "タイプ:" "$type"
        printf "  %-22s %s\n" "状態:" "$state"
        printf "  %-22s %s\n" "パブリックIP:" "${pub_ip:-N/A}"
        printf "  %-22s %s\n" "プライベートIP:" "${priv_ip:-N/A}"
        printf "  %-22s %s\n" "VPC:" "${vpc:-N/A}"
        printf "  %-22s %s\n" "サブネット:" "${subnet:-N/A}"
        printf "  %-22s %s\n" "キーペア:" "${key:-N/A}"
        printf "  %-22s %s\n" "AMI:" "${ami:-N/A}"
        printf "  %-22s %s\n" "起動時刻:" "${launch:-N/A}"
    done
    echo ""
}

parse_arguments() {
    [[ $# -eq 0 ]] && { show_usage; exit 0; }
    action="$1"; shift

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -r|--region)  [[ $# -lt 2 ]] && error_exit "--region には値が必要です"; region="$2"; shift 2 ;;
            -i|--id)      [[ $# -lt 2 ]] && error_exit "--id には値が必要です"; instance_id="$2"; shift 2 ;;
            -t|--tag)     [[ $# -lt 2 ]] && error_exit "--tag には値が必要です"; tag_filter="$2"; shift 2 ;;
            -k|--key)     [[ $# -lt 2 ]] && error_exit "--key には値が必要です"; key_path="$2"; shift 2 ;;
            -u|--user)    [[ $# -lt 2 ]] && error_exit "--user には値が必要です"; ssh_user="$2"; shift 2 ;;
            -w|--wait)    [[ $# -lt 2 ]] && error_exit "--wait には数値が必要です"; wait_timeout="$2"; shift 2 ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  error_exit "不明な引数: $1" ;;
        esac
    done
}

main() {
    parse_arguments "$@"
    check_aws

    case "$action" in
        list)  do_list ;;
        start) do_start ;;
        stop)  do_stop ;;
        ssh)   do_ssh ;;
        info)  do_info ;;
        *)     error_exit "不明なアクション: $action。--help を参照してください" ;;
    esac
}

main "$@"
