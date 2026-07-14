#!/bin/bash
set -euo pipefail

#
# cron式ジェネレーター & 解析ツール
# 作成日: 2026-07-14
# バージョン: 1.0
#
# cron式を対話的に生成・解析・説明するツール
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション] [cron式]

cron式を生成・解析・説明します。

引数:
  [cron式]         解析するcron式（例: "0 9 * * 1-5"）

オプション:
  -h, --help       このヘルプを表示
  -v, --version    バージョン情報を表示
  -g, --generate   対話的にcron式を生成
  -p, --presets    プリセット一覧を表示
  -x, --explain    cron式の詳細説明

例:
  $PROG_NAME "0 9 * * 1-5"
  $PROG_NAME --generate
  $PROG_NAME --presets
EOF
}

explain_field() {
    local field="$1"
    local name="$2"
    local min="$3"
    local max="$4"

    if [[ "$field" == "*" ]]; then
        echo "全て（${min}-${max}）"
    elif [[ "$field" =~ ^\*\/([0-9]+)$ ]]; then
        echo "毎${BASH_REMATCH[1]}${name}"
    elif [[ "$field" =~ ^([0-9]+)-([0-9]+)$ ]]; then
        echo "${BASH_REMATCH[1]}${name}から${BASH_REMATCH[2]}${name}まで"
    elif [[ "$field" =~ ^([0-9]+)-([0-9]+)\/([0-9]+)$ ]]; then
        echo "${BASH_REMATCH[1]}-${BASH_REMATCH[2]}の範囲で毎${BASH_REMATCH[3]}${name}"
    elif [[ "$field" =~ ^[0-9]+(,[0-9]+)+$ ]]; then
        echo "${field}（複数指定）"
    elif [[ "$field" =~ ^[0-9]+$ ]]; then
        echo "${field}${name}"
    else
        echo "$field"
    fi
}

explain_weekday() {
    local field="$1"
    local days=("日" "月" "火" "水" "木" "金" "土")

    if [[ "$field" == "*" ]]; then
        echo "毎日"
        return
    fi

    local result="$field"
    for i in {0..6}; do
        result="${result//$i/${days[$i]}曜}"
    done
    echo "$result"
}

explain_month() {
    local field="$1"
    local months=("" "1月" "2月" "3月" "4月" "5月" "6月" "7月" "8月" "9月" "10月" "11月" "12月")

    if [[ "$field" == "*" ]]; then
        echo "毎月"
        return
    fi

    local result="$field"
    for i in {12..1}; do
        result="${result//$i/${months[$i]}}"
    done
    echo "$result"
}

