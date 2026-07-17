#!/bin/bash
set -euo pipefail

#
# ログローテーションユーティリティ
# バージョン: 1.0
#
# ログファイルのローテーション・圧縮・古いファイル削除ツール
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare -a LOG_FILES=()
declare -i keep_count=7
declare compress=true
declare dry_run=false
declare -i max_size_mb=100
declare suffix_format="%Y%m%d"

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション] ログファイル [ログファイル...]

ログファイルのローテーション・圧縮・クリーンアップツール

引数:
  ログファイル          対象ログファイル (複数指定可)

オプション:
  -h, --help            このヘルプを表示
  -v, --version         バージョン情報を表示
  -k, --keep NUM        保持するバックアップ数 [デフォルト: 7]
  -s, --size MB         ローテーション閾値 (MB) [デフォルト: 100]
  --no-compress         圧縮しない
  --dry-run             実際には実行せず内容を表示

例:
  $PROG_NAME /var/log/app.log
  $PROG_NAME -k 14 -s 50 /var/log/app.log /var/log/error.log
  $PROG_NAME --dry-run /var/log/app.log

EOF
}

get_file_size_mb() {
    local file="$1"
    local size_bytes
    size_bytes=$(stat -c %s "$file" 2>/dev/null || echo 0)
    echo $(( size_bytes / 1024 / 1024 ))
}

needs_rotation() {
    local file="$1"
    local size_mb
    size_mb=$(get_file_size_mb "$file")
    (( size_mb >= max_size_mb ))
}

rotate_file() {
    local file="$1"
    local dir base
    dir=$(dirname "$file")
    base=$(basename "$file")

    local timestamp
    timestamp=$(date +"$suffix_format")
    local rotated="${file}.${timestamp}"

    if [[ "$dry_run" == true ]]; then
        log_info "[DRY-RUN] $file → $rotated"
        if [[ "$compress" == true ]]; then
            log_info "[DRY-RUN] 圧縮: ${rotated}.gz"
        fi
        return
    fi

    cp "$file" "$rotated"
    : > "$file"
    log_success "ローテーション完了: $rotated"

    if [[ "$compress" == true ]]; then
        gzip -f "$rotated"
        log_success "圧縮完了: ${rotated}.gz"
    fi
}

cleanup_old_files() {
    local file="$1"
    local dir base pattern
    dir=$(dirname "$file")
    base=$(basename "$file")

    local -a backups
    mapfile -t backups < <(
        find "$dir" -maxdepth 1 -name "${base}.*" \
            \( -name "*.gz" -o -name "*.bz2" -o -name "${base}.[0-9]*" \) \
            | sort -r
    )

    local count=${#backups[@]}
    if (( count > keep_count )); then
        local to_delete=$(( count - keep_count ))
        log_info "${base}: バックアップ ${count}個 → ${keep_count}個 (${to_delete}個削除)"
        for (( i=keep_count; i<count; i++ )); do
            if [[ "$dry_run" == true ]]; then
                log_info "[DRY-RUN] 削除: ${backups[$i]}"
            else
                rm -f "${backups[$i]}"
                log_success "削除: ${backups[$i]}"
            fi
        done
    else
        log_info "${base}: バックアップ ${count}個 (保持上限: ${keep_count}個)"
    fi
}

process_file() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        log_warning "ファイルが存在しません: $file"
        return
    fi

    local size_mb
    size_mb=$(get_file_size_mb "$file")
    log_info "処理: $file (${size_mb}MB)"

    if needs_rotation "$file"; then
        rotate_file "$file"
    else
        log_info "  ローテーション不要 (${size_mb}MB < ${max_size_mb}MB)"
    fi

    cleanup_old_files "$file"
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -k|--keep)
                [[ $# -lt 2 ]] && error_exit "--keep には数値が必要です"
                if ! [[ "$2" =~ ^[0-9]+$ ]]; then
                    error_exit "保持数は数値で指定してください"
                fi
                keep_count="$2"; shift 2 ;;
            -s|--size)
                [[ $# -lt 2 ]] && error_exit "--size には数値が必要です"
                if ! [[ "$2" =~ ^[0-9]+$ ]]; then
                    error_exit "サイズは数値 (MB) で指定してください"
                fi
                max_size_mb="$2"; shift 2 ;;
            --no-compress) compress=false; shift ;;
            --dry-run)     dry_run=true; shift ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  LOG_FILES+=("$1"); shift ;;
        esac
    done
}

main() {
    parse_arguments "$@"

    if [[ ${#LOG_FILES[@]} -eq 0 ]]; then
        error_exit "ログファイルを指定してください。詳細は --help を参照"
    fi

    [[ "$dry_run" == true ]] && log_warning "DRY-RUNモード: 実際の変更は行いません"

    log_info "ログローテーション開始 (保持数: ${keep_count}, 閾値: ${max_size_mb}MB)"
    echo ""

    for file in "${LOG_FILES[@]}"; do
        process_file "$file"
        echo ""
    done

    log_success "ローテーション処理完了"
}

main "$@"
