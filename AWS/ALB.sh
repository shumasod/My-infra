#!/bin/bash

set -euo pipefail

###########################################
# 設定値
###########################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/alb-manager-$(date '+%Y%m%d').log"

CONFIG_FILE="${SCRIPT_DIR}/config.env"

# デフォルト値（環境変数またはconfig.envで上書き可能）
AWS_REGION="${AWS_REGION:-ap-northeast-1}"
AWS_PROFILE="${AWS_PROFILE:-default}"
LOAD_BALANCER_NAME="${LOAD_BALANCER_NAME:-default-lb}"
LISTENER_PORT="${LISTENER_PORT:-443}"

# 設定ファイルがあれば読み込み
if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
fi

mkdir -p "$LOG_DIR"

###########################################
# ユーティリティ関数
###########################################

log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

handle_error() {
    local message="$1"
    local exit_code="${2:-1}"
    log_message "ERROR" "$message"
    exit "$exit_code"
}

# AWS CLI共通オプション
aws_cmd() {
    aws --profile "${AWS_PROFILE}" --region "${AWS_REGION}" "$@"
}

###########################################
# 前提条件チェック
###########################################

check_prerequisites() {
    log_message "INFO" "前提条件のチェックを開始します"

    command -v aws &>/dev/null || handle_error "AWS CLIがインストールされていません"
    command -v jq &>/dev/null || handle_error "jqがインストールされていません"

    # AWS CLI v2推奨警告
    local major_version
    major_version=$(aws --version 2>&1 | awk '{print $1}' | cut -d/ -f2 | cut -d. -f1)
    (( major_version < 2 )) && log_message "WARN" "AWS CLI v2の使用を推奨します（現在 v${major_version}）"

    # 認証確認
    aws_cmd sts get-caller-identity &>/dev/null || handle_error "AWS認証情報が無効です。プロファイルとリージョンを確認してください"

    log_message "INFO" "前提条件のチェックが完了しました"
}

###########################################
# ALB操作関数
###########################################

get_load_balancer_arn() {
    log_message "INFO" "ロードバランサーARNを取得中（Name: ${LOAD_BALANCER_NAME}）"

    local lb_arn
    lb_arn=$(aws_cmd elbv2 describe-load-balancers \
        --names "${LOAD_BALANCER_NAME}" \
        --query "LoadBalancers[0].LoadBalancerArn" \
        --output text) || handle_error "ロードバランサー '${LOAD_BALANCER_NAME}' の取得に失敗しました"

    [[ -n "$lb_arn" && "$lb_arn" != "None" ]] || handle_error "ロードバランサー '${LOAD_BALANCER_NAME}' が見つかりません"
    
    log_message "INFO" "ロードバランサーARN取得: $lb_arn"
    echo "$lb_arn"
}

get_listener_arn() {
    local lb_arn="$1"
    local port="${LISTENER_PORT}"

    log_message "INFO" "リスナーARNを取得中（Port: ${port}）"

    local listener_arn
    listener_arn=$(aws_cmd elbv2 describe-listeners \
        --load-balancer-arn "$lb_arn" \
        --query "Listeners[?Port==\`${port}\`].ListenerArn | [0]" \
        --output text) || handle_error "ポート ${port} のリスナー取得に失敗しました"

    [[ -n "$listener_arn" && "$listener_arn" != "None" ]] || handle_error "ポート ${port} のリスナーが見つかりません"
    
    log_message "INFO" "リスナーARN取得: $listener_arn"
    echo "$listener_arn"
}

get_rules() {
    local listener_arn="$1"

    log_message "INFO" "ルール一覧を取得中"

    local rules
    rules=$(aws_cmd elbv2 describe-rules \
        --listener-arn "$listener_arn" \
        --query 'Rules[*].{Priority:Priority, RuleArn:RuleArn, IsDefault:IsDefault}' \
        --output json) || handle_error "ルール一覧の取得に失敗しました"

    [[ -n "$rules" ]] && echo "$rules" | jq -e . >/dev/null || handle_error "ルールデータの形式が不正です"

    local count
    count=$(echo "$rules" | jq 'length')
    log_message "INFO" "ルール取得完了（${count}件）"

    echo "$rules"
}

