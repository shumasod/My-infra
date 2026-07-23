#!/bin/bash
set -euo pipefail

#
# ASCIIカレンダー
# バージョン: 1.0
#
# ターミナルに美しいカレンダーを表示するツール
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare -i target_year=0
declare -i target_month=0
declare show_year=false
declare -a JP_MONTHS=("" "1月" "2月" "3月" "4月" "5月" "6月"
                       "7月" "8月" "9月" "10月" "11月" "12月")
declare -a JP_HOLIDAYS_KEY=()
declare -a JP_HOLIDAYS_VAL=()

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション] [年 月]

カレンダー表示ツール

引数:
  年 月                表示する年と月 (省略時: 今月)

オプション:
  -h, --help            このヘルプを表示
  -v, --version         バージョン情報を表示
  -y, --year            年間カレンダーを表示

例:
  $PROG_NAME
  $PROG_NAME 2025 3
  $PROG_NAME -y
  $PROG_NAME -y 2026

EOF
}

init_holidays() {
    local year="$1"
    JP_HOLIDAYS_KEY=()
    JP_HOLIDAYS_VAL=()

    local fixed_holidays=(
        "${year}0101:元日"
        "${year}0211:建国記念の日"
        "${year}0223:天皇誕生日"
        "${year}0320:春分の日"
        "${year}0429:昭和の日"
        "${year}0503:憲法記念日"
        "${year}0504:みどりの日"
        "${year}0505:こどもの日"
        "${year}0811:山の日"
        "${year}0923:秋分の日"
        "${year}1103:文化の日"
        "${year}1123:勤労感謝の日"
    )

    for entry in "${fixed_holidays[@]}"; do
        JP_HOLIDAYS_KEY+=("${entry%%:*}")
        JP_HOLIDAYS_VAL+=("${entry#*:}")
    done
}

is_holiday() {
    local date_str="$1"
    for key in "${JP_HOLIDAYS_KEY[@]}"; do
        [[ "$key" == "$date_str" ]] && return 0
    done
    return 1
}

days_in_month() {
    local year="$1"
    local month="$2"
    local days
    case "$month" in
        1|3|5|7|8|10|12) days=31 ;;
        4|6|9|11)         days=30 ;;
        2)
            if (( year % 400 == 0 || (year % 4 == 0 && year % 100 != 0) )); then
                days=29
            else
                days=28
            fi
            ;;
    esac
    echo "$days"
}

day_of_week() {
    local year="$1"
    local month="$2"
    local day="$3"
    date -d "${year}-$(printf '%02d' "$month")-$(printf '%02d' "$day")" "+%w" 2>/dev/null || \
    python3 -c "import datetime; print(datetime.date($year,$month,$day).weekday()%7)" 2>/dev/null || \
    echo "0"
}

print_month() {
    local year="$1"
    local month="$2"
    local today_year today_month today_day
    today_year=$(date +%Y)
    today_month=$(date +%-m)
    today_day=$(date +%-d)

    init_holidays "$year"

    local month_label
    month_label=$(printf "%d年 %s" "$year" "${JP_MONTHS[$month]}")
    local label_len=${#month_label}
    local padding=$(( (20 - label_len) / 2 ))
    printf "%${padding}s${C_BOLD}%s${C_RESET}\n" "" "$month_label"
    echo -e "${C_DIM}日  月  火  水  木  金  土${C_RESET}"

    local first_dow
    first_dow=$(day_of_week "$year" "$month" 1)
    local total_days
    total_days=$(days_in_month "$year" "$month")

    printf "%s" "$(printf '    %.0s' $(seq 1 "$first_dow"))"

    local current_dow="$first_dow"
    for (( day=1; day<=total_days; day++ )); do
        local date_str
        date_str=$(printf "%d%02d%02d" "$year" "$month" "$day")

        local day_color="$C_RESET"
        if [[ $current_dow -eq 0 ]]; then
            day_color="$C_RED"
        elif [[ $current_dow -eq 6 ]]; then
            day_color="$C_CYAN"
        fi
        if is_holiday "$date_str"; then
            day_color="$C_RED"
        fi

        local is_today=false
        if (( year == today_year && month == today_month && day == today_day )); then
            is_today=true
        fi

        if [[ "$is_today" == true ]]; then
            printf "${C_BG_BLUE}${C_BOLD}%b%2d${C_RESET}${C_BG_BLUE} ${C_RESET} " "$day_color" "$day"
        else
            printf "%b%2d${C_RESET}  " "$day_color" "$day"
        fi

        (( current_dow++ )) || true
        if (( current_dow == 7 )); then
            current_dow=0
            echo ""
        fi
    done
    [[ $current_dow -ne 0 ]] && echo ""
}

print_year_calendar() {
    local year="$1"
    log_info "${year}年 年間カレンダー"
    echo ""

    for (( month=1; month<=12; month++ )); do
        echo -e "  ${C_YELLOW}$(printf '─%.0s' {1..24})${C_RESET}"
        print_month "$year" "$month" | sed 's/^/  /'
        echo ""
    done
}

parse_arguments() {
    local -a pos_args=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -y|--year)    show_year=true; shift ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  pos_args+=("$1"); shift ;;
        esac
    done

    if [[ ${#pos_args[@]} -ge 2 ]]; then
        target_year="${pos_args[0]}"
        target_month="${pos_args[1]}"
    elif [[ ${#pos_args[@]} -eq 1 ]]; then
        target_year="${pos_args[0]}"
    fi
}

main() {
    parse_arguments "$@"

    local now_year now_month
    now_year=$(date +%Y)
    now_month=$(date +%-m)

    if (( target_year == 0 )); then
        target_year=$now_year
    fi
    if (( target_month == 0 )); then
        target_month=$now_month
    fi

    if [[ "$show_year" == true ]]; then
        print_year_calendar "$target_year"
    else
        echo ""
        print_month "$target_year" "$target_month"
        echo ""
    fi
}

main "$@"
