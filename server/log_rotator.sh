#!/bin/bash
set -euo pipefail

#
# ログローテーションツール
# 作成日: 2026-08-25
# バージョン: 1.0
#
# アプリケーションログのローテーション・アーカイブ・削除を管理します
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare command_name="status"
declare config_file=""
declare log_dir="/var/log"
declare max_size="100M"
declare keep_count=10
declare keep_days=30
declare compress=1
declare dry_run=0
declare pattern="*.log"

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション]

ログファイルのローテーション管理ツールです。

コマンド:
  status               ログファイルの状況確認 (デフォルト)
  rotate               ログローテーション実行
  archive              古いログをアーカイブ
  clean                古いログを削除
  analyze              ログディレクトリの分析
  watch <ファイル>     ログファイルを監視 (サイズアラート)

オプション:
  -h, --help           このヘルプを表示
  -v, --version        バージョン情報を表示
  -d, --dir <ディレクトリ> 対象ディレクトリ [デフォルト: /var/log]
  -p, --pattern <パターン> ファイルパターン [デフォルト: *.log]
  -s, --size <サイズ>  ローテーション閾値 (例: 100M, 1G) [デフォルト: 100M]
  -k, --keep <数>      保持ファイル数 [デフォルト: 10]
  -r, --retention <日数> 保持日数 [デフォルト: 30]
  --no-compress        圧縮を無効化
  -n, --dry-run        実行せず確認のみ

例:
  $PROG_NAME status -d /var/log/nginx
  $PROG_NAME rotate -d /app/logs -s 50M -k 5
  $PROG_NAME clean --retention 7 -d /var/log/app
  $PROG_NAME analyze -d /var/log
EOF
}

parse_size() {
    local size_str="$1"
    local unit="${size_str: -1}"
    local num="${size_str:0:-1}"
    case "${unit^^}" in
        G) echo $(( num * 1073741824 )) ;;
        M) echo $(( num * 1048576 )) ;;
        K) echo $(( num * 1024 )) ;;
        *) echo "$size_str" ;;
    esac
}

format_size() {
    local bytes="$1"
    if (( bytes >= 1073741824 )); then
        printf "%.1f GB" "$(echo "scale=1; $bytes/1073741824" | bc)"
    elif (( bytes >= 1048576 )); then
        printf "%.1f MB" "$(echo "scale=1; $bytes/1048576" | bc)"
    elif (( bytes >= 1024 )); then
        printf "%.1f KB" "$(echo "scale=1; $bytes/1024" | bc)"
    else
        printf "%d B" "$bytes"
    fi
}

get_log_files() {
    find "$log_dir" -maxdepth 2 -type f -name "$pattern" 2>/dev/null | sort
}

cmd_status() {
    log_info "ログファイル状況: $log_dir"
    echo ""

    local threshold
    threshold=$(parse_size "$max_size")

    printf "${C_BOLD}  %-45s %10s %12s %s${C_RESET}\n" "ファイル" "サイズ" "最終更新" "状態"
    printf "  %s\n" "$(printf '%.0s─' {1..80})"

    local total_size=0 count=0 large_count=0

    while IFS= read -r f; do
        local size mtime
        size=$(stat -c%s "$f" 2>/dev/null || echo 0)
        mtime=$(stat -c%Y "$f" 2>/dev/null || echo 0)
        local age_days=$(( ($(date +%s) - mtime) / 86400 ))
        local date_str
        date_str=$(date -d "@$mtime" "+%Y-%m-%d" 2>/dev/null || echo "N/A")

        local status_str="正常" color="$C_GREEN"
        if (( size > threshold )); then
            status_str="要ローテーション"
            color="$C_RED"
            (( large_count++ ))
        elif (( size > threshold / 2 )); then
            status_str="注意"
            color="$C_YELLOW"
        fi
        if (( age_days > keep_days )); then
            status_str="古い"
            color="$C_DIM"
        fi

        local fname
        fname=$(basename "$f")
        printf "  %-45s %10s %12s ${color}%s${C_RESET}\n" \
            "${f:0:43}" "$(format_size "$size")" "$date_str" "$status_str"

        (( total_size += size ))
        (( count++ ))
    done < <(get_log_files)

    echo ""
    printf "  合計: %d ファイル  総サイズ: %s  要対応: ${C_RED}%d${C_RESET}\n" \
        "$count" "$(format_size "$total_size")" "$large_count"
    echo ""
}

