#!/bin/bash
set -euo pipefail

#
# ファイル一括リネームツール
# 作成日: 2026-07-31
# バージョン: 1.0
#
# 正規表現・ナンバリング・大文字小文字変換などによる一括リネームを行います
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare command_name="preview"
declare target_dir="."
declare target_pattern="*"
declare dry_run=true
declare recursive=false
declare -a rename_ops=()

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME <コマンド> [オプション] [ディレクトリ]

ファイルの一括リネームツールです。

コマンド:
  replace <検索> <置換>  文字列を置換してリネーム
  number [開始番号]      連番を付与してリネーム
  lower                  ファイル名を小文字に変換
  upper                  ファイル名を大文字に変換
  trim                   先頭・末尾のスペースを削除
  ext <新拡張子>         拡張子を一括変更
  date                   更新日時をプレフィックスに追加
  preview                リネーム結果をプレビュー

オプション:
  -h, --help             このヘルプを表示
  -v, --version          バージョン情報を表示
  -p, --pattern <パターン> 対象ファイルパターン [デフォルト: *]
  -r, --recursive        サブディレクトリも対象
  --exec                 実際にリネームを実行 (デフォルトはプレビューのみ)
  --prefix <文字列>      プレフィックスを追加
  --suffix <文字列>      サフィックスを追加 (拡張子の前)

例:
  $PROG_NAME replace "image" "photo" -p "*.jpg"
  $PROG_NAME number 1 -p "*.jpg" --exec
  $PROG_NAME lower -p "*.TXT" --exec
  $PROG_NAME ext .md -p "*.txt"
  $PROG_NAME date -p "*.log" --exec
EOF
}

declare -a file_list=()

collect_files() {
    local dir="${target_dir}"
    local pattern="${target_pattern}"

    if $recursive; then
        while IFS= read -r f; do
            [[ -f "$f" ]] && file_list+=("$f")
        done < <(find "$dir" -name "$pattern" -type f | sort)
    else
        while IFS= read -r f; do
            [[ -f "$f" ]] && file_list+=("$f")
        done < <(find "$dir" -maxdepth 1 -name "$pattern" -type f | sort)
    fi
}

do_rename() {
    local src="$1"
    local dst="$2"

    if [[ "$src" == "$dst" ]]; then
        return 0
    fi

    if $dry_run; then
        printf "  ${C_DIM}%-40s${C_RESET} → ${C_CYAN}%s${C_RESET}\n" \
            "$(basename "$src")" "$(basename "$dst")"
    else
        if [[ -e "$dst" ]]; then
            log_warning "スキップ (同名ファイル存在): $(basename "$dst")"
            return 0
        fi
        mv "$src" "$dst"
        printf "  ${C_GREEN}✓${C_RESET} %-40s → %s\n" "$(basename "$src")" "$(basename "$dst")"
    fi
}

cmd_replace() {
    local search="${ARGS[0]:-}"
    local replace="${ARGS[1]:-}"
    [[ -z "$search" ]] && error_exit "検索文字列を指定してください"

    collect_files
    local count=0

    for f in "${file_list[@]}"; do
        local dir base new_name
        dir=$(dirname "$f")
        base=$(basename "$f")
        new_name="${base//$search/$replace}"
        do_rename "$f" "$dir/$new_name"
        (( count++ ))
    done
    echo ""
    log_info "${count}件のファイルを処理しました"
    $dry_run && log_warning "--exec を付けると実際にリネームされます"
}

