#!/bin/bash

# AWS SSO 自動プロビジョニング・同期スクリプト
# 使用方法: ./sso_provisioning_sync.sh [options]

set -euo pipefail

# 設定
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/config"
LOG_DIR="${SCRIPT_DIR}/logs"
DATE=$(date '+%Y%m%d_%H%M%S')
LOG_FILE="${LOG_DIR}/provisioning_${DATE}.log"

# 設定ファイル
USER_CONFIG="${CONFIG_DIR}/users.json"
GROUP_CONFIG="${CONFIG_DIR}/groups.json"
PERMISSION_SET_CONFIG="${CONFIG_DIR}/permission_sets.json"
ASSIGNMENT_CONFIG="${CONFIG_DIR}/assignments.json"

# オプション初期化
DRY_RUN=false
PROFILE=""
INSTANCE_ARN=""
FORCE_UPDATE=false
BACKUP_ENABLED=true
NOTIFICATION_ENABLED=false
WEBHOOK_URL=""

# ログ関数
log() {
    local level="$1"
    shift
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] - $*" | tee -a "$LOG_FILE"
}

# エラーハンドリング
error_exit() {
    log "ERROR" "$1"
    send_notification "ERROR" "SSO プロビジョニングエラー: $1"
    exit 1
}

# 成功通知
success_log() {
    log "SUCCESS" "$1"
    send_notification "SUCCESS" "$1"
}

# 通知送信
send_notification() {
    if [[ "$NOTIFICATION_ENABLED" == true && -n "$WEBHOOK_URL" ]]; then
        local level="$1"
        local message="$2"
        local color="good"
        
        case "$level" in
            "ERROR") color="danger" ;;
            "WARNING") color="warning" ;;
            "SUCCESS") color="good" ;;
        esac
        
        curl -X POST "$WEBHOOK_URL" \
            -H 'Content-type: application/json' \
            --data "{
                \"attachments\": [{
                    \"color\": \"$color\",
                    \"title\": \"AWS SSO プロビジョニング\",
                    \"text\": \"$message\",
                    \"ts\": $(date +%s)
                }]
            }" &>/dev/null || true
    fi
}

# 使用方法表示
show_usage() {
    cat << EOF
AWS SSO 自動プロビジョニング・同期スクリプト

使用方法:
    $0 [OPTIONS] [COMMAND]

OPTIONS:
    -p, --profile PROFILE           AWS プロファイル名
    -i, --instance-arn ARN          SSO インスタンス ARN
    -d, --dry-run                   実際の変更を行わずにシミュレーション
    -f, --force                     強制更新（確認スキップ）
    -n, --notify WEBHOOK_URL        Slack通知用のWebhook URL
    --no-backup                     バックアップを無効化
    -h, --help                      このヘルプを表示

COMMAND:
    sync-users                      ユーザーの同期
    sync-groups                     グループの同期
    sync-permission-sets            Permission Setの同期
    sync-assignments               アカウント割り当ての同期
    sync-all                       すべての同期（デフォルト）
    init-config                    設定ファイルの初期化
    backup                         現在の設定のバックアップ

例:
    $0 --profile sso-admin sync-all
    $0 -p admin -d sync-users
    $0 --force --notify https://hooks.slack.com/... sync-all
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
    
    # ディレクトリ作成
    mkdir -p "$CONFIG_DIR" "$LOG_DIR"
    
    # SSO インスタンス ARN の取得（指定されていない場合）
    if [[ -z "$INSTANCE_ARN" ]]; then
        log "INFO" "SSO インスタンス ARN を取得中..."
        INSTANCE_ARN=$(aws sso-admin list-instances --query 'Instances[0].InstanceArn' --output text ${PROFILE:+--profile $PROFILE} 2>/dev/null || echo "")
        if [[ -z "$INSTANCE_ARN" || "$INSTANCE_ARN" == "None" ]]; then
            error_exit "SSO インスタンスが見つかりません。--instance-arn オプションで指定してください"
        fi
        log "INFO" "SSO インスタンス ARN: $INSTANCE_ARN"
    fi
}