rotate_file() {
    local f="$1"
    local base="${f%.log}"
    local ts
    ts=$(date +"%Y%m%d_%H%M%S")
    local rotated="${base}_${ts}.log"

    if (( dry_run )); then
        log_info "[DRY-RUN] ローテーション: $f -> $(basename "$rotated")"
        return
    fi

    cp "$f" "$rotated"
    : > "$f"

    if (( compress )); then
        gzip "$rotated"
        rotated="${rotated}.gz"
    fi

    log_success "ローテーション完了: $(basename "$rotated")"

    local dir
    dir=$(dirname "$f")
    local base_name
    base_name=$(basename "${f%.log}")

    local old_files=()
    while IFS= read -r old; do
        old_files+=("$old")
    done < <(find "$dir" -maxdepth 1 -name "${base_name}_*.log*" | sort | head -n -"$keep_count")

    for old in "${old_files[@]}"; do
        if (( dry_run )); then
            log_info "[DRY-RUN] 削除: $old"
        else
            rm -f "$old"
            log_info "古いログを削除: $(basename "$old")"
        fi
    done
}

cmd_rotate() {
    log_info "ログローテーション実行 (閾値: $max_size)"
    (( dry_run )) && log_warning "DRY-RUNモード: 実際には変更しません"
    echo ""

    local threshold
    threshold=$(parse_size "$max_size")
    local rotated=0

    while IFS= read -r f; do
        local size
        size=$(stat -c%s "$f" 2>/dev/null || echo 0)
        if (( size >= threshold )); then
            rotate_file "$f"
            (( rotated++ ))
        fi
    done < <(get_log_files)

    echo ""
    if (( rotated == 0 )); then
        log_info "ローテーションが必要なファイルはありません"
    else
        log_success "ローテーション完了: ${rotated} ファイル"
    fi
    echo ""
}

