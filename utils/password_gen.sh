#!/bin/bash
set -euo pipefail

#
# セキュアパスワードジェネレーター
# 作成日: 2026-07-04
# バージョン: 1.0
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

readonly CHARS_UPPER="ABCDEFGHIJKLMNOPQRSTUVWXYZ"
readonly CHARS_LOWER="abcdefghijklmnopqrstuvwxyz"
readonly CHARS_DIGIT="0123456789"
readonly CHARS_SYMBOL="!@#\$%^&*()-_=+[]{}|;:,.<>?"

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション]

セキュアなランダムパスワードを生成します。

オプション:
  -h, --help        このヘルプを表示
  -v, --version     バージョン情報を表示
  -l, --length N    パスワード長（デフォルト: 16）
  -n, --count N     生成数（デフォルト: 1）
  --no-upper        大文字を含まない
  --no-lower        小文字を含まない
  --no-digit        数字を含まない
  --no-symbol       記号を含まない
  --pin N           数字のみのPINコードを生成（N桁）
  --passphrase N    単語 N 個のパスフレーズを生成

例:
  $PROG_NAME
  $PROG_NAME -l 24 -n 5
  $PROG_NAME --no-symbol -l 20
  $PROG_NAME --pin 6
  $PROG_NAME --passphrase 4
EOF
}

generate_password() {
    local length="$1"
    local use_upper="$2"
    local use_lower="$3"
    local use_digit="$4"
    local use_symbol="$5"

    local charset=""
    "$use_upper"  && charset+="$CHARS_UPPER"
    "$use_lower"  && charset+="$CHARS_LOWER"
    "$use_digit"  && charset+="$CHARS_DIGIT"
    "$use_symbol" && charset+="$CHARS_SYMBOL"

    [ -z "$charset" ] && error_exit "少なくとも1つの文字種を有効にしてください"

    local charset_len="${#charset}"
    local password=""
    local i
    for (( i = 0; i < length; i++ )); do
        local idx=$(( RANDOM % charset_len ))
        password+="${charset:$idx:1}"
    done
    echo "$password"
}

check_strength() {
    local pw="$1"
    local length="${#pw}"
    local score=0

    [ "$length" -ge 12 ] && score=$(( score + 1 ))
    [ "$length" -ge 16 ] && score=$(( score + 1 ))
    [ "$length" -ge 24 ] && score=$(( score + 1 ))
    [[ "$pw" =~ [A-Z] ]] && score=$(( score + 1 ))
    [[ "$pw" =~ [a-z] ]] && score=$(( score + 1 ))
    [[ "$pw" =~ [0-9] ]] && score=$(( score + 1 ))
    [[ "$pw" =~ [^A-Za-z0-9] ]] && score=$(( score + 1 ))

    case "$score" in
        7)   echo "${C_GREEN}非常に強い★★★★★${C_RESET}" ;;
        5|6) echo "${C_GREEN}強い    ★★★★☆${C_RESET}" ;;
        3|4) echo "${C_YELLOW}普通    ★★★☆☆${C_RESET}" ;;
        1|2) echo "${C_RED}弱い    ★★☆☆☆${C_RESET}" ;;
        *)   echo "${C_RED}非常に弱い★☆☆☆☆${C_RESET}" ;;
    esac
}

readonly -a WORDS=(
    correct horse battery staple sunset dragon purple castle ninja rocket
    forest ocean breeze silver golden cloud thunder winter autumn spring
    island cherry blossom travel wisdom bridge harbor valley meadow river
)

generate_passphrase() {
    local word_count="$1"
    local phrase=""
    local i
    for (( i = 0; i < word_count; i++ )); do
        local idx=$(( RANDOM % ${#WORDS[@]} ))
        [ "$i" -gt 0 ] && phrase+="-"
        phrase+="${WORDS[$idx]}"
    done
    echo "$phrase"
}

main() {
    local length=16
    local count=1
    local use_upper=true
    local use_lower=true
    local use_digit=true
    local use_symbol=true
    local pin_len=0
    local passphrase_words=0

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -l|--length)
                [[ $# -lt 2 ]] && error_exit "--length には数値が必要です"
                length="$2"; shift 2 ;;
            -n|--count)
                [[ $# -lt 2 ]] && error_exit "--count には数値が必要です"
                count="$2"; shift 2 ;;
            --no-upper)  use_upper=false;  shift ;;
            --no-lower)  use_lower=false;  shift ;;
            --no-digit)  use_digit=false;  shift ;;
            --no-symbol) use_symbol=false; shift ;;
            --pin)
                [[ $# -lt 2 ]] && error_exit "--pin には桁数が必要です"
                pin_len="$2"; shift 2 ;;
            --passphrase)
                [[ $# -lt 2 ]] && error_exit "--passphrase には単語数が必要です"
                passphrase_words="$2"; shift 2 ;;
            *) error_exit "不明なオプション: $1" ;;
        esac
    done

    echo ""
    print_center "セキュアパスワードジェネレーター" 0 "${C_BOLD}${C_CYAN}"
    echo ""

    if [ "$pin_len" -gt 0 ]; then
        echo -e "  ${C_BOLD}PINコード (${pin_len}桁):${C_RESET}"
        echo ""
        local i
        for (( i = 0; i < count; i++ )); do
            local pin=""
            local j
            for (( j = 0; j < pin_len; j++ )); do
                pin+=$(( RANDOM % 10 ))
            done
            printf "  ${C_BOLD}${C_GREEN}%s${C_RESET}\n" "$pin"
        done
        echo ""
        return
    fi

    if [ "$passphrase_words" -gt 0 ]; then
        echo -e "  ${C_BOLD}パスフレーズ (${passphrase_words}単語):${C_RESET}"
        echo ""
        local i
        for (( i = 0; i < count; i++ )); do
            local phrase
            phrase=$(generate_passphrase "$passphrase_words")
            printf "  ${C_BOLD}${C_GREEN}%s${C_RESET}\n" "$phrase"
            local strength
            strength=$(check_strength "$phrase")
            printf "  強度: %b\n" "$strength"
            echo ""
        done
        return
    fi

    local char_info=""
    "$use_upper"  && char_info+="大文字 "
    "$use_lower"  && char_info+="小文字 "
    "$use_digit"  && char_info+="数字 "
    "$use_symbol" && char_info+="記号"

    echo -e "  長さ: ${C_BOLD}${length}文字${C_RESET}  文字種: ${C_DIM}${char_info}${C_RESET}"
    echo ""

    local i
    for (( i = 0; i < count; i++ )); do
        local pw
        pw=$(generate_password "$length" "$use_upper" "$use_lower" "$use_digit" "$use_symbol")
        printf "  ${C_BOLD}${C_GREEN}%s${C_RESET}\n" "$pw"
        local strength
        strength=$(check_strength "$pw")
        printf "  強度: %b\n" "$strength"
        [ "$count" -gt 1 ] && echo ""
    done
    echo ""
}

main "$@"
