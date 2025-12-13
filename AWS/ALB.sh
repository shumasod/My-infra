#!/bin/bash

set -e
set -u
set -o pipefail

###########################################
# 設定値
###########################################

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
    LISTENER_PORT="${LISTENER_PORT:-443}"
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
    
    # AWS CLIのバージョンチェック (v2推奨)
    local aws_version
    aws_version=$(aws --version 2>&1 | cut -d' ' -f1 | cut -d'/' -f2 | cut -d'.' -f1)
    if [[ "$aws_version" -lt 2 ]]; then
        log_message "WARN" "AWS CLI v2の使用を推奨します（現在: v${aws_version}）"
    fi
    
    # AWS認証情報の確認
    if ! aws sts get-caller-identity --profile "${AWS_PROFILE}" --region "${AWS_REGION}" &> /dev/null; then
        handle_error "AWS認証情報の取得に失敗しました。AWS_PROFILEとリージョンを確認してください。"
    fi
    
    log_message "INFO" "前提条件のチェックが完了しました"
}

###########################################
# ALB操作関数
###########################################

# ロードバランサーARNの取得
get_load_balancer_arn() {
    log_message "INFO" "ロードバランサーARNの取得を開始します (Name: ${LOAD_BALANCER_NAME})"
    
    local lb_arn
    lb_arn=$(aws elbv2 describe-load-balancers \
        --profile "${AWS_PROFILE}" \
        --region "${AWS_REGION}" \
        --names "${LOAD_BALANCER_NAME}" \
        --query "LoadBalancers[0].LoadBalancerArn" \
        --output text 2>&1) || handle_error "ロードバランサーARNの取得に失敗しました: ${lb_arn}"
    
    if [[ -z "$lb_arn" ]] || [[ "$lb_arn" == "None" ]] || [[ "$lb_arn" == "null" ]]; then
        handle_error "ロードバランサー '${LOAD_BALANCER_NAME}' が見つかりません"
    fi
    
    log_message "INFO" "ロードバランサーARNを取得しました"
    echo "$lb_arn"
}

# リスナーARNの取得
get_listener_arn() {
    local lb_arn="$1"
    local port="${LISTENER_PORT}"
    
    log_message "INFO" "リスナーARNの取得を開始します (Port: ${port})"
    
    local listener_arn
    listener_arn=$(aws elbv2 describe-listeners \
        --profile "${AWS_PROFILE}" \
        --region "${AWS_REGION}" \
        --load-balancer-arn "$lb_arn" \
        --query "Listeners[?Port==\`${port}\`].ListenerArn | [0]" \
        --output text 2>&1) || handle_error "リスナーARNの取得に失敗しました: ${listener_arn}"
    
    if [[ -z "$listener_arn" ]] || [[ "$listener_arn" == "None" ]] || [[ "$listener_arn" == "null" ]]; then
        handle_error "指定されたポート(${port})のリスナーが見つかりません"
    fi
    
    log_message "INFO" "リスナーARNを取得しました"
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
        --query 'Rules[*].{Priority:Priority,RuleArn:RuleArn,IsDefault:IsDefault}' \
        --output json 2>&1) || handle_error "ルール一覧の取得に失敗しました: ${rules}"
    
    if [[ -z "$rules" ]] || ! echo "$rules" | jq -e . >/dev/null 2>&1; then
        handle_error "ルール一覧の取得結果が不正です"
    fi
    
    log_message "INFO" "ルール一覧を取得しました (件数: $(echo "$rules" | jq 'length'))"
    echo "$rules"
}

# 優先度の存在チェック
check_priority_exists() {
    local rules="$1"
    local priority="$2"
    local exclude_arn="${3:-}"
    
    local exists
    if [[ -n "$exclude_arn" ]]; then
        exists=$(echo "$rules" | jq -r --arg priority "$priority" --arg arn "$exclude_arn" \
            '.[] | select(.Priority == $priority and .RuleArn != $arn and .IsDefault == false) | .RuleArn')
    else
        exists=$(echo "$rules" | jq -r --arg priority "$priority" \
            '.[] | select(.Priority == $priority and .IsDefault == false) | .RuleArn')
    fi
    
    if [[ -n "$exists" ]]; then
        return 0  # 存在する
    else
        return 1  # 存在しない
    fi
}

# 利用可能な優先度を見つける
find_available_priority() {
    local rules="$1"
    local start_priority="${2:-99}"
    
    log_message "INFO" "利用可能な優先度を検索します (開始: ${start_priority})"
    
    local priority=$start_priority
    while [[ $priority -le 50000 ]]; do
        if ! check_priority_exists "$rules" "$priority"; then
            log_message "INFO" "利用可能な優先度を見つけました: ${priority}"
            echo "$priority"
            return 0
        fi
        ((priority++))
    done
    
    handle_error "利用可能な優先度が見つかりませんでした"
}

