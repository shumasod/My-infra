#!/bin/bash
set -euo pipefail

#
# BMI・健康指標計算ツール
# 作成日: 2026-07-04
# バージョン: 1.0
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション] [身長(cm)] [体重(kg)]

BMI・適正体重・カロリー消費量を計算します。

引数:
  身長(cm)  身長をセンチメートルで指定
  体重(kg)  体重をキログラムで指定

オプション:
  -h, --help         このヘルプを表示
  -v, --version      バージョン情報を表示
  -a, --age N        年齢（基礎代謝計算用）
  -g, --gender M/F   性別 M=男性 F=女性
  --imperial         フィート/ポンドで入力
EOF
}

calc_bmi() {
    local height_m="$1"
    local weight_kg="$2"
    awk "BEGIN{printf \"%.1f\", $weight_kg / ($height_m * $height_m)}"
}

bmi_category() {
    local bmi="$1"
    if awk "BEGIN{exit !($bmi < 18.5)}"; then
        echo "低体重 (痩せ型)"
    elif awk "BEGIN{exit !($bmi < 25.0)}"; then
        echo "標準体重"
    elif awk "BEGIN{exit !($bmi < 30.0)}"; then
        echo "過体重"
    elif awk "BEGIN{exit !($bmi < 35.0)}"; then
        echo "肥満 (1度)"
    elif awk "BEGIN{exit !($bmi < 40.0)}"; then
        echo "肥満 (2度)"
    else
        echo "肥満 (3度)"
    fi
}

bmi_color() {
    local bmi="$1"
    if awk "BEGIN{exit !($bmi < 18.5)}"; then
        echo "$C_BLUE"
    elif awk "BEGIN{exit !($bmi < 25.0)}"; then
        echo "$C_GREEN"
    elif awk "BEGIN{exit !($bmi < 30.0)}"; then
        echo "$C_YELLOW"
    else
        echo "$C_RED"
    fi
}

calc_ideal_weight() {
    local height_m="$1"
    awk "BEGIN{printf \"%.1f\", 22.0 * $height_m * $height_m}"
}

calc_bmr() {
    local weight="$1"
    local height_cm="$2"
    local age="$3"
    local gender="$4"
    if [ "$gender" == "M" ]; then
        awk "BEGIN{printf \"%.0f\", 88.362 + (13.397 * $weight) + (4.799 * $height_cm) - (5.677 * $age)}"
    else
        awk "BEGIN{printf \"%.0f\", 447.593 + (9.247 * $weight) + (3.098 * $height_cm) - (4.330 * $age)}"
    fi
}

draw_bmi_gauge() {
    local bmi="$1"
    local width=40
    local min_bmi=15.0
    local max_bmi=40.0
    local pos
    pos=$(awk "BEGIN{
        pos = int(($bmi - $min_bmi) / ($max_bmi - $min_bmi) * $width)
        if (pos < 0) pos = 0
        if (pos > $width) pos = $width
        print pos
    }")

    local gauge=""
    local i
    for (( i = 0; i < width; i++ )); do
        local pct=$(( i * 100 / width ))
        local bmi_at
        bmi_at=$(awk "BEGIN{printf \"%.1f\", $min_bmi + ($max_bmi - $min_bmi) * $i / $width}")

        if awk "BEGIN{exit !($bmi_at < 18.5)}"; then
            gauge+="${C_BLUE}─${C_RESET}"
        elif awk "BEGIN{exit !($bmi_at < 25.0)}"; then
            gauge+="${C_GREEN}─${C_RESET}"
        elif awk "BEGIN{exit !($bmi_at < 30.0)}"; then
            gauge+="${C_YELLOW}─${C_RESET}"
        else
            gauge+="${C_RED}─${C_RESET}"
        fi
    done

    printf "  %b\n" "$gauge"
    printf "  %${pos}s▲\n" ""
    printf "  15    18.5      25        30        35       40\n"
}

interactive_mode() {
    clear_screen
    print_center "BMI・健康指標計算ツール" 0 "${C_BOLD}${C_CYAN}"
    echo ""

    printf "  身長を入力してください (cm): "
    local height_cm
    read -r height_cm
    if ! [[ "$height_cm" =~ ^[0-9]+(\.[0-9]+)?$ ]] || awk "BEGIN{exit !($height_cm < 50 || $height_cm > 250)}"; then
        error_exit "身長は50〜250cmの範囲で入力してください"
    fi

    printf "  体重を入力してください (kg): "
    local weight_kg
    read -r weight_kg
    if ! [[ "$weight_kg" =~ ^[0-9]+(\.[0-9]+)?$ ]] || awk "BEGIN{exit !($weight_kg < 10 || $weight_kg > 300)}"; then
        error_exit "体重は10〜300kgの範囲で入力してください"
    fi

    printf "  年齢を入力してください (Enterでスキップ): "
    local age=""
    read -r age

    local gender="M"
    printf "  性別を入力してください (M=男性/F=女性, Enterでスキップ): "
    local g_input
    read -r g_input
    [[ "$g_input" == "F" || "$g_input" == "f" ]] && gender="F"

    show_results "$height_cm" "$weight_kg" "$age" "$gender"
}

