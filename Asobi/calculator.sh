#!/bin/bash
set -euo pipefail

#
# TUI電卓
# 作成日: 2026-07-31
# バージョン: 1.0
#
# ターミナル上で動作する関数電卓です
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare display=""
declare prev_num=""
declare operator=""
declare result=""
declare -a history=()
declare mode="basic"
declare mem=0

cleanup() {
    show_cursor
    printf '\033[?1049l'
    stty echo 2>/dev/null || true
    stty icanon 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# 電卓のボタン配置
declare -a basic_buttons=(
    "MC" "MR" "M+" "M-" "MS"
    "C"  "±"  "%"  "÷"  ""
    "7"  "8"  "9"  "×"  ""
    "4"  "5"  "6"  "-"  ""
    "1"  "2"  "3"  "+"  "="
    "0"  ""   "."  ""   ""
)

draw_display() {
    local col=2 row=3
    move_cursor $row $col
    printf "${C_BG_BLACK}${C_WHITE}"

    local disp_val="${display:-0}"
    [[ -n "$result" ]] && disp_val="$result"

    # 表示幅
    local disp_width=25
    printf " %-${disp_width}s " "$disp_val"
    printf "${C_RESET}"

    # 演算子表示
    move_cursor $(( row + 1 )) $col
    printf "${C_DIM} %-10s %14s ${C_RESET}" "${operator:-}" "${prev_num:+$prev_num ${operator}}"

    # メモリ表示
    [[ "$mem" != "0" ]] && {
        move_cursor $row $(( col + disp_width + 2 ))
        printf "${C_YELLOW}M${C_RESET}"
    }
}

draw_history() {
    local hist_col=32
    move_cursor 3 $hist_col
    printf "${C_BOLD}【履歴】${C_RESET}"

    local max_rows=15
    local start=$(( ${#history[@]} > max_rows ? ${#history[@]} - max_rows : 0 ))
    local row=4
    for (( i=start; i<${#history[@]}; i++ )); do
        move_cursor $row $hist_col
        printf "${C_DIM}%s${C_RESET}" "${history[$i]:0:20}"
        (( row++ ))
    done
}

draw_buttons() {
    local start_row=6
    local start_col=2
    local btn_w=5

    local -a buttons=(
        "7" "8" "9" "÷" "C"
        "4" "5" "6" "×" "±"
        "1" "2" "3" "-" "%"
        "0" "." "=" "+" "BS"
        "sin" "cos" "tan" "√" "x²"
        "log" "ln" "π" "e" "MC"
        "M+" "M-" "MR" "MS" "("
    )

    local colors=(
        "$C_WHITE" "$C_WHITE" "$C_WHITE" "$C_YELLOW" "$C_RED"
        "$C_WHITE" "$C_WHITE" "$C_WHITE" "$C_YELLOW" "$C_CYAN"
        "$C_WHITE" "$C_WHITE" "$C_WHITE" "$C_YELLOW" "$C_CYAN"
        "$C_WHITE" "$C_WHITE" "$C_GREEN" "$C_YELLOW" "$C_CYAN"
        "$C_MAGENTA" "$C_MAGENTA" "$C_MAGENTA" "$C_MAGENTA" "$C_MAGENTA"
        "$C_MAGENTA" "$C_MAGENTA" "$C_MAGENTA" "$C_MAGENTA" "$C_BLUE"
        "$C_BLUE" "$C_BLUE" "$C_BLUE" "$C_BLUE" "$C_CYAN"
    )

    local cols=5
    for (( i=0; i<${#buttons[@]}; i++ )); do
        local row=$(( start_row + i / cols ))
        local col=$(( start_col + (i % cols) * (btn_w + 1) ))
        local btn="${buttons[$i]}"
        local color="${colors[$i]:-$C_WHITE}"

        move_cursor $row $col
        printf "${color}[%-3s]${C_RESET}" "$btn"
    done
}

draw_ui() {
    clear_screen
    update_terminal_size

    # タイトル
    move_cursor 1 1
    printf "${C_BG_BLUE}${C_WHITE}${C_BOLD}"
    printf " %-28s" " TUI電卓 v${VERSION}"
    printf "${C_RESET}"

    draw_display
    draw_buttons
    draw_history

    # ヘルプ
    local help_row=$(( 6 + 7 + 1 ))
    move_cursor $help_row 2
    printf "${C_DIM}数字キーで入力 | Enter/=で計算 | q=終了 | h=履歴クリア${C_RESET}"
}

calculate() {
    local expr="$1"
    if command -v python3 &>/dev/null; then
        python3 -c "
import math
try:
    expr = '''$expr'''
    # 安全な関数のみ許可
    safe = {
        'sin': math.sin, 'cos': math.cos, 'tan': math.tan,
        'sqrt': math.sqrt, 'log': math.log10, 'ln': math.log,
        'pi': math.pi, 'e': math.e, 'abs': abs,
        'asin': math.asin, 'acos': math.acos, 'atan': math.atan,
    }
    result = eval(expr, {'__builtins__': {}}, safe)
    if isinstance(result, float) and result == int(result):
        print(int(result))
    else:
        print(round(float(result), 10))
except ZeroDivisionError:
    print('ERROR:ゼロ除算')
except Exception as e:
    print(f'ERROR:{e}')
" 2>/dev/null || echo "ERROR"
    elif command -v bc &>/dev/null; then
        echo "$expr" | bc -l 2>/dev/null || echo "ERROR"
    else
        echo "ERROR:計算エンジンが見つかりません"
    fi
}

process_key() {
    local key="$1"

    case "$key" in
        [0-9])
            if [[ -n "$result" ]]; then
                display="$key"
                result=""
            else
                [[ "$display" == "0" ]] && display="$key" || display="${display}${key}"
            fi
            ;;
        ".")
            [[ "$display" != *"."* ]] && display="${display:-0}."
            ;;
        "+"|"-"|"*"|"/"|"×"|"÷")
            local op="$key"
            [[ "$key" == "×" ]] && op="*"
            [[ "$key" == "÷" ]] && op="/"
            if [[ -n "$display" || -n "$result" ]]; then
                prev_num="${result:-$display}"
                operator="$op"
                display=""
                result=""
            fi
            ;;
        "="|$'\r'|$'\n')
            if [[ -n "$prev_num" && -n "$operator" ]]; then
                local cur="${display:-$result:-0}"
                local expr="${prev_num}${operator}${cur}"
                local calc_result
                calc_result=$(calculate "$expr")
                if [[ "$calc_result" == ERROR* ]]; then
                    result="${calc_result#ERROR:}"
                    history+=("${expr} → Error")
                else
                    history+=("${expr} = ${calc_result}")
                    result="$calc_result"
                fi
                display=""
                prev_num=""
                operator=""
            elif [[ -n "$display" ]]; then
                result="$display"
                display=""
            fi
            ;;
        "c"|"C")
            display=""
            result=""
            prev_num=""
            operator=""
            ;;
        "h"|"H")
            history=()
            ;;
        $'\x7f'|$'\b')
            if [[ -n "$display" ]]; then
                display="${display%?}"
            fi
            ;;
        "m"|"M")
            mem="${result:-${display:-0}}"
            ;;
        "r"|"R")
            display="$mem"
            result=""
            ;;
        "s"|"S")
            if [[ -n "${display:-$result}" ]]; then
                local val="${result:-$display}"
                local sq_result
                sq_result=$(calculate "sqrt($val)")
                history+=("√${val} = ${sq_result}")
                result="$sq_result"
                display=""
            fi
            ;;
        "p"|"P")
            display="3.14159265358979"
            result=""
            ;;
        "q"|"Q"|$'\x1b')
            return 1
            ;;
    esac
    return 0
}

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション]

TUI電卓を起動します。

オプション:
  -h, --help     このヘルプを表示
  -v, --version  バージョン情報を表示
  --mode <モード> モード (basic|scientific) [デフォルト: basic]

キー操作:
  0-9        数字入力
  + - * /    四則演算
  Enter/=    計算実行
  c          クリア
  BS         バックスペース
  m          メモリ保存
  r          メモリ呼出
  s          平方根
  p          π(パイ)
  h          履歴クリア
  q/ESC      終了
EOF
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            --mode)       [[ $# -lt 2 ]] && error_exit "--mode には値が必要です"; mode="$2"; shift 2 ;;
            -*) error_exit "不明なオプション: $1" ;;
            *) shift ;;
        esac
    done
}

main() {
    parse_arguments "$@"

    printf '\033[?1049h'
    hide_cursor
    stty -echo 2>/dev/null || true
    stty -icanon min 1 time 0 2>/dev/null || true

    draw_ui

    while true; do
        local key
        if ! key=$(dd bs=4 count=1 2>/dev/null | cat); then
            break
        fi

        if ! process_key "$key"; then
            break
        fi

        draw_ui
    done
}

main "$@"
