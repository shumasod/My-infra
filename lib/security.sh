#!/bin/bash
#
# セキュリティハードニング共通ライブラリ
# 作成日: 2026-02-13
# バージョン: 1.0
#
# 2026年2月の脅威情報（IPA 10大脅威 2026、CVE-2025-30066等）を参考に、
# シェルスクリプトのセキュリティを強化するための共通関数を提供します。
#
# 使用方法: source "$(dirname "${BASH_SOURCE[0]}")/../lib/security.sh"
#

# 二重読み込み防止
[[ -n "${_SECURITY_SH_LOADED:-}" ]] && return 0
readonly _SECURITY_SH_LOADED=1

# ============================================================================
# PATH ハードニング
# ============================================================================

#
# PATHを信頼できるディレクトリのみに制限
# コマンドインジェクション・PATH改竄攻撃を防止
#
harden_path() {
    export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
}

# ============================================================================
# 入力検証関数
# ============================================================================

#
# 英数字とハイフン・アンダースコアのみ許可
# 引数: $1=入力値 $2=フィールド名（エラーメッセージ用）
# 戻り値: 0=有効, 1=無効
#
validate_safe_string() {
    local input="${1:-}"
    local field_name="${2:-input}"

    if [[ -z "$input" ]]; then
        echo "エラー: ${field_name}が空です" >&2
        return 1
    fi

    if [[ ! "$input" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "エラー: ${field_name}に無効な文字が含まれています" >&2
        return 1
    fi

    # 長さ制限（DoS防止）
    if [[ ${#input} -gt 255 ]]; then
        echo "エラー: ${field_name}が長すぎます (最大255文字)" >&2
        return 1
    fi

    return 0
}

#
# ファイルパスの検証（ディレクトリトラバーサル防止）
# 引数: $1=パス $2=許可ベースディレクトリ
# 戻り値: 0=安全, 1=危険
#
validate_file_path() {
    local input_path="${1:-}"
    local base_dir="${2:-}"

    if [[ -z "$input_path" ]]; then
        echo "エラー: パスが空です" >&2
        return 1
    fi

    # ディレクトリトラバーサルパターンを拒否
    if [[ "$input_path" == *".."* ]]; then
        echo "エラー: ディレクトリトラバーサルが検出されました" >&2
        return 1
    fi

    # Null byte インジェクション防止
    if [[ "$input_path" == *$'\x00'* ]]; then
        echo "エラー: Null byteが検出されました" >&2
        return 1
    fi

    # ベースディレクトリが指定されている場合、パスがその配下にあることを確認
    if [[ -n "$base_dir" ]]; then
        local resolved_path
        resolved_path=$(realpath -m "$input_path" 2>/dev/null) || return 1
        local resolved_base
        resolved_base=$(realpath -m "$base_dir" 2>/dev/null) || return 1

        if [[ "$resolved_path" != "$resolved_base"* ]]; then
            echo "エラー: パスが許可されたディレクトリ外です" >&2
            return 1
        fi
    fi

    return 0
}

#
# 数値の検証
# 引数: $1=値 $2=最小値 $3=最大値 $4=フィールド名
# 戻り値: 0=有効, 1=無効
#
validate_integer() {
    local value="${1:-}"
    local min="${2:-0}"
    local max="${3:-2147483647}"
    local field_name="${4:-value}"

    if [[ ! "$value" =~ ^-?[0-9]+$ ]]; then
        echo "エラー: ${field_name}は整数である必要があります" >&2
        return 1
    fi

    if [[ "$value" -lt "$min" ]] || [[ "$value" -gt "$max" ]]; then
        echo "エラー: ${field_name}は${min}から${max}の範囲で指定してください" >&2
        return 1
    fi

    return 0
}

# ============================================================================
# セキュアな一時ファイル管理
# ============================================================================

#
# セキュアな一時ファイルを作成
# 出力: 一時ファイルのパス
#
create_secure_tempfile() {
    local prefix="${1:-myinfra}"
    local tmpfile
    tmpfile=$(mktemp "/tmp/${prefix}.XXXXXX") || {
        echo "エラー: 一時ファイルの作成に失敗しました" >&2
        return 1
    }
    chmod 600 "$tmpfile"
    echo "$tmpfile"
}

#
# セキュアな一時ディレクトリを作成
# 出力: 一時ディレクトリのパス
#
create_secure_tempdir() {
    local prefix="${1:-myinfra}"
    local tmpdir
    tmpdir=$(mktemp -d "/tmp/${prefix}.XXXXXX") || {
        echo "エラー: 一時ディレクトリの作成に失敗しました" >&2
        return 1
    }
    chmod 700 "$tmpdir"
    echo "$tmpdir"
}

# ============================================================================
# データベース接続のセキュリティ
# ============================================================================

#
# MySQL安全接続（プロセスリストへのパスワード露出を防止）
# 引数: $1=ホスト $2=ユーザー $3=パスワード $4=データベース $5...=追加引数
#
mysql_secure_exec() {
    local host="${1:?ホストを指定してください}"
    local user="${2:?ユーザーを指定してください}"
    local password="${3:?パスワードを指定してください}"
    local database="${4:-}"
    shift 4 || shift $#

    # 一時設定ファイルでパスワードを渡す（ps auxで見えない）
    local cnf_file
    cnf_file=$(create_secure_tempfile "mysql_cnf") || return 1

    cat > "$cnf_file" << MYCNF
[client]
host=${host}
user=${user}
password=${password}
MYCNF
    chmod 600 "$cnf_file"

    local result=0
    if [[ -n "$database" ]]; then
        mysql --defaults-file="$cnf_file" "$database" "$@" || result=$?
    else
        mysql --defaults-file="$cnf_file" "$@" || result=$?
    fi

    # 一時ファイルを安全に削除
    rm -f "$cnf_file"
    return $result
}

# ============================================================================
# ログ出力のサニタイズ
# ============================================================================

#
# ログ出力から機密情報を除去
# 引数: $1=ログメッセージ
# 出力: サニタイズされたメッセージ
#
sanitize_log_message() {
    local message="${1:-}"

    # パスワード、トークン、キーをマスク
    message=$(echo "$message" | sed -E \
        -e 's/(password|passwd|pwd|token|secret|key|api_key)=\S+/\1=*****/gi' \
        -e 's/AKIA[0-9A-Z]{16}/AKIA****************/g' \
        -e 's/eyJ[A-Za-z0-9_-]*\.[A-Za-z0-9_-]*\.[A-Za-z0-9_-]*/[JWT_REDACTED]/g')

    echo "$message"
}

# ============================================================================
# umask 設定
# ============================================================================

#
# セキュアなumaskを設定（新規ファイルは所有者のみ読み書き可能）
#
set_secure_umask() {
    umask 077
}
