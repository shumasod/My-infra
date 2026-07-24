#!/bin/bash
set -euo pipefail

#
# バックアップ管理ツール
# バージョン: 1.0
#
# ファイル・ディレクトリの定期バックアップ・世代管理ツール
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare action=""
declare -a sources=()
declare dest_dir="/backup"
declare -i keep_daily=7
declare -i keep_weekly=4
declare -i keep_monthly=12
declare compress=true
declare encrypt=false
declare encrypt_key=""
declare dry_run=false
declare restore_file=""
declare restore_dest="."

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME <アクション> [オプション] [ソース...]

バックアップ管理ツール

アクション:
  backup    バックアップを作成
  list      バックアップ一覧
  restore   バックアップを復元
  clean     古いバックアップを削除
  verify    バックアップを検証

オプション:
  -h, --help            このヘルプを表示
  -v, --version         バージョン情報を表示
  -d, --dest DIR        バックアップ先 [デフォルト: /backup]
  --keep-daily NUM      日次保持数 [デフォルト: 7]
  --keep-weekly NUM     週次保持数 [デフォルト: 4]
  --keep-monthly NUM    月次保持数 [デフォルト: 12]
  --no-compress         圧縮しない
  --encrypt KEY         GPG暗号化 (キーID指定)
  --dry-run             実際には実行しない
  -r, --restore FILE    復元するバックアップファイル
  -o, --output DIR      復元先ディレクトリ [デフォルト: .]

例:
  $PROG_NAME backup /etc /home/user
  $PROG_NAME backup -d /mnt/nas /var/www
  $PROG_NAME list
  $PROG_NAME restore -r backup_20240101_120000.tar.gz
  $PROG_NAME clean

EOF
}

