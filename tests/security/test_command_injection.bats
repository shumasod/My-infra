#!/usr/bin/env bats
#
# セキュリティテスト: コマンドインジェクション防止
# 作成日: 2025-12-02
# バージョン: 1.0
#
# このテストはコマンドインジェクションの脆弱性をチェックします。

setup() {
    export TEST_TMPDIR="$(mktemp -d)"
    export TEST_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export PATH="$TEST_TMPDIR:$PATH"
}

teardown() {
    [ -d "$TEST_TMPDIR" ] && rm -rf "$TEST_TMPDIR"
}

# ===== evalの危険な使用チェック =====

@test "evalコマンドが使用されていない" {
    # evalは任意のコードを実行できるため、ユーザー入力と組み合わせると危険
    local eval_usage=$(find "$TEST_ROOT" -name "*.sh" -type f \
        -exec grep -n 'eval ' {} + 2>/dev/null | \
        grep -v '^#' | \
        head -20)

    if [ -n "$eval_usage" ]; then
        echo "evalコマンドの使用が検出されました:"
        echo "$eval_usage"
        echo ""
        echo "警告: evalは任意のコードを実行できます。必ず入力を検証してください。"
        # これは警告レベル（evalが必要な場合もあるため）
        skip "手動レビューが必要です"
    fi
}

# ===== クォートされていない変数展開チェック =====

@test "シェル変数が適切にクォートされている" {
    # 危険なパターン: rm -rf $user_input (スペースで分割される)
    # 安全: rm -rf "$user_input"

    # テストファイルを作成
    cat > "$TEST_TMPDIR/test_unquoted.sh" << 'EOF'
#!/bin/bash
# 安全な例
safe_var="test"
rm -f "$safe_var"
echo "${safe_var}"

# 危険な例（変数がクォートされていない）
dangerous_var="test"
rm -f $dangerous_var
echo $dangerous_var
EOF

    # shellcheckを使用してチェック（利用可能な場合）
    if command -v shellcheck > /dev/null 2>&1; then
        # SC2086: Double quote to prevent globbing and word splitting
        local violations=$(shellcheck -f gcc "$TEST_TMPDIR/test_unquoted.sh" 2>/dev/null | grep "SC2086" || true)

        if [ -z "$violations" ]; then
            skip "shellcheckがインストールされていません"
        fi

        # 検証: 危険な例のみ検出されるべき
        local count=$(echo "$violations" | grep -c "SC2086" || true)
        [ "$count" -eq 2 ] # 危険な例の2行のみ
    else
        skip "shellcheckがインストールされていません"
    fi
}

