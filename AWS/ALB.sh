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
# 環境設定の読み込み
source ./config.env 2>/dev/null || {
    echo "設定ファイルが見つかりません。デフォルト値を使用します。"
    
    # デフォルト設定値
    readonly AWS_REGION="ap-northeast-1"
    readonly AWS_ACCOUNT_ID="123456789012"
    readonly LOAD_BALANCER_NAME="default-lb"
}

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
    which aws >/dev/null 2>&1 || handle_error "AWS CLIがインストールされていません"
    
    # jqが利用可能かチェック
    which jq >/dev/null 2>&1 || handle_error "jqがインストールされていません"
    
    # 必要なJSONファイルの存在チェック
    test -f "conditions.json" || handle_error "conditions.jsonが見つかりません"
    test -f "actions.json" || handle_error "actions.jsonが見つかりません"
    
    log_message "INFO" "前提条件のチェックが完了しました"
}

###########################################
# ALB操作関数
###########################################

# リスナーARNの取得
get_listener_arn() {
    log_message "INFO" "リスナーARNの取得を開始します"
    
    local lb_arn="arn:aws:elasticloadbalancing:${AWS_REGION}:${AWS_ACCOUNT_ID}:loadbalancer/app/${LOAD_BALANCER_NAME}/1234567890abcdef"
    
    local listener_arn
    listener_arn=$(aws elbv2 describe-listeners \
        --load-balancer-arn "$lb_arn" \
        --query "Listeners[?Port==443].ListenerArn" \
        --output text) || handle_error "リスナーARNの取得に失敗しました"
    
    echo "$listener_arn"
}

# ルール一覧の取得
get_rules() {
    local listener_arn="$1"
    log_message "INFO" "ルール一覧の取得を開始します"
    
    aws elbv2 describe-rules \
        --listener-arn "$listener_arn" \
        --query 'Rules[*].{Priority:Priority,RuleArn:RuleArn}' \
        --output json || handle_error "ルール一覧の取得に失敗しました"
}

# ルールの優先度変更
update_rule_priority() {
    local rule_arn="$1"
    local new_priority="$2"
    log_message "INFO" "ルール(${rule_arn})の優先度を${new_priority}に変更します"
    
    aws elbv2 modify-rule \
        --rule-arn "$rule_arn" \
        --conditions file://conditions.json \
        --actions file://actions.json \
        --priority "$new_priority" || handle_error "ルールの優先度変更に失敗しました"
    
    log_message "INFO" "ルールの優先度を変更しました"
}

###########################################
# メイン処理
###########################################

main() {
    log_message "INFO" "スクリプトの実行を開始します"
    
    # 前提条件のチェック
    check_prerequisites
    
    # リスナーARNの取得
    local listener_arn
    listener_arn=$(get_listener_arn)
    log_message "INFO" "取得したリスナーARN: ${listener_arn}"
    
    # ルール一覧の取得と処理
    local rules
    rules=$(get_rules "$listener_arn")
    
    echo "$rules" | jq -c '.[]' | while read -r rule; do
        local priority
        priority=$(echo "$rule" | jq -r '.Priority')
        
        local rule_arn
        rule_arn=$(echo "$rule" | jq -r '.RuleArn')
        
        # 優先度1のルールを見つけた場合、優先度を99に変更
        if [ "$priority" = "1" ]; then
            update_rule_priority "$rule_arn" "99"
            log_message "INFO" "優先度1のルールを優先度99に変更しました"
        fi
    done
    
    log_message "INFO" "スクリプトの実行が完了しました"
}

# スクリプトの実行
main "$@"