parse_explain() {
    local cron_expr="$1"
    local fields
    read -ra fields <<< "$cron_expr"

    if [[ ${#fields[@]} -lt 5 ]]; then
        error_exit "cron式は5フィールド必要です: 分 時 日 月 曜日"
    fi

    local min_field="${fields[0]}"
    local hour_field="${fields[1]}"
    local day_field="${fields[2]}"
    local month_field="${fields[3]}"
    local wday_field="${fields[4]}"

    echo ""
    print_center "cron式の解析結果" 0 "${C_BOLD}${C_CYAN}"
    echo ""
    echo -e "  ${C_BOLD}式:${C_RESET} ${C_YELLOW}$cron_expr${C_RESET}"
    echo ""
    echo -e "  ${C_BOLD}フィールド解析:${C_RESET}"
    printf "  ${C_GREEN}%-8s${C_RESET} %-10s → %s\n" "分:" "$min_field" "$(explain_field "$min_field" "分" 0 59)"
    printf "  ${C_GREEN}%-8s${C_RESET} %-10s → %s\n" "時:" "$hour_field" "$(explain_field "$hour_field" "時" 0 23)"
    printf "  ${C_GREEN}%-8s${C_RESET} %-10s → %s\n" "日:" "$day_field" "$(explain_field "$day_field" "日" 1 31)"
    printf "  ${C_GREEN}%-8s${C_RESET} %-10s → %s\n" "月:" "$month_field" "$(explain_month "$month_field")"
    printf "  ${C_GREEN}%-8s${C_RESET} %-10s → %s\n" "曜日:" "$wday_field" "$(explain_weekday "$wday_field")"
    echo ""
}

show_presets() {
    echo ""
    print_center "cronプリセット一覧" 0 "${C_BOLD}${C_CYAN}"
    echo ""

    declare -A presets=(
        ["毎分"]="* * * * *"
        ["毎時0分"]="0 * * * *"
        ["毎日0時0分"]="0 0 * * *"
        ["毎日9時（平日）"]="0 9 * * 1-5"
        ["毎週月曜9時"]="0 9 * * 1"
        ["毎月1日0時"]="0 0 1 * *"
        ["毎月末日23時"]="0 23 28-31 * *"
        ["30分おき"]="*/30 * * * *"
        ["6時間おき"]="0 */6 * * *"
        ["平日朝9時〜18時毎時"]="0 9-18 * * 1-5"
        ["毎週土曜3時（バックアップ）"]="0 3 * * 6"
        ["四半期ごと（1,4,7,10月）"]="0 0 1 1,4,7,10 *"
        ["毎日深夜2時（メンテ）"]="0 2 * * *"
        ["毎5分"]="*/5 * * * *"
        ["毎15分"]="*/15 * * * *"
    )

    local i=0
    for desc in "${!presets[@]}"; do
        expr="${presets[$desc]}"
        printf "  ${C_GREEN}%-30s${C_RESET} ${C_YELLOW}%-20s${C_RESET}\n" "$desc" "$expr"
        (( i++ ))
    done
    echo ""
}

generate_interactive() {
    print_center "cron式ジェネレーター" 0 "${C_BOLD}${C_CYAN}"
    echo ""

    declare -i min_val=0 hour_val=0 day_val=1 month_val=1 wday_val=0
    local min_str="*" hour_str="*" day_str="*" month_str="*" wday_str="*"

    echo -e "  ${C_BOLD}実行頻度を選択してください:${C_RESET}"
    echo -e "  ${C_DIM}[1] 毎分  [2] 毎時  [3] 毎日  [4] 毎週  [5] 毎月  [6] カスタム${C_RESET}"
    echo -n "  選択: "
    read -r freq_choice

    case "$freq_choice" in
        1)
            echo -e "\n  ${C_GREEN}生成式:${C_RESET} ${C_YELLOW}* * * * *${C_RESET}"
            echo -e "  ${C_DIM}（毎分実行）${C_RESET}"
            ;;
        2)
            echo -n "  実行する分 [0-59]: "
            read -r min_val
            min_str="$min_val"
            echo -e "\n  ${C_GREEN}生成式:${C_RESET} ${C_YELLOW}${min_str} * * * *${C_RESET}"
            echo -e "  ${C_DIM}（毎時${min_val}分実行）${C_RESET}"
            ;;
        3)
            echo -n "  実行する時刻 [0-23]: "
            read -r hour_val
            echo -n "  実行する分 [0-59]: "
            read -r min_val
            echo -e "\n  ${C_GREEN}生成式:${C_RESET} ${C_YELLOW}${min_val} ${hour_val} * * *${C_RESET}"
            echo -e "  ${C_DIM}（毎日 ${hour_val}:$(printf '%02d' "$min_val") 実行）${C_RESET}"
            ;;
        4)
            echo -e "  曜日を選択 [0=日 1=月 2=火 3=水 4=木 5=金 6=土]"
            echo -n "  曜日: "
            read -r wday_val
            echo -n "  実行する時刻 [0-23]: "
            read -r hour_val
            echo -n "  実行する分 [0-59]: "
            read -r min_val
            local days=("日" "月" "火" "水" "木" "金" "土")
            echo -e "\n  ${C_GREEN}生成式:${C_RESET} ${C_YELLOW}${min_val} ${hour_val} * * ${wday_val}${C_RESET}"
            echo -e "  ${C_DIM}（毎週${days[$wday_val]}曜 ${hour_val}:$(printf '%02d' "$min_val") 実行）${C_RESET}"
            ;;
        5)
            echo -n "  実行する日 [1-31]: "
            read -r day_val
            echo -n "  実行する時刻 [0-23]: "
            read -r hour_val
            echo -n "  実行する分 [0-59]: "
            read -r min_val
            echo -e "\n  ${C_GREEN}生成式:${C_RESET} ${C_YELLOW}${min_val} ${hour_val} ${day_val} * *${C_RESET}"
            echo -e "  ${C_DIM}（毎月${day_val}日 ${hour_val}:$(printf '%02d' "$min_val") 実行）${C_RESET}"
            ;;
        6)
            echo -n "  分 [0-59 or * or */N]: "
            read -r min_str
            echo -n "  時 [0-23 or * or */N]: "
            read -r hour_str
            echo -n "  日 [1-31 or *]: "
            read -r day_str
            echo -n "  月 [1-12 or *]: "
            read -r month_str
            echo -n "  曜日 [0-6 or *]: "
            read -r wday_str
            echo -e "\n  ${C_GREEN}生成式:${C_RESET} ${C_YELLOW}${min_str} ${hour_str} ${day_str} ${month_str} ${wday_str}${C_RESET}"
            ;;
        *)
            log_warning "無効な選択です"
            ;;
    esac
    echo ""
}

main() {
    local generate_mode=false
    local preset_mode=false
    local explain_mode=false
    local cron_expr=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)     show_usage; exit 0 ;;
            -v|--version)  echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -g|--generate) generate_mode=true; shift ;;
            -p|--presets)  preset_mode=true; shift ;;
            -x|--explain)  explain_mode=true; shift ;;
            -*)            error_exit "不明なオプション: $1" ;;
            *)             cron_expr="$1"; shift ;;
        esac
    done

    if "$preset_mode"; then
        show_presets
        exit 0
    fi

    if "$generate_mode"; then
        generate_interactive
        exit 0
    fi

    if [[ -n "$cron_expr" ]]; then
        parse_explain "$cron_expr"
        exit 0
    fi

    generate_interactive
}

main "$@"
