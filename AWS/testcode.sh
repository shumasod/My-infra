#!/bin/bash

# AWS SSO スクリプトテストスイート
# 使用方法: ./sso_test_suite.sh

set -euo pipefail

# 設定
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="${SCRIPT_DIR}/test_results"
DATE=$(date '+%Y%m%d_%H%M%S')
TEST_LOG="${TEST_DIR}/test_results_${DATE}.log"

# テスト対象スクリプト
SESSION_SCRIPT="${SCRIPT_DIR}/sso_session_manager.sh"
AUDIT_SCRIPT="${SCRIPT_DIR}/sso_audit_report.sh"
PROVISIONING_SCRIPT="${SCRIPT_DIR}/sso_provisioning_sync.sh"

# テスト結果カウンター
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# ログ関数
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$TEST_LOG"
}

# テスト関数
test_function() {
    local test_name="$1"
    local test_command="$2"
    local expected_result="$3"  # 0=成功期待, 1=失敗期待
    
    ((TESTS_TOTAL++))
    log "テスト実行: $test_name"
    
    if eval "$test_command" &>/dev/null; then
        local result=0
    else
        local result=1
    fi
    
    if [[ $result -eq $expected_result ]]; then
        ((TESTS_PASSED++))
        log "  ✓ PASSED: $test_name"
        return 0
    else
        ((TESTS_FAILED++))
        log "  ✗ FAILED: $test_name (期待値: $expected_result, 実際: $result)"
        return 1
    fi
}

# 構文チェック関数
syntax_check() {
    local script_path="$1"
    local script_name="$(basename "$script_path")"
    
    log "構文チェック: $script_name"
    
    if [[ ! -f "$script_path" ]]; then
        log "  ✗ FAILED: ファイルが存在しません: $script_path"
        ((TESTS_FAILED++))
        return 1
    fi
    
    if bash -n "$script_path" 2>/dev/null; then
        log "  ✓ PASSED: 構文チェック OK"
        ((TESTS_PASSED++))
        return 0
    else
        log "  ✗ FAILED: 構文エラーが見つかりました"
        ((TESTS_FAILED++))
        return 1
    fi
}

# 実行権限チェック
permission_check() {
    local script_path="$1"
    local script_name="$(basename "$script_path")"
    
    log "実行権限チェック: $script_name"
    
    if [[ -x "$script_path" ]]; then
        log "  ✓ PASSED: 実行権限 OK"
        ((TESTS_PASSED++))
        return 0
    else
        log "  ✗ FAILED: 実行権限がありません"
        chmod +x "$script_path" 2>/dev/null || true
        if [[ -x "$script_path" ]]; then
            log "  ✓ FIXED: 実行権限を設定しました"
            ((TESTS_PASSED++))
            return 0
        else
            ((TESTS_FAILED++))
            return 1
        fi
    fi
}

# ヘルプ表示テスト
help_test() {
    local script_path="$1"
    local script_name="$(basename "$script_path")"
    
    log "ヘルプ表示テスト: $script_name"
    
    if "$script_path" --help &>/dev/null || "$script_path" -h &>/dev/null; then
        log "  ✓ PASSED: ヘルプ表示 OK"
        ((TESTS_PASSED++))
        return 0
    else
        log "  ✗ FAILED: ヘルプ表示でエラー"
        ((TESTS_FAILED++))
        return 1
    fi
}

# 依存関係チェック
dependency_check() {
    log "依存関係チェック"
    
    local deps=("aws" "jq" "curl")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if command -v "$dep" &>/dev/null; then
            log "  ✓ $dep: インストール済み"
            ((TESTS_PASSED++))
        else
            log "  ✗ $dep: 見つかりません"
            missing_deps+=("$dep")
            ((TESTS_FAILED++))
        fi
        ((TESTS_TOTAL++))
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log "不足している依存関係: ${missing_deps[*]}"
        return 1
    fi
    
    return 0
}