# バックアップ作成
create_backup() {
    if [[ "$BACKUP_ENABLED" == false ]]; then
        return 0
    fi
    
    log "INFO" "現在の設定をバックアップ中..."
    local backup_dir="${SCRIPT_DIR}/backups/backup_${DATE}"
    mkdir -p "$backup_dir"
    
    local identity_store_id
    identity_store_id=$(aws sso-admin list-instances --query 'Instances[0].IdentityStoreId' --output text ${PROFILE:+--profile $PROFILE})
    
    # ユーザーバックアップ
    aws identitystore list-users --identity-store-id "$identity_store_id" ${PROFILE:+--profile $PROFILE} > "${backup_dir}/users_backup.json"
    
    # グループバックアップ
    aws identitystore list-groups --identity-store-id "$identity_store_id" ${PROFILE:+--profile $PROFILE} > "${backup_dir}/groups_backup.json"
    
    # Permission Setバックアップ
    aws sso-admin list-permission-sets --instance-arn "$INSTANCE_ARN" ${PROFILE:+--profile $PROFILE} > "${backup_dir}/permission_sets_backup.json"
    
    log "INFO" "バックアップ完了: $backup_dir"
}

# 設定ファイル初期化
init_config() {
    log "INFO" "設定ファイルを初期化中..."
    
    # ユーザー設定テンプレート
    cat > "$USER_CONFIG" << 'EOF'
{
  "users": [
    {
      "userName": "example.user",
      "displayName": "Example User",
      "name": {
        "givenName": "Example",
        "familyName": "User"
      },
      "emails": [
        {
          "value": "example.user@company.com",
          "type": "work",
          "primary": true
        }
      ],
      "active": true,
      "groups": ["Developers", "AllUsers"]
    }
  ]
}
EOF
    
    # グループ設定テンプレート
    cat > "$GROUP_CONFIG" << 'EOF'
{
  "groups": [
    {
      "displayName": "Developers",
      "description": "開発者グループ"
    },
    {
      "displayName": "AllUsers",
      "description": "全ユーザーグループ"
    },
    {
      "displayName": "Admins",
      "description": "管理者グループ"
    }
  ]
}
EOF
    
    # Permission Set設定テンプレート
    cat > "$PERMISSION_SET_CONFIG" << 'EOF'
{
  "permissionSets": [
    {
      "name": "DeveloperAccess",
      "description": "開発者用アクセス権限",
      "sessionDuration": "PT8H",
      "managedPolicies": [
        "arn:aws:iam::aws:policy/PowerUserAccess"
      ],
      "inlinePolicy": {
        "Version": "2012-10-17",
        "Statement": [
          {
            "Effect": "Deny",
            "Action": [
              "iam:*User*",
              "iam:*Role*"
            ],
            "Resource": "*"
          }
        ]
      }
    },
    {
      "name": "ReadOnlyAccess",
      "description": "読み取り専用アクセス",
      "sessionDuration": "PT4H",
      "managedPolicies": [
        "arn:aws:iam::aws:policy/ReadOnlyAccess"
      ]
    }
  ]
}
EOF
    
    # アカウント割り当て設定テンプレート
    cat > "$ASSIGNMENT_CONFIG" << 'EOF'
{
  "assignments": [
    {
      "accountId": "123456789012",
      "permissionSetName": "DeveloperAccess",
      "principalType": "GROUP",
      "principalName": "Developers"
    },
    {
      "accountId": "123456789012",
      "permissionSetName": "ReadOnlyAccess",
      "principalType": "GROUP",
      "principalName": "AllUsers"
    }
  ]
}
EOF
    
    log "SUCCESS" "設定ファイルの初期化が完了しました"
    echo "設定ファイルを編集してから同期を実行してください:"
    echo "  - ユーザー: $USER_CONFIG"
    echo "  - グループ: $GROUP_CONFIG"
    echo "  - Permission Set: $PERMISSION_SET_CONFIG"
    echo "  - 割り当て: $ASSIGNMENT_CONFIG"
}

