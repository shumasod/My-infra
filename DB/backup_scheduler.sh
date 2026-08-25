#!/bin/bash
set -euo pipefail

#
# データベースバックアップスケジューラー
# 作成日: 2026-08-25
# バージョン: 1.0
#
# MySQL/PostgreSQLのバックアップを管理・スケジュールします
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare command_name="status"
declare db_type="mysql"
declare db_host="127.0.0.1"
declare db_port=""
declare db_user="root"
declare db_pass=""
declare db_name=""
declare backup_dir="/var/backup/db"
declare retention_days=30
declare compress=1
declare encrypt=0
declare encrypt_key=""
declare notify_email=""

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション]

データベースバックアップ管理ツールです。

コマンド:
  status               バックアップ状況の確認 (デフォルト)
  backup               即時バックアップ実行
  restore <ファイル>   バックアップから復元
  list                 バックアップ一覧表示
  clean                古いバックアップを削除
  verify <ファイル>    バックアップファイルの検証
  schedule             crontabへの登録ガイド

オプション:
  -h, --help           このヘルプを表示
  -v, --version        バージョン情報を表示
  --type <種類>        DBタイプ (mysql|postgres) [デフォルト: mysql]
  -H, --host <ホスト>  DBホスト [デフォルト: 127.0.0.1]
  -P, --port <ポート>  DBポート
  -u, --user <ユーザー> DBユーザー
  -p, --pass <パスワード> DBパスワード
  -d, --db <DB名>      バックアップ対象DB (all で全DB)
  -o, --output <ディレクトリ> バックアップ保存先 [デフォルト: /var/backup/db]
  -r, --retention <日数> 保持日数 [デフォルト: 30]
  --no-compress        圧縮を無効化
  --encrypt <鍵>       GPG暗号化

例:
  $PROG_NAME backup --type mysql -u root -p secret -d mydb
  $PROG_NAME backup --type postgres -u postgres -d all
  $PROG_NAME list
  $PROG_NAME restore /var/backup/db/mydb_20260825_020000.sql.gz
  $PROG_NAME clean --retention 7
  $PROG_NAME status
EOF
}

get_timestamp() {
    date +"%Y%m%d_%H%M%S"
}

get_db_port() {
    case "$db_type" in
        mysql)    echo "${db_port:-3306}" ;;
        postgres) echo "${db_port:-5432}" ;;
        *)        echo "${db_port:-3306}" ;;
    esac
}

mysql_backup_db() {
    local dbname="$1"
    local outfile="$2"
    local port
    port=$(get_db_port)

    local args=(-h "$db_host" -P "$port" -u "$db_user")
    [[ -n "$db_pass" ]] && args+=(-p"$db_pass")

    mysqldump "${args[@]}" \
        --single-transaction \
        --routines \
        --triggers \
        --events \
        --hex-blob \
        "$dbname" > "$outfile"
}

postgres_backup_db() {
    local dbname="$1"
    local outfile="$2"
    local port
    port=$(get_db_port)

    local env_args=()
    [[ -n "$db_pass" ]] && env_args+=("PGPASSWORD=$db_pass")

    env "${env_args[@]}" pg_dump \
        -h "$db_host" \
        -p "$port" \
        -U "$db_user" \
        -Fc \
        "$dbname" > "$outfile"
}

get_db_list() {
    local port
    port=$(get_db_port)

    case "$db_type" in
        mysql)
            local args=(-h "$db_host" -P "$port" -u "$db_user" --batch --skip-column-names)
            [[ -n "$db_pass" ]] && args+=(-p"$db_pass")
            mysql "${args[@]}" -e "SHOW DATABASES;" 2>/dev/null | \
                grep -v "^information_schema$\|^performance_schema$\|^mysql$\|^sys$"
            ;;
        postgres)
            local env_args=()
            [[ -n "$db_pass" ]] && env_args+=("PGPASSWORD=$db_pass")
            env "${env_args[@]}" psql \
                -h "$db_host" -p "$port" -U "$db_user" \
                -t -c "SELECT datname FROM pg_database WHERE datistemplate=false AND datname NOT IN ('postgres');" \
                2>/dev/null | grep -v "^$"
            ;;
    esac
}

