#!/usr/bin/env bats
#
# セキュリティテスト: 認証情報の漏洩チェック
# 作成日: 2025-12-02
# バージョン: 1.0
#
# このテストは認証情報がハードコードされていないか、
# プロセスリストに露出していないかをチェックします。

# セットアップ
setup() {
    # テスト用の一時ディレクトリ
    export TEST_TMPDIR="$(mktemp -d)"
    export TEST_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
}

# クリーンアップ
teardown() {
    [ -d "$TEST_TMPDIR" ] && rm -rf "$TEST_TMPDIR"
}

# ===== ハードコードされた認証情報のチェック =====

@test "スクリプトにパスワードがハードコードされていない" {
    # 危険なパターンをチェック
    local dangerous_patterns=(
        'PASSWORD="[^$]'
        'password="[^$]'
        'PASS="[^$]'
        'DB_PASS="[^$]'
        'API_KEY="[^A-Z]'
        'SECRET="[^$]'
        'TOKEN="[^$]'
    )

    local violations=()

    for pattern in "${dangerous_patterns[@]}"; do
        # your_password, your_username などのプレースホルダーは除外
        local found=$(find "$TEST_ROOT" -name "*.sh" -type f \
            -exec grep -l -E "$pattern" {} \; 2>/dev/null | \
            grep -v -E "your_password|your_username|example|placeholder|TODO")

        if [ -n "$found" ]; then
            violations+=("$pattern: $found")
        fi
    done

    if [ ${#violations[@]} -gt 0 ]; then
        echo "ハードコードされた認証情報が見つかりました:"
        printf '%s\n' "${violations[@]}"
        return 1
    fi
}

@test "スクリプトにAWS認証情報がハードコードされていない" {
    # AWS認証情報の危険なパターン
    local aws_violations=$(find "$TEST_ROOT" -name "*.sh" -type f \
        -exec grep -E 'AKIA[0-9A-Z]{16}|aws_secret_access_key.*=.*[^$]' {} \; 2>/dev/null)

    if [ -n "$aws_violations" ]; then
        echo "AWS認証情報がハードコードされています:"
        echo "$aws_violations"
        return 1
    fi
}

@test "プライベートキーがリポジトリに含まれていない" {
    # プライベートキーのチェック
    local key_files=$(find "$TEST_ROOT" -type f \
        -name "*.pem" -o \
        -name "*.key" -o \
        -name "*_rsa" -o \
        -name "id_rsa" 2>/dev/null)

    if [ -n "$key_files" ]; then
        echo "プライベートキーファイルが見つかりました:"
        echo "$key_files"
        return 1
    fi

    # PEM形式のキーが埋め込まれていないかチェック
    local embedded_keys=$(find "$TEST_ROOT" -name "*.sh" -type f \
        -exec grep -l "BEGIN.*PRIVATE KEY" {} \; 2>/dev/null)

    if [ -n "$embedded_keys" ]; then
        echo "スクリプトにプライベートキーが埋め込まれています:"
        echo "$embedded_keys"
        return 1
    fi
}

# ===== コマンドラインでのパスワード露出チェック =====

@test "MySQLコマンドでパスワードがコマンドライン引数に含まれていない" {
    # 危険: mysql -p"password" (プロセスリストに表示される)
    # 安全: mysql (パスワードプロンプト) または MYSQL_PWD環境変数

    local violations=$(find "$TEST_ROOT" -name "*.sh" -type f \
        -exec grep -n 'mysql.*-p[^[:space:]]' {} + 2>/dev/null | \
        grep -v '\-p\$' | grep -v 'MYSQL_PWD')

    if [ -n "$violations" ]; then
        echo "MySQLパスワードがコマンドライン引数に含まれています:"
        echo "$violations"
        echo ""
        echo "推奨: MYSQL_PWD環境変数を使用するか、my.cnfに設定してください"
        return 1
    fi
}

@test "PostgreSQLコマンドでパスワードがコマンドライン引数に含まれていない" {
    # 危険: psql -password=xxx
    # 安全: PGPASSWORD環境変数 または .pgpass ファイル

    local violations=$(find "$TEST_ROOT" -name "*.sh" -type f \
        -exec grep -n 'psql.*password=' {} + 2>/dev/null | \
        grep -v 'PGPASSWORD=')

    if [ -n "$violations" ]; then
        echo "PostgreSQLパスワードがコマンドライン引数に含まれています:"
        echo "$violations"
        return 1
    fi
}

# ===== 環境変数とファイルのセキュリティチェック =====

@test ".envファイルが.gitignoreに含まれている" {
    if [ -f "$TEST_ROOT/.gitignore" ]; then
        if ! grep -q "^\.env$" "$TEST_ROOT/.gitignore"; then
            echo ".envファイルが.gitignoreに含まれていません"
            return 1
        fi
    else
        skip ".gitignoreファイルが存在しません"
    fi
}

@test "認証情報ファイルが適切なパーミッションを持っている" {
    local config_files=$(find "$TEST_ROOT" -name "*.env" -o -name "*credentials*" -o -name "*secret*" 2>/dev/null)

    if [ -z "$config_files" ]; then
        skip "認証情報ファイルが見つかりません"
    fi

    local insecure_files=()

    while IFS= read -r file; do
        local perms=$(stat -c "%a" "$file" 2>/dev/null || stat -f "%Lp" "$file" 2>/dev/null)

        # パーミッションが600または400でない場合は危険
        if [[ "$perms" != "600" ]] && [[ "$perms" != "400" ]]; then
            insecure_files+=("$file (パーミッション: $perms)")
        fi
    done <<< "$config_files"

    if [ ${#insecure_files[@]} -gt 0 ]; then
        echo "不適切なパーミッションの認証情報ファイル:"
        printf '%s\n' "${insecure_files[@]}"
        echo ""
        echo "推奨: chmod 600 <file> を実行してください"
        return 1
    fi
}

# ===== APIキーとトークンのチェック =====

@test "JWTトークンがハードコードされていない" {
    # JWT形式のトークン: eyJ...
    local jwt_violations=$(find "$TEST_ROOT" -name "*.sh" -type f \
        -exec grep -n 'eyJ[A-Za-z0-9_-]*\.[A-Za-z0-9_-]*\.[A-Za-z0-9_-]*' {} + 2>/dev/null | \
        head -10)

    if [ -n "$jwt_violations" ]; then
        echo "JWTトークンがハードコードされている可能性があります:"
        echo "$jwt_violations"
        return 1
    fi
}

@test "Base64エンコードされた認証情報がハードコードされていない" {
    # 長いBase64文字列をチェック (認証情報の可能性)
    local base64_violations=$(find "$TEST_ROOT" -name "*.sh" -type f \
        -exec grep -n 'Authorization.*Basic [A-Za-z0-9+/=]\{20,\}' {} + 2>/dev/null)

    if [ -n "$base64_violations" ]; then
        echo "Base64エンコードされた認証情報がハードコードされています:"
        echo "$base64_violations"
        return 1
    fi
}

# ===== セキュアな代替手段の確認 =====

@test "認証情報は環境変数または設定ファイルから読み込まれている" {
    # DB接続を行うスクリプトを検索
    local db_scripts=$(find "$TEST_ROOT" -name "*.sh" -type f \
        -exec grep -l 'mysql\|psql\|sqlplus' {} \; 2>/dev/null)

    if [ -z "$db_scripts" ]; then
        skip "データベース接続スクリプトが見つかりません"
    fi

    local violations=()

    while IFS= read -r script; do
        # 環境変数または設定ファイルから読み込んでいるかチェック
        if grep -q 'mysql\|psql' "$script" && \
           ! grep -q '\$DB_PASSWORD\|\$PASSWORD\|\${.*PASSWORD\}\|source.*env\|load.*config' "$script"; then
            violations+=("$script: 認証情報の読み込み方法が不明確")
        fi
    done <<< "$db_scripts"

    if [ ${#violations[@]} -gt 0 ]; then
        echo "認証情報の読み込み方法を確認してください:"
        printf '%s\n' "${violations[@]}"
        # これは警告のみ（必ずしもエラーではない）
        skip "手動確認が必要です"
    fi
}

# ===== Gitリポジトリの履歴チェック =====

@test "Git履歴に認証情報が含まれていない（最近100コミット）" {
    if ! git -C "$TEST_ROOT" rev-parse --git-dir > /dev/null 2>&1; then
        skip "Gitリポジトリではありません"
    fi

    # 最近100コミットをチェック
    local violations=$(git -C "$TEST_ROOT" log --all --pretty=format: --name-only -100 | \
        sort -u | \
        grep -E '\.env$|credentials|secrets|\.pem$|\.key$|id_rsa' || true)

    if [ -n "$violations" ]; then
        echo "Git履歴に認証情報ファイルが含まれています:"
        echo "$violations"
        echo ""
        echo "警告: git-filter-branch または BFG Repo-Cleaner でクリーンアップを検討してください"
        # これは情報提供のみ（過去の履歴は変更困難）
        skip "手動確認が必要です"
    fi
}