# ユーザー同期
sync_users() {
    log "INFO" "ユーザー同期を開始..."
    
    if [[ ! -f "$USER_CONFIG" ]]; then
        error_exit "ユーザー設定ファイルが見つかりません: $USER_CONFIG"
    fi
    
    local identity_store_id
    identity_store_id=$(aws sso-admin list-instances --query 'Instances[0].IdentityStoreId' --output text ${PROFILE:+--profile $PROFILE})
    
    # 既存ユーザー取得
    local existing_users
    existing_users=$(aws identitystore list-users --identity-store-id "$identity_store_id" ${PROFILE:+--profile $PROFILE} --output json)
    
    local created=0 updated=0 errors=0
    
    # 設定ファイルからユーザーを読み込み
    jq -r '.users[] | @base64' "$USER_CONFIG" | while read -r user_data; do
        local user
        user=$(echo "$user_data" | base64 --decode)
        
        local username
        username=$(echo "$user" | jq -r '.userName')
        
        # 既存ユーザーチェック
        local existing_user_id
        existing_user_id=$(echo "$existing_users" | jq -r --arg un "$username" '.Users[] | select(.UserName == $un) | .UserId' | head -1)
        
        if [[ -n "$existing_user_id" ]]; then
            # ユーザー更新
            log "INFO" "ユーザー '$username' を更新中..."
            if [[ "$DRY_RUN" == false ]]; then
                if update_user "$identity_store_id" "$existing_user_id" "$user"; then
                    ((updated++))
                    log "SUCCESS" "ユーザー '$username' を更新しました"
                else
                    ((errors++))
                    log "ERROR" "ユーザー '$username' の更新に失敗しました"
                fi
            else
                log "INFO" "[DRY RUN] ユーザー '$username' を更新します"
                ((updated++))
            fi
        else
            # ユーザー作成
            log "INFO" "ユーザー '$username' を作成中..."
            if [[ "$DRY_RUN" == false ]]; then
                if create_user "$identity_store_id" "$user"; then
                    ((created++))
                    log "SUCCESS" "ユーザー '$username' を作成しました"
                else
                    ((errors++))
                    log "ERROR" "ユーザー '$username' の作成に失敗しました"
                fi
            else
                log "INFO" "[DRY RUN] ユーザー '$username' を作成します"
                ((created++))
            fi
        fi
    done
    
    log "INFO" "ユーザー同期完了: 作成=$created, 更新=$updated, エラー=$errors"
}

# ユーザー作成
create_user() {
    local identity_store_id="$1"
    local user_data="$2"
    
    local temp_file
    temp_file=$(mktemp)
    echo "$user_data" > "$temp_file"
    
    if aws identitystore create-user --identity-store-id "$identity_store_id" --cli-input-json "file://$temp_file" ${PROFILE:+--profile $PROFILE} &>/dev/null; then
        rm -f "$temp_file"
        return 0
    else
        rm -f "$temp_file"
        return 1
    fi
}

# ユーザー更新
update_user() {
    local identity_store_id="$1"
    local user_id="$2"
    local user_data="$3"
    
    # 更新用のJSONを構築（UserIdを追加）
    local update_data
    update_data=$(echo "$user_data" | jq --arg uid "$user_id" '. + {UserId: $uid}')
    
    local temp_file
    temp_file=$(mktemp)
    echo "$update_data" > "$temp_file"
    
    if aws identitystore update-user --identity-store-id "$identity_store_id" --user-id "$user_id" --cli-input-json "file://$temp_file" ${PROFILE:+--profile $PROFILE} &>/dev/null; then
        rm -f "$temp_file"
        return 0
    else
        rm -f "$temp_file"
        return 1
    fi
}

