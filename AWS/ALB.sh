#!/bin/bash

###########################################
# ALBリスナールール管理スクリプト
# 
# 機能:
# - ALBリスナーの取得
# - ルールの優先度変更
# - エラーハンドリング
###########################################

set -e
set -u

###########################################
# 設定値
###########################################
# スクリプト実行ディレクトリの取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/alb-manager-$(date '+%Y%m%d').log"

# 設定ファイルの読み込み
CONFIG_FILE="${SCRIPT_DIR}/config.env"
if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
else
    echo "設定ファイルが見つかりません。デフォルト値を使用します。"
    
    # デフォルト設定値
    AWS_REGION="${AWS_REGION:-ap-northeast-1}"
    AWS_PROFILE="${AWS_PROFILE:-default}"
    LOAD_BALANCER_NAME="${LOAD_BALANCER_NAME:-default-lb}"
fi

# ログディレクトリの作成
mkdir -p "$LOG_DIR"

###########################################
# ユーティリティ関数
###########################################

# ログ出力関数
log_message() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" | tee -a "$LOG_FILE"
}

# エラーハンドリング関数
handle_error() {
    local error_message="$1"
    log_message "ERROR" "$error_message"
    exit 1
}

# 前提条件チェック
check_prerequisites() {
    log_message "INFO" "前提条件のチェックを開始します"
    
    # AWS CLIが利用可能かチェック
    if ! command -v aws &> /dev/null; then
        handle_error "AWS CLIがインストールされていません"
    fi
    
    # jqが利用可能かチェック
    if ! command -v jq &> /dev/null; then
        handle_error "jqがインストールされていません"
    fi
    
    # AWS認証情報の確認
    if ! aws sts get-caller-identity --profile "${AWS_PROFILE}" &> /dev/null; then
        handle_error "AWS認証情報の取得に失敗しました。AWS_PROFILEを確認してください。"
    fi
    
    # 必要なJSONファイルの存在チェック
    if [[ ! -f "${SCRIPT_DIR}/conditions.json" ]]; then
        handle_error "conditions.jsonが見つかりません"
    fi
    
    if [[ ! -f "${SCRIPT_DIR}/actions.json" ]]; then
        handle_error "actions.jsonが見つかりません"
    fi
    
    log_message "INFO" "前提条件のチェックが完了しました"
}

###########################################
# ALB操作関数
###########################################

# ロードバランサーARNの取得
get_load_balancer_arn() {
    log_message "INFO" "ロードバランサーARNの取得を開始します"
    
    local lb_arn
    lb_arn=$(aws elbv2 describe-load-balancers \
        --profile "${AWS_PROFILE}" \
        --region "${AWS_REGION}" \
        --names "${LOAD_BALANCER_NAME}" \
        --query "LoadBalancers[0].LoadBalancerArn" \
        --output text) || handle_error "ロードバランサーARNの取得に失敗しました"
    
    if [[ -z "$lb_arn" || "$lb_arn" == "null" ]]; then
        handle_error "ロードバランサー '${LOAD_BALANCER_NAME}' が見つかりません"
    fi
    
    echo "$lb_arn"
}

# リスナーARNの取得
get_listener_arn() {
    local lb_arn="$1"
    local port="${LISTENER_PORT:-443}"
    
    log_message "INFO" "リスナーARNの取得を開始します (ポート: ${port})"
    
    local listener_arn
    listener_arn=$(aws elbv2 describe-listeners \
        --profile "${AWS_PROFILE}" \
        --region "${AWS_REGION}" \
        --load-balancer-arn "$lb_arn" \
        --query "Listeners[?Port==${port}].ListenerArn" \
        --output text) || handle_error "リスナーARNの取得に失敗しました"
    
    if [[ -z "$listener_arn" || "$listener_arn" == "null" ]]; then
        handle_error "指定されたポート(${port})のリスナーが見つかりません"
    fi
    
    echo "$listener_arn"
}

# ルール一覧の取得
get_rules() {
    local listener_arn="$1"
    log_message "INFO" "ルール一覧の取得を開始します"
    
    local rules
    rules=$(aws elbv2 describe-rules \
        --profile "${AWS_PROFILE}" \
        --region "${AWS_REGION}" \
        --listener-arn "$listener_arn" \
        --query 'Rules[*].{Priority:Priority,RuleArn:RuleArn}' \
        --output json) || handle_error "ルール一覧の取得に失敗しました"
    
    echo "$rules"
}

# ルールの優先度変更
update_rule_priority() {
    local rule_arn="$1"
    local new_priority="$2"
    log_message "INFO" "ルール(${rule_arn})の優先度を${new_priority}に変更します"
    
    aws elbv2 modify-rule \
        --profile "${AWS_PROFILE}" \
        --region "${AWS_REGION}" \
        --rule-arn "$rule_arn" \
        --conditions file://"${SCRIPT_DIR}/conditions.json" \
        --actions file://"${SCRIPT_DIR}/actions.json" \
        --priority "$new_priority" || handle_error "ルールの優先度変更に失敗しました"
    
    log_message "INFO" "ルールの優先度を変更しました"
}

# リスナールールの優先度を設定
set_rule_priorities() {
    local priorities_json="$1"
    log_message "INFO" "複数ルールの優先度を設定します"
    
    aws elbv2 set-rule-priorities \
        --profile "${AWS_PROFILE}" \
        --region "${AWS_REGION}" \
        --rule-priorities "$priorities_json" || handle_error "ルールの優先度設定に失敗しました"
    
    log_message "INFO" "ルールの優先度を設定しました"
}

###########################################
# メイン処理
###########################################

main() {
    log_message "INFO" "スクリプトの実行を開始します"
    
    # 前提条件のチェック
    check_prerequisites
    
    # ロードバランサーARNの取得
    local lb_arn
    lb_arn=$(get_load_balancer_arn)
    log_message "INFO" "取得したロードバランサーARN: ${lb_arn}"
    
    # リスナーARNの取得
    local listener_arn
    listener_arn=$(get_listener_arn "$lb_arn")
    log_message "INFO" "取得したリスナーARN: ${listener_arn}"
    
    # ルール一覧の取得と処理
    local rules
    rules=$(get_rules "$listener_arn")
    
    # 処理対象のルールに関する情報を表示
    log_message "INFO" "現在のルール設定:"
    echo "$rules" | jq '.'
    
    # 優先度1のルールを見つけ、優先度を変更
    local priority1_rule_arn
    priority1_rule_arn=$(echo "$rules" | jq -r '.[] | select(.Priority == "1") | .RuleArn')
    
    if [[ -n "$priority1_rule_arn" && "$priority1_rule_arn" != "null" ]]; then
        update_rule_priority "$priority1_rule_arn" "99"
        log_message "INFO" "優先度1のルールを優先度99に変更しました"
    else
        log_message "WARN" "優先度1のルールが見つかりませんでした"
    fi
    
    log_message "INFO" "スクリプトの実行が完了しました"
}

# スクリプトの実行
main "$@"