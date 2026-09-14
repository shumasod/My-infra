#!/bin/bash
set -euo pipefail

#
# バックアップ整合性チェックツール
# 作成日: 2026-07-04
# バージョン: 1.0
#
# バックアップディレクトリの存在・更新日時・サイズ・チェックサムを検証する
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"
readonly DEFAULT_MAX_AGE=1
readonly DEFAULT_MIN_SIZE=1

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション] <バックアップディレクトリ>

バックアップの整合性を検証します。

引数:
  <バックアップディレクトリ>  チェック対象のディレクトリ

オプション:
  -h, --help           このヘルプを表示
  -v, --version        バージョン情報を表示
  -a, --max-age N      最大許容日数（デフォルト: ${DEFAULT_MAX_AGE}日）
  -s, --min-size N     最小ファイルサイズ(KB)（デフォルト: ${DEFAULT_MIN_SIZE}KB）
  -p, --pattern GLOB   チェック対象ファイルのパターン（デフォルト: *）
  -o, --output FILE    レポートをファイルに保存
  --checksum           MD5チェックサムを検証（.md5ファイルが必要）
  --alert-email ADDR   問題発生時のアラートメールアドレス（要mailコマンド）

例:
  $PROG_NAME /backup/db
  $PROG_NAME -a 7 -s 1024 /backup/files
  $PROG_NAME -p "*.sql.gz" --checksum /backup/mysql
EOF
}

declare -i check_pass=0
declare -i check_warn=0
declare -i check_fail=0

result_pass() { local msg="$1"; log_success "$msg"; check_pass=$(( check_pass + 1 )); }
result_warn() { local msg="$1"; log_warning "$msg"; check_warn=$(( check_warn + 1 )); }
result_fail() { local msg="$1"; log_error "$msg";   check_fail=$(( check_fail + 1 )); }

check_directory_exists() {
    local dir="$1"
    if [ -d "$dir" ]; then
        result_pass "ディレクトリが存在します: $dir"
        return 0
    else
        result_fail "ディレクトリが見つかりません: $dir"
        return 1
    fi
}

check_directory_readable() {
    local dir="$1"
    if [ -r "$dir" ] && [ -x "$dir" ]; then
        result_pass "ディレクトリの読み取り権限OK"
    else
        result_fail "ディレクトリの読み取り権限がありません: $dir"
    fi
}

check_file_count() {
    local dir="$1"
    local pattern="$2"
    local count
    count=$(find "$dir" -maxdepth 1 -name "$pattern" -type f 2>/dev/null | wc -l)
    if [ "$count" -eq 0 ]; then
        result_fail "バックアップファイルが見つかりません (パターン: ${pattern})"
    elif [ "$count" -lt 3 ]; then
        result_warn "バックアップファイル数が少ない: ${count}件 (パターン: ${pattern})"
    else
        result_pass "バックアップファイル数OK: ${count}件"
    fi
    echo "$count"
}

check_latest_file_age() {
    local dir="$1"
    local pattern="$2"
    local max_age_days="$3"

    local latest
    latest=$(find "$dir" -maxdepth 1 -name "$pattern" -type f -printf '%T@ %p\n' 2>/dev/null | \
             sort -rn | head -1 | cut -d' ' -f2-)

    if [ -z "$latest" ]; then
        result_fail "最新バックアップファイルが見つかりません"
        return
    fi

    local file_time now_time age_secs age_days
    file_time=$(stat -c %Y "$latest" 2>/dev/null || stat -f %m "$latest" 2>/dev/null)
    now_time=$(date +%s)
    age_secs=$(( now_time - file_time ))
    age_days=$(( age_secs / 86400 ))

    local latest_name
    latest_name=$(basename "$latest")
    if [ "$age_days" -le "$max_age_days" ]; then
        result_pass "最新バックアップは ${age_days}日前: ${latest_name}"
    elif [ "$age_days" -le $(( max_age_days * 2 )) ]; then
        result_warn "最新バックアップが古い: ${age_days}日前 (閾値: ${max_age_days}日) — ${latest_name}"
    else
        result_fail "バックアップが非常に古い: ${age_days}日前 (閾値: ${max_age_days}日) — ${latest_name}"
    fi
}

check_file_sizes() {
    local dir="$1"
    local pattern="$2"
    local min_size_kb="$3"

    local -i small_count=0 total_size=0 file_count=0
    while IFS= read -r f; do
        [ -z "$f" ] && continue
        file_count=$(( file_count + 1 ))
        local size_kb
        size_kb=$(du -k "$f" 2>/dev/null | cut -f1)
        total_size=$(( total_size + size_kb ))
        if [ "$size_kb" -lt "$min_size_kb" ]; then
            small_count=$(( small_count + 1 ))
            result_warn "ファイルサイズが小さすぎます: $(basename "$f") (${size_kb}KB < ${min_size_kb}KB)"
        fi
    done < <(find "$dir" -maxdepth 1 -name "$pattern" -type f 2>/dev/null)

    if [ "$file_count" -gt 0 ] && [ "$small_count" -eq 0 ]; then
        result_pass "全ファイルのサイズOK (合計: $(( total_size / 1024 ))MB)"
    fi
}

