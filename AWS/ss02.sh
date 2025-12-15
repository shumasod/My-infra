#!/bin/bash

# 使用方法: ./sso_audit_report.sh [options]

set -euo pipefail

# 設定
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORT_DIR="${SCRIPT_DIR}/sso_reports"
DATE=$(date '+%Y%m%d_%H%M%S')
LOG_FILE="${REPORT_DIR}/audit_${DATE}.log"

# レポートファイル
USER_REPORT="${REPORT_DIR}/users_report_${DATE}.csv"
GROUP_REPORT="${REPORT_DIR}/groups_report_${DATE}.csv"
PERMISSION_SET_REPORT="${REPORT_DIR}/permission_sets_report_${DATE}.csv"
ACCOUNT_ASSIGNMENT_REPORT="${REPORT_DIR}/account_assignments_report_${DATE}.csv"
SUMMARY_REPORT="${REPORT_DIR}/summary_report_${DATE}.txt"

# オプション初期化
INCLUDE_INACTIVE=false
EXPORT_JSON=false
PROFILE=""
INSTANCE_ARN=""

# ログ関数
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# エラーハンドリング
error_exit() {
    log "ERROR: $1"
    exit 1
}

# 使用方法表示
show_usage() {
    cat << EOF
AWS SSO 監査レポートスクリプト

使用方法:
    $0 [OPTIONS]

OPTIONS:
    -p, --profile PROFILE           AWS プロファイル名
    -i, --instance-arn ARN          SSO インスタンス ARN
    -a, --include-inactive          非アクティブユーザーも含める
    -j, --export-json              JSON形式でもエクスポート
    -h, --help                     このヘルプを表示

例:
    $0 --profile sso-admin --instance-arn arn:aws:sso:::instance/ssoins-xxxxxxxxx
    $0 -p admin -i arn:aws:sso:::instance/ssoins-xxxxxxxxx --include-inactive
EOF
}

# 前提条件チェック
check_prerequisites() {
    if ! command -v aws &> /dev/null; then
        error_exit "AWS CLI がインストールされていません"
    fi
    
    if ! command -v jq &> /dev/null; then
        error_exit "jq がインストールされていません"
    fi
    
    # レポートディレクトリ作成
    mkdir -p "$REPORT_DIR"
    
    # SSO インスタンス ARN の取得（指定されていない場合）
    if [[ -z "$INSTANCE_ARN" ]]; then
        log "SSO インスタンス ARN を取得中..."
        INSTANCE_ARN=$(aws sso-admin list-instances --query 'Instances[0].InstanceArn' --output text ${PROFILE:+--profile $PROFILE} 2>/dev/null || echo "")
        if [[ -z "$INSTANCE_ARN" || "$INSTANCE_ARN" == "None" ]]; then
            error_exit "SSO インスタンスが見つかりません。--instance-arn オプションで指定してください"
        fi
        log "SSO インスタンス ARN: $INSTANCE_ARN"
    fi
}