display_rules() {
    local rules_json="$1"
    local title="${2:-現在のルール設定}"

    log_message "INFO" "=== ${title} ==="
    echo "$rules_json" | jq -r '
        .[] 
        | select(.IsDefault == false) 
        | "  Priority: \(.Priority | lpad(5)), RuleArn: \(.RuleArn)"' | tee -a "$LOG_FILE"
}

priority_exists() {
    local rules_json="$1"
    local priority="$2"
    local exclude_arn="${3:-}"

    local jq_filter='.[] | select(.Priority == $priority and .IsDefault == false'
    [[ -n "$exclude_arn" ]] && jq_filter+=' and .RuleArn != $exclude_arn'
    jq_filter+=' ) | .RuleArn'

    local found
    found=$(echo "$rules_json" | jq -r --arg priority "$priority" --arg exclude_arn "$exclude_arn" "$jq_filter")

    [[ -n "$found" ]]
}

find_available_priority() {
    local rules_json="$1"
    local start="${2:-99}"

    log_message "INFO" "利用可能な優先度を検索中（開始: ${start}）"

    local priority=$start
    while (( priority <= 50000 )); do
        if ! priority_exists "$rules_json" "$priority"; then
            log_message "INFO" "利用可能な優先度発見: ${priority}"
            echo "$priority"
            return 0
        fi
        ((priority++))
    done

    handle_error "利用可能な優先度が見つかりませんでした（99〜50000の範囲）"
}

move_priority1_to_safe() {
    local rules_json="$1"
    local listener_arn="$2"

    local priority1_arn
    priority1_arn=$(echo "$rules_json" | jq -r '.[] | select(.Priority == "1" and .IsDefault == false) | .RuleArn')

    if [[ -z "$priority1_arn" || "$priority1_arn" == "null" ]]; then
        log_message "WARN" "優先度1のルールは存在しません。処理をスキップします。"
        return 0
    fi

    log_message "INFO" "優先度1のルールを発見（ARN: ${priority1_arn}）"

    local target_priority
    if priority_exists "$rules_json" "99" "$priority1_arn"; then
        log_message "WARN" "優先度99は使用中です。空き優先度を検索します。"
        target_priority=$(find_available_priority "$rules_json" 99)
    else
        target_priority=99
    fi

    log_message "INFO" "優先度1 → ${target_priority} に移動します"

    aws_cmd elbv2 modify-rule \
        --rule-arn "$priority1_arn" \
        --priority "$target_priority" \
        >/dev/null || handle_error "優先度変更に失敗しました（RuleArn: ${priority1_arn}）"

    log_message "INFO" "優先度を ${target_priority} に変更しました"
}

###########################################
# メイン処理
###########################################

main() {
    log_message "INFO" "========================================="
    log_message "INFO" "ALB優先度1ルール退避スクリプト 開始"
    log_message "INFO" "========================================="
    log_message "INFO" "設定: Profile=${AWS_PROFILE}, Region=${AWS_REGION}"
    log_message "INFO" "      LB=${LOAD_BALANCER_NAME}, Port=${LISTENER_PORT}"
    log_message "INFO" "========================================="

    check_prerequisites

    local lb_arn
    lb_arn=$(get_load_balancer_arn)

    local listener_arn
    listener_arn=$(get_listener_arn "$lb_arn")

    local rules
    rules=$(get_rules "$listener_arn")

    display_rules "$rules" "【変更前】ルール一覧"

    move_priority1_to_safe "$rules" "$listener_arn"

    # 変更後確認
    rules=$(get_rules "$listener_arn")
    display_rules "$rules" "【変更後】ルール一覧"

    log_message "INFO" "========================================="
    log_message "INFO" "スクリプトが正常終了しました"
    log_message "INFO" "========================================="
}

# 実行
main "$@"