# グループ同期
sync_groups() {
    log "INFO" "グループ同期を開始..."
    
    if [[ ! -f "$GROUP_CONFIG" ]]; then
        error_exit "グループ設定ファイルが見つかりません: $GROUP_CONFIG"
    fi
    
    local identity_store_id
    identity_store_id=$(aws sso-admin list-instances --query 'Instances[0].IdentityStoreId' --output text ${PROFILE:+--profile $PROFILE})
    
    # 既存グループ取得
    local existing_groups
    existing_groups=$(aws identitystore list-groups --identity-store-id "$identity_store_id" ${PROFILE:+--profile $PROFILE} --output json)
    
    local created=0 updated=0 errors=0
    
    # 設定ファイルからグループを読み込み
    jq -r '.groups[] | @base64' "$GROUP_CONFIG" | while read -r group_data; do
        local group
        group=$(echo "$group_data" | base64 --decode)
        
        local group_name
        group_name=$(echo "$group" | jq -r '.displayName')
        
        # 既存グループチェック
        local existing_group_id
        existing_group_id=$(echo "$existing_groups" | jq -r --arg gn "$group_name" '.Groups[] | select(.DisplayName == $gn) | .GroupId' | head -1)
        
        if [[ -n "$existing_group_id" ]]; then
            # グループ更新
            log "INFO" "グループ '$group_name' を更新中..."
            if [[ "$DRY_RUN" == false ]]; then
                if update_group "$identity_store_id" "$existing_group_id" "$group"; then
                    ((updated++))
                    log "SUCCESS" "グループ '$group_name' を更新しました"
                else
                    ((errors++))
                    log "ERROR" "グループ '$group_name' の更新に失敗しました"
                fi
            else
                log "INFO" "[DRY RUN] グループ '$group_name' を更新します"
                ((updated++))
            fi
        else
            # グループ作成
            log "INFO" "グループ '$group_name' を作成中..."
            if [[ "$DRY_RUN" == false ]]; then
                if create_group "$identity_store_id" "$group"; then
                    ((created++))
                    log "SUCCESS" "グループ '$group_name' を作成しました"
                else
                    ((errors++))
                    log "ERROR" "グループ '$group_name' の作成に失敗しました"
                fi
            else
                log "INFO" "[DRY RUN] グループ '$group_name' を作成します"
                ((created++))
            fi
        fi
    done
    
    log "INFO" "グループ同期完了: 作成=$created, 更新=$updated, エラー=$errors"
}

# グループ作成
create_group() {
    local identity_store_id="$1"
    local group_data="$2"
    
    local temp_file
    temp_file=$(mktemp)
    echo "$group_data" > "$temp_file"
    
    if aws identitystore create-group --identity-store-id "$identity_store_id" --cli-input-json "file://$temp_file" ${PROFILE:+--profile $PROFILE} &>/dev/null; then
        rm -f "$temp_file"
        return 0
    else
        rm -f "$temp_file"
        return 1
    fi
}

# グループ更新
update_group() {
    local identity_store_id="$1"
    local group_id="$2"
    local group_data="$3"
    
    # 更新用のJSONを構築（GroupIdを追加）
    local update_data
    update_data=$(echo "$group_data" | jq --arg gid "$group_id" '. + {GroupId: $gid}')
    
    local temp_file
    temp_file=$(mktemp)
    echo "$update_data" > "$temp_file"
    
    if aws identitystore update-group --identity-store-id "$identity_store_id" --group-id "$group_id" --cli-input-json "file://$temp_file" ${PROFILE:+--profile $PROFILE} &>/dev/null; then
        rm -f "$temp_file"
        return 0
    else
        rm -f "$temp_file"
        return 1
    fi
}