# ユーザー情報収集
collect_users() {
    log "ユーザー情報を収集中..."
    
    # CSVヘッダー
    echo "UserName,UserId,DisplayName,Email,Status,CreatedDate,LastModifiedDate,ExternalIds" > "$USER_REPORT"
    
    local identity_store_id
    identity_store_id=$(aws sso-admin list-instances --query 'Instances[0].IdentityStoreId' --output text ${PROFILE:+--profile $PROFILE})
    
    local users_json
    users_json=$(aws identitystore list-users --identity-store-id "$identity_store_id" ${PROFILE:+--profile $PROFILE} --output json)
    
    local user_count=0
    local active_count=0
    local inactive_count=0
    
    echo "$users_json" | jq -r '.Users[] | 
        [
            .UserName // "N/A",
            .UserId,
            .DisplayName // "N/A",
            (.Emails[0].Value // "N/A"),
            (.Active | tostring),
            .Meta.CreatedDateTime,
            .Meta.LastModifiedDateTime,
            ((.ExternalIds // []) | map(.Id) | join(";"))
        ] | @csv' >> "$USER_REPORT"
    
    # 統計計算
    user_count=$(echo "$users_json" | jq -r '.Users | length')
    active_count=$(echo "$users_json" | jq -r '[.Users[] | select(.Active == true)] | length')
    inactive_count=$((user_count - active_count))
    
    log "ユーザー統計: 総数=$user_count, アクティブ=$active_count, 非アクティブ=$inactive_count"
    
    # JSON エクスポート
    if [[ "$EXPORT_JSON" == true ]]; then
        echo "$users_json" > "${REPORT_DIR}/users_${DATE}.json"
    fi
}

# グループ情報収集
collect_groups() {
    log "グループ情報を収集中..."
    
    # CSVヘッダー
    echo "GroupName,GroupId,DisplayName,Description,CreatedDate,LastModifiedDate,MemberCount" > "$GROUP_REPORT"
    
    local identity_store_id
    identity_store_id=$(aws sso-admin list-instances --query 'Instances[0].IdentityStoreId' --output text ${PROFILE:+--profile $PROFILE})
    
    local groups_json
    groups_json=$(aws identitystore list-groups --identity-store-id "$identity_store_id" ${PROFILE:+--profile $PROFILE} --output json)
    
    local group_count=0
    group_count=$(echo "$groups_json" | jq -r '.Groups | length')
    
    # 各グループの詳細情報を取得
    echo "$groups_json" | jq -r '.Groups[].GroupId' | while read -r group_id; do
        local group_detail
        group_detail=$(echo "$groups_json" | jq -r --arg gid "$group_id" '.Groups[] | select(.GroupId == $gid)')
        
        # グループメンバー数を取得
        local member_count
        member_count=$(aws identitystore list-group-memberships --identity-store-id "$identity_store_id" --group-id "$group_id" ${PROFILE:+--profile $PROFILE} --query 'GroupMemberships | length' --output text 2>/dev/null || echo "0")
        
        echo "$group_detail" | jq -r --arg mc "$member_count" '
            [
                .DisplayName,
                .GroupId,
                .DisplayName,
                (.Description // "N/A"),
                .Meta.CreatedDateTime,
                .Meta.LastModifiedDateTime,
                $mc
            ] | @csv' >> "$GROUP_REPORT"
    done
    
    log "グループ統計: 総数=$group_count"
    
    # JSON エクスポート
    if [[ "$EXPORT_JSON" == true ]]; then
        echo "$groups_json" > "${REPORT_DIR}/groups_${DATE}.json"
    fi
}

# Permission Set 情報収集
collect_permission_sets() {
    log "Permission Set 情報を収集中..."
    
    # CSVヘッダー
    echo "Name,Arn,Description,SessionDuration,RelayState,CreatedDate,Tags" > "$PERMISSION_SET_REPORT"
    
    local permission_sets_json
    permission_sets_json=$(aws sso-admin list-permission-sets --instance-arn "$INSTANCE_ARN" ${PROFILE:+--profile $PROFILE} --output json)
    
    local ps_count=0
    ps_count=$(echo "$permission_sets_json" | jq -r '.PermissionSets | length')
    
    # 各Permission Setの詳細情報を取得
    echo "$permission_sets_json" | jq -r '.PermissionSets[]' | while read -r ps_arn; do
        local ps_detail
        ps_detail=$(aws sso-admin describe-permission-set --instance-arn "$INSTANCE_ARN" --permission-set-arn "$ps_arn" ${PROFILE:+--profile $PROFILE} --output json)
        
        # タグ情報取得
        local tags
        tags=$(aws sso-admin list-tags-for-resource --instance-arn "$INSTANCE_ARN" --resource-arn "$ps_arn" ${PROFILE:+--profile $PROFILE} --query 'Tags' --output json 2>/dev/null || echo "[]")
        
        echo "$ps_detail" | jq -r --argjson tags_data "$tags" '
            .PermissionSet |
            [
                .Name,
                .PermissionSetArn,
                (.Description // "N/A"),
                (.SessionDuration // "N/A"),
                (.RelayState // "N/A"),
                .CreatedDate,
                ($tags_data | map(.Key + "=" + .Value) | join(";"))
            ] | @csv' >> "$PERMISSION_SET_REPORT"
    done
    
    log "Permission Set 統計: 総数=$ps_count"
    
    # JSON エクスポート
    if [[ "$EXPORT_JSON" == true ]]; then
        echo "$permission_sets_json" > "${REPORT_DIR}/permission_sets_${DATE}.json"
    fi
}

# アカウント割り当て情報収集
collect_account_assignments() {
    log "アカウント割り当て情報を収集中..."
    
    # CSVヘッダー
    echo "AccountId,PermissionSetName,PermissionSetArn,PrincipalType,PrincipalId,PrincipalName" > "$ACCOUNT_ASSIGNMENT_REPORT"
    
    local identity_store_id
    identity_store_id=$(aws sso-admin list-instances --query 'Instances[0].IdentityStoreId' --output text ${PROFILE:+--profile $PROFILE})
    
    # Organization のアカウント一覧を取得
    local accounts
    accounts=$(aws organizations list-accounts --query 'Accounts[].Id' --output text ${PROFILE:+--profile $PROFILE} 2>/dev/null || echo "")
    
    if [[ -z "$accounts" ]]; then
        log "WARNING: Organizations のアカウント情報を取得できません。SSO の直接的な割り当てのみをチェックします"
        # 代替方法: SSO から既知のアカウント割り当てを取得
        accounts=$(aws sso-admin list-permission-sets --instance-arn "$INSTANCE_ARN" ${PROFILE:+--profile $PROFILE} --query 'PermissionSets[]' --output text | head -1 | xargs -I {} aws sso-admin list-accounts-for-provisioned-permission-set --instance-arn "$INSTANCE_ARN" --permission-set-arn {} ${PROFILE:+--profile $PROFILE} --query 'AccountIds' --output text 2>/dev/null || echo "")
    fi
    
    local assignment_count=0
    
    for account_id in $accounts; do
        local permission_sets
        permission_sets=$(aws sso-admin list-permission-sets-provisioned-to-account --instance-arn "$INSTANCE_ARN" --account-id "$account_id" ${PROFILE:+--profile $PROFILE} --query 'PermissionSets' --output text 2>/dev/null || echo "")
        
        for ps_arn in $permission_sets; do
            # Permission Set名を取得
            local ps_name
            ps_name=$(aws sso-admin describe-permission-set --instance-arn "$INSTANCE_ARN" --permission-set-arn "$ps_arn" ${PROFILE:+--profile $PROFILE} --query 'PermissionSet.Name' --output text 2>/dev/null || echo "Unknown")
            
            # 割り当て情報を取得
            local assignments
            assignments=$(aws sso-admin list-account-assignments --instance-arn "$INSTANCE_ARN" --account-id "$account_id" --permission-set-arn "$ps_arn" ${PROFILE:+--profile $PROFILE} --output json 2>/dev/null || echo '{"AccountAssignments":[]}')
            
            echo "$assignments" | jq -r --arg account "$account_id" --arg ps_name "$ps_name" --arg ps_arn "$ps_arn" '
                .AccountAssignments[] |
                [
                    $account,
                    $ps_name,
                    $ps_arn,
                    .PrincipalType,
                    .PrincipalId,
                    "TBD"
                ] | @csv' >> "$ACCOUNT_ASSIGNMENT_REPORT"
            
            assignment_count=$((assignment_count + $(echo "$assignments" | jq -r '.AccountAssignments | length')))
        done
    done
    
    log "アカウント割り当て統計: 総数=$assignment_count"
}

# サマリーレポート生成
generate_summary() {
    log "サマリーレポートを生成中..."
    
    local user_count group_count ps_count assignment_count
    user_count=$(tail -n +2 "$USER_REPORT" | wc -l)
    group_count=$(tail -n +2 "$GROUP_REPORT" | wc -l)
    ps_count=$(tail -n +2 "$PERMISSION_SET_REPORT" | wc -l)
    assignment_count=$(tail -n +2 "$ACCOUNT_ASSIGNMENT_REPORT" | wc -l)
    
    cat > "$SUMMARY_REPORT" << EOF
=====================================
AWS SSO 監査レポート サマリー
=====================================
生成日時: $(date '+%Y-%m-%d %H:%M:%S')
SSO インスタンス: $INSTANCE_ARN

統計情報:
---------
ユーザー数:              $user_count
グループ数:              $group_count
Permission Set数:        $ps_count
アカウント割り当て数:    $assignment_count

生成されたレポートファイル:
---------------------------
ユーザーレポート:        $USER_REPORT
グループレポート:        $GROUP_REPORT
Permission Setレポート:  $PERMISSION_SET_REPORT
アカウント割り当て:      $ACCOUNT_ASSIGNMENT_REPORT

レコメンデーション:
------------------
1. 非アクティブユーザーの定期的な見直し
2. 未使用のPermission Setの確認
3. 過剰な権限付与の監査
4. グループベースの権限管理の活用

詳細は各CSVレポートを参照してください。
EOF
    
    log "サマリーレポートを生成しました: $SUMMARY_REPORT"
}

# オプション解析
parse_options() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--profile)
                PROFILE="$2"
                shift 2
                ;;
            -i|--instance-arn)
                INSTANCE_ARN="$2"
                shift 2
                ;;
            -a|--include-inactive)
                INCLUDE_INACTIVE=true
                shift
                ;;
            -j|--export-json)
                EXPORT_JSON=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                error_exit "未知のオプション: $1"
                ;;
        esac
    done
}

# メイン処理
main() {
    parse_options "$@"
    check_prerequisites
    
    log "AWS SSO 監査レポート生成を開始します"
    log "レポート出力先: $REPORT_DIR"
    
    # データ収集
    collect_users
    collect_groups
    collect_permission_sets
    collect_account_assignments
    
    # サマリー生成
    generate_summary
    
    log "監査レポート生成が完了しました"
    echo
    echo "生成されたレポート:"
    echo "  サマリー: $SUMMARY_REPORT"
    echo "  ユーザー: $USER_REPORT"
    echo "  グループ: $GROUP_REPORT"
    echo "  Permission Set: $PERMISSION_SET_REPORT"
    echo "  アカウント割り当て: $ACCOUNT_ASSIGNMENT_REPORT"
}

# スクリプト実行
main "$@"