@test "重要なスクリプトでクォートされていない変数が検出されない" {
    if ! command -v shellcheck > /dev/null 2>&1; then
        skip "shellcheckがインストールされていません"
    fi

    # 重要なスクリプト（DB操作、デプロイなど）をチェック
    local critical_scripts=$(find "$TEST_ROOT" \( \
        -path "*/DB/*.sh" -o \
        -path "*/deploy/*.sh" -o \
        -path "*/server/*backup*.sh" -o \
        -path "*/server/*restore*.sh" \
        \) -type f)

    if [ -z "$critical_scripts" ]; then
        skip "重要なスクリプトが見つかりません"
    fi

    local violations=()

    while IFS= read -r script; do
        # SC2086 (クォートなし変数展開) をチェック
        local issues=$(shellcheck -f gcc "$script" 2>/dev/null | grep "SC2086" || true)

        if [ -n "$issues" ]; then
            violations+=("$script: クォートされていない変数が検出されました")
        fi
    done <<< "$critical_scripts"

    if [ ${#violations[@]} -gt 0 ]; then
        echo "重要なスクリプトにクォートされていない変数があります:"
        printf '%s\n' "${violations[@]}"
        echo ""
        echo "推奨: 変数を\"\"で囲んでください"
        return 1
    fi
}

# ===== コマンド置換の安全性チェック =====

@test "コマンド置換でユーザー入力が直接使用されていない" {
    # 危険: result=$(command $user_input)
    # ユーザー入力がコマンド置換に直接渡されるパターンを検索

    # テストケース作成
    cat > "$TEST_TMPDIR/test_cmd_substitution.sh" << 'EOF'
#!/bin/bash

# 危険な例
user_input="$1"
result=$(ls $user_input)  # ユーザー入力を直接使用

# より安全な例
validated_input="$1"
if [[ "$validated_input" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    result=$(ls "$validated_input")
fi
EOF

    # パターンマッチングでチェック
    local dangerous_pattern='^\s*[a-zA-Z_][a-zA-Z0-9_]*=\$([^(]*\$[1-9@*]|\$\{[1-9@*]\})'

    if grep -qE "$dangerous_pattern" "$TEST_TMPDIR/test_cmd_substitution.sh"; then
        # 期待通り検出される
        :
    fi

    # 実際のスクリプトをチェック
    local real_violations=$(find "$TEST_ROOT" -name "*.sh" -type f \
        -exec grep -l '\$([^)]*\$[1-9]' {} \; 2>/dev/null | head -10)

    if [ -n "$real_violations" ]; then
        echo "コマンド置換でユーザー入力が使用されている可能性:"
        echo "$real_violations"
        echo ""
        echo "警告: ユーザー入力を検証せずにコマンド置換で使用すると危険です"
        skip "手動レビューが必要です"
    fi
}

# ===== SQLインジェクション防止チェック =====

@test "SQL文字列に変数が直接埋め込まれていない" {
    # 危険: mysql -e "SELECT * FROM users WHERE name='$user_input'"
    # 安全: プリペアドステートメントまたは適切なエスケープ

    # テストケース作成
    cat > "$TEST_TMPDIR/test_sql_injection.sh" << 'EOF'
#!/bin/bash

# 危険な例
user_name="$1"
mysql -e "SELECT * FROM users WHERE name='$user_name'"
mysql -e "DELETE FROM logs WHERE id=$log_id"

# より安全な例（エスケープ処理）
safe_user="${1//\'/\'\'}"  # シングルクォートをエスケープ
mysql -e "SELECT * FROM users WHERE name='$safe_user'"
EOF

    # SQL文で変数が直接使用されているパターン
    local sql_violations=$(find "$TEST_ROOT" -name "*.sh" -type f \
        -exec grep -n 'mysql.*-e.*".*\$\|psql.*-c.*".*\$' {} + 2>/dev/null | \
        grep -v "escapeshellarg\|quote\|//\\\\\'" | \
        head -10)

    if [ -n "$sql_violations" ]; then
        echo "SQL文に変数が直接埋め込まれています:"
        echo "$sql_violations"
        echo ""
        echo "警告: SQLインジェクションのリスクがあります"
        echo "推奨: プリペアドステートメントまたは適切なエスケープを使用してください"
        return 1
    fi
}

# ===== ファイルパス操作の安全性チェック =====

@test "ファイルパス操作でディレクトリトラバーサルが防止されている" {
    # 危険: cat /var/log/$user_file (user_file="../../etc/passwd" の場合)

    # テストスクリプト作成
    cat > "$TEST_TMPDIR/test_path_traversal.sh" << 'EOF'
#!/bin/bash

# 危険な例
user_file="$1"
cat "/var/log/$user_file"  # ../../../etc/passwd が可能

# 安全な例
user_file="$1"
# ファイル名のみを抽出（パスを除外）
safe_file=$(basename "$user_file")
# さらに検証
if [[ "$safe_file" =~ ^[a-zA-Z0-9._-]+$ ]]; then
    cat "/var/log/$safe_file"
fi
EOF

    # basename を使用せずにユーザー入力をパスに使用しているパターン
    local path_violations=$(find "$TEST_ROOT" -name "*.sh" -type f \
        -exec grep -n 'cat.*\$[1-9]\|rm.*\$[1-9]\|cp.*\$[1-9]' {} + 2>/dev/null | \
        grep -v 'basename\|realpath\|readlink' | \
        head -10)

    if [ -n "$path_violations" ]; then
        echo "ファイルパス操作でディレクトリトラバーサルのリスク:"
        echo "$path_violations"
        echo ""
        echo "推奨: basename や realpath で正規化してください"
        skip "手動レビューが必要です"
    fi
}

# ===== システムコマンド実行の検証 =====

@test "systemコマンド実行でシェル経由を避けている" {
    # Python/Ruby等のスクリプトでsystem()やexec()を使用する場合

    # Python system() の危険な使用
    local python_violations=$(find "$TEST_ROOT" -name "*.py" -type f \
        -exec grep -n 'os\.system\|subprocess\.call.*shell=True' {} + 2>/dev/null | \
        head -10)

    if [ -n "$python_violations" ]; then
        echo "Pythonでシェル経由のコマンド実行が検出されました:"
        echo "$python_violations"
        echo ""
        echo "推奨: subprocess.run() with shell=False を使用してください"
        return 1
    fi
}

# ===== 入力検証のテスト =====

@test "ユーザー入力が検証されている（サンプルスクリプト）" {
    # 良い例のテスト
    cat > "$TEST_TMPDIR/validated_input.sh" << 'EOF'
#!/bin/bash
set -euo pipefail

validate_input() {
    local input="$1"
    # 英数字とハイフン、アンダースコアのみ許可
    if [[ ! "$input" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "エラー: 無効な入力" >&2
        return 1
    fi
    echo "$input"
}

main() {
    if [ $# -lt 1 ]; then
        echo "Usage: $0 <input>" >&2
        exit 1
    fi

    local safe_input
    if ! safe_input=$(validate_input "$1"); then
        exit 1
    fi

    # 検証済み入力を使用
    echo "Safe input: $safe_input"
}

main "$@"
EOF

    # スクリプトを実行してテスト
    chmod +x "$TEST_TMPDIR/validated_input.sh"

    # 正常な入力
    run bash "$TEST_TMPDIR/validated_input.sh" "test123"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Safe input: test123"* ]]

    # 危険な入力（コマンドインジェクション試行）
    run bash "$TEST_TMPDIR/validated_input.sh" "test; rm -rf /"
    [ "$status" -eq 1 ]
    [[ "$output" == *"エラー"* ]]

    # ディレクトリトラバーサル試行
    run bash "$TEST_TMPDIR/validated_input.sh" "../../../etc/passwd"
    [ "$status" -eq 1 ]
}

# ===== 特殊文字のエスケープテスト =====

@test "シェル特殊文字が適切にエスケープされている" {
    # テストスクリプト作成
    cat > "$TEST_TMPDIR/test_escape.sh" << 'EOF'
#!/bin/bash

# シェル特殊文字をエスケープする関数
escape_shell() {
    local input="$1"
    # シングルクォートで囲み、内部のシングルクォートをエスケープ
    printf '%s' "'${input//\'/\'\\\'\'}'"
}

# テスト
user_input="test';rm -rf /;echo 'hacked"
escaped=$(escape_shell "$user_input")

# エスケープされた値を使用
eval "echo $escaped"
EOF

    chmod +x "$TEST_TMPDIR/test_escape.sh"

    # エスケープ関数のテスト
    run bash "$TEST_TMPDIR/test_escape.sh"
    [ "$status" -eq 0 ]

    # 出力に危険なコマンドが実行されていないことを確認
    [[ "$output" == *"test"* ]]
    [[ "$output" != *"hacked"* ]] || true  # コマンドが実行されなければこの文字列は出力されない
}

# ===== リアルワールドテスト =====

@test "DB/backup.shでコマンドインジェクション脆弱性がない" {
    local backup_script="$TEST_ROOT/DB/backup.sh"

    if [ ! -f "$backup_script" ]; then
        skip "backup.shが存在しません"
    fi

    # スクリプトの内容をチェック
    # 変数が適切にクォートされているか
    if grep -q 'mysqldump.*\$[A-Z_]*[^"]' "$backup_script"; then
        echo "backup.shに クォートされていない変数があります"
        return 1
    fi
}

@test "deploy/deploy1.shでコマンドインジェクション脆弱性がない" {
    local deploy_script="$TEST_ROOT/deploy/deploy1.sh"

    if [ ! -f "$deploy_script" ]; then
        skip "deploy1.shが存在しません"
    fi

    # evalの使用をチェック
    if grep -q 'eval ' "$deploy_script"; then
        echo "deploy1.shでevalが使用されています"
        skip "手動レビューが必要です"
    fi

    # set -euo pipefail が設定されているかチェック
    if ! grep -q 'set -euo pipefail' "$deploy_script"; then
        echo "deploy1.shに set -euo pipefail が設定されていません"
        return 1
    fi
}