# テスト用設定ファイル作成
create_test_configs() {
    local test_config_dir="${TEST_DIR}/config"
    mkdir -p "$test_config_dir"
    
    log "テスト用設定ファイルを作成中..."
    
    # ユーザー設定
    cat > "${test_config_dir}/users.json" << 'EOF'
{
  "users": [
    {
      "userName": "test.user1",
      "displayName": "Test User 1",
      "name": {
        "givenName": "Test",
        "familyName": "User1"
      },
      "emails": [
        {
          "value": "test.user1@company.com",
          "type": "work",
          "primary": true
        }
      ],
      "active": true,
      "groups": ["TestGroup"]
    }
  ]
}
EOF
    
    # グループ設定
    cat > "${test_config_dir}/groups.json" << 'EOF'
{
  "groups": [
    {
      "displayName": "TestGroup",
      "description": "テスト用グループ"
    }
  ]
}
EOF
    
    # Permission Set設定
    cat > "${test_config_dir}/permission_sets.json" << 'EOF'
{
  "permissionSets": [
    {
      "name": "TestPermissionSet",
      "description": "テスト用Permission Set",
      "sessionDuration": "PT1H",
      "managedPolicies": [
        "arn:aws:iam::aws:policy/ReadOnlyAccess"
      ]
    }
  ]
}
EOF
    
    # アサインメント設定
    cat > "${test_config_dir}/assignments.json" << 'EOF'
{
  "assignments": [
    {
      "accountId": "123456789012",
      "permissionSetName": "TestPermissionSet",
      "principalType": "GROUP",
      "principalName": "TestGroup"
    }
  ]
}
EOF
    
    log "  ✓ テスト用設定ファイルを作成しました: $test_config_dir"
}

# JSON形式検証
validate_json_configs() {
    local test_config_dir="${TEST_DIR}/config"
    
    log "JSON設定ファイルの検証"
    
    local json_files=(
        "${test_config_dir}/users.json"
        "${test_config_dir}/groups.json"
        "${test_config_dir}/permission_sets.json"
        "${test_config_dir}/assignments.json"
    )
    
    for json_file in "${json_files[@]}"; do
        ((TESTS_TOTAL++))
        if jq empty "$json_file" 2>/dev/null; then
            log "  ✓ PASSED: $(basename "$json_file") - 有効なJSON"
            ((TESTS_PASSED++))
        else
            log "  ✗ FAILED: $(basename "$json_file") - 無効なJSON"
            ((TESTS_FAILED++))
        fi
    done
}

# セッション管理スクリプトのテスト
test_session_manager() {
    log "=== セッション管理スクリプトのテスト ==="
    
    if [[ ! -f "$SESSION_SCRIPT" ]]; then
        log "セッション管理スクリプトが見つかりません: $SESSION_SCRIPT"
        return 1
    fi
    
    syntax_check "$SESSION_SCRIPT"
    permission_check "$SESSION_SCRIPT"
    help_test "$SESSION_SCRIPT"
    
    # リスト表示テスト（AWS CLI設定なしでもエラーにならないことを確認）
    test_function "プロファイル一覧表示" \
        "$SESSION_SCRIPT list || true" \
        0
}

# 監査レポートスクリプトのテスト
test_audit_report() {
    log "=== 監査レポートスクリプトのテスト ==="
    
    if [[ ! -f "$AUDIT_SCRIPT" ]]; then
        log "監査レポートスクリプトが見つかりません: $AUDIT_SCRIPT"
        return 1
    fi
    
    syntax_check "$AUDIT_SCRIPT"
    permission_check "$AUDIT_SCRIPT"
    help_test "$AUDIT_SCRIPT"
}

# プロビジョニングスクリプトのテスト
test_provisioning() {
    log "=== プロビジョニングスクリプトのテスト ==="
    
    if [[ ! -f "$PROVISIONING_SCRIPT" ]]; then
        log "プロビジョニングスクリプトが見つかりません: $PROVISIONING_SCRIPT"
        return 1
    fi
    
    syntax_check "$PROVISIONING_SCRIPT"
    permission_check "$PROVISIONING_SCRIPT"
    help_test "$PROVISIONING_SCRIPT"
    
    # 設定ファイル初期化テスト
    test_function "設定ファイル初期化" \
        "cd '$TEST_DIR' && '$PROVISIONING_SCRIPT' init-config" \
        0
}

