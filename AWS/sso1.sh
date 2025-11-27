#!/bin/bash

# AWS SSO セッション管理・自動ログインスクリプト
# 使用方法: ./sso_session_manager.sh [profile_name] [action]

set -euo pipefail

# 設定
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/sso_session.log"
CONFIG_FILE="${HOME}/.aws/config"
CREDENTIALS_FILE="${HOME}/.aws/credentials"

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
AWS SSO セッション管理スクリプト

使用方法:
    $0 [PROFILE] [ACTION]

ACTION:
    login     - SSOログインを実行
    status    - セッション状態を確認
    logout    - SSOログアウトを実行
    refresh   - セッションを更新
    list      - 利用可能なプロファイルを一覧表示
    auto      - 自動ログイン（期限切れの場合のみ）

例:
    $0 dev-profile login
    $0 prod-profile status
    $0 auto
EOF
}

# AWS CLI の存在確認
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        error_exit "AWS CLI がインストールされていません"
    fi
}

# プロファイル一覧取得
list_profiles() {
    log "利用可能なSSOプロファイル:"
    if [[ -f "$CONFIG_FILE" ]]; then
        grep -E "^\[profile" "$CONFIG_FILE" | sed 's/\[profile \(.*\)\]/\1/' | while read -r profile; do
            if aws configure get sso_start_url --profile "$profile" &>/dev/null; then
                echo "  - $profile"
            fi
        done
    else
        log "AWS設定ファイルが見つかりません: $CONFIG_FILE"
    fi
}

# セッション状態確認
check_session_status() {
    local profile="$1"
    
    if ! aws configure get sso_start_url --profile "$profile" &>/dev/null; then
        return 2  # SSOプロファイルではない
    fi
    
    # セッション確認のため簡単なコマンドを実行
    if aws sts get-caller-identity --profile "$profile" &>/dev/null; then
        return 0  # セッション有効
    else
        return 1  # セッション無効
    fi
}

# SSOログイン実行
sso_login() {
    local profile="$1"
    
    log "プロファイル '$profile' でSSOログインを開始..."
    
    if ! aws configure get sso_start_url --profile "$profile" &>/dev/null; then
        error_exit "プロファイル '$profile' はSSOプロファイルではありません"
    fi
    
    # ログイン実行
    if aws sso login --profile "$profile"; then
        log "プロファイル '$profile' のSSOログインが完了しました"
        
        # 認証情報を確認
        if aws sts get-caller-identity --profile "$profile" &>/dev/null; then
            local account_id=$(aws sts get-caller-identity --profile "$profile" --query Account --output text 2>/dev/null || echo "N/A")
            local user_arn=$(aws sts get-caller-identity --profile "$profile" --query Arn --output text 2>/dev/null || echo "N/A")
            log "アカウント ID: $account_id"
            log "ユーザー ARN: $user_arn"
        fi
    else
        error_exit "プロファイル '$profile' のSSOログインに失敗しました"
    fi
}

# SSOログアウト実行
sso_logout() {
    local profile="$1"
    
    log "プロファイル '$profile' でSSOログアウトを実行..."
    
    if aws sso logout --profile "$profile"; then
        log "プロファイル '$profile' のSSOログアウトが完了しました"
    else
        log "WARNING: プロファイル '$profile' のSSOログアウトでエラーが発生しました"
    fi
}

# セッション更新
refresh_session() {
    local profile="$1"
    
    log "プロファイル '$profile' のセッションを更新中..."
    sso_logout "$profile"
    sleep 2
    sso_login "$profile"
}

# 自動ログイン（全プロファイルの期限切れをチェック）
auto_login() {
    log "自動ログイン処理を開始..."
    
    local login_required=false
    
    if [[ -f "$CONFIG_FILE" ]]; then
        grep -E "^\[profile" "$CONFIG_FILE" | sed 's/\[profile \(.*\)\]/\1/' | while read -r profile; do
            if aws configure get sso_start_url --profile "$profile" &>/dev/null; then
                check_session_status "$profile"
                case $? in
                    0)
                        log "プロファイル '$profile': セッション有効"
                        ;;
                    1)
                        log "プロファイル '$profile': セッション期限切れ - ログインが必要"
                        sso_login "$profile"
                        login_required=true
                        ;;
                    2)
                        # SSOプロファイルではない場合はスキップ
                        ;;
                esac
            fi
        done
    fi
    
    if [[ "$login_required" == false ]]; then
        log "すべてのSSOセッションは有効です"
    fi
}

# メイン処理
main() {
    check_aws_cli
    
    # 引数チェック
    if [[ $# -eq 0 ]]; then
        show_usage
        exit 0
    fi
    
    case "$1" in
        "list")
            list_profiles
            ;;
        "auto")
            auto_login
            ;;
        *)
            if [[ $# -ne 2 ]]; then
                show_usage
                exit 1
            fi
            
            local profile="$1"
            local action="$2"
            
            case "$action" in
                "login")
                    sso_login "$profile"
                    ;;
                "logout")
                    sso_logout "$profile"
                    ;;
                "status")
                    check_session_status "$profile"
                    case $? in
                        0)
                            log "プロファイル '$profile': セッション有効"
                            aws sts get-caller-identity --profile "$profile" 2>/dev/null || true
                            ;;
                        1)
                            log "プロファイル '$profile': セッション期限切れまたは無効"
                            ;;
                        2)
                            error_exit "プロファイル '$profile' はSSOプロファイルではありません"
                            ;;
                    esac
                    ;;
                "refresh")
                    refresh_session "$profile"
                    ;;
                *)
                    show_usage
                    exit 1
                    ;;
            esac
            ;;
    esac
}

# スクリプト実行
main "$@"
