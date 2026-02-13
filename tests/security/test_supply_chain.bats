#!/usr/bin/env bats
#
# セキュリティテスト: サプライチェーン攻撃・ハードニング検証
# 作成日: 2026-02-13
# バージョン: 1.0
#
# 2026年2月の脅威情報に基づくセキュリティテスト
# 参照:
#   - IPA 情報セキュリティ10大脅威 2026 (#2 サプライチェーン攻撃)
#   - CVE-2025-30066 (tj-actions/changed-files サプライチェーン攻撃)
#   - CVE-2025-9074 (Docker Desktop API アクセス制御不備)
#

setup() {
    export TEST_TMPDIR="$(mktemp -d)"
    export TEST_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
}

teardown() {
    [ -d "$TEST_TMPDIR" ] && rm -rf "$TEST_TMPDIR"
}

# ===== GitHub Actions サプライチェーン対策 =====

@test "GitHub ActionsがコミットSHAで固定されている" {
    local workflow_dir="$TEST_ROOT/.github/workflows"

    if [ ! -d "$workflow_dir" ]; then
        skip "GitHub Actionsワークフローが存在しません"
    fi

    local violations=""

    for workflow in "$workflow_dir"/*.yml; do
        if [ -f "$workflow" ]; then
            # uses: action@vN のようなタグ参照を検出（コメント行を除外）
            local tag_refs
            tag_refs=$(grep -n 'uses:.*@' "$workflow" | \
                grep -v '@[0-9a-f]\{40\}' | \
                grep -v '^\s*#' || true)

            if [ -n "$tag_refs" ]; then
                violations="${violations}\n${workflow}:\n${tag_refs}"
            fi
        fi
    done

    if [ -n "$violations" ]; then
        echo "サプライチェーン攻撃リスク: Actionsがコミットハッシュで固定されていません"
        echo -e "$violations"
        echo ""
        echo "参考: CVE-2025-30066 (tj-actions/changed-files)"
        echo "推奨: uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 の形式に変更"
        return 1
    fi
}

@test "GitHub Actionsでpersist-credentialsがfalseに設定されている" {
    local workflow_dir="$TEST_ROOT/.github/workflows"

    if [ ! -d "$workflow_dir" ]; then
        skip "GitHub Actionsワークフローが存在しません"
    fi

    for workflow in "$workflow_dir"/*.yml; do
        if [ -f "$workflow" ]; then
            # checkoutステップにpersist-credentials: falseが含まれているか確認
            local checkout_count
            checkout_count=$(grep -c 'actions/checkout' "$workflow" || true)

            local persist_false_count
            persist_false_count=$(grep -c 'persist-credentials: false' "$workflow" || true)

            if [ "$checkout_count" -gt 0 ] && [ "$persist_false_count" -lt "$checkout_count" ]; then
                echo "$(basename "$workflow"): checkout に persist-credentials: false が不足"
                echo "  checkout数: $checkout_count, persist-credentials: false 数: $persist_false_count"
                echo "推奨: 認証情報の不要な永続化を防止するため設定してください"
                return 1
            fi
        fi
    done
}

@test "GitHub Actionsでpermissionsが最小権限に設定されている" {
    local workflow_dir="$TEST_ROOT/.github/workflows"

    if [ ! -d "$workflow_dir" ]; then
        skip "GitHub Actionsワークフローが存在しません"
    fi

    for workflow in "$workflow_dir"/*.yml; do
        if [ -f "$workflow" ]; then
            if ! grep -q 'permissions:' "$workflow"; then
                echo "$(basename "$workflow"): permissions が設定されていません"
                echo "推奨: GITHUB_TOKENの権限を最小限に制限してください"
                return 1
            fi
        fi
    done
}

# ===== スクリプトセキュリティハードニング =====

@test "重要なスクリプトでPATHが明示的に設定されている" {
    # 重要なディレクトリのスクリプトを対象
    local critical_scripts
    critical_scripts=$(find "$TEST_ROOT" \( \
        -path "*/deploy/*.sh" -o \
        -path "*/server/*backup*.sh" \
        \) -type f 2>/dev/null || true)

    if [ -z "$critical_scripts" ]; then
        skip "対象スクリプトが見つかりません"
    fi

    local warnings=""

    while IFS= read -r script; do
        # PATHが設定されているか確認
        if ! grep -q 'export PATH=\|readonly PATH=' "$script" 2>/dev/null; then
            warnings="${warnings}\n  - $script"
        fi
    done <<< "$critical_scripts"

    if [ -n "$warnings" ]; then
        echo "PATHが明示的に設定されていないスクリプト:"
        echo -e "$warnings"
        echo ""
        echo "推奨: export PATH=\"/usr/local/bin:/usr/bin:/bin\" を追加してください"
        skip "手動レビューが必要です"
    fi
}

@test "スクリプトで安全な一時ファイル作成が使用されている" {
    # mktemp を使用せずに /tmp に書き込むパターンを検出
    local violations
    violations=$(find "$TEST_ROOT" -name "*.sh" -type f \
        -exec grep -ln '/tmp/[a-zA-Z].*[^X]"' {} \; 2>/dev/null | \
        grep -v 'mktemp\|test\|bats' | head -10 || true)

    if [ -n "$violations" ]; then
        echo "安全でない一時ファイル作成パターンが検出されました:"
        echo "$violations"
        echo ""
        echo "推奨: mktemp コマンドを使用してください"
        echo "例: tmpfile=\$(mktemp /tmp/myapp.XXXXXX)"
        skip "手動レビューが必要です"
    fi
}

@test "外部リソースのダウンロード後に検証が行われている" {
    # curl | bash や wget | sh の危険なパターンを検出
    local pipe_exec
    pipe_exec=$(find "$TEST_ROOT" -name "*.sh" -type f \
        -exec grep -ln 'curl.*|.*sh\|curl.*|.*bash\|wget.*|.*sh\|wget.*|.*bash' {} \; 2>/dev/null || true)

    if [ -n "$pipe_exec" ]; then
        echo "危険な外部スクリプト実行パターンが検出されました:"
        echo "$pipe_exec"
        echo ""
        echo "推奨: ダウンロード → チェックサム検証 → 実行 の手順に変更してください"
        return 1
    fi
}

# ===== Docker セキュリティ (CVE-2025-9074 対策) =====

@test "Dockerfileで非rootユーザーが使用されている" {
    local dockerfiles
    dockerfiles=$(find "$TEST_ROOT" -name "dockerfile" -o -name "Dockerfile" 2>/dev/null)

    if [ -z "$dockerfiles" ]; then
        skip "Dockerfileが見つかりません"
    fi

    while IFS= read -r df; do
        # 最小限のDockerfile（HEALTHCHECK のみ等）はスキップ
        local line_count
        line_count=$(wc -l < "$df")
        if [ "$line_count" -lt 3 ]; then
            skip "Dockerfileが最小構成です"
        fi

        if ! grep -qi 'USER\|user' "$df"; then
            echo "$df: 非rootユーザーが設定されていません"
            echo "推奨: USER nonroot を追加してください"
            return 1
        fi
    done <<< "$dockerfiles"
}

@test "Dockerfileで:latestタグが使用されていない" {
    local dockerfiles
    dockerfiles=$(find "$TEST_ROOT" -name "dockerfile" -o -name "Dockerfile" 2>/dev/null)

    if [ -z "$dockerfiles" ]; then
        skip "Dockerfileが見つかりません"
    fi

    local violations=""

    while IFS= read -r df; do
        local latest_refs
        latest_refs=$(grep -in ':latest' "$df" 2>/dev/null || true)
        if [ -n "$latest_refs" ]; then
            violations="${violations}\n$df: $latest_refs"
        fi
    done <<< "$dockerfiles"

    if [ -n "$violations" ]; then
        echo ":latest タグが使用されています:"
        echo -e "$violations"
        echo "推奨: 具体的なバージョンタグまたはダイジェストを使用してください"
        return 1
    fi
}

# ===== セキュリティライブラリのテスト =====

@test "lib/security.sh が正常に読み込める" {
    local security_lib="$TEST_ROOT/lib/security.sh"

    if [ ! -f "$security_lib" ]; then
        skip "lib/security.sh が存在しません"
    fi

    # sourceして構文エラーがないことを確認
    run bash -c "source '$security_lib'"
    [ "$status" -eq 0 ]
}

@test "validate_safe_string がインジェクション攻撃を防止する" {
    local security_lib="$TEST_ROOT/lib/security.sh"

    if [ ! -f "$security_lib" ]; then
        skip "lib/security.sh が存在しません"
    fi

    source "$security_lib"

    # 正常な入力
    run validate_safe_string "test123" "name"
    [ "$status" -eq 0 ]

    run validate_safe_string "my-value_01" "name"
    [ "$status" -eq 0 ]

    # コマンドインジェクション
    run validate_safe_string "test; rm -rf /" "name"
    [ "$status" -eq 1 ]

    # SQLインジェクション
    run validate_safe_string "admin' OR '1'='1" "name"
    [ "$status" -eq 1 ]

    # ディレクトリトラバーサル
    run validate_safe_string "../../../etc/passwd" "name"
    [ "$status" -eq 1 ]

    # 空文字列
    run validate_safe_string "" "name"
    [ "$status" -eq 1 ]
}

@test "validate_file_path がディレクトリトラバーサルを防止する" {
    local security_lib="$TEST_ROOT/lib/security.sh"

    if [ ! -f "$security_lib" ]; then
        skip "lib/security.sh が存在しません"
    fi

    source "$security_lib"

    # ディレクトリトラバーサル
    run validate_file_path "../../../etc/passwd"
    [ "$status" -eq 1 ]

    # Null byte
    run validate_file_path $'test\x00.txt'
    [ "$status" -eq 1 ]

    # 正常パス
    run validate_file_path "/var/log/app.log"
    [ "$status" -eq 0 ]
}

@test "sanitize_log_message が機密情報をマスクする" {
    local security_lib="$TEST_ROOT/lib/security.sh"

    if [ ! -f "$security_lib" ]; then
        skip "lib/security.sh が存在しません"
    fi

    source "$security_lib"

    # パスワードのマスク
    local result
    result=$(sanitize_log_message "password=mysecret123 host=localhost")
    [[ "$result" != *"mysecret123"* ]]

    # AWSキーのマスク
    result=$(sanitize_log_message "key=AKIAIOSFODNN7EXAMPLE")
    [[ "$result" != *"AKIAIOSFODNN7EXAMPLE"* ]]
}
