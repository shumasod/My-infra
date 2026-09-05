#!/bin/bash
set -euo pipefail

#
# テキスト変換ツール
# 作成日: 2026-07-14
# バージョン: 1.0
#
# 大文字・小文字・スネークケース・キャメルケース等の変換を行う
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション] <テキスト>

テキストのケース変換・フォーマット変換を行います。

引数:
  <テキスト>         変換する文字列

オプション:
  -h, --help         このヘルプを表示
  -v, --version      バージョン情報を表示
  -u, --upper        大文字に変換
  -l, --lower        小文字に変換
  -t, --title        タイトルケースに変換
  -s, --snake        スネークケース (hello_world)
  -k, --kebab        ケバブケース (hello-world)
  -c, --camel        キャメルケース (helloWorld)
  -p, --pascal       パスカルケース (HelloWorld)
  -r, --reverse      文字列を逆順に
  -w, --words        単語数・文字数カウント
  --base64-enc       Base64エンコード
  --base64-dec       Base64デコード
  --url-enc          URLエンコード
  --all              全変換結果を表示

例:
  $PROG_NAME --upper "hello world"
  $PROG_NAME --snake "helloWorldText"
  $PROG_NAME --all "my variable name"
EOF
}

to_upper()  { echo "${1^^}"; }
to_lower()  { echo "${1,,}"; }

to_title() {
    local text="$1"
    local result=""
    for word in $text; do
        result+="${word^} "
    done
    echo "${result% }"
}

normalize_words() {
    local text="$1"
    text=$(echo "$text" | sed 's/[_\-]/ /g')
    text=$(echo "$text" | sed 's/\([A-Z]\)/ \1/g')
    echo "${text,,}" | tr -s ' ' | sed 's/^ //'
}

to_snake() {
    local words
    words=$(normalize_words "$1")
    echo "$words" | tr ' ' '_'
}

to_kebab() {
    local words
    words=$(normalize_words "$1")
    echo "$words" | tr ' ' '-'
}

to_camel() {
    local words
    words=$(normalize_words "$1")
    local result=""
    local first=true
    for word in $words; do
        if "$first"; then
            result+="$word"
            first=false
        else
            result+="${word^}"
        fi
    done
    echo "$result"
}

to_pascal() {
    local words
    words=$(normalize_words "$1")
    local result=""
    for word in $words; do
        result+="${word^}"
    done
    echo "$result"
}

to_reverse() {
    echo "$1" | rev
}

count_words() {
    local text="$1"
    local chars=${#text}
    local words
    words=$(echo "$text" | wc -w)
    local lines
    lines=$(echo "$text" | wc -l)
    echo "文字数: ${chars}  単語数: ${words}  行数: ${lines}"
}

base64_encode() {
    echo -n "$1" | base64
}

base64_decode() {
    echo -n "$1" | base64 -d
}

url_encode() {
    local text="$1"
    python3 -c "import urllib.parse; print(urllib.parse.quote('${text}'))" 2>/dev/null \
        || echo "$text" | sed 's/ /%20/g; s/!/%21/g; s/"/%22/g; s/#/%23/g; s/&/%26/g'
}

show_all() {
    local text="$1"
    echo ""
    print_center "テキスト変換結果" 0 "${C_BOLD}${C_CYAN}"
    echo ""
    echo -e "  ${C_BOLD}入力:${C_RESET} ${C_YELLOW}${text}${C_RESET}"
    echo ""

    printf "  ${C_GREEN}%-16s${C_RESET} %s\n" "大文字:"        "$(to_upper "$text")"
    printf "  ${C_GREEN}%-16s${C_RESET} %s\n" "小文字:"        "$(to_lower "$text")"
    printf "  ${C_GREEN}%-16s${C_RESET} %s\n" "タイトル:"      "$(to_title "$text")"
    printf "  ${C_GREEN}%-16s${C_RESET} %s\n" "スネーク:"      "$(to_snake "$text")"
    printf "  ${C_GREEN}%-16s${C_RESET} %s\n" "ケバブ:"        "$(to_kebab "$text")"
    printf "  ${C_GREEN}%-16s${C_RESET} %s\n" "キャメル:"      "$(to_camel "$text")"
    printf "  ${C_GREEN}%-16s${C_RESET} %s\n" "パスカル:"      "$(to_pascal "$text")"
    printf "  ${C_GREEN}%-16s${C_RESET} %s\n" "逆順:"          "$(to_reverse "$text")"
    printf "  ${C_GREEN}%-16s${C_RESET} %s\n" "Base64:"        "$(base64_encode "$text")"
    printf "  ${C_GREEN}%-16s${C_RESET} %s\n" "URLエンコード:" "$(url_encode "$text")"
    echo ""
    printf "  ${C_DIM}%s${C_RESET}\n" "$(count_words "$text")"
    echo ""
}

main() {
    local mode=""
    local input=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)      show_usage; exit 0 ;;
            -v|--version)   echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -u|--upper)     mode="upper"; shift ;;
            -l|--lower)     mode="lower"; shift ;;
            -t|--title)     mode="title"; shift ;;
            -s|--snake)     mode="snake"; shift ;;
            -k|--kebab)     mode="kebab"; shift ;;
            -c|--camel)     mode="camel"; shift ;;
            -p|--pascal)    mode="pascal"; shift ;;
            -r|--reverse)   mode="reverse"; shift ;;
            -w|--words)     mode="words"; shift ;;
            --base64-enc)   mode="b64enc"; shift ;;
            --base64-dec)   mode="b64dec"; shift ;;
            --url-enc)      mode="urlenc"; shift ;;
            --all)          mode="all"; shift ;;
            -*)             error_exit "不明なオプション: $1" ;;
            *)              input="$1"; shift ;;
        esac
    done

    if [[ -z "$input" ]]; then
        echo -n "変換するテキストを入力: "
        read -r input
    fi

    case "$mode" in
        upper)   to_upper "$input" ;;
        lower)   to_lower "$input" ;;
        title)   to_title "$input" ;;
        snake)   to_snake "$input" ;;
        kebab)   to_kebab "$input" ;;
        camel)   to_camel "$input" ;;
        pascal)  to_pascal "$input" ;;
        reverse) to_reverse "$input" ;;
        words)   count_words "$input" ;;
        b64enc)  base64_encode "$input" ;;
        b64dec)  base64_decode "$input" ;;
        urlenc)  url_encode "$input" ;;
        all|"")  show_all "$input" ;;
    esac
}

main "$@"