# Permission Set同期
sync_permission_sets() {
    log "INFO" "Permission Set同期を開始..."
    
    if [[ ! -f "$PERMISSION_SET_CONFIG" ]]; then
        error_exit "Permission Set設定ファイルが見つかりません: $PERMISSION_SET_CONFIG"
    fi
    
    # 既存Permission Set取得
    local existing_ps
    existing_ps=$(aws sso-admin list-permission-sets --instance-arn "$INSTANCE_ARN" ${PROFILE:+--profile $PROFILE} --output json)
    
    local created=0 updated=0 errors=0
    
    # 設定ファイルからPermission Setを読み込み
    jq -r '.permissionSets[] | @base64' "$PERMISSION_SET_CONFIG" | while read -r ps_data; do
        local ps
        ps=$(echo "$ps_data" | base64 --decode)
        
        local ps_name
        ps_name=$(echo "$ps" | jq -r '.name')
        
        # 既存Permission SetチェックとARN取得
        local existing_ps_arn=""
        for ps_arn in $(echo "$existing_ps" | jq -r '.PermissionSets[]'); do
            local existing_name
            existing_name=$(aws sso-admin describe-permission-set --instance-arn "$INSTANCE_ARN" --permission-set-arn "$ps_arn" ${PROFILE:+--profile $PROFILE} --query 'PermissionSet.Name' --output text 2>/dev/null || echo "")
            if [[ "$existing_name" == "$ps_name" ]]; then
                existing_ps_arn="$ps_arn"
                break
            fi
        done
        
        if [[ -n "$existing_ps_arn" ]]; then
            # Permission Set更新
            log "INFO" "Permission Set '$ps_name' を更新中..."
            if [[ "$DRY_RUN" == false ]]; then
                if update_permission_set "$existing_ps_arn" "$ps"; then
                    ((updated++))
                    log "SUCCESS" "Permission Set '$ps_name' を更新しました"
                else
                    ((errors++))
                    log "ERROR" "Permission Set '$ps_name' の更新に失敗しました"
                fi
            else
                log "INFO" "[DRY RUN] Permission Set '$ps_name' を更新します"
                ((updated++))
            fi
        else
            # Permission Set作成
            log "INFO" "Permission Set '$ps_name' を作成中..."
            if [[ "$DRY_RUN" == false ]]; then
                if create_permission_set "$ps"; then
                    ((created++))
                    log "SUCCESS" "Permission Set '$ps_name' を作成しました"
                else
                    ((errors++))
                    log "ERROR" "Permission Set '$ps_name' の作成に失敗しました"
                fi
            else
                log "INFO" "[DRY RUN] Permission Set '$ps_name' を作成します"
                ((created++))
            fi
        fi
    done
    
    log "INFO" "Permission Set同期完了: 作成=$created, 更新=$updated, エラー=$errors"
}

# Permission Set作成
create_permission_set() {
    local ps_data="$1"
    
    local name description session_duration
    name=$(echo "$ps_data" | jq -r '.name')
    description=$(echo "$ps_data" | jq -r '.description // ""')
    session_duration=$(echo "$ps_data" | jq -r '.sessionDuration // "PT1H"')
    
    local ps_arn
    ps_arn=$(aws sso-admin create-permission-set \
        --instance-arn "$INSTANCE_ARN" \
        --name "$name" \
        --description "$description" \
        --session-duration "$session_duration" \
        ${PROFILE:+--profile $PROFILE} \
        --query 'PermissionSet.PermissionSetArn' --output text 2>/dev/null)
    
    if [[ -z "$ps_arn" ]]; then
        return 1
    fi
    
    # マネージドポリシーのアタッチ
    if echo "$ps_data" | jq -e '.managedPolicies' >/dev/null; then
        echo "$ps_data" | jq -r '.managedPolicies[]?' | while read -r policy_arn; do
            aws sso-admin attach-managed-policy-to-permission-set \
                --instance-arn "$INSTANCE_ARN" \
                --permission-set-arn "$ps_arn" \
                --managed-policy-arn "$policy_arn" \
                ${PROFILE:+--profile $PROFILE} &>/dev/null || true
        done
    fi
    
    # インラインポリシーの設定
    if echo "$ps_data" | jq -e '.inlinePolicy' >/dev/null; then
        local inline_policy
        inline_policy=$(echo "$ps_data" | jq -c '.inlinePolicy')
        aws sso-admin put-inline-policy-to-permission-set \
            --instance-arn "$INSTANCE_ARN" \
            --permission-set-arn "$ps_arn" \
            --inline-policy "$inline_policy" \
            ${PROFILE:+--profile $PROFILE} &>/dev/null || true
    fi
    
    return 0
}

