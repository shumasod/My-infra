#!/bin/bash
set -euo pipefail

#
# モールス信号変換ツール
# 作成日: 2026-07-14
# バージョン: 1.0
#
# テキストをモールス信号に変換、またはモールス信号をテキストに変換する
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare -A MORSE_ENC
declare -A MORSE_DEC

init_morse_table() {
    MORSE_ENC[A]=".-";   MORSE_ENC[B]="-..."; MORSE_ENC[C]="-.-."; MORSE_ENC[D]="-.."
    MORSE_ENC[E]=".";    MORSE_ENC[F]="..-."; MORSE_ENC[G]="--.";  MORSE_ENC[H]="...."
    MORSE_ENC[I]="..";   MORSE_ENC[J]=".---"; MORSE_ENC[K]="-.-";  MORSE_ENC[L]=".-.."
    MORSE_ENC[M]="--";   MORSE_ENC[N]="-.";   MORSE_ENC[O]="---";  MORSE_ENC[P]=".--."
    MORSE_ENC[Q]="--.-"; MORSE_ENC[R]=".-.";  MORSE_ENC[S]="...";  MORSE_ENC[T]="-"
    MORSE_ENC[U]="..-";  MORSE_ENC[V]="...-"; MORSE_ENC[W]=".--";  MORSE_ENC[X]="-..-"
    MORSE_ENC[Y]="-.--"; MORSE_ENC[Z]="--.."
    MORSE_ENC[0]="-----"; MORSE_ENC[1]=".----"; MORSE_ENC[2]="..---"; MORSE_ENC[3]="...--"
    MORSE_ENC[4]="....-"; MORSE_ENC[5]="....."; MORSE_ENC[6]="-...."; MORSE_ENC[7]="--..."
    MORSE_ENC[8]="---."; MORSE_ENC[9]="----."
    MORSE_ENC[DOT]=".-.-.-"; MORSE_ENC[COMMA]="--..--"; MORSE_ENC[QUES]="..--.."
    MORSE_ENC[SLASH]="-..-."

    for key in "${!MORSE_ENC[@]}"; do
        MORSE_DEC["${MORSE_ENC[$key]}"]="$key"
    done
}

encode_text() {
    local text="${1^^}"
    local result=""
    local i char code

    for (( i=0; i<${#text}; i++ )); do
        char="${text:$i:1}"
        if [[ "$char" == " " ]]; then
            result+="/ "
        elif [[ -n "${MORSE_ENC[$char]+x}" ]]; then
            result+="${MORSE_ENC[$char]} "
        elif [[ "$char" == "." ]]; then
            result+="${MORSE_ENC[DOT]} "
        elif [[ "$char" == "," ]]; then
            result+="${MORSE_ENC[COMMA]} "
        elif [[ "$char" == "?" ]]; then
            result+="${MORSE_ENC[QUES]} "
        else
            result+="? "
        fi
    done
    echo "${result% }"
}

decode_morse() {
    local morse="$1"
    local result=""
    local word char

    for word in $morse; do
        if [[ "$word" == "/" ]]; then
            result+=" "
        elif [[ -n "${MORSE_DEC[$word]+x}" ]]; then
            char="${MORSE_DEC[$word]}"
            case "$char" in
                DOT)   result+="." ;;
                COMMA) result+="," ;;
                QUES)  result+="?" ;;
                SLASH) result+="/" ;;
                *)     result+="$char" ;;
            esac
        else
            result+="?"
        fi
    done
    echo "$result"
}

play_morse_visual() {
    local morse="$1"
    local i ch

    echo -ne "${C_CYAN}"
    for (( i=0; i<${#morse}; i++ )); do
        ch="${morse:$i:1}"
        if   [[ "$ch" == "." ]]; then echo -n "•"
        elif [[ "$ch" == "-" ]]; then echo -n "━"
        elif [[ "$ch" == " " ]]; then echo -n " "
        elif [[ "$ch" == "/" ]]; then echo -n " | "
        fi
    done
    echo -e "${C_RESET}"
}

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション] [テキスト]

テキストをモールス信号に変換します。

引数:
  [テキスト]      変換するテキスト（省略時はインタラクティブモード）

オプション:
  -h, --help      このヘルプを表示
  -v, --version   バージョン情報を表示
  -d, --decode    モールス信号をテキストにデコード
  -t, --table     モールス信号表を表示
  -i, --inter     インタラクティブモード

例:
  $PROG_NAME "Hello World"
  $PROG_NAME -d ".... . .-.. .-.. --- / .-- --- .-. .-.. -.."
  $PROG_NAME --table
EOF
}

show_table() {
    echo ""
    print_center "モールス信号表" 0 "${C_BOLD}${C_CYAN}"
    echo ""

    local letters=({A..Z})
    local i=0

    echo -e "  ${C_BOLD}アルファベット${C_RESET}"
    for letter in "${letters[@]}"; do
        code="${MORSE_ENC[$letter]}"
        printf "  ${C_GREEN}%-2s${C_RESET} ${C_YELLOW}%-8s${C_RESET}" "$letter" "$code"
        (( i++ ))
        if (( i % 4 == 0 )); then echo; fi
    done
    echo ""
    echo ""
    echo -e "  ${C_BOLD}数字${C_RESET}"
    for num in {0..9}; do
        code="${MORSE_ENC[$num]}"
        printf "  ${C_GREEN}%-2s${C_RESET} ${C_YELLOW}%-8s${C_RESET}" "$num" "$code"
    done
    echo ""
}

interactive_mode() {
    print_center "モールス信号変換ツール" 0 "${C_BOLD}${C_CYAN}"
    echo ""

    while true; do
        echo -e "  ${C_DIM}[1] テキスト→モールス  [2] モールス→テキスト  [q] 終了${C_RESET}"
        echo -n "  選択: "
        read -r choice

        case "$choice" in
            1)
                echo -n "  テキストを入力: "
                read -r input
                result=$(encode_text "$input")
                echo -e "  ${C_GREEN}結果:${C_RESET} $result"
                echo -n "  ビジュアル: "
                play_morse_visual "$result"
                ;;
            2)
                echo -n "  モールス信号を入力: "
                read -r input
                result=$(decode_morse "$input")
                echo -e "  ${C_GREEN}結果:${C_RESET} $result"
                ;;
            q|Q)
                break
                ;;
            *)
                log_warning "1, 2, または q を入力してください"
                ;;
        esac
        echo ""
    done
}

main() {
    local decode_mode=false
    local show_table_mode=false
    local inter_mode=false
    local input=""

    init_morse_table

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -d|--decode)  decode_mode=true; shift ;;
            -t|--table)   show_table_mode=true; shift ;;
            -i|--inter)   inter_mode=true; shift ;;
            -*)           error_exit "不明なオプション: $1" ;;
            *)            input="$1"; shift ;;
        esac
    done

    if "$show_table_mode"; then
        show_table
        exit 0
    fi

    if "$inter_mode" || [[ -z "$input" ]]; then
        interactive_mode
        exit 0
    fi

    local result
    if "$decode_mode"; then
        result=$(decode_morse "$input")
        echo -e "${C_GREEN}デコード結果:${C_RESET} $result"
    else
        result=$(encode_text "$input")
        echo -e "${C_GREEN}モールス信号:${C_RESET} $result"
        echo -n "ビジュアル: "
        play_morse_visual "$result"
    fi
}

main "$@"
