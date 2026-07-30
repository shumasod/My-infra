#!/bin/bash
set -euo pipefail

#
# データベースマイグレーション管理ツール
# 作成日: 2026-07-30
# バージョン: 1.0
#
# SQLマイグレーションファイルのバージョン管理・適用を行います
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"
readonly MIGRATIONS_DIR="${MIGRATIONS_DIR:-./migrations}"
readonly MIGRATION_TABLE="_schema_migrations"

declare command_name="status"
declare db_type="mysql"
declare db_host="localhost"
declare db_port=""
declare db_name=""
declare db_user=""
declare db_pass=""
declare dry_run=false
declare steps=0

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME <コマンド> [オプション]

データベースマイグレーション管理ツールです。

コマンド:
  status               現在のマイグレーション状態を表示
  up [N]               マイグレーションを適用 (N件、省略時は全て)
  down [N]             マイグレーションをロールバック (N件、省略時は1件)
  create <名前>        新しいマイグレーションファイルを作成
  list                 マイグレーションファイル一覧
  validate             マイグレーションファイルの整合性チェック

オプション:
  -h, --help           このヘルプを表示
  -v, --version        バージョン情報を表示
  --db-type <種類>     DB種類 (mysql|postgres) [デフォルト: mysql]
  --host <ホスト>      DBホスト [デフォルト: localhost]
  --port <ポート>      DBポート
  --name <DB名>        データベース名
  --user <ユーザー>    DBユーザー名
  --pass <パスワード>  DBパスワード
  --dir <ディレクトリ> マイグレーションディレクトリ [デフォルト: ./migrations]
  --dry-run            実際には実行せずに表示のみ

環境変数:
  MIGRATIONS_DIR       マイグレーションディレクトリ
  DB_HOST / DB_PORT / DB_NAME / DB_USER / DB_PASS

例:
  $PROG_NAME create add_users_table
  $PROG_NAME status --name mydb
  $PROG_NAME up --name mydb --user root
  $PROG_NAME down 3 --name mydb
EOF
}

get_default_port() {
    case "$db_type" in
        mysql)    echo "3306" ;;
        postgres) echo "5432" ;;
        *)        echo "" ;;
    esac
}

run_sql() {
    local sql="$1"
    local port="${db_port:-$(get_default_port)}"

    if $dry_run; then
        printf "${C_DIM}[DRY-RUN] SQL: %s${C_RESET}\n" "${sql:0:80}"
        return 0
    fi

    case "$db_type" in
        mysql)
            local args=(-h "$db_host" -P "$port" -u "${db_user:-root}" "${db_name}")
            [[ -n "$db_pass" ]] && args=(-p"$db_pass" "${args[@]}")
            mysql "${args[@]}" -e "$sql" 2>/dev/null
            ;;
        postgres)
            PGPASSWORD="${db_pass:-}" psql \
                -h "$db_host" -p "$port" \
                -U "${db_user:-postgres}" -d "$db_name" \
                -c "$sql" -t -A 2>/dev/null
            ;;
    esac
}

ensure_migration_table() {
    local sql
    case "$db_type" in
        mysql)
            sql="CREATE TABLE IF NOT EXISTS ${MIGRATION_TABLE} (
                id INT AUTO_INCREMENT PRIMARY KEY,
                version VARCHAR(255) NOT NULL UNIQUE,
                filename VARCHAR(512) NOT NULL,
                applied_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                checksum VARCHAR(64)
            );"
            ;;
        postgres)
            sql="CREATE TABLE IF NOT EXISTS ${MIGRATION_TABLE} (
                id SERIAL PRIMARY KEY,
                version VARCHAR(255) NOT NULL UNIQUE,
                filename VARCHAR(512) NOT NULL,
                applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                checksum VARCHAR(64)
            );"
            ;;
    esac
    run_sql "$sql" 2>/dev/null || true
}

get_applied_versions() {
    if $dry_run; then echo ""; return; fi
    run_sql "SELECT version FROM ${MIGRATION_TABLE} ORDER BY version;" 2>/dev/null || echo ""
}

get_migration_files() {
    local dir="${1:-$MIGRATIONS_DIR}"
    [[ ! -d "$dir" ]] && return 0
    find "$dir" -maxdepth 1 -name "V[0-9]*__*.sql" | sort
}

extract_version() {
    local filename
    filename=$(basename "$1")
    echo "${filename%%__*}"
}

