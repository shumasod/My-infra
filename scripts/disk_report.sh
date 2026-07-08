#!/bin/bash
set -euo pipefail

#
# ディスク使用量レポートジェネレーター
# 作成日: 2026-07-04
# バージョン: 1.0
#
# ディスク使用状況をレポート形式で出力し、
# 警告閾値を超えたパーティションをアラート表示する
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"
readonly DEFAULT_WARN_THRESHOLD=80
readonly DEFAULT_CRIT_THRESHOLD=90

declare -i warn_threshold=$DEFAULT_WARN_THRESHOLD
declare -i crit_threshold=$DEFAULT_CRIT_THRESHOLD
declare output_file=""
declare show_top=false
declare -i top_n=10

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション] [ディレクトリ...]

ディスク使用量レポートを生成します。

引数:
  [ディレクトリ...]  解析対象ディレクトリ（省略時は全マウントポイント）

オプション:
  -h, --help           このヘルプを表示
  -v, --version        バージョン情報を表示
  -w, --warn N         警告閾値(%) デフォルト: ${DEFAULT_WARN_THRESHOLD}
  -c, --critical N     重大閾値(%) デフォルト: ${DEFAULT_CRIT_THRESHOLD}
  -o, --output FILE    レポートをファイルに保存
  -t, --top [N]        容量を消費しているディレクトリTOP N（デフォルト: 10）

例:
  $PROG_NAME
  $PROG_NAME -w 70 -c 85
  $PROG_NAME -o report.txt -t 20 /var /home
EOF
}

get_usage_color() {
    local pct="$1"
    if [ "$pct" -ge "$crit_threshold" ]; then
        echo "$C_RED"
    elif [ "$pct" -ge "$warn_threshold" ]; then
        echo "$C_YELLOW"
    else
        echo "$C_GREEN"
    fi
}

usage_bar() {
    local pct="$1"
    local width=20
    local filled=$(( pct * width / 100 ))
    local empty=$(( width - filled ))
    local color
    color=$(get_usage_color "$pct")
    local bar=""
    local i
    for (( i = 0; i < filled; i++ )); do bar+="█"; done
    for (( i = 0; i < empty; i++ )); do bar+="░"; done
    echo -e "${color}${bar}${C_RESET}"
}

show_disk_overview() {
    echo ""
    print_center "ディスク使用量レポート" 0 "${C_BOLD}${C_CYAN}"
    print_center "$(get_timestamp)" 0 "$C_DIM"
    echo ""

    printf "  ${C_BOLD}%-20s  %6s  %6s  %6s  %5s  %-22s  %s${C_RESET}\n" \
        "マウントポイント" "サイズ" "使用済" "空き" "使用率" "使用バー" "FS"
    printf "  ${C_DIM}%s${C_RESET}\n" "$(printf '%0.s─' {1..90})"

    local alert_count=0

    while IFS= read -r line; do
        local fs size used avail pct_raw mount
        read -r fs size used avail pct_raw mount <<< "$line"
        local pct="${pct_raw%%%}"

        local color
        color=$(get_usage_color "$pct")
        local bar
        bar=$(usage_bar "$pct")

        printf "  %-20s  %6s  %6s  %6s  ${color}%4s%%${C_RESET}  %s  ${C_DIM}%s${C_RESET}\n" \
            "${mount:0:20}" "$size" "$used" "$avail" "$pct" "$bar" "$fs"

        if [ "$pct" -ge "$crit_threshold" ]; then
            alert_count=$(( alert_count + 1 ))
        fi
    done < <(df -h --output=source,size,used,avail,pcent,target 2>/dev/null | tail -n +2 | grep -v "tmpfs\|devtmpfs\|udev" || \
              df -h 2>/dev/null | tail -n +2)

    echo ""
    if [ "$alert_count" -gt 0 ]; then
        log_error "${alert_count}個のパーティションが重大閾値(${crit_threshold}%)を超えています！"
    else
        log_success "全パーティションが正常範囲内です"
    fi
}

show_top_dirs() {
    local -a target_dirs=("$@")
    [ "${#target_dirs[@]}" -eq 0 ] && target_dirs=("/")

    echo ""
    print_center "容量使用ランキング TOP ${top_n}" 0 "${C_BOLD}${C_CYAN}"
    echo ""

    local dir
    for dir in "${target_dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            log_warning "ディレクトリが見つかりません: $dir"
            continue
        fi

        echo -e "  ${C_BOLD}${dir}${C_RESET} 以下のトップ ${top_n} ディレクトリ:"
        echo ""

        du -sh "$dir"/* 2>/dev/null | sort -rh | head -n "$top_n" | \
        while IFS= read -r line; do
            local dsize dpath
            read -r dsize dpath <<< "$line"
            printf "  ${C_YELLOW}%8s${C_RESET}  %s\n" "$dsize" "$dpath"
        done

        echo ""
    done
}

save_report() {
    local file="$1"
    {
        echo "# ディスク使用量レポート"
        echo "# 生成日時: $(get_timestamp)"
        echo "# 警告閾値: ${warn_threshold}%  重大閾値: ${crit_threshold}%"
        echo ""
        echo "## ディスク概要"
        df -h 2>/dev/null
        echo ""
        echo "## inode使用状況"
        df -i 2>/dev/null || true
    } > "$file"
    log_success "レポートを保存しました: $file"
}

main() {
    local -a target_dirs=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -w|--warn)
                [[ $# -lt 2 ]] && error_exit "--warn には数値が必要です"
                warn_threshold="$2"; shift 2 ;;
            -c|--critical)
                [[ $# -lt 2 ]] && error_exit "--critical には数値が必要です"
                crit_threshold="$2"; shift 2 ;;
            -o|--output)
                [[ $# -lt 2 ]] && error_exit "--output にはファイル名が必要です"
                output_file="$2"; shift 2 ;;
            -t|--top)
                show_top=true
                if [[ $# -ge 2 ]] && [[ "$2" =~ ^[0-9]+$ ]]; then
                    top_n="$2"; shift 2
                else
                    shift
                fi
                ;;
            -*)
                error_exit "不明なオプション: $1" ;;
            *)
                target_dirs+=("$1"); shift ;;
        esac
    done

    show_disk_overview

    if "$show_top"; then
        if [ "${#target_dirs[@]}" -gt 0 ]; then
            show_top_dirs "${target_dirs[@]}"
        else
            show_top_dirs "/"
        fi
    fi

    if [ -n "$output_file" ]; then
        save_report "$output_file"
    fi
}

main "$@"
