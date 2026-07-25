#!/bin/bash
set -euo pipefail

#
# MySQLバックアップ管理ツール
# バージョン: 1.0
#
# MySQL/MariaDBのバックアップ・検証・リストアを管理するツール
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"
readonly DEFAULT_BACKUP_DIR="/var/backups/mysql"
readonly TIMESTAMP=$(date +%Y%m%d_%H%M%S)

declare mode="backup"
declare db_host="localhost"
declare -i db_port=3306
declare db_user="${MYSQL_USER:-root}"
declare db_password="${MYSQL_PWD:-}"
declare db_name=""
declare backup_dir="$DEFAULT_BACKUP_DIR"
declare backup_type="full"
declare -i retention_days=30
declare -i retention_weekly=4
declare compress=true
declare encrypt=false
declare gpg_key=""
declare restore_file=""
declare output_format="table"

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション] コマンド

MySQLバックアップ管理ツール

コマンド:
  backup            データベースをバックアップ (デフォルト)
  restore FILE      バックアップからリストア
  list              バックアップ一覧表示
  verify FILE       バックアップファイルを検証
  cleanup           古いバックアップを削除
  schedule          バックアップスケジュールを表示

オプション:
  -h, --help              このヘルプを表示
  -v, --version           バージョン情報を表示
  -H, --host HOST         MySQLホスト [デフォルト: localhost]
  -P, --port PORT         MySQLポート [デフォルト: 3306]
  -u, --user USER         MySQLユーザー [デフォルト: root]
  -d, --database DB       対象データベース (省略時は全DB)
  -D, --dir DIR           バックアップ保存先 [デフォルト: $DEFAULT_BACKUP_DIR]
  -t, --type TYPE         バックアップ種別 (full|schema|data) [デフォルト: full]
  -r, --retention DAYS    バックアップ保持日数 [デフォルト: 30]
  -w, --weekly NUM        週次バックアップ保持数 [デフォルト: 4]
  --no-compress           圧縮を無効化
  --encrypt               GPG暗号化を有効化
  --gpg-key KEY           GPG鍵のID/メールアドレス
  -f, --format FMT        一覧出力形式 (table|csv)

環境変数:
  MYSQL_USER              MySQLユーザー名
  MYSQL_PWD               MySQLパスワード

例:
  $PROG_NAME backup -d myapp
  $PROG_NAME backup -d myapp -t schema
  $PROG_NAME list -D /backups/mysql
  $PROG_NAME restore backup_20260101_120000_myapp.sql.gz -d myapp
  $PROG_NAME cleanup -r 14
  $PROG_NAME verify backup_20260101_120000_myapp.sql.gz

EOF
}

mysql_opts() {
    local opts=(-h "$db_host" -P "$db_port" -u "$db_user")
    [[ -n "$db_password" ]] && opts+=(-p"$db_password")
    echo "${opts[@]}"
}

get_backup_filename() {
    local db="${1:-all}"
    local type="$2"
    echo "${TIMESTAMP}_${db}_${type}.sql"
}