show_results() {
    local height_cm="$1"
    local weight_kg="$2"
    local age="$3"
    local gender="$4"

    local height_m
    height_m=$(awk "BEGIN{printf \"%.4f\", $height_cm / 100}")

    local bmi
    bmi=$(calc_bmi "$height_m" "$weight_kg")
    local category
    category=$(bmi_category "$bmi")
    local color
    color=$(bmi_color "$bmi")
    local ideal
    ideal=$(calc_ideal_weight "$height_m")
    local diff
    diff=$(awk "BEGIN{printf \"%.1f\", $weight_kg - $ideal}")

    clear_screen
    echo ""
    print_center "BMI 計算結果" 0 "${C_BOLD}${C_CYAN}"
    print_center "─────────────────────────────────" 0 "$C_DIM"
    echo ""

    printf "  ${C_BOLD}身長:${C_RESET}     %.1fcm\n" "$height_cm"
    printf "  ${C_BOLD}体重:${C_RESET}     %.1fkg\n" "$weight_kg"
    echo ""
    printf "  ${C_BOLD}BMI:${C_RESET}      ${color}${C_BOLD}%s${C_RESET}\n" "$bmi"
    printf "  ${C_BOLD}判定:${C_RESET}     ${color}%s${C_RESET}\n" "$category"
    echo ""

    draw_bmi_gauge "$bmi"
    echo ""

    printf "  ${C_BOLD}適正体重:${C_RESET} %.1fkg  (BMI 22.0)\n" "$ideal"
    if awk "BEGIN{exit !($diff > 0)}"; then
        printf "  ${C_YELLOW}現在の体重は適正より +%.1fkg です${C_RESET}\n" "$diff"
    elif awk "BEGIN{exit !($diff < 0)}"; then
        local abs_diff
        abs_diff=$(awk "BEGIN{printf \"%.1f\", -$diff}")
        printf "  ${C_BLUE}現在の体重は適正より -%.1fkg です${C_RESET}\n" "$abs_diff"
    else
        printf "  ${C_GREEN}適正体重です！${C_RESET}\n"
    fi

    if [ -n "$age" ] && [[ "$age" =~ ^[0-9]+$ ]]; then
        echo ""
        print_center "─────────────────────────────────" 0 "$C_DIM"
        local bmr
        bmr=$(calc_bmr "$weight_kg" "$height_cm" "$age" "$gender")
        printf "  ${C_BOLD}基礎代謝量 (BMR):${C_RESET} %skcal/日\n" "$bmr"
        printf "  ${C_DIM}軽い活動:${C_RESET}  %skcal/日\n" "$(awk "BEGIN{printf \"%d\", $bmr * 1.375}")"
        printf "  ${C_DIM}普通の活動:${C_RESET} %skcal/日\n" "$(awk "BEGIN{printf \"%d\", $bmr * 1.55}")"
        printf "  ${C_DIM}激しい運動:${C_RESET} %skcal/日\n" "$(awk "BEGIN{printf \"%d\", $bmr * 1.725}")"
    fi
    echo ""
}

main() {
    local height_cm=""
    local weight_kg=""
    local age=""
    local gender="M"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -a|--age)
                [[ $# -lt 2 ]] && error_exit "--age には数値が必要です"
                age="$2"; shift 2 ;;
            -g|--gender)
                [[ $# -lt 2 ]] && error_exit "--gender には M/F が必要です"
                gender="${2^^}"; shift 2 ;;
            -*)  error_exit "不明なオプション: $1" ;;
            *)
                if [ -z "$height_cm" ]; then
                    height_cm="$1"
                elif [ -z "$weight_kg" ]; then
                    weight_kg="$1"
                fi
                shift ;;
        esac
    done

    if [ -n "$height_cm" ] && [ -n "$weight_kg" ]; then
        show_results "$height_cm" "$weight_kg" "$age" "$gender"
    else
        interactive_mode
    fi
}

main "$@"
