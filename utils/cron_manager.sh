#!/bin/bash
set -euo pipefail

#
# Cronジョブ管理ツール
# バージョン: 1.0
#
# crontabの表示・追加・削除・有効化/無効化を管理するツール
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare mode="list"
declare target_user=""
declare cron_entry=""
declare cron_id=""
declare output_file=""

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション] [コマンド]

Cronジョブ管理ツール

コマンド:
  list              現在のcronジョブ一覧表示 (デフォルト)
  add               cronジョブを追加
  remove ID         cronジョブを削除 (行番号指定)
  disable ID        cronジョブをコメントアウトして無効化
  enable ID         無効化されたcronジョブを有効化
  test EXPR         cron式を解析・次回実行時刻を表示
  backup            crontabをバックアップ
  restore FILE      バックアップから復元

オプション:
  -h, --help        このヘルプを表示
  -v, --version     バージョン情報を表示
  -u, --user USER   対象ユーザー (root権限必要)
  -e, --entry EXPR  追加するcron式+コマンド
  -o, --output FILE バックアップ出力ファイル

例:
  $PROG_NAME list
  $PROG_NAME add -e "0 2 * * * /usr/bin/backup.sh"
  $PROG_NAME remove 3
  $PROG_NAME disable 2
  $PROG_NAME test "*/15 * * * *"
  $PROG_NAME backup -o ~/crontab.bak

EOF
}

get_crontab() {
    if [[ -n "$target_user" ]]; then
        crontab -u "$target_user" -l 2>/dev/null || true
    else
        crontab -l 2>/dev/null || true
    fi
}

set_crontab() {
    local content="$1"
    if [[ -n "$target_user" ]]; then
        echo "$content" | crontab -u "$target_user" -
    else
        echo "$content" | crontab -
    fi
}

