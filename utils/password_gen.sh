#!/bin/bash
set -euo pipefail

#
# パスワードジェネレーター
# バージョン: 1.0
#
# 安全なパスワード生成・強度評価・記憶しやすいパスフレーズ生成ツール
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare mode="generate"
declare -i length=16
declare -i count=1
declare use_upper=true
declare use_lower=true
declare use_digits=true
declare use_symbols=true
declare exclude_ambiguous=false
declare -i passphrase_words=4
declare separator="-"
declare check_password=""

# パスフレーズ用単語リスト (覚えやすい日常語)
declare -a WORD_LIST=(
    "apple" "brave" "cloud" "dance" "eagle" "flame" "green" "heart"
    "island" "jungle" "kite" "lemon" "magic" "night" "ocean" "piano"
    "queen" "river" "stone" "tiger" "ultra" "violet" "water" "xenon"
    "yellow" "zebra" "anchor" "butter" "castle" "dragon" "energy"
    "forest" "galaxy" "hammer" "impact" "jaguar" "knight" "lantern"
    "mirror" "nature" "orange" "pepper" "quartz" "rabbit" "silver"
    "thunder" "umbrella" "valley" "winter" "express" "fortune" "golden"
    "harbor" "intense" "journey" "kingdom" "liberty" "morning" "network"
    "outside" "perfect" "quantum" "rainbow" "sunrise" "tornado" "unique"
    "vibrant" "warrior" "extreme" "younger" "amazing" "balance" "capital"
)

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション] [コマンド]

パスワードジェネレーター

コマンド:
  generate          パスワードを生成 (デフォルト)
  passphrase        パスフレーズを生成
  check PASSWORD    パスワード強度を評価
  pin               数字PINを生成

オプション:
  -h, --help              このヘルプを表示
  -v, --version           バージョン情報を表示
  -l, --length NUM        パスワード長 [デフォルト: 16]
  -n, --count NUM         生成数 [デフォルト: 1]
  --no-upper              大文字を含まない
  --no-lower              小文字を含まない
  --no-digits             数字を含まない
  --no-symbols            記号を含まない
  --no-ambiguous          紛らわしい文字を除外 (0/O/I/l/1)
  -w, --words NUM         パスフレーズの単語数 [デフォルト: 4]
  -s, --separator CHAR    パスフレーズの区切り文字 [デフォルト: -]

例:
  $PROG_NAME
  $PROG_NAME -l 24 -n 5
  $PROG_NAME --no-symbols -l 20
  $PROG_NAME passphrase -w 5 -s _
  $PROG_NAME check "MyP@ssw0rd"
  $PROG_NAME pin -l 6

EOF
}