# Permission Set更新
update_permission_set() {
    local ps_arn="$1"
    local ps_data="$2"
    
    local description session_duration
    description=$(echo "$ps_data" | jq -r '.description // ""')
    session_duration=$(echo "$ps_data" | jq -r '.sessionDuration // "PT1H"')
    
    # 基本情報更新
    aws sso-admin update-permission-set \
        --instance-arn "$INSTANCE_ARN" \
        --permission-set-arn "$ps_arn" \
        --description "$description" \
        --session-duration "$session_duration" \
        ${PROFILE:+--profile $PROFILE} &>/dev/null || return 1
    
    # 既存のマネージドポリシーをデタッチ
    aws sso-admin list-managed-policies-in-permission-set \
        --instance-arn "$INSTANCE_ARN" \
        --permission-set-arn "$ps_arn" \
        ${PROFILE:+--profile $PROFILE} \
        --query 'AttachedManagedPolicies[].Arn' --output text 2>/dev/null | \
    xargs -r -n1 aws sso-admin detach-managed-policy-from-permission-set \
        --instance-arn "$INSTANCE_ARN" \
        --permission-set-arn "$ps_arn" \
        --managed-policy-arn ${PROFILE:+--profile $PROFILE} || true
    
    # 新しいマネージドポリシーをアタッチ
    if echo "$ps_data" | jq -e '.managedPolicies' >/dev/null; then
        echo "$ps_data" | jq -r '.managedPolicies[]?' | while read -r policy_arn; do
            aws sso-admin attach-managed-policy-to-permission-set \
                --instance-arn "$INSTANCE_ARN" \
                --permission-set-arn "$ps_arn" \
                --managed-policy-arn "$policy_arn" \
                ${PROFILE:+--profile $PROFILE} &>/dev/null || true
        done
    fi
    
    # インラインポリシーの更新
    if echo "$ps_data" | jq -e '.inlinePolicy' >/dev/null; then
        local inline_policy
        inline_policy=$(echo "$ps_data" | jq -c '.inlinePolicy')
        aws sso-admin put-inline-policy-to-permission-set \
            --instance-arn "$INSTANCE_ARN" \
            --permission-set-arn "$ps_arn" \
            --inline-policy "$inline_policy" \
            ${PROFILE:+--profile $PROFILE} &>/dev/null || true
    else
        # インラインポリシーを削除
        aws sso-admin delete-inline-policy-from-permission-set \
            --instance-arn "$INSTANCE_ARN" \
            --permission-set-arn "$ps_arn" \
            ${PROFILE:+--profile $PROFILE} &>/dev/null || true
    fi
    
    return 0
}