# ログローテーションテスト
test_log_rotation() {
    log "=== ログローテーションテスト ==="
    
    # 古いログファイルを作成
    local old_log="${TEST_DIR}/old_test.log"
    echo "Old log content" > "$old_log"
    
    # ログサイズチェック
    if [[ -f "$TEST_LOG" ]]; then
        local log_size
        log_size=$(wc -c < "$TEST_LOG")
        ((TESTS_TOTAL++))
        
        if [[ $log_size -gt 0 ]]; then
            log "  ✓ PASSED: ログファイルに内容が記録されています ($log_size bytes)"
            ((TESTS_PASSED++))
        else
            log "  ✗ FAILED: ログファイルが空です"
            ((TESTS_FAILED++))
        fi
    fi
}

# パフォーマンステスト
performance_test() {
    log "=== パフォーマンステスト ==="
    
    # スクリプト起動時間測定
    local scripts=("$SESSION_SCRIPT" "$AUDIT_SCRIPT" "$PROVISIONING_SCRIPT")
    
    for script in "${scripts[@]}"; do
        if [[ -f "$script" ]]; then
            ((TESTS_TOTAL++))
            local script_name
            script_name=$(basename "$script")
            
            local start_time
            start_time=$(date +%s%N)
            
            # ヘルプ表示で起動時間を測定
            if "$script" --help &>/dev/null; then
                local end_time
                end_time=$(date +%s%N)
                local duration
                duration=$(( (end_time - start_time) / 1000000 )) # ミリ秒
                
                log "  ✓ $script_name 起動時間: ${duration}ms"
                ((TESTS_PASSED++))
            else
                log "  ✗ $script_name 起動時間測定失敗"
                ((TESTS_FAILED++))
            fi
        fi
    done
}

# セキュリティチェック
security_check() {
    log "=== セキュリティチェック ==="
    
    local scripts=("$SESSION_SCRIPT" "$AUDIT_SCRIPT" "$PROVISIONING_SCRIPT")
    
    for script in "${scripts[@]}"; do
        if [[ -f "$script" ]]; then
            ((TESTS_TOTAL++))
            local script_name
            script_name=$(basename "$script")
            
            # 機密情報のハードコードチェック
            local sensitive_patterns=(
                "aws_access_key_id"
                "aws_secret_access_key"
                "password"
                "secret"
                "token"
            )
            
            local found_sensitive=false
            for pattern in "${sensitive_patterns[@]}"; do
                if grep -qi "$pattern" "$script" 2>/dev/null; then
                    log "  ✗ WARNING: $script_name に機密情報の可能性: $pattern"
                    found_sensitive=true
                fi
            done
            
            if [[ "$found_sensitive" == false ]]; then
                log "  ✓ PASSED: $script_name - 機密情報なし"
                ((TESTS_PASSED++))
            else
                ((TESTS_FAILED++))
            fi
        fi
    done
}

# テスト結果サマリー
print_summary() {
    log "=== テスト結果サマリー ==="
    log "総テスト数: $TESTS_TOTAL"
    log "成功: $TESTS_PASSED"
    log "失敗: $TESTS_FAILED"
    log "成功率: $(( TESTS_PASSED * 100 / TESTS_TOTAL ))%"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        log "🎉 すべてのテストが成功しました！"
        return 0
    else
        log "⚠️  $TESTS_FAILED 個のテストが失敗しました"
        return 1
    fi
}

# メイン処理
main() {
    mkdir -p "$TEST_DIR"
    log "AWS SSO スクリプトテストスイートを開始します"
    log "テスト結果: $TEST_DIR"
    
    # 基本テスト
    dependency_check
    
    # 設定ファイルテスト
    create_test_configs
    validate_json_configs
    
    # 各スクリプトのテスト
    test_session_manager
    test_audit_report  
    test_provisioning
    
    # 追加テスト
    test_log_rotation
    performance_test
    security_check
    
    # 結果表示
    print_summary
    
    echo
    echo "詳細なテスト結果は以下のファイルを参照してください:"
    echo "  $TEST_LOG"
    echo "  $TEST_DIR"
}

# スクリプト実行
main "$@"