cmd_status() {
    [[ -z "$db_name" ]] && { log_warning "--name が指定されていません"; }

    log_info "マイグレーション状態を確認中..."
    echo ""

    local migration_files
    migration_files=$(get_migration_files "$MIGRATIONS_DIR")

    if [[ -z "$migration_files" ]]; then
        log_info "マイグレーションファイルが見つかりません: $MIGRATIONS_DIR"
        return
    fi

    local applied_versions=""
    if [[ -n "$db_name" ]]; then
        ensure_migration_table
        applied_versions=$(get_applied_versions)
    fi

    printf "${C_BOLD}%-8s %-30s %-12s %s${C_RESET}\n" "バージョン" "ファイル名" "状態" "適用日時"
    printf "%s\n" "$(printf '%.0s─' {1..70})"

    local pending=0 applied_count=0
    while IFS= read -r f; do
        local ver filename base
        ver=$(extract_version "$f")
        base=$(basename "$f")
        filename="${base#*__}"
        filename="${filename%.sql}"

        if echo "$applied_versions" | grep -qx "$ver"; then
            printf "  ${C_DIM}%-8s${C_RESET} %-30s ${C_GREEN}%-12s${C_RESET}\n" \
                "$ver" "${filename:0:30}" "適用済み"
            (( applied_count++ )) || true
        else
            printf "  ${C_YELLOW}%-8s${C_RESET} %-30s ${C_YELLOW}%-12s${C_RESET}\n" \
                "$ver" "${filename:0:30}" "未適用"
            (( pending++ )) || true
        fi
    done <<< "$migration_files"

    echo ""
    printf "  適用済み: ${C_GREEN}%d${C_RESET}  未適用: ${C_YELLOW}%d${C_RESET}\n" "$applied_count" "$pending"
    echo ""
}

cmd_up() {
    [[ -z "$db_name" ]] && error_exit "--name でデータベース名を指定してください"

    ensure_migration_table
    local applied_versions
    applied_versions=$(get_applied_versions)

    local migration_files
    migration_files=$(get_migration_files "$MIGRATIONS_DIR")
    [[ -z "$migration_files" ]] && { log_info "適用するマイグレーションはありません"; return; }

    local count=0
    while IFS= read -r f; do
        [[ -n "$steps" && $steps -gt 0 && $count -ge $steps ]] && break
        local ver
        ver=$(extract_version "$f")
        echo "$applied_versions" | grep -qx "$ver" && continue

        local base
        base=$(basename "$f")
        log_info "適用中: $base"

        if $dry_run; then
            printf "${C_DIM}  [DRY-RUN] %s を適用します${C_RESET}\n" "$base"
        else
            local sql_content
            sql_content=$(cat "$f")
            run_sql "$sql_content"
            local checksum
            checksum=$(md5sum "$f" | awk '{print $1}')
            run_sql "INSERT INTO ${MIGRATION_TABLE} (version, filename, checksum) VALUES ('$ver', '$base', '$checksum');"
            log_success "適用完了: $base"
        fi
        (( count++ )) || true
    done <<< "$migration_files"

    if [[ $count -eq 0 ]]; then
        log_info "適用するマイグレーションはありませんでした"
    else
        log_success "合計 ${count}件 のマイグレーションを適用しました"
    fi
}

cmd_down() {
    [[ -z "$db_name" ]] && error_exit "--name でデータベース名を指定してください"

    local n="${steps:-1}"
    [[ $n -eq 0 ]] && n=1

    ensure_migration_table
    local applied_versions
    applied_versions=$(get_applied_versions | sort -r)

    local count=0
    while IFS= read -r ver; do
        [[ -z "$ver" ]] && continue
        [[ $count -ge $n ]] && break

        local down_file
        down_file=$(find "$MIGRATIONS_DIR" -maxdepth 1 -name "${ver}__*.down.sql" 2>/dev/null | head -1)

        if [[ -z "$down_file" ]]; then
            log_warning "ロールバックファイルが見つかりません: ${ver}__*.down.sql"
        else
            log_info "ロールバック中: $(basename "$down_file")"
            if ! $dry_run; then
                run_sql "$(cat "$down_file")"
                run_sql "DELETE FROM ${MIGRATION_TABLE} WHERE version='$ver';"
                log_success "ロールバック完了: $ver"
            else
                printf "${C_DIM}  [DRY-RUN] %s をロールバックします${C_RESET}\n" "$ver"
            fi
        fi
        (( count++ )) || true
    done <<< "$applied_versions"
}

cmd_create() {
    local name="${ARGS[0]:-}"
    [[ -z "$name" ]] && error_exit "マイグレーション名を指定してください"

    mkdir -p "$MIGRATIONS_DIR"

    local version
    version=$(date +V%Y%m%d%H%M%S)
    local safe_name
    safe_name=$(echo "$name" | tr ' ' '_' | tr -cd '[:alnum:]_')

    local up_file="${MIGRATIONS_DIR}/${version}__${safe_name}.sql"
    local down_file="${MIGRATIONS_DIR}/${version}__${safe_name}.down.sql"

    cat > "$up_file" <<EOF
-- Migration: ${safe_name}
-- Version: ${version}
-- Created: $(date '+%Y-%m-%d %H:%M:%S')
-- Direction: UP

-- ここにマイグレーションSQLを記述してください
-- 例:
-- CREATE TABLE example (
--     id INT AUTO_INCREMENT PRIMARY KEY,
--     name VARCHAR(255) NOT NULL,
--     created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
-- );
EOF

    cat > "$down_file" <<EOF
-- Migration: ${safe_name}
-- Version: ${version}
-- Created: $(date '+%Y-%m-%d %H:%M:%S')
-- Direction: DOWN (rollback)

-- ここにロールバックSQLを記述してください
-- 例:
-- DROP TABLE IF EXISTS example;
EOF

    log_success "マイグレーションファイルを作成しました:"
    printf "  UP:   %s\n" "$up_file"
    printf "  DOWN: %s\n" "$down_file"
}