do_list() {
    local raw
    raw=$(get_crontab)

    if [[ -z "$raw" ]]; then
        log_warning "cronジョブが登録されていません"
        return 0
    fi

    local user_label="${target_user:-$(whoami)}"
    log_info "Cronジョブ一覧: $user_label"
    echo ""
    printf "  ${C_BOLD}%-4s %-15s %-15s %-15s %-10s %s${C_RESET}\n" \
        "ID" "分" "時" "日/月/曜" "状態" "コマンド"
    printf "  %s\n" "$(printf '%.0s-' {1..80})"

    local id=1
    while IFS= read -r line; do
        if [[ -z "$line" ]]; then
            (( id++ )) || true
            continue
        fi

        # コメント行(環境変数設定除く)
        if [[ "$line" =~ ^#[[:space:]]*(.*) ]]; then
            local inner="${BASH_REMATCH[1]}"
            if [[ "$inner" =~ ^[0-9*] ]]; then
                # 無効化されたcronエントリ
                local fields
                read -ra fields <<< "$inner"
                local min="${fields[0]:-?}" hour="${fields[1]:-?}" dom="${fields[2]:-?}"
                local mon="${fields[3]:-?}" dow="${fields[4]:-?}"
                local cmd_part="${fields[*]:5}"
                printf "  ${C_DIM}%-4d %-5s %-5s %-5s/%-5s/%-5s ${C_YELLOW}%-10s${C_RESET} ${C_DIM}%s${C_RESET}\n" \
                    "$id" "$min" "$hour" "$dom" "$mon" "$dow" "無効" "$cmd_part"
            else
                printf "  ${C_DIM}%-4d %s${C_RESET}\n" "$id" "$line"
            fi
        elif [[ "$line" =~ ^[A-Z_]+=  ]]; then
            printf "  %-4d ${C_CYAN}%s${C_RESET}\n" "$id" "$line"
        elif [[ "$line" =~ ^[@0-9*] ]]; then
            local fields
            read -ra fields <<< "$line"
            local min="${fields[0]:-?}" hour="${fields[1]:-?}" dom="${fields[2]:-?}"
            local mon="${fields[3]:-?}" dow="${fields[4]:-?}"
            local cmd_part="${fields[*]:5}"
            printf "  ${C_GREEN}%-4d${C_RESET} %-5s %-5s %-5s/%-5s/%-5s ${C_GREEN}%-10s${C_RESET} %s\n" \
                "$id" "$min" "$hour" "$dom" "$mon" "$dow" "有効" "$cmd_part"
        else
            printf "  %-4d %s\n" "$id" "$line"
        fi
        (( id++ )) || true
    done <<< "$raw"

    local total
    total=$(echo "$raw" | grep -c '^[^#]' || true)
    echo ""
    printf "  合計: ${C_BOLD}%d${C_RESET} ジョブ\n" "$total"
    echo ""
}

do_add() {
    [[ -z "$cron_entry" ]] && error_exit "cron式を -e で指定してください"

    # 簡易バリデーション
    local fields
    read -ra fields <<< "$cron_entry"
    if [[ ${#fields[@]} -lt 6 ]]; then
        error_exit "cron式が不正です。形式: 分 時 日 月 曜 コマンド"
    fi

    local current
    current=$(get_crontab)

    local new_cron
    if [[ -z "$current" ]]; then
        new_cron="$cron_entry"
    else
        new_cron="${current}
${cron_entry}"
    fi

    set_crontab "$new_cron"
    log_success "追加しました: $cron_entry"
}

do_remove() {
    [[ -z "$cron_id" ]] && error_exit "削除する行番号を指定してください"

    local raw
    raw=$(get_crontab)
    local total_lines
    total_lines=$(echo "$raw" | wc -l)

    if (( cron_id < 1 || cron_id > total_lines )); then
        error_exit "無効なID: $cron_id (範囲: 1-$total_lines)"
    fi

    local target_line
    target_line=$(echo "$raw" | sed -n "${cron_id}p")
    echo "削除対象: $target_line"
    confirm "削除しますか?" "n" || { log_info "キャンセルしました"; return 0; }

    local new_cron
    new_cron=$(echo "$raw" | sed "${cron_id}d")
    set_crontab "$new_cron"
    log_success "行 $cron_id を削除しました"
}

do_disable() {
    [[ -z "$cron_id" ]] && error_exit "無効化する行番号を指定してください"

    local raw
    raw=$(get_crontab)
    local total_lines
    total_lines=$(echo "$raw" | wc -l)

    if (( cron_id < 1 || cron_id > total_lines )); then
        error_exit "無効なID: $cron_id (範囲: 1-$total_lines)"
    fi

    local target_line
    target_line=$(echo "$raw" | sed -n "${cron_id}p")

    if [[ "$target_line" =~ ^# ]]; then
        log_warning "行 $cron_id はすでにコメントアウトされています"
        return 0
    fi

    local new_cron
    new_cron=$(echo "$raw" | sed "${cron_id}s/^/# /")
    set_crontab "$new_cron"
    log_success "行 $cron_id を無効化しました"
}

do_enable() {
    [[ -z "$cron_id" ]] && error_exit "有効化する行番号を指定してください"

    local raw
    raw=$(get_crontab)
    local total_lines
    total_lines=$(echo "$raw" | wc -l)

    if (( cron_id < 1 || cron_id > total_lines )); then
        error_exit "無効なID: $cron_id (範囲: 1-$total_lines)"
    fi

    local target_line
    target_line=$(echo "$raw" | sed -n "${cron_id}p")

    if [[ ! "$target_line" =~ ^# ]]; then
        log_warning "行 $cron_id はすでに有効です"
        return 0
    fi

    local new_cron
    new_cron=$(echo "$raw" | sed "${cron_id}s/^# *//")
    set_crontab "$new_cron"
    log_success "行 $cron_id を有効化しました"
}

parse_cron_field() {
    local field="$1"
    local min="$2"
    local max="$3"
    local name="$4"

    if [[ "$field" == "*" ]]; then
        echo "毎${name}"
    elif [[ "$field" =~ ^\*/([0-9]+)$ ]]; then
        echo "${BASH_REMATCH[1]}${name}ごと"
    elif [[ "$field" =~ ^([0-9]+)-([0-9]+)$ ]]; then
        echo "${BASH_REMATCH[1]}〜${BASH_REMATCH[2]}${name}"
    elif [[ "$field" =~ ^[0-9]+$ ]]; then
        echo "${field}${name}"
    else
        echo "$field"
    fi
}

do_test() {
    [[ -z "$cron_entry" ]] && error_exit "テストするcron式を指定してください"

    local fields
    read -ra fields <<< "$cron_entry"
    if [[ ${#fields[@]} -lt 5 ]]; then
        error_exit "cron式が不正です。形式: 分 時 日 月 曜"
    fi

    local min_f="${fields[0]}" hour_f="${fields[1]}" dom_f="${fields[2]}"
    local mon_f="${fields[3]}" dow_f="${fields[4]}"

    local dow_names=("日" "月" "火" "水" "木" "金" "土")
    local mon_names=("" "1" "2" "3" "4" "5" "6" "7" "8" "9" "10" "11" "12")

    log_info "Cron式解析: $cron_entry"
    echo ""
    printf "  %-10s %s\n" "分:" "$(parse_cron_field "$min_f" 0 59 '分')"
    printf "  %-10s %s\n" "時:" "$(parse_cron_field "$hour_f" 0 23 '時')"
    printf "  %-10s %s\n" "日:" "$(parse_cron_field "$dom_f" 1 31 '日')"
    printf "  %-10s %s\n" "月:" "$(parse_cron_field "$mon_f" 1 12 '月')"

    local dow_str
    if [[ "$dow_f" =~ ^[0-9]+$ ]] && (( dow_f >= 0 && dow_f <= 6 )); then
        dow_str="${dow_names[$dow_f]}曜日"
    else
        dow_str="$(parse_cron_field "$dow_f" 0 7 '曜')"
    fi
    printf "  %-10s %s\n" "曜日:" "$dow_str"
    echo ""

    # 意味の説明
    log_info "意味:"
    local meaning=""
    if [[ "$min_f" == "0" && "$hour_f" =~ ^[0-9]+$ ]]; then
        meaning="${hour_f}時0分に"
    elif [[ "$min_f" =~ ^\*/([0-9]+)$ ]]; then
        meaning="${BASH_REMATCH[1]}分ごとに"
    elif [[ "$hour_f" == "*" && "$min_f" == "*" ]]; then
        meaning="毎分"
    fi

    if [[ -n "$meaning" ]]; then
        echo "  ${meaning}実行"
    fi
    echo ""
}

do_backup() {
    local raw
    raw=$(get_crontab)

    if [[ -z "$raw" ]]; then
        log_warning "バックアップするcronジョブがありません"
        return 0
    fi

    local dest="${output_file:-crontab_$(date +%Y%m%d_%H%M%S).bak}"
    echo "$raw" > "$dest"
    log_success "バックアップ完了: $dest"
    echo "  行数: $(echo "$raw" | wc -l)"
}

do_restore() {
    local restore_file="$cron_entry"
    [[ -z "$restore_file" ]] && error_exit "復元するファイルを指定してください"
    [[ ! -f "$restore_file" ]] && error_exit "ファイルが見つかりません: $restore_file"

    confirm "現在のcrontabを上書きしますか?" "n" || { log_info "キャンセルしました"; return 0; }

    crontab "$restore_file"
    log_success "復元完了: $restore_file"
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -u|--user)    [[ $# -lt 2 ]] && error_exit "--user には値が必要です"; target_user="$2"; shift 2 ;;
            -e|--entry)   [[ $# -lt 2 ]] && error_exit "--entry には値が必要です"; cron_entry="$2"; shift 2 ;;
            -o|--output)  [[ $# -lt 2 ]] && error_exit "--output には値が必要です"; output_file="$2"; shift 2 ;;
            list|add|backup) mode="$1"; shift ;;
            remove|disable|enable)
                mode="$1"
                [[ $# -ge 2 ]] && { cron_id="$2"; shift; }
                shift
                ;;
            test)
                mode="test"
                [[ $# -ge 2 ]] && { cron_entry="$2"; shift; }
                shift
                ;;
            restore)
                mode="restore"
                [[ $# -ge 2 ]] && { cron_entry="$2"; shift; }
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
        list)    do_list ;;
        add)     do_add ;;
        remove)  do_remove ;;
        disable) do_disable ;;
        enable)  do_enable ;;
        test)    do_test ;;
        backup)  do_backup ;;
        restore) do_restore ;;
        *)       error_exit "不明なコマンド: $mode" ;;
    esac
}

main "$@"