gen_password() {
    local charset=""

    $use_upper   && charset+="ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    $use_lower   && charset+="abcdefghijklmnopqrstuvwxyz"
    $use_digits  && charset+="0123456789"
    $use_symbols && charset+='!@#$%^&*()_+-=[]{}|;:,.<>?'

    if $exclude_ambiguous; then
        charset="${charset//[0OIl1]}"
    fi

    [[ -z "$charset" ]] && error_exit "文字セットが空です。オプションを確認してください"

    local password=""
    local charset_len=${#charset}

    for (( i=0; i<length; i++ )); do
        local idx=$(( RANDOM % charset_len ))
        password+="${charset:$idx:1}"
    done

    # 必須文字チェック・補完
    local has_upper=false has_lower=false has_digit=false has_symbol=false

    [[ "$password" =~ [A-Z] ]] && has_upper=true
    [[ "$password" =~ [a-z] ]] && has_lower=true
    [[ "$password" =~ [0-9] ]] && has_digit=true
    [[ "$password" =~ ['!@#$%^&*()_+\-=\[\]{}|;:,.<>?'] ]] && has_symbol=true

    # 足りない文字を先頭に挿入(後でシャッフル)
    local extra=""
    $use_upper && ! $has_upper && {
        local uc="ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        extra+="${uc:$(( RANDOM % 26 )):1}"
    }
    $use_lower && ! $has_lower && {
        local lc="abcdefghijklmnopqrstuvwxyz"
        extra+="${lc:$(( RANDOM % 26 )):1}"
    }
    $use_digits && ! $has_digit && {
        extra+="$(( RANDOM % 10 ))"
    }
    $use_symbols && ! $has_symbol && {
        local syms='!@#$%^&*()_+-=[]{}|;:,.<>?'
        extra+="${syms:$(( RANDOM % ${#syms} )):1}"
    }

    if [[ -n "$extra" ]]; then
        local combined="${extra}${password:${#extra}}"
        # Fisher-Yates シャッフル
        local arr=()
        for (( i=0; i<${#combined}; i++ )); do
            arr+=("${combined:$i:1}")
        done
        local n=${#arr[@]}
        for (( i=n-1; i>0; i-- )); do
            local j=$(( RANDOM % (i+1) ))
            local tmp="${arr[$i]}"
            arr[$i]="${arr[$j]}"
            arr[$j]="$tmp"
        done
        password=""
        for c in "${arr[@]}"; do password+="$c"; done
    fi

    echo "$password"
}

gen_passphrase() {
    local phrase=""
    local word_count=${#WORD_LIST[@]}

    for (( i=0; i<passphrase_words; i++ )); do
        local idx=$(( RANDOM % word_count ))
        local word="${WORD_LIST[$idx]}"

        # ランダムに先頭大文字
        (( RANDOM % 3 == 0 )) && word="${word^}"

        phrase+="$word"
        (( i < passphrase_words - 1 )) && phrase+="$separator"
    done

    # 数字を末尾に追加
    phrase+="${separator}$(( RANDOM % 900 + 100 ))"

    echo "$phrase"
}

evaluate_strength() {
    local pass="$1"
    local len=${#pass}
    local score=0
    local -a feedback=()

    # 長さチェック
    if (( len >= 16 )); then
        (( score += 25 )) || true
    elif (( len >= 12 )); then
        (( score += 15 )) || true
        feedback+=("推奨: 16文字以上")
    elif (( len >= 8 )); then
        (( score += 5 )) || true
        feedback+=("警告: 8文字は最低限です")
    else
        feedback+=("危険: 8文字未満は非常に脆弱です")
    fi

    # 文字種チェック
    [[ "$pass" =~ [a-z] ]] && (( score += 10 )) || { feedback+=("小文字を追加してください"); }
    [[ "$pass" =~ [A-Z] ]] && (( score += 10 )) || { feedback+=("大文字を追加してください"); }
    [[ "$pass" =~ [0-9] ]] && (( score += 15 )) || { feedback+=("数字を追加してください"); }
    [[ "$pass" =~ ['!@#$%^&*()_+\-=\[\]{}|;:,.<>?'] ]] && (( score += 20 )) || { feedback+=("記号を追加してください"); }

    # 繰り返し文字チェック
    if echo "$pass" | grep -qE '(.)\1{2,}'; then
        (( score -= 10 )) || true
        feedback+=("同じ文字の連続を避けてください")
    fi

    # エントロピー推定
    local charset_size=0
    [[ "$pass" =~ [a-z] ]] && (( charset_size += 26 )) || true
    [[ "$pass" =~ [A-Z] ]] && (( charset_size += 26 )) || true
    [[ "$pass" =~ [0-9] ]] && (( charset_size += 10 )) || true
    [[ "$pass" =~ ['!@#$%^&*()_+\-=\[\]{}|;:,.<>?'] ]] && (( charset_size += 32 )) || true

    local entropy=0
    (( charset_size > 0 )) && entropy=$(python3 -c "import math; print(int($len * math.log2($charset_size)))" 2>/dev/null || echo 0)

    (( score > 100 )) && score=100
    (( score < 0 )) && score=0

    local grade color
    if (( score >= 80 )); then grade="強 (Strong)"; color="$C_GREEN"
    elif (( score >= 60 )); then grade="良 (Good)"; color="$C_CYAN"
    elif (( score >= 40 )); then grade="普通 (Fair)"; color="$C_YELLOW"
    elif (( score >= 20 )); then grade="弱 (Weak)"; color="$C_RED"
    else grade="非常に弱い (Very Weak)"; color="${C_RED}${C_BOLD}"
    fi

    log_info "パスワード強度評価"
    echo ""
    printf "  %-20s %s\n" "パスワード:" "$pass"
    printf "  %-20s %d 文字\n" "長さ:" "$len"
    printf "  %-20s 約 %d bit\n" "エントロピー:" "$entropy"
    printf "  %-20s " "スコア:"
    draw_progress_bar "$score" 100 20
    printf " %d/100\n" "$score"
    printf "  %-20s ${color}%s${C_RESET}\n" "評価:" "$grade"

    if [[ ${#feedback[@]} -gt 0 ]]; then
        echo ""
        log_info "改善提案:"
        for f in "${feedback[@]}"; do
            printf "  ${C_YELLOW}→ %s${C_RESET}\n" "$f"
        done
    fi
    echo ""
}

do_pin() {
    for (( i=0; i<count; i++ )); do
        local pin=""
        for (( j=0; j<length; j++ )); do
            pin+="$(( RANDOM % 10 ))"
        done
        echo "  $pin"
    done
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -l|--length)  [[ $# -lt 2 ]] && error_exit "-l には値が必要です"; length="$2"; shift 2 ;;
            -n|--count)   [[ $# -lt 2 ]] && error_exit "-n には値が必要です"; count="$2"; shift 2 ;;
            -w|--words)   [[ $# -lt 2 ]] && error_exit "-w には値が必要です"; passphrase_words="$2"; shift 2 ;;
            -s|--separator) [[ $# -lt 2 ]] && error_exit "-s には値が必要です"; separator="$2"; shift 2 ;;
            --no-upper)   use_upper=false; shift ;;
            --no-lower)   use_lower=false; shift ;;
            --no-digits)  use_digits=false; shift ;;
            --no-symbols) use_symbols=false; shift ;;
            --no-ambiguous) exclude_ambiguous=true; shift ;;
            generate|passphrase|pin) mode="$1"; shift ;;
            check)
                mode="check"
                [[ $# -ge 2 && ! "$2" =~ ^- ]] && { check_password="$2"; shift; }
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
        generate)
            log_info "パスワード生成 (長さ: ${length}, 数: ${count})"
            echo ""
            for (( i=0; i<count; i++ )); do
                printf "  %s\n" "$(gen_password)"
            done
            echo ""
            ;;
        passphrase)
            log_info "パスフレーズ生成 (${passphrase_words}単語)"
            echo ""
            for (( i=0; i<count; i++ )); do
                printf "  %s\n" "$(gen_passphrase)"
            done
            echo ""
            ;;
        check)
            [[ -z "$check_password" ]] && { printf "評価するパスワードを入力: "; IFS= read -r -s check_password; echo ""; }
            evaluate_strength "$check_password"
            ;;
        pin)
            log_info "PIN生成 (${length}桁, 数: ${count})"
            echo ""
            do_pin
            echo ""
            ;;
    esac
}

main "$@"