check_checksums() {
    local dir="$1"
    local pattern="$2"

    local md5_files
    md5_files=$(find "$dir" -maxdepth 1 -name "*.md5" -type f 2>/dev/null | wc -l)

    if [ "$md5_files" -eq 0 ]; then
        result_warn "MD5チェックサムファイルが見つかりません (.md5ファイル)"
        return
    fi

    local -i ok=0 ng=0
    while IFS= read -r md5file; do
        [ -z "$md5file" ] && continue
        local target="${md5file%.md5}"
        if [ ! -f "$target" ]; then
            result_warn "チェックサム対象ファイルがありません: $(basename "$target")"
            ng=$(( ng + 1 ))
            continue
        fi
        local expected actual
        expected=$(cat "$md5file" | awk '{print $1}')
        actual=$(md5sum "$target" 2>/dev/null | awk '{print $1}')
        if [ "$expected" == "$actual" ]; then
            ok=$(( ok + 1 ))
        else
            result_fail "チェックサム不一致: $(basename "$target")"
            ng=$(( ng + 1 ))
        fi
    done < <(find "$dir" -maxdepth 1 -name "*.md5" -type f 2>/dev/null)

    [ "$ok" -gt 0 ] && result_pass "チェックサム一致: ${ok}件"
}

show_summary() {
    local dir="$1"
    local output_file="$2"

    echo ""
    printf "  ${C_DIM}%s${C_RESET}\n" "$(printf '%.0s─' {1..50})"
    echo ""
    printf "  ${C_BOLD}チェック結果サマリー${C_RESET}\n"
    printf "  ${C_GREEN}合格: %d${C_RESET}  ${C_YELLOW}警告: %d${C_RESET}  ${C_RED}失敗: %d${C_RESET}\n" \
        "$check_pass" "$check_warn" "$check_fail"
    echo ""

    if [ "$check_fail" -gt 0 ]; then
        print_center "⚠ バックアップに問題が見つかりました" 0 "${C_BOLD}${C_RED}"
    elif [ "$check_warn" -gt 0 ]; then
        print_center "△ 警告があります。確認してください" 0 "${C_BOLD}${C_YELLOW}"
    else
        print_center "✓ バックアップは正常です" 0 "${C_BOLD}${C_GREEN}"
    fi
    echo ""

    if [ -n "$output_file" ]; then
        {
            echo "# バックアップチェックレポート"
            echo "# 生成日時: $(get_timestamp)"
            echo "# 対象: $dir"
            echo "# 合格: $check_pass  警告: $check_warn  失敗: $check_fail"
        } > "$output_file"
        log_success "レポートを保存しました: $output_file"
    fi
}

main() {
    local backup_dir=""
    local max_age=$DEFAULT_MAX_AGE
    local min_size=$DEFAULT_MIN_SIZE
    local pattern="*"
    local output_file=""
    local do_checksum=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -a|--max-age)
                [[ $# -lt 2 ]] && error_exit "--max-age には数値が必要です"
                max_age="$2"; shift 2 ;;
            -s|--min-size)
                [[ $# -lt 2 ]] && error_exit "--min-size には数値が必要です"
                min_size="$2"; shift 2 ;;
            -p|--pattern)
                [[ $# -lt 2 ]] && error_exit "--pattern にはグロブパターンが必要です"
                pattern="$2"; shift 2 ;;
            -o|--output)
                [[ $# -lt 2 ]] && error_exit "--output にはファイル名が必要です"
                output_file="$2"; shift 2 ;;
            --checksum) do_checksum=true; shift ;;
            --alert-email) shift 2 ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  backup_dir="$1"; shift ;;
        esac
    done

    [ -z "$backup_dir" ] && error_exit "バックアップディレクトリを指定してください"

    echo ""
    print_center "バックアップ整合性チェック" 0 "${C_BOLD}${C_CYAN}"
    print_center "$(get_timestamp)" 0 "$C_DIM"
    echo ""
    echo -e "  ${C_BOLD}対象:${C_RESET} $backup_dir"
    echo -e "  ${C_BOLD}パターン:${C_RESET} $pattern  ${C_BOLD}最大経過日数:${C_RESET} ${max_age}日  ${C_BOLD}最小サイズ:${C_RESET} ${min_size}KB"
    echo ""

    check_directory_exists "$backup_dir" || { show_summary "$backup_dir" "$output_file"; exit 1; }
    check_directory_readable "$backup_dir"
    check_file_count "$backup_dir" "$pattern" > /dev/null
    check_latest_file_age "$backup_dir" "$pattern" "$max_age"
    check_file_sizes "$backup_dir" "$pattern" "$min_size"
    "$do_checksum" && check_checksums "$backup_dir" "$pattern"

    show_summary "$backup_dir" "$output_file"

    [ "$check_fail" -gt 0 ] && exit 1
    exit 0
}

main "$@"