cmd_list() {
    local migration_files
    migration_files=$(get_migration_files "$MIGRATIONS_DIR")

    if [[ -z "$migration_files" ]]; then
        log_info "マイグレーションファイルが見つかりません: $MIGRATIONS_DIR"
        return
    fi

    printf "\n${C_BOLD}%-20s %-35s %8s${C_RESET}\n" "バージョン" "名前" "サイズ"
    printf "%s\n" "$(printf '%.0s─' {1..65})"

    while IFS= read -r f; do
        local ver base name size
        ver=$(extract_version "$f")
        base=$(basename "$f")
        name="${base#*__}"
        name="${name%.sql}"
        size=$(wc -c < "$f")
        printf "  ${C_CYAN}%-18s${C_RESET} %-35s %6d B\n" "$ver" "${name:0:35}" "$size"
    done <<< "$migration_files"
    echo ""
}

cmd_validate() {
    log_info "マイグレーションファイルを検証中..."

    local migration_files
    migration_files=$(get_migration_files "$MIGRATIONS_DIR")
    [[ -z "$migration_files" ]] && { log_info "ファイルが見つかりません"; return; }

    local errors=0
    local prev_ver=""

    while IFS= read -r f; do
        local ver
        ver=$(extract_version "$f")

        # バージョン重複チェック
        if [[ "$ver" == "$prev_ver" ]]; then
            log_error "バージョン重複: $ver"
            (( errors++ )) || true
        fi
        prev_ver="$ver"

        # 構文チェック (SELECT/INSERT/UPDATE/DELETE/CREATE/DROP/ALTER を確認)
        if ! grep -qiE '(SELECT|INSERT|UPDATE|DELETE|CREATE|DROP|ALTER|BEGIN|COMMIT)' "$f" 2>/dev/null; then
            log_warning "SQLが含まれていない可能性があります: $(basename "$f")"
        fi

        printf "  ${C_GREEN}✓${C_RESET} %s\n" "$(basename "$f")"
    done <<< "$migration_files"

    echo ""
    if [[ $errors -eq 0 ]]; then
        log_success "検証完了: 問題は見つかりませんでした"
    else
        log_error "検証失敗: ${errors}件のエラー"
        exit 1
    fi
}

declare -a ARGS=()

parse_arguments() {
    [[ $# -eq 0 ]] && return 0

    # 環境変数からデフォルト値を読み込み
    db_host="${DB_HOST:-$db_host}"
    db_name="${DB_NAME:-$db_name}"
    db_user="${DB_USER:-$db_user}"
    db_pass="${DB_PASS:-$db_pass}"

    case "$1" in
        status|up|down|create|list|validate)
            command_name="$1"; shift ;;
    esac

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            --db-type)    [[ $# -lt 2 ]] && error_exit "--db-type には値が必要です"; db_type="$2"; shift 2 ;;
            --host)       [[ $# -lt 2 ]] && error_exit "--host には値が必要です"; db_host="$2"; shift 2 ;;
            --port)       [[ $# -lt 2 ]] && error_exit "--port には値が必要です"; db_port="$2"; shift 2 ;;
            --name)       [[ $# -lt 2 ]] && error_exit "--name には値が必要です"; db_name="$2"; shift 2 ;;
            --user)       [[ $# -lt 2 ]] && error_exit "--user には値が必要です"; db_user="$2"; shift 2 ;;
            --pass)       [[ $# -lt 2 ]] && error_exit "--pass には値が必要です"; db_pass="$2"; shift 2 ;;
            --dir)        [[ $# -lt 2 ]] && error_exit "--dir には値が必要です"; MIGRATIONS_DIR="$2"; shift 2 ;;
            --dry-run)    dry_run=true; shift ;;
            [0-9]*)       steps="$1"; shift ;;
            -*)           error_exit "不明なオプション: $1" ;;
            *)            ARGS+=("$1"); shift ;;
        esac
    done
}

main() {
    parse_arguments "$@"
    case "$command_name" in
        status)   cmd_status ;;
        up)       cmd_up ;;
        down)     cmd_down ;;
        create)   cmd_create ;;
        list)     cmd_list ;;
        validate) cmd_validate ;;
        *)        error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