# アカウント割り当て同期
sync_assignments() {
    log "INFO" "アカウント割り当て同期を開始..."
    
    if [[ ! -f "$ASSIGNMENT_CONFIG" ]]; then
        error_exit "アカウント割り当て設定ファイルが見つかりません: $ASSIGNMENT_CONFIG"
    fi
    
    local identity_store_id
    identity_store_id=$(aws sso-admin list-instances --query 'Instances[0].IdentityStoreId' --output text ${PROFILE:+--profile $PROFILE})
    
    local created=0 errors=0
    
    # 設定ファイルから割り当てを読み込み
    jq -r '.assignments[] | @base64' "$ASSIGNMENT_CONFIG" | while read -r assignment_data; do
        local assignment
        assignment=$(echo "$assignment_data" | base64 --decode)
        
        local account_id ps_name principal_type principal_name
        account_id=$(echo "$assignment" | jq -r '.accountId')
        ps_name=$(echo "$assignment" | jq -r '.permissionSetName')
        principal_type=$(echo "$assignment" | jq -r '.principalType')
        principal_name=$(echo "$assignment" | jq -r '.principalName')
        
        # Permission Set ARN を取得
        local ps_arn
        ps_arn=$(get_permission_set_arn_by_name "$ps_name")
        if [[ -z "$ps_arn" ]]; then
            log "ERROR" "Permission Set '$ps_name' が見つかりません"
            ((errors++))
            continue
        fi
        
        # Principal ID を取得
        local principal_id
        if [[ "$principal_type" == "USER" ]]; then
            principal_id=$(get_user_id_by_name "$identity_store_id" "$principal_name")
        elif [[ "$principal_type" == "GROUP" ]]; then
            principal_id=$(get_group_id_by_name "$identity_store_id" "$principal_name")
        else
            log "ERROR" "サポートされていないプリンシパルタイプ: $principal_type"
            ((errors++))
            continue
        fi
        
        if [[ -z "$principal_id" ]]; then
            log "ERROR" "$principal_type '$principal_name' が見つかりません"
            ((errors++))
            continue
        fi
        
        # 既存の割り当てをチェック
        local existing_assignment
        existing_assignment=$(aws sso-admin list-account-assignments \
            --instance-arn "$INSTANCE_ARN" \
            --account-id "$account_id" \
            --permission-set-arn "$ps_arn" \
            ${PROFILE:+--profile $PROFILE} \
            --query "AccountAssignments[?PrincipalId=='$principal_id' && PrincipalType=='$principal_type']" \
            --output text 2>/dev/null || echo "")
        
        if [[ -z "$existing_assignment" ]]; then
            # アカウント割り当て作成
            log "INFO" "アカウント割り当てを作成中: $account_id -> $ps_name -> $principal_type:$principal_name"
            if [[ "$DRY_RUN" == false ]]; then
                if aws sso-admin create-account-assignment \
                    --instance-arn "$INSTANCE_ARN" \
                    --target-id "$account_id" \
                    --target-type "AWS_ACCOUNT" \
                    --permission-set-arn "$ps_arn" \
                    --principal-type "$principal_type" \
                    --principal-id "$principal_id" \
                    ${PROFILE:+--profile $PROFILE} &>/dev/null; then
                    ((created++))
                    log "SUCCESS" "アカウント割り当てを作成しました"
                else
                    ((errors++))
                    log "ERROR" "アカウント割り当ての作成に失敗しました"
                fi
            else
                log "INFO" "[DRY RUN] アカウント割り当てを作成します"
                ((created++))
            fi
        else
            log "INFO" "アカウント割り当ては既に存在します: $account_id -> $ps_name -> $principal_type:$principal_name"
        fi
    done
    
    log "INFO" "アカウント割り当て同期完了: 作成=$created, エラー=$errors"
}

# Permission Set ARN を名前で取得
get_permission_set_arn_by_name() {
    local ps_name="$1"
    local permission_sets
    permission_sets=$(aws sso-admin list-permission-sets --instance-arn "$INSTANCE_ARN" ${PROFILE:+--profile $PROFILE} --query 'PermissionSets' --output text)
    
    for ps_arn in $permission_sets; do
        local existing_name
        existing_name=$(aws sso-admin describe-permission-set --instance-arn "$INSTANCE_ARN" --permission-set-arn "$ps_arn" ${PROFILE:+--profile $PROFILE} --query 'PermissionSet.Name' --output text 2>/dev/null || echo "")
        if [[ "$existing_name" == "$ps_name" ]]; then
            echo "$ps_arn"
            return 0
        fi
    done
    
    return 1
}

# ユーザーIDを名前で取得
get_user_id_by_name() {
    local identity_store_id="$1"
    local user_name="$2"
    
    aws identitystore list-users --identity-store-id "$identity_store_id" ${PROFILE:+--profile $PROFILE} \
        --query "Users[?UserName=='$user_name'].UserId" --output text 2>/dev/null | head -1
}

# グループIDを名前で取得
get_group_id_by_name() {
    local identity_store_id="$1"
    local group_name="$2"
    
    aws identitystore list-groups --identity-store-id "$identity_store_id" ${PROFILE:+--profile $PROFILE} \
        --query "Groups[?DisplayName=='$group_name'].GroupId" --output text 2>/dev/null | head -1
}

# オプション解析
parse_options() {
    local command="sync-all"
    
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
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -f|--force)
                FORCE_UPDATE=true
                shift
                ;;
            -n|--notify)
                NOTIFICATION_ENABLED=true
                WEBHOOK_URL="$2"
                shift 2
                ;;
            --no-backup)
                BACKUP_ENABLED=false
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            sync-users|sync-groups|sync-permission-sets|sync-assignments|sync-all|init-config|backup)
                command="$1"
                shift
                ;;
            *)
                error_exit "未知のオプション: $1"
                ;;
        esac
    done