do_backup() {
    mkdir -p "$backup_dir"

    local mc
    read -ra mc <<< "$(mysql_opts)"

    # 接続テスト
    if ! mysqladmin "${mc[@]}" ping --silent 2>/dev/null; then
        error_exit "MySQLへの接続に失敗しました: ${db_host}:${db_port}"
    fi

    # バックアップ対象DB取得
    local -a databases=()
    if [[ -n "$db_name" ]]; then
        databases=("$db_name")
    else
        mapfile -t databases < <(
            mysql "${mc[@]}" -N -e "SHOW DATABASES;" 2>/dev/null | \
            grep -v -E '^(information_schema|performance_schema|mysql|sys)$'
        )
    fi

    if [[ ${#databases[@]} -eq 0 ]]; then
        log_warning "バックアップ対象のデータベースがありません"
        return 0
    fi

    log_info "バックアップ開始: ${#databases[@]} DB(s) → $backup_dir"
    echo ""

    local success_count=0
    local total=${#databases[@]}

    for db in "${databases[@]}"; do
        local filename
        filename=$(get_backup_filename "$db" "$backup_type")
        local filepath="${backup_dir}/${filename}"

        printf "  [%d/%d] %s ... " "$(( success_count + 1 ))" "$total" "$db"

        local dump_opts=("${mc[@]}" --single-transaction --quick --lock-tables=false)

        case "$backup_type" in
            schema) dump_opts+=(--no-data) ;;
            data)   dump_opts+=(--no-create-info) ;;
        esac

        dump_opts+=("$db")

        if $compress; then
            filepath="${filepath}.gz"
            if mysqldump "${dump_opts[@]}" 2>/dev/null | gzip > "$filepath"; then
                local size
                size=$(du -sh "$filepath" | cut -f1)
                printf "${C_GREEN}OK${C_RESET} (%s)\n" "$size"
            else
                printf "${C_RED}FAILED${C_RESET}\n"
                rm -f "$filepath"
                continue
            fi
        else
            if mysqldump "${dump_opts[@]}" > "$filepath" 2>/dev/null; then
                local size
                size=$(du -sh "$filepath" | cut -f1)
                printf "${C_GREEN}OK${C_RESET} (%s)\n" "$size"
            else
                printf "${C_RED}FAILED${C_RESET}\n"
                rm -f "$filepath"
                continue
            fi
        fi

        if $encrypt && [[ -n "$gpg_key" ]]; then
            gpg --recipient "$gpg_key" --encrypt "$filepath" && rm -f "$filepath"
            filepath="${filepath}.gpg"
            printf "    ${C_DIM}→ GPG暗号化: $(basename "$filepath")${C_RESET}\n"
        fi

        (( success_count++ )) || true
        draw_progress_bar "$success_count" "$total" 30
        echo ""
    done

    echo ""
    log_success "バックアップ完了: ${success_count}/${total} DB"
    echo "  保存先: $backup_dir"
    echo ""
}

do_list() {
    if [[ ! -d "$backup_dir" ]]; then
        log_warning "バックアップディレクトリが存在しません: $backup_dir"
        return 0
    fi

    log_info "バックアップ一覧: $backup_dir"
    echo ""

    local -a files
    mapfile -t files < <(find "$backup_dir" -maxdepth 1 -name "*.sql*" -o -name "*.sql.gz*" | sort -r)

    if [[ ${#files[@]} -eq 0 ]]; then
        log_warning "バックアップファイルが見つかりません"
        return 0
    fi

    if [[ "$output_format" == "csv" ]]; then
        echo "ファイル,サイズ,更新日時"
    else
        printf "  ${C_BOLD}%-45s %8s %-20s${C_RESET}\n" "ファイル名" "サイズ" "作成日時"
        printf "  %s\n" "$(printf '%.0s-' {1..76})"
    fi

    local total_size=0
    for f in "${files[@]}"; do
        local basename_f
        basename_f=$(basename "$f")
        local size_human
        size_human=$(du -sh "$f" | cut -f1)
        local size_bytes
        size_bytes=$(stat -c%s "$f")
        local mtime
        mtime=$(stat -c '%y' "$f" | cut -d'.' -f1)
        (( total_size += size_bytes )) || true

        if [[ "$output_format" == "csv" ]]; then
            echo "${basename_f},${size_human},${mtime}"
        else
            printf "  %-45s %8s %s\n" "$basename_f" "$size_human" "$mtime"
        fi
    done

    echo ""
    local total_mb=$(( total_size / 1024 / 1024 ))
    printf "  合計: ${C_BOLD}%d ファイル${C_RESET}, ${C_CYAN}%d MB${C_RESET}\n" "${#files[@]}" "$total_mb"
    echo ""
}

do_restore() {
    local file="${restore_file}"
    [[ -z "$file" ]] && error_exit "リストアするファイルを指定してください"
    [[ ! -f "$file" ]] && error_exit "ファイルが見つかりません: $file"
    [[ -z "$db_name" ]] && error_exit "リストア先のデータベースを -d で指定してください"

    local mc
    read -ra mc <<< "$(mysql_opts)"

    log_info "リストア: $file → $db_name"
    echo ""
    confirm "データベース '$db_name' を上書きしますか?" "n" || { log_info "キャンセル"; return 0; }

    # DB作成(存在しない場合)
    mysql "${mc[@]}" -e "CREATE DATABASE IF NOT EXISTS \`${db_name}\`;" 2>/dev/null

    if [[ "$file" == *.gz ]]; then
        if gunzip -c "$file" | mysql "${mc[@]}" "$db_name" 2>/dev/null; then
            log_success "リストア完了: $db_name"
        else
            error_exit "リストアに失敗しました"
        fi
    else
        if mysql "${mc[@]}" "$db_name" < "$file" 2>/dev/null; then
            log_success "リストア完了: $db_name"
        else
            error_exit "リストアに失敗しました"
        fi
    fi
}

do_verify() {
    local file="${restore_file}"
    [[ -z "$file" ]] && error_exit "検証するファイルを指定してください"
    [[ ! -f "$file" ]] && error_exit "ファイルが見つかりません: $file"

    log_info "バックアップ検証: $file"
    echo ""

    local check_ok=true

    # ファイルサイズチェック
    local size
    size=$(stat -c%s "$file")
    if (( size > 0 )); then
        printf "  %-30s ${C_GREEN}OK${C_RESET} (%d bytes)\n" "ファイルサイズ:" "$size"
    else
        printf "  %-30s ${C_RED}FAIL${C_RESET} (空ファイル)\n" "ファイルサイズ:"
        check_ok=false
    fi

    # 形式チェック
    if [[ "$file" == *.gz ]]; then
        if gzip -t "$file" 2>/dev/null; then
            printf "  %-30s ${C_GREEN}OK${C_RESET}\n" "gzip整合性:"
        else
            printf "  %-30s ${C_RED}FAIL${C_RESET}\n" "gzip整合性:"
            check_ok=false
        fi

        # SQLチェック
        local first_line
        first_line=$(gunzip -c "$file" 2>/dev/null | head -1)
        if echo "$first_line" | grep -qi "mysqldump\|mysql\|mariadb"; then
            printf "  %-30s ${C_GREEN}OK${C_RESET}\n" "SQLフォーマット:"
        else
            printf "  %-30s ${C_YELLOW}WARN${C_RESET} (MySQLダンプではない可能性)\n" "SQLフォーマット:"
        fi

        # テーブル数カウント
        local table_count
        table_count=$(gunzip -c "$file" 2>/dev/null | grep -c "^CREATE TABLE" || true)
        printf "  %-30s %d\n" "テーブル数:" "$table_count"
    else
        if [[ "$(head -1 "$file")" =~ (MySQL|MariaDB|mysqldump) ]]; then
            printf "  %-30s ${C_GREEN}OK${C_RESET}\n" "SQLフォーマット:"
        else
            printf "  %-30s ${C_YELLOW}WARN${C_RESET}\n" "SQLフォーマット:"
        fi
    fi

    echo ""
    if $check_ok; then
        log_success "バックアップファイルは正常です"
    else
        log_error "バックアップファイルに問題があります"
        return 1
    fi
}

do_cleanup() {
    if [[ ! -d "$backup_dir" ]]; then
        log_warning "バックアップディレクトリが存在しません: $backup_dir"
        return 0
    fi

    log_info "古いバックアップを削除 (${retention_days}日以上経過)"
    echo ""

    local -a old_files
    mapfile -t old_files < <(find "$backup_dir" -maxdepth 1 \( -name "*.sql" -o -name "*.sql.gz" \) -mtime +"$retention_days" 2>/dev/null || true)

    if [[ ${#old_files[@]} -eq 0 ]]; then
        log_info "削除対象のバックアップファイルはありません"
        return 0
    fi

    printf "  削除対象: %d ファイル\n" "${#old_files[@]}"
    for f in "${old_files[@]}"; do
        printf "  %s\n" "$(basename "$f")"
    done

    confirm "削除しますか?" "n" || { log_info "キャンセル"; return 0; }

    local removed=0
    for f in "${old_files[@]}"; do
        rm -f "$f" && (( removed++ )) || true
    done

    log_success "${removed} ファイルを削除しました"
    echo ""
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -H|--host)    [[ $# -lt 2 ]] && error_exit "-H には値が必要です"; db_host="$2"; shift 2 ;;
            -P|--port)    [[ $# -lt 2 ]] && error_exit "-P には値が必要です"; db_port="$2"; shift 2 ;;
            -u|--user)    [[ $# -lt 2 ]] && error_exit "-u には値が必要です"; db_user="$2"; shift 2 ;;
            -d|--database) [[ $# -lt 2 ]] && error_exit "-d には値が必要です"; db_name="$2"; shift 2 ;;
            -D|--dir)     [[ $# -lt 2 ]] && error_exit "-D には値が必要です"; backup_dir="$2"; shift 2 ;;
            -t|--type)    [[ $# -lt 2 ]] && error_exit "-t には値が必要です"; backup_type="$2"; shift 2 ;;
            -r|--retention) [[ $# -lt 2 ]] && error_exit "-r には値が必要です"; retention_days="$2"; shift 2 ;;
            -w|--weekly)  [[ $# -lt 2 ]] && error_exit "-w には値が必要です"; retention_weekly="$2"; shift 2 ;;
            --no-compress) compress=false; shift ;;
            --encrypt)    encrypt=true; shift ;;
            --gpg-key)    [[ $# -lt 2 ]] && error_exit "--gpg-key には値が必要です"; gpg_key="$2"; shift 2 ;;
            -f|--format)  [[ $# -lt 2 ]] && error_exit "-f には値が必要です"; output_format="$2"; shift 2 ;;
            backup|list|cleanup|schedule) mode="$1"; shift ;;
            restore)
                mode="restore"
                [[ $# -ge 2 && ! "$2" =~ ^- ]] && { restore_file="$2"; shift; }
                shift
                ;;
            verify)
                mode="verify"
                [[ $# -ge 2 && ! "$2" =~ ^- ]] && { restore_file="$2"; shift; }
                shift
                ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  shift ;;
        esac
    done
}

main() {
    parse_arguments "$@"

    case "$mode" in
        backup)  do_backup ;;
        restore) do_restore ;;
        list)    do_list ;;
        verify)  do_verify ;;
        cleanup) do_cleanup ;;
        *)       error_exit "不明なコマンド: $mode" ;;
    esac
}

main "$@"