do_backup_single() {
    local dbname="$1"
    local ts
    ts=$(get_timestamp)
    local base="${backup_dir}/${db_type}_${dbname}_${ts}"
    local ext="sql"

    [[ "$db_type" == "postgres" ]] && ext="dump"

    mkdir -p "$backup_dir"
    local tmpfile="${base}.${ext}.tmp"

    log_info "バックアップ開始: $dbname"
    local start
    start=$(date +%s)

    case "$db_type" in
        mysql)    mysql_backup_db    "$dbname" "$tmpfile" ;;
        postgres) postgres_backup_db "$dbname" "$tmpfile" ;;
    esac

    local outfile="${base}.${ext}"

    if (( compress )); then
        log_info "圧縮中..."
        gzip -c "$tmpfile" > "${outfile}.gz"
        rm -f "$tmpfile"
        outfile="${outfile}.gz"
    else
        mv "$tmpfile" "$outfile"
    fi

    if (( encrypt )) && [[ -n "$encrypt_key" ]]; then
        log_info "暗号化中..."
        gpg --batch --yes --passphrase "$encrypt_key" \
            --symmetric --cipher-algo AES256 \
            -o "${outfile}.gpg" "$outfile" 2>/dev/null
        rm -f "$outfile"
        outfile="${outfile}.gpg"
    fi

    local end size
    end=$(date +%s)
    size=$(stat -c%s "$outfile" 2>/dev/null || echo 0)
    local size_h
    if (( size >= 1073741824 )); then
        size_h=$(printf "%.1f GB" "$(echo "scale=1; $size/1073741824" | bc)")
    elif (( size >= 1048576 )); then
        size_h=$(printf "%.1f MB" "$(echo "scale=1; $size/1048576" | bc)")
    else
        size_h=$(printf "%d KB" "$(( size / 1024 ))")
    fi

    local elapsed=$(( end - start ))
    log_success "バックアップ完了: $outfile (${size_h}, ${elapsed}秒)"
    echo "$outfile"
}