# ルールの優先度変更 (修正版)
update_rule_priority() {
    local rule_arn="$1"
    local new_priority="$2"
    
    log_message "INFO" "ルールの優先度を変更します"
    log_message "INFO" "  RuleArn: ${rule_arn}"
    log_message "INFO" "  新しい優先度: ${new_priority}"
    
    # 優先度のみを変更 (conditionsとactionsは指定しない)
    local result
    result=$(aws elbv2 modify-rule \
        --profile "${AWS_PROFILE}" \
        --region "${AWS_REGION}" \
        --rule-arn "$rule_arn" \
        --priority "$new_priority" 2>&1) || handle_error "ルールの優先度変更に失敗しました: ${result}"
    
    log_message "INFO" "ルールの優先度を変更しました"
}

# 複数ルールの優先度を一括設定
set_rule_priorities() {
    local rule_priorities="$1"
    
    log_message "INFO" "複数ルールの優先度を一括設定します"
    log_message "DEBUG" "設定内容: ${rule_priorities}"
    
    local result
    result=$(aws elbv2 set-rule-priorities \
        --profile "${AWS_PROFILE}" \
        --region "${AWS_REGION}" \
        --rule-priorities "$rule_priorities" 2>&1) || handle_error "ルールの優先度設定に失敗しました: ${result}"
    
    log_message "INFO" "ルールの優先度を設定しました"
}

# ルール情報の表示
display_rules() {
    local rules="$1"
    local title="${2:-現在のルール設定}"
    
    log_message "INFO" "$title"
    echo "$rules" | jq -r '.[] | select(.IsDefault == false) | "  Priority: \(.Priority), RuleArn: \(.RuleArn)"' | tee -a "$LOG_FILE"
}

###########################################
# メイン処理
###########################################

main() {
    log_message "INFO" "========================================="
    log_message "INFO" "スクリプトの実行を開始します"
    log_message "INFO" "========================================="
    log_message "INFO" "設定情報:"
    log_message "INFO" "  AWS Profile: ${AWS_PROFILE}"
    log_message "INFO" "  AWS Region: ${AWS_REGION}"
    log_message "INFO" "  Load Balancer: ${LOAD_BALANCER_NAME}"
    log_message "INFO" "  Listener Port: ${LISTENER_PORT}"
    log_message "INFO" "========================================="
    
    # 前提条件のチェック
    check_prerequisites
    
    # ロードバランサーARNの取得
    local lb_arn
    lb_arn=$(get_load_balancer_arn)
    log_message "DEBUG" "LoadBalancer ARN: ${lb_arn}"
    
    # リスナーARNの取得
    local listener_arn
    listener_arn=$(get_listener_arn "$lb_arn")
    log_message "DEBUG" "Listener ARN: ${listener_arn}"
    
    # ルール一覧の取得
    local rules
    rules=$(get_rules "$listener_arn")
    
    # 現在のルール設定を表示
    display_rules "$rules" "変更前のルール設定"
    
    # 優先度1のルールを見つける
    local priority1_rule_arn
    priority1_rule_arn=$(echo "$rules" | jq -r '.[] | select(.Priority == "1" and .IsDefault == false) | .RuleArn')
    
    if [[ -n "$priority1_rule_arn" ]] && [[ "$priority1_rule_arn" != "null" ]]; then
        log_message "INFO" "優先度1のルールが見つかりました"
        
        # 優先度99が利用可能かチェック
        local target_priority
        if check_priority_exists "$rules" "99" "$priority1_rule_arn"; then
            log_message "WARN" "優先度99は既に使用されています。利用可能な優先度を検索します"
            target_priority=$(find_available_priority "$rules" 99)
        else
            target_priority=99
        fi
        
        # 優先度を変更
        update_rule_priority "$priority1_rule_arn" "$target_priority"
        log_message "INFO" "優先度1のルールを優先度${target_priority}に変更しました"
        
        # 変更後のルール一覧を取得して表示
        sleep 2  # AWS側の反映待ち
        rules=$(get_rules "$listener_arn")
        display_rules "$rules" "変更後のルール設定"
    else
        log_message "WARN" "優先度1のルールが見つかりませんでした"
        log_message "INFO" "処理をスキップします"
    fi
    
    log_message "INFO" "========================================="
    log_message "INFO" "スクリプトの実行が完了しました"
    log_message "INFO" "========================================="
}

# スクリプトの実行
main "$@"