cmd_archive() {
    log_info "ログアーカイブ作成"
    (( dry_run )) && log_warning "DRY-RUNモード: 実際には変更しません"
    echo ""

    local ts
    ts=$(date +"%Y%m%d_%H%M%S")
    local archive_name="logs_archive_${ts}.tar.gz"
    local archive_path="${log_dir}/${archive_name}"

    local old_files=()
    while IFS= read -r f; do
        local mtime age_days
        mtime=$(stat -c%Y "$f" 2>/dev/null || echo 0)
        age_days=$(( ($(date +%s) - mtime) / 86400 ))
        (( age_days > keep_days )) && old_files+=("$f")
    done < <(get_log_files)

    if [[ ${#old_files[@]} -eq 0 ]]; then
        log_info "${keep_days}日以上前のログファイルはありません"
        return
    fi

    log_info "アーカイブ対象: ${#old_files[@]} ファイル"
    for f in "${old_files[@]}"; do
        printf "  ${C_DIM}%s${C_RESET}\n" "$f"
    done
    echo ""

    if (( ! dry_run )); then
        tar -czf "$archive_path" "${old_files[@]}" 2>/dev/null
        log_success "アーカイブ作成: $archive_path"

        if confirm "アーカイブ元ファイルを削除しますか？" "n"; then
            for f in "${old_files[@]}"; do
                rm -f "$f"
                log_info "削除: $(basename "$f")"
            done
        fi
    else
        log_info "[DRY-RUN] アーカイブ先: $archive_path"
    fi
    echo ""
}

cmd_clean() {
    log_info "古いログファイルを削除 (${keep_days}日以上前)"
    (( dry_run )) && log_warning "DRY-RUNモード: 実際には変更しません"
    echo ""

    local deleted=0 freed=0

    while IFS= read -r f; do
        local mtime age_days size
        mtime=$(stat -c%Y "$f" 2>/dev/null || echo 0)
        age_days=$(( ($(date +%s) - mtime) / 86400 ))
        size=$(stat -c%s "$f" 2>/dev/null || echo 0)

        if (( age_days > keep_days )); then
            printf "  ${C_DIM}削除: %s (%s, %d日前)${C_RESET}\n" \
                "$(basename "$f")" "$(format_size "$size")" "$age_days"
            if (( ! dry_run )); then
                rm -f "$f"
                (( freed += size ))
            fi
            (( deleted++ ))
        fi
    done < <(find "$log_dir" -maxdepth 2 -type f \( -name "$pattern" -o -name "*.gz" \) 2>/dev/null | sort)

    echo ""
    printf "  削除: ${C_GREEN}%d${C_RESET} ファイル  解放: %s\n" \
        "$deleted" "$(format_size "$freed")"
    echo ""
}

cmd_analyze() {
    log_info "ログディレクトリ分析: $log_dir"
    echo ""

    printf "${C_BOLD}【ディレクトリ別使用量】${C_RESET}\n\n"
    du -sh "${log_dir}"/*/ 2>/dev/null | sort -rh | head -20 | \
    while IFS=$'\t' read -r size dir; do
        printf "  ${C_CYAN}%8s${C_RESET}  %s\n" "$size" "$(basename "$dir")"
    done

    echo ""
    printf "${C_BOLD}【拡張子別ファイル数】${C_RESET}\n\n"
    find "$log_dir" -maxdepth 3 -type f 2>/dev/null | \
        sed 's/.*\.//' | sort | uniq -c | sort -rn | head -15 | \
    while IFS= read -r line; do
        local cnt ext
        cnt=$(echo "$line" | awk '{print $1}')
        ext=$(echo "$line" | awk '{print $2}')
        printf "  ${C_GREEN}%6s${C_RESET}  .%s\n" "$cnt" "$ext"
    done

    echo ""
    printf "${C_BOLD}【最近更新されたファイル】${C_RESET}\n\n"
    find "$log_dir" -maxdepth 2 -type f -name "$pattern" 2>/dev/null \
        -printf "%T@ %s %p\n" | sort -rn | head -10 | \
    while IFS=' ' read -r mtime size path; do
        local date_str
        date_str=$(date -d "@${mtime%.*}" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "N/A")
        printf "  ${C_YELLOW}%s${C_RESET}  %8s  %s\n" \
            "$date_str" "$(format_size "$size")" "$(basename "$path")"
    done
    echo ""
}

cmd_watch() {
    local target_file="${1:-}"
    [[ -z "$target_file" ]] && error_exit "監視するファイルを指定してください"
    [[ ! -f "$target_file" ]] && error_exit "ファイルが見つかりません: $target_file"

    local threshold
    threshold=$(parse_size "$max_size")
    log_info "ファイル監視: $target_file (閾値: $max_size)"
    echo ""

    local cleanup_done=false
    cleanup() { $cleanup_done && return; cleanup_done=true; echo ""; }
    trap cleanup EXIT INT TERM

    local last_size=0
    while true; do
        local size
        size=$(stat -c%s "$target_file" 2>/dev/null || echo 0)
        local growth=$(( size - last_size ))
        last_size=$size

        local ts color="$C_GREEN"
        ts=$(date "+%H:%M:%S")
        (( size > threshold / 2 )) && color="$C_YELLOW"
        (( size > threshold ))     && color="$C_RED"

        local growth_str=""
        (( growth > 0 )) && growth_str=" (+$(format_size "$growth"))"

        printf "\r  ${C_DIM}[%s]${C_RESET} %s: ${color}%s${C_RESET}%s  " \
            "$ts" "$(basename "$target_file")" "$(format_size "$size")" "$growth_str"

        if (( size > threshold )); then
            echo ""
            log_warning "閾値を超えました！ローテーションを検討してください"
        fi

        sleep 5
    done
}

parse_arguments() {
    [[ $# -eq 0 ]] && return 0
    case "$1" in
        status|rotate|archive|clean|analyze|watch)
            command_name="$1"; shift ;;
    esac

    local positional=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)     show_usage; exit 0 ;;
            -v|--version)  echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -d|--dir)      [[ $# -lt 2 ]] && error_exit "--dir には値が必要です"; log_dir="$2"; shift 2 ;;
            -p|--pattern)  [[ $# -lt 2 ]] && error_exit "--pattern には値が必要です"; pattern="$2"; shift 2 ;;
            -s|--size)     [[ $# -lt 2 ]] && error_exit "--size には値が必要です"; max_size="$2"; shift 2 ;;
            -k|--keep)     [[ $# -lt 2 ]] && error_exit "--keep には値が必要です"; keep_count="$2"; shift 2 ;;
            -r|--retention) [[ $# -lt 2 ]] && error_exit "--retention には値が必要です"; keep_days="$2"; shift 2 ;;
            --no-compress) compress=0; shift ;;
            -n|--dry-run)  dry_run=1; shift ;;
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
        status)  cmd_status ;;
        rotate)  cmd_rotate ;;
        archive) cmd_archive ;;
        clean)   cmd_clean ;;
        analyze) cmd_analyze ;;
        watch)   cmd_watch "${POSITIONAL[0]:-}" ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