cmd_backup() {
    log_info "データベースバックアップ開始"
    echo ""

    local dbs=()
    if [[ "$db_name" == "all" || -z "$db_name" ]]; then
        while IFS= read -r d; do
            [[ -n "$d" ]] && dbs+=("$d")
        done < <(get_db_list)
        if [[ ${#dbs[@]} -eq 0 ]]; then
            error_exit "バックアップ対象のDBが見つかりません"
        fi
        log_info "対象DB: ${dbs[*]}"
    else
        dbs=("$db_name")
    fi

    local success=0 failed=0
    for db in "${dbs[@]}"; do
        if do_backup_single "$db"; then
            (( success++ ))
        else
            log_error "バックアップ失敗: $db"
            (( failed++ ))
        fi
    done

    echo ""
    printf "  成功: ${C_GREEN}%d${C_RESET}  失敗: ${C_RED}%d${C_RESET}\n" "$success" "$failed"

    if [[ -n "$notify_email" && "$failed" -gt 0 ]]; then
        echo "バックアップ失敗: $failed DB" | \
            mail -s "[警告] DBバックアップ失敗" "$notify_email" 2>/dev/null || true
    fi
    echo ""
}

cmd_list() {
    log_info "バックアップ一覧: $backup_dir"
    echo ""

    if [[ ! -d "$backup_dir" ]]; then
        log_warning "バックアップディレクトリが存在しません: $backup_dir"
        return
    fi

    printf "${C_BOLD}  %-45s %10s %s${C_RESET}\n" "ファイル名" "サイズ" "作成日時"
    printf "  %s\n" "$(printf '%.0s─' {1..70})"

    local total_size=0
    local count=0

    find "$backup_dir" -maxdepth 1 -type f \
        \( -name "*.sql" -o -name "*.sql.gz" -o -name "*.dump" \
           -o -name "*.dump.gz" -o -name "*.gpg" \) \
        -printf "%T@ %s %f\n" 2>/dev/null | \
    sort -rn | \
    while IFS=' ' read -r mtime size fname; do
        local date_str
        date_str=$(date -d "@${mtime%.*}" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "N/A")
        local size_h
        if (( size >= 1073741824 )); then
            size_h=$(printf "%.1f GB" "$(echo "scale=1; $size/1073741824" | bc)")
        elif (( size >= 1048576 )); then
            size_h=$(printf "%.1f MB" "$(echo "scale=1; $size/1048576" | bc)")
        else
            size_h=$(printf "%d KB" "$(( size / 1024 ))")
        fi
        printf "  %-45s %10s %s\n" "${fname:0:43}" "$size_h" "$date_str"
    done

    echo ""
    local file_count
    file_count=$(find "$backup_dir" -maxdepth 1 -type f \
        \( -name "*.sql*" -o -name "*.dump*" -o -name "*.gpg" \) | wc -l)
    printf "  合計: %d ファイル\n" "$file_count"
    echo ""
}

cmd_restore() {
    local backup_file="${1:-}"
    [[ -z "$backup_file" ]] && error_exit "バックアップファイルを指定してください"
    [[ ! -f "$backup_file" ]] && error_exit "ファイルが見つかりません: $backup_file"

    log_warning "復元先DBを確認してください: ${db_name:-指定なし}"
    [[ -z "$db_name" ]] && error_exit "復元先DBを --db で指定してください"

    if ! confirm "バックアップ '$backup_file' を '$db_name' に復元しますか？" "n"; then
        log_warning "キャンセルしました"
        return
    fi

    local port
    port=$(get_db_port)
    local tmpfile=""

    local work_file="$backup_file"

    if [[ "$backup_file" == *.gpg ]]; then
        [[ -z "$encrypt_key" ]] && error_exit "暗号化ファイルの復号に --encrypt キーが必要です"
        tmpfile=$(mktemp)
        gpg --batch --passphrase "$encrypt_key" --decrypt "$backup_file" > "$tmpfile" 2>/dev/null
        work_file="$tmpfile"
    fi

    log_info "復元中: $backup_file -> $db_name"

    case "$db_type" in
        mysql)
            local args=(-h "$db_host" -P "$port" -u "$db_user")
            [[ -n "$db_pass" ]] && args+=(-p"$db_pass")
            if [[ "$work_file" == *.gz ]]; then
                zcat "$work_file" | mysql "${args[@]}" "$db_name"
            else
                mysql "${args[@]}" "$db_name" < "$work_file"
            fi
            ;;
        postgres)
            local env_args=()
            [[ -n "$db_pass" ]] && env_args+=("PGPASSWORD=$db_pass")
            if [[ "$work_file" == *.dump* ]]; then
                env "${env_args[@]}" pg_restore \
                    -h "$db_host" -p "$port" -U "$db_user" \
                    -d "$db_name" --clean "$work_file" 2>/dev/null
            else
                env "${env_args[@]}" psql \
                    -h "$db_host" -p "$port" -U "$db_user" \
                    -d "$db_name" < "$work_file"
            fi
            ;;
    esac

    [[ -n "$tmpfile" ]] && rm -f "$tmpfile"
    log_success "復元完了: $db_name"
}

cmd_clean() {
    log_info "古いバックアップを削除: ${retention_days}日以上前"
    echo ""

    [[ ! -d "$backup_dir" ]] && { log_warning "ディレクトリなし: $backup_dir"; return; }

    local deleted=0 freed=0
    while IFS= read -r f; do
        local size
        size=$(stat -c%s "$f" 2>/dev/null || echo 0)
        log_info "削除: $(basename "$f")"
        rm -f "$f"
        (( deleted++ ))
        (( freed += size ))
    done < <(find "$backup_dir" -maxdepth 1 -type f \
        \( -name "*.sql*" -o -name "*.dump*" -o -name "*.gpg" \) \
        -mtime "+${retention_days}" 2>/dev/null)

    local freed_mb=$(( freed / 1048576 ))
    printf "  削除: ${C_GREEN}%d${C_RESET} ファイル (${freed_mb} MB 解放)\n" "$deleted"
    echo ""
}

cmd_verify() {
    local backup_file="${1:-}"
    [[ -z "$backup_file" ]] && error_exit "検証するファイルを指定してください"
    [[ ! -f "$backup_file" ]] && error_exit "ファイルが見つかりません: $backup_file"

    log_info "バックアップ検証: $backup_file"
    echo ""

    local size
    size=$(stat -c%s "$backup_file" 2>/dev/null || echo 0)
    printf "  %-20s %s\n" "ファイルサイズ:" "${size} bytes"

    local md5
    md5=$(md5sum "$backup_file" 2>/dev/null | awk '{print $1}')
    printf "  %-20s %s\n" "MD5チェックサム:" "$md5"

    if [[ "$backup_file" == *.gz ]]; then
        if gzip -t "$backup_file" 2>/dev/null; then
            log_success "gzip整合性: OK"
        else
            log_error "gzip整合性: 破損の可能性"
        fi
    fi

    local mtime
    mtime=$(stat -c%Y "$backup_file" 2>/dev/null || echo 0)
    local age=$(( ($(date +%s) - mtime) / 3600 ))
    printf "  %-20s %d時間前\n" "作成:" "$age"
    echo ""
    log_success "検証完了: $backup_file"
}

cmd_status() {
    log_info "バックアップ状況"
    echo ""

    printf "${C_BOLD}【設定】${C_RESET}\n\n"
    printf "  %-20s %s\n" "DBタイプ:"        "$db_type"
    printf "  %-20s %s\n" "接続先:"          "${db_host}:$(get_db_port)"
    printf "  %-20s %s\n" "ユーザー:"        "$db_user"
    printf "  %-20s %s\n" "バックアップ先:"  "$backup_dir"
    printf "  %-20s %d日\n" "保持期間:"      "$retention_days"
    printf "  %-20s %s\n" "圧縮:"            "$( (( compress )) && echo "有効" || echo "無効" )"
    printf "  %-20s %s\n" "暗号化:"          "$( (( encrypt )) && echo "有効" || echo "無効" )"
    echo ""

    if [[ -d "$backup_dir" ]]; then
        local count
        count=$(find "$backup_dir" -maxdepth 1 -type f \
            \( -name "*.sql*" -o -name "*.dump*" -o -name "*.gpg" \) | wc -l)
        local latest
        latest=$(find "$backup_dir" -maxdepth 1 -type f \
            \( -name "*.sql*" -o -name "*.dump*" -o -name "*.gpg" \) \
            -printf "%T@ %f\n" 2>/dev/null | sort -rn | head -1 | awk '{print $2}')
        printf "${C_BOLD}【バックアップ情報】${C_RESET}\n\n"
        printf "  %-20s %d ファイル\n" "バックアップ数:" "$count"
        printf "  %-20s %s\n" "最新:" "${latest:-なし}"
        echo ""
    fi
}

cmd_schedule() {
    log_info "Cron登録ガイド"
    echo ""
    printf "${C_BOLD}以下をcrontabに追加することを推奨します:${C_RESET}\n\n"
    cat <<EOF
  # 毎日午前2時にバックアップ実行
  0 2 * * * $PROG_NAME backup --type $db_type -u $db_user -d all -o $backup_dir >> /var/log/db_backup.log 2>&1

  # 毎週日曜午前3時に古いバックアップを削除
  0 3 * * 0 $PROG_NAME clean --retention $retention_days -o $backup_dir >> /var/log/db_backup.log 2>&1

crontabの編集:
  crontab -e

EOF
    log_info "crontab -e でエディタを開いて上記を貼り付けてください"
}

parse_arguments() {
    [[ $# -eq 0 ]] && return 0
    case "$1" in
        status|backup|restore|list|clean|verify|schedule)
            command_name="$1"; shift ;;
    esac

    local positional=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)     show_usage; exit 0 ;;
            -v|--version)  echo "$PROG_NAME version $VERSION"; exit 0 ;;
            --type)        [[ $# -lt 2 ]] && error_exit "--type には値が必要です"; db_type="$2"; shift 2 ;;
            -H|--host)     [[ $# -lt 2 ]] && error_exit "--host には値が必要です"; db_host="$2"; shift 2 ;;
            -P|--port)     [[ $# -lt 2 ]] && error_exit "--port には値が必要です"; db_port="$2"; shift 2 ;;
            -u|--user)     [[ $# -lt 2 ]] && error_exit "--user には値が必要です"; db_user="$2"; shift 2 ;;
            -p|--pass)     [[ $# -lt 2 ]] && error_exit "--pass には値が必要です"; db_pass="$2"; shift 2 ;;
            -d|--db)       [[ $# -lt 2 ]] && error_exit "--db には値が必要です"; db_name="$2"; shift 2 ;;
            -o|--output)   [[ $# -lt 2 ]] && error_exit "--output には値が必要です"; backup_dir="$2"; shift 2 ;;
            -r|--retention) [[ $# -lt 2 ]] && error_exit "--retention には値が必要です"; retention_days="$2"; shift 2 ;;
            --no-compress) compress=0; shift ;;
            --encrypt)     [[ $# -lt 2 ]] && error_exit "--encrypt には値が必要です"; encrypt=1; encrypt_key="$2"; shift 2 ;;
            --notify)      [[ $# -lt 2 ]] && error_exit "--notify には値が必要です"; notify_email="$2"; shift 2 ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  positional+=("$1"); shift ;;
        esac
    done
    POSITIONAL=("${positional[@]+"${positional[@]}"}")
}

declare -a POSITIONAL=()

main() {
    parse_arguments "$@"
    case "$command_name" in
        status)   cmd_status ;;
        backup)   cmd_backup ;;
        restore)  cmd_restore "${POSITIONAL[0]:-}" ;;
        list)     cmd_list ;;
        clean)    cmd_clean ;;
        verify)   cmd_verify "${POSITIONAL[0]:-}" ;;
        schedule) cmd_schedule ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
