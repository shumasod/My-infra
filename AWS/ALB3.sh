#!/bin/bash

###########################################
# ALBリスナールール優先度管理スクリプト
#
# 使い方:
#   ./alb-rule-priority-manager.sh change   # 優先度変更
#   ./alb-rule-priority-manager.sh restore  # 優先度復元
#   ./alb-rule-priority-manager.sh --help   # ヘルプ表示
#
# 必要な環境変数（config.envで定義推奨）:
#   AWS_REGION, AWS_PROFILE, LISTENER_ARN, EC2_RULE_ARN, LAMBDA_RULE_ARN
#
###########################################

set -e
set -o pipefail

# 定数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/alb-cli-$(date '+%Y%m%d').log"
PRIORITIES_FILE="${SCRIPT_DIR}/original_priorities.json"

# 設定ファイルの読み込み
CONFIG_FILE="${SCRIPT_DIR}/config.env"
if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
fi

# 必須環境変数
AWS_REGION="${AWS_REGION:-ap-northeast-1}"
AWS_PROFILE="${AWS_PROFILE:-default}"
LISTENER_ARN="${LISTENER_ARN:-}"
EC2_RULE_ARN="${EC2_RULE_ARN:-}"
LAMBDA_RULE_ARN="${LAMBDA_RULE_ARN:-}"

# ログディレクトリ作成
mkdir -p "$LOG_DIR"

###########################################
# ユーティリティ関数
###########################################

log_message() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" | tee -a "$LOG_FILE"
}

handle_error() {
    local error_message="$1"
    log_message "ERROR" "$error_message"
    exit 1
}

show_help() {
    cat <<EOF
ALBリスナールール優先度管理スクリプト

使い方:
  $0 change    # 優先度変更
  $0 restore   # 優先度復元
  $0 --help    # このヘルプを表示

必要な環境変数（config.envで定義推奨）:
  AWS_REGION, AWS_PROFILE, LISTENER_ARN, EC2_RULE_ARN, LAMBDA_RULE_ARN
EOF
    exit 1
}

check_prerequisites() {
    log_message "INFO" "前提条件のチェックを開始します"
    if ! command -v aws &> /dev/null; then
        handle_error "AWS CLIがインストールされていません"
    fi
    if ! command -v jq &> /dev/null; then
        handle_error "jqがインストールされていません"
    fi
    if ! aws sts get-caller-identity --profile "${AWS_PROFILE}" &> /dev/null; then
        handle_error "AWS認証情報の取得に失敗しました。AWS_PROFILEを確認してください。"
    fi
    for v in LISTENER_ARN EC2_RULE_ARN LAMBDA_RULE_ARN; do
        if [[ -z "${!v}" ]]; then
            handle_error "${v}が設定されていません"
        fi
    done
    log_message "INFO" "前提条件のチェックが完了しました"
}

check_rule_exists() {
    local rule_arn="$1"
    local description="$2"
    log_message "INFO" "${description}の存在確認を開始します"
    if ! aws elbv2 describe-rules --profile "${AWS_PROFILE}" --region "${AWS_REGION}" --rule-arns "$rule_arn" &> /dev/null; then
        handle_error "${description}(${rule_arn})が存在しません"
    fi
    log_message "INFO" "${description}の存在を確認しました"
}

get_current_rule_priorities() {
    log_message "INFO" "現在のルール優先順位を取得中..."
    local rule_priorities
    rule_priorities=$(aws elbv2 describe-rules \
        --profile "${AWS_PROFILE}" \
        --region "${AWS_REGION}" \
        --listener-arn "${LISTENER_ARN}" \
        --query 'Rules[*].{RuleArn:RuleArn,Priority:Priority}' \
        --output json) || handle_error "ルールの優先順位の取得に失敗しました"
    echo "$rule_priorities" > "$PRIORITIES_FILE"
    log_message "INFO" "現在のルール優先順位を保存しました: $PRIORITIES_FILE"
}

check_priority_conflict() {
    log_message "INFO" "優先度競合チェックを実行します"
    local priorities
    priorities=$(aws elbv2 describe-rules \
        --profile "${AWS_PROFILE}" \
        --region "${AWS_REGION}" \
        --listener-arn "${LISTENER_ARN}" \
        --query 'Rules[*].{RuleArn:RuleArn,Priority:Priority}' \
        --output json)
    local exist_1 exist_2
    exist_1=$(echo "$priorities" | jq -r '.[] | select(.Priority == "1" and .RuleArn != "'"$LAMBDA_RULE_ARN"'") | .RuleArn')
    exist_2=$(echo "$priorities" | jq -r '.[] | select(.Priority == "2" and .RuleArn != "'"$EC2_RULE_ARN"'") | .RuleArn')
    if [[ -n "$exist_1" ]]; then
        log_message "WARN" "優先度1が他のルール($exist_1)で使われています。競合の可能性あり。"
    fi
    if [[ -n "$exist_2" ]]; then
        log_message "WARN" "優先度2が他のルール($exist_2)で使われています。競合の可能性あり。"
    fi
}

set_rule_priorities() {
    log_message "INFO" "ルール優先度を変更中..."
    check_priority_conflict
    if ! aws elbv2 set-rule-priorities \
        --profile "${AWS_PROFILE}" \
        --region "${AWS_REGION}" \
        --rule-priorities "[{\"RuleArn\":\"${LAMBDA_RULE_ARN}\",\"Priority\":1},{\"RuleArn\":\"${EC2_RULE_ARN}\",\"Priority\":2}]" 2>>"$LOG_FILE"; then
        handle_error "優先度の変更に失敗しました（詳細はログを参照）"
    fi
    log_message "INFO" "優先度の変更が完了しました"
}

restore_rule_priorities() {
    log_message "INFO" "優先度を復元中..."
    if [[ ! -f "$PRIORITIES_FILE" ]]; then
        log_message "WARN" "復元用の優先度ファイルが見つかりません"
        return 1
    fi
    local restore_json
    restore_json=$(jq -c 'map(select(.Priority != null) | {RuleArn: .RuleArn, Priority: (.Priority | tonumber)})' "$PRIORITIES_FILE")
    if [[ -z "$restore_json" ]]; then
        handle_error "優先度復元用JSONの生成に失敗しました"
    fi
    if ! aws elbv2 set-rule-priorities \
        --profile "${AWS_PROFILE}" \
        --region "${AWS_REGION}" \
        --rule-priorities "$restore_json" 2>>"$LOG_FILE"; then
        handle_error "優先度の復元に失敗しました（詳細はログを参照）"
    fi
    log_message "INFO" "優先度の復元が完了しました"
}

main() {
    if [[ $# -eq 0 || "$1" == "--help" ]]; then
        show_help
    fi

    local command="$1"
    check_prerequisites
    check_rule_exists "$EC2_RULE_ARN" "EC2用ルール"
    check_rule_exists "$LAMBDA_RULE_ARN" "Lambda用ルール"

    case "$command" in
        "change")
            get_current_rule_priorities
            set_rule_priorities
            log_message "INFO" "ルール優先度の変更が完了しました。復元する場合は 'restore' コマンドを実行してください。"
            ;;
        "restore")
            restore_rule_priorities
            log_message "INFO" "ルール優先度の復元が完了しました。"
            ;;
        *)
            handle_error "不明なコマンド: $command (有効なコマンド: change, restore, --help)"
            ;;
    esac
    log_message "INFO" "スクリプトの実行が完了しました"
}

main "$@"