cmd_number() {
    local start="${ARGS[0]:-1}"
    collect_files

    local i=$start
    local total=${#file_list[@]}
    local pad=${#total}

    for f in "${file_list[@]}"; do
        local dir base ext stem new_name
        dir=$(dirname "$f")
        base=$(basename "$f")
        ext="${base##*.}"
        stem="${base%.*}"
        [[ "$ext" == "$base" ]] && ext=""

        local num
        num=$(printf "%0${pad}d" "$i")
        if [[ -n "$ext" ]]; then
            new_name="${num}_${stem}.${ext}"
        else
            new_name="${num}_${stem}"
        fi

        do_rename "$f" "$dir/$new_name"
        (( i++ ))
    done
    echo ""
    log_info "${total}件のファイルを処理しました"
    $dry_run && log_warning "--exec を付けると実際にリネームされます"
}

cmd_lower() {
    collect_files
    local count=0
    for f in "${file_list[@]}"; do
        local dir base new_name
        dir=$(dirname "$f")
        base=$(basename "$f")
        new_name=$(echo "$base" | tr '[:upper:]' '[:lower:]')
        do_rename "$f" "$dir/$new_name"
        (( count++ ))
    done
    echo ""
    log_info "${count}件のファイルを処理しました"
    $dry_run && log_warning "--exec を付けると実際にリネームされます"
}

cmd_upper() {
    collect_files
    local count=0
    for f in "${file_list[@]}"; do
        local dir base new_name
        dir=$(dirname "$f")
        base=$(basename "$f")
        new_name=$(echo "$base" | tr '[:lower:]' '[:upper:]')
        do_rename "$f" "$dir/$new_name"
        (( count++ ))
    done
    echo ""
    log_info "${count}件のファイルを処理しました"
    $dry_run && log_warning "--exec を付けると実際にリネームされます"
}

cmd_ext() {
    local new_ext="${ARGS[0]:-}"
    [[ -z "$new_ext" ]] && error_exit "新しい拡張子を指定してください"
    new_ext="${new_ext#.}"

    collect_files
    local count=0
    for f in "${file_list[@]}"; do
        local dir base stem
        dir=$(dirname "$f")
        base=$(basename "$f")
        stem="${base%.*}"
        do_rename "$f" "$dir/${stem}.${new_ext}"
        (( count++ ))
    done
    echo ""
    log_info "${count}件のファイルを処理しました"
    $dry_run && log_warning "--exec を付けると実際にリネームされます"
}

cmd_date() {
    collect_files
    local count=0
    for f in "${file_list[@]}"; do
        local dir base date_prefix new_name
        dir=$(dirname "$f")
        base=$(basename "$f")
        date_prefix=$(date -r "$f" +%Y%m%d 2>/dev/null || date +%Y%m%d)
        new_name="${date_prefix}_${base}"
        do_rename "$f" "$dir/$new_name"
        (( count++ ))
    done
    echo ""
    log_info "${count}件のファイルを処理しました"
    $dry_run && log_warning "--exec を付けると実際にリネームされます"
}

cmd_trim() {
    collect_files
    local count=0
    for f in "${file_list[@]}"; do
        local dir base new_name
        dir=$(dirname "$f")
        base=$(basename "$f")
        new_name=$(echo "$base" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr ' ' '_')
        do_rename "$f" "$dir/$new_name"
        (( count++ ))
    done
    echo ""
    log_info "${count}件のファイルを処理しました"
    $dry_run && log_warning "--exec を付けると実際にリネームされます"
}

cmd_preview() {
    collect_files
    echo ""
    if [[ ${#file_list[@]} -eq 0 ]]; then
        log_info "対象ファイルが見つかりません: $target_pattern in $target_dir"
        return
    fi
    printf "${C_BOLD}対象ファイル一覧 (%d件):${C_RESET}\n\n" "${#file_list[@]}"
    for f in "${file_list[@]}"; do
        printf "  %s\n" "$(basename "$f")"
    done
    echo ""
}

declare -a ARGS=()
declare opt_prefix=""
declare opt_suffix=""

parse_arguments() {
    [[ $# -eq 0 ]] && { show_usage; exit 0; }

    case "$1" in
        replace|number|lower|upper|trim|ext|date|preview)
            command_name="$1"; shift ;;
    esac

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -p|--pattern)
                [[ $# -lt 2 ]] && error_exit "--pattern には値が必要です"
                target_pattern="$2"; shift 2 ;;
            -r|--recursive) recursive=true; shift ;;
            --exec) dry_run=false; shift ;;
            --prefix)
                [[ $# -lt 2 ]] && error_exit "--prefix には値が必要です"
                opt_prefix="$2"; shift 2 ;;
            --suffix)
                [[ $# -lt 2 ]] && error_exit "--suffix には値が必要です"
                opt_suffix="$2"; shift 2 ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)
                if [[ -d "$1" ]]; then
                    target_dir="$1"
                else
                    ARGS+=("$1")
                fi
                shift ;;
        esac
    done
}

main() {
    parse_arguments "$@"

    if $dry_run; then
        log_warning "プレビューモード (実行するには --exec を付けてください)"
    fi
    echo ""

    case "$command_name" in
        replace) cmd_replace ;;
        number)  cmd_number ;;
        lower)   cmd_lower ;;
        upper)   cmd_upper ;;
        trim)    cmd_trim ;;
        ext)     cmd_ext ;;
        date)    cmd_date ;;
        preview) cmd_preview ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
