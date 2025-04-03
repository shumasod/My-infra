#!/bin/bash

###########################################
# ALBリスナールール優先度管理スクリプト
# 
# 機能:
# - リスナールールの優先度の変更
# - 作業後の優先度の復元
# - エラーハンドリング
###########################################

# エラーハンドリングを設定
set -e
set -o pipefail

# スクリプト実行ディレクトリの取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/alb-cli-$(date '+%Y%m%d').log"

# 設定ファイルの読み込み
CONFIG_FILE="${SCRIPT_DIR}/config.env"
if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
fi

# 必須環境変数の確認または設定
AWS_REGION="${AWS_REGION:-ap-northeast-1}"
AWS_PROFILE="${AWS_PROFILE:-default}"
LISTENER_ARN="${LISTENER_ARN:-}"
EC2_RULE_ARN="${EC2_RULE_ARN:-}"
LAMBDA_RULE_ARN="${LAMBDA_RULE_ARN:-}"

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
    
    # 必須パラメータの確認
    if [[ -z "$LISTENER_ARN" ]]; then
        handle_error "LISTENER_ARNが設定されていません"
    fi
    
    if [[ -z "$EC2_RULE_ARN" ]]; then
        handle_error "EC2_RULE_ARNが設定されていません"
    fi
    
    if [[ -z "$LAMBDA_RULE_ARN" ]]; then
        handle_error "LAMBDA_RULE_ARNが設定されていません"
    fi
    
    log_message "INFO" "前提条件のチェックが完了しました"
}

# リスナールールの存在確認
check_rule_exists() {
    local rule_arn="$1"
    local description="$2"
    log_message "INFO" "${description}の存在確認を開始します"
    
    aws elbv2 describe-rules \
        --profile "${AWS_PROFILE}" \
        --region "${AWS_REGION}" \
        --rule-arns "$rule_arn" &> /dev/null || {
            handle_error "${description}(${rule_arn})が存在しません"
        }
    
    log_message "INFO" "${description}の存在を確認しました"
}

# 現在のルール優先順位を取得して保存
get_current_rule_priorities() {
    log_message "INFO" "現在のルール優先順位を取得中..."
    
    local rule_priorities
    rule_priorities=$(aws elbv2 describe-rules \
        --profile "${AWS_PROFILE}" \
        --region "${AWS_REGION}" \
        --listener-arn "${LISTENER_ARN}" \
        --query 'Rules[*].{RuleArn:RuleArn,Priority:Priority}') || {
            handle_error "ルールの優先順位の取得に失敗しました"
        }
    
    # 結果をJSONファイルに保存
    echo "$rule_priorities" > "${SCRIPT_DIR}/original_priorities.json"
    log_message "INFO" "現在のルール優先順位を保存しました: ${SCRIPT_DIR}/original_priorities.json"
    
    return 0
}

# ルール優先度の変更
set_rule_priorities() {
    log_message "INFO" "ルール優先度を変更中..."
    
    # 優先度変更コマンドを実行
    aws elbv2 set-rule-priorities \
        --profile "${AWS_PROFILE}" \
        --region "${AWS_REGION}" \
        --rule-priorities "[{\"RuleArn\":\"${LAMBDA_RULE_ARN}\",\"Priority\":1},{\"RuleArn\":\"${EC2_RULE_ARN}\",\"Priority\":2}]" || {
            handle_error "優先度の変更に失敗しました"
        }
    
    log_message "INFO" "優先度の変更が完了しました"
    return 0
}

# 優先度の復元
restore_rule_priorities() {
    log_message "INFO" "優先度を復元中..."
    
    # 保存した優先度が存在するか確認
    if [[ ! -f "${SCRIPT_DIR}/original_priorities.json" ]]; then
        log_message "WARN" "復元用の優先度ファイルが見つかりません"
        return 1
    fi
    
    # 優先度復元用のJSON形式に変換
    local restore_json
    restore_json=$(jq 'map({RuleArn: .RuleArn, Priority: (.Priority | tonumber)})' "${SCRIPT_DIR}/original_priorities.json")
    
    # 優先度を復元
    aws elbv2 set-rule-priorities \
        --profile "${AWS_PROFILE}" \
        --region "${AWS_REGION}" \
        --rule-priorities "$restore_json" || {
            handle_error "優先度の復元に失敗しました"
        }
    
    log_message "INFO" "優先度の復元が完了しました"
    return 0
}

###########################################
# メイン処理
###########################################

main() {
    log_message "INFO" "スクリプトの実行を開始します"
    
    # コマンドライン引数の解析
    local command="change"  # デフォルトはルール変更
    if [[ $# -gt 0 ]]; then
        command="$1"
    fi
    
    # 前提条件のチェック
    check_prerequisites
    
    # 各ルールの存在確認
    check_rule_exists "$EC2_RULE_ARN" "EC2用ルール"
    check_rule_exists "$LAMBDA_RULE_ARN" "Lambda用ルール"
    
    case "$command" in
        "change")
            # 現在のルール優先順位を取得して保存
            get_current_rule_priorities
            
            # ルール優先度の変更
            set_rule_priorities
            
            log_message "INFO" "ルール優先度の変更が完了しました。復元する場合は 'restore' コマンドを実行してください。"
            ;;
        
        "restore")
            # 優先度の復元
            restore_rule_priorities
            
            log_message "INFO" "ルール優先度の復元が完了しました。"
            ;;
        
        *)
            handle_error "不明なコマンド: $command (有効なコマンド: change, restore)"
            ;;
    esac
    
    log_message "INFO" "スクリプトの実行が完了しました"
}

# スクリプトの実行
main "$@"