make_backup_name() {
    local source="$1"
    local base
    base=$(basename "$source" | tr '/' '_')
    local timestamp
    timestamp=$(date '+%Y%m%d_%H%M%S')
    local day_of_week
    day_of_week=$(date '+%u')
    local day_of_month
    day_of_month=$(date '+%d')

    local suffix="daily"
    (( day_of_week == 7 )) && suffix="weekly"
    (( 10#$day_of_month == 1 )) && suffix="monthly"

    echo "${base}_${timestamp}_${suffix}"
}

do_backup() {
    [[ ${#sources[@]} -eq 0 ]] && error_exit "バックアップ元を指定してください"

    mkdir -p "$dest_dir"
    log_info "バックアップ開始 → $dest_dir"
    echo ""

    local -i success=0
    local -i fail=0

    for src in "${sources[@]}"; do
        if [[ ! -e "$src" ]]; then
            log_warning "存在しません: $src"
            (( fail++ )) || true
            continue
        fi

        local name
        name=$(make_backup_name "$src")
        local outfile="${dest_dir}/${name}"

        local tar_args=(-czf)
        [[ "$compress" == false ]] && tar_args=(-cf)

        if [[ "$compress" == true ]]; then
            outfile="${outfile}.tar.gz"
        else
            outfile="${outfile}.tar"
        fi

        printf "  バックアップ中: %s\n" "$src"

        if [[ "$dry_run" == true ]]; then
            log_info "[DRY-RUN] → $outfile"
            (( success++ )) || true
            continue
        fi

        if tar "${tar_args[@]}" "$outfile" -C "$(dirname "$src")" "$(basename "$src")" 2>/dev/null; then
            local size
            size=$(du -sh "$outfile" | awk '{print $1}')
            log_success "完了: $outfile ($size)"
            (( success++ )) || true
        else
            log_error "失敗: $src"
            (( fail++ )) || true
        fi

        if [[ "$encrypt" == true && -n "$encrypt_key" && "$dry_run" == false ]]; then
            gpg --recipient "$encrypt_key" --encrypt "$outfile" && rm -f "$outfile"
            log_success "暗号化: ${outfile}.gpg"
        fi
    done

    echo ""
    log_info "結果: 成功 ${success}件 / 失敗 ${fail}件"
}

do_list() {
    log_info "バックアップ一覧: $dest_dir"
    echo ""

    if [[ ! -d "$dest_dir" ]]; then
        log_info "バックアップディレクトリが存在しません"
        return
    fi

    printf "  %-50s %-12s %s\n" "ファイル名" "サイズ" "日付"
    printf "  %s\n" "$(printf '%.0s-' {1..75})"

    find "$dest_dir" -maxdepth 1 \( -name "*.tar.gz" -o -name "*.tar" -o -name "*.gpg" \) \
        -printf "%T@ %f\n" 2>/dev/null | sort -rn | head -30 | \
    while read -r _ fname; do
        local fpath="${dest_dir}/${fname}"
        local size
        size=$(du -sh "$fpath" 2>/dev/null | awk '{print $1}')
        local mtime
        mtime=$(stat -c '%y' "$fpath" 2>/dev/null | cut -c1-16)

        local type_color="$C_GREEN"
        [[ "$fname" == *"_weekly_"* ]]  && type_color="$C_BLUE"
        [[ "$fname" == *"_monthly_"* ]] && type_color="$C_YELLOW"

        printf "  %b%-50s%b %-12s %s\n" "$type_color" "${fname:0:48}" "$C_RESET" "$size" "$mtime"
    done

    echo ""
    local total_size
    total_size=$(du -sh "$dest_dir" 2>/dev/null | awk '{print $1}')
    printf "  合計使用量: %s\n\n" "$total_size"
}

do_restore() {
    [[ -z "$restore_file" ]] && error_exit "--restore でファイルを指定してください"

    local restore_path
    if [[ -f "$restore_file" ]]; then
        restore_path="$restore_file"
    elif [[ -f "${dest_dir}/${restore_file}" ]]; then
        restore_path="${dest_dir}/${restore_file}"
    else
        error_exit "バックアップファイルが見つかりません: $restore_file"
    fi

    log_info "復元: $restore_path → $restore_dest"
    mkdir -p "$restore_dest"

    if [[ "$dry_run" == true ]]; then
        log_info "[DRY-RUN] tar -tzf $restore_path"
        tar -tzf "$restore_path" | head -20
        return
    fi

    if tar -xzf "$restore_path" -C "$restore_dest" 2>/dev/null; then
        log_success "復元完了: $restore_dest"
    else
        error_exit "復元失敗"
    fi
}

do_clean() {
    [[ ! -d "$dest_dir" ]] && { log_info "バックアップディレクトリが存在しません"; return; }

    log_info "古いバックアップ削除 (日次: ${keep_daily}日, 週次: ${keep_weekly}週, 月次: ${keep_monthly}月)"
    echo ""

    local -i deleted=0

    for pattern in "daily" "weekly" "monthly"; do
        local keep
        case "$pattern" in
            daily)   keep=$keep_daily ;;
            weekly)  keep=$keep_weekly ;;
            monthly) keep=$keep_monthly ;;
        esac

        mapfile -t files < <(
            find "$dest_dir" -maxdepth 1 -name "*_${pattern}*" \
                -printf "%T@ %f\n" 2>/dev/null | sort -rn | awk '{print $2}'
        )

        if (( ${#files[@]} > keep )); then
            for (( i=keep; i<${#files[@]}; i++ )); do
                local fpath="${dest_dir}/${files[$i]}"
                if [[ "$dry_run" == true ]]; then
                    log_info "[DRY-RUN] 削除: ${files[$i]}"
                else
                    rm -f "$fpath"
                    log_success "削除: ${files[$i]}"
                    (( deleted++ )) || true
                fi
            done
        fi
    done

    echo ""
    log_info "${deleted}件削除しました"
}

do_verify() {
    [[ ! -d "$dest_dir" ]] && error_exit "バックアップディレクトリが存在しません"

    log_info "バックアップ検証: $dest_dir"
    echo ""

    local -i ok=0 ng=0
    find "$dest_dir" -maxdepth 1 -name "*.tar.gz" | while read -r f; do
        if tar -tzf "$f" &>/dev/null; then
            printf "  ${C_GREEN}OK${C_RESET}  %s\n" "$(basename "$f")"
            (( ok++ )) || true
        else
            printf "  ${C_RED}NG${C_RESET}  %s\n" "$(basename "$f")"
            (( ng++ )) || true
        fi
    done

    echo ""
    log_info "検証完了"
}

parse_arguments() {
    [[ $# -eq 0 ]] && { show_usage; exit 0; }
    action="$1"; shift

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -d|--dest)         [[ $# -lt 2 ]] && error_exit "--dest には値が必要です"; dest_dir="$2"; shift 2 ;;
            --keep-daily)      [[ $# -lt 2 ]] && error_exit "--keep-daily には数値が必要です"; keep_daily="$2"; shift 2 ;;
            --keep-weekly)     [[ $# -lt 2 ]] && error_exit "--keep-weekly には数値が必要です"; keep_weekly="$2"; shift 2 ;;
            --keep-monthly)    [[ $# -lt 2 ]] && error_exit "--keep-monthly には数値が必要です"; keep_monthly="$2"; shift 2 ;;
            --no-compress)     compress=false; shift ;;
            --encrypt)         [[ $# -lt 2 ]] && error_exit "--encrypt にはキーIDが必要です"; encrypt=true; encrypt_key="$2"; shift 2 ;;
            --dry-run)         dry_run=true; shift ;;
            -r|--restore)      [[ $# -lt 2 ]] && error_exit "--restore には値が必要です"; restore_file="$2"; shift 2 ;;
            -o|--output)       [[ $# -lt 2 ]] && error_exit "--output には値が必要です"; restore_dest="$2"; shift 2 ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  sources+=("$1"); shift ;;
        esac
    done
}

main() {
    parse_arguments "$@"

    case "$action" in
        backup)  do_backup ;;
        list)    do_list ;;
        restore) do_restore ;;
        clean)   do_clean ;;
        verify)  do_verify ;;
        *)       error_exit "不明なアクション: $action。--help を参照してください" ;;
    esac
}

main "$@"
