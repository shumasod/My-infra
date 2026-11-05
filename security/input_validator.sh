#!/bin/bash
set -euo pipefail

#
# 入力値検証ライブラリ
# 作成日: 2026-11-05
# バージョン: 1.0
#
# 脆弱性対応: 不適切な入力値検証による各種インジェクション攻撃の防止
# CVE該当: CWE-20 (Improper Input Validation), CWE-116 (Improper Encoding or Escaping)
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare command_name="demo"

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション]

入力値検証・サニタイズのユーティリティライブラリです。
スクリプトから source して使用することもできます。

コマンド:
  demo         各検証関数のデモ実行
  validate     対話型入力検証テスト
  sanitize     サニタイズ関数デモ
  test         全関数のユニットテスト

ライブラリ関数 (sourceして使用):
  validate_integer VAL [MIN] [MAX]   整数値の検証
  validate_string VAL [MAX_LEN]      文字列の検証
  validate_ip VAL                    IPアドレス検証
  validate_email VAL                 メールアドレス検証
  validate_path VAL [BASE_DIR]       ファイルパス検証
  validate_hostname VAL              ホスト名検証
  sanitize_shell VAL                 シェル用サニタイズ
  sanitize_log VAL                   ログ用サニタイズ
  sanitize_sql VAL                   SQL用サニタイズ

脆弱性概要:
  CWE-20: 入力値の不適切な検証
  CWE-116: 不適切なエンコード・エスケープ
EOF
}

# ===== 検証関数 =====

validate_integer() {
    local value="$1"
    local min="${2:-}"
    local max="${3:-}"

    if [[ ! "$value" =~ ^-?[0-9]+$ ]]; then
        log_error "整数ではありません: '$value'"
        return 1
    fi
    if [[ -n "$min" && "$value" -lt "$min" ]]; then
        log_error "値が最小値($min)を下回っています: $value"
        return 1
    fi
    if [[ -n "$max" && "$value" -gt "$max" ]]; then
        log_error "値が最大値($max)を超えています: $value"
        return 1
    fi
    return 0
}

validate_string() {
    local value="$1"
    local max_len="${2:-255}"

    # 長さチェック
    if [[ ${#value} -gt "$max_len" ]]; then
        log_error "文字列が長すぎます (最大: $max_len, 実際: ${#value})"
        return 1
    fi

    # Nullバイトチェック
    if [[ "$value" == *$'\x00'* ]]; then
        log_error "Nullバイトを含む文字列は許可されません"
        return 1
    fi

    # 制御文字チェック
    if echo "$value" | grep -qP '[\x01-\x08\x0b\x0c\x0e-\x1f\x7f]'; then
        log_error "制御文字を含む文字列は許可されません"
        return 1
    fi

    return 0
}

validate_ip() {
    local ip="$1"

    # IPv4チェック
    if [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        local IFS='.'
        read -ra octets <<< "$ip"
        for octet in "${octets[@]}"; do
            if (( octet > 255 )); then
                log_error "無効なIPアドレス: '$ip'"
                return 1
            fi
        done
        return 0
    fi

    # IPv6チェック (簡易)
    if [[ "$ip" =~ ^[0-9a-fA-F:]+$ ]]; then
        return 0
    fi

    log_error "無効なIPアドレス形式: '$ip'"
    return 1
}

validate_email() {
    local email="$1"
    local regex='^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$'

    if [[ ! "$email" =~ $regex ]]; then
        log_error "無効なメールアドレス: '$email'"
        return 1
    fi

    # 長さチェック
    if [[ ${#email} -gt 254 ]]; then
        log_error "メールアドレスが長すぎます"
        return 1
    fi

    return 0
}

validate_path() {
    local path="$1"
    local base_dir="${2:-}"

    # パストラバーサルチェック
    if [[ "$path" == *".."* ]]; then
        log_error "パストラバーサルが検出されました: '$path'"
        return 1
    fi

    # Nullバイトチェック
    if [[ "$path" == *$'\x00'* ]]; then
        log_error "パスにNullバイトが含まれています"
        return 1
    fi

    # ベースディレクトリチェック
    if [[ -n "$base_dir" ]]; then
        local real_path
        real_path=$(realpath -m "$path" 2>/dev/null || echo "$path")
        if [[ "$real_path" != "$base_dir"* ]]; then
            log_error "パスがベースディレクトリ外を指しています: '$path'"
            return 1
        fi
    fi

    return 0
}

validate_hostname() {
    local hostname="$1"
    local regex='^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$'

    if [[ ${#hostname} -gt 253 ]]; then
        log_error "ホスト名が長すぎます"
        return 1
    fi

    if [[ ! "$hostname" =~ $regex ]]; then
        log_error "無効なホスト名: '$hostname'"
        return 1
    fi

    return 0
}

# ===== サニタイズ関数 =====

sanitize_shell() {
    local input="$1"
    # シェルメタキャラクターをエスケープ
    printf '%q' "$input"
}

sanitize_log() {
    local input="$1"
    # ログインジェクション対策: 改行・制御文字を除去
    echo "$input" | tr -d '\r\n' | tr -cd '[:print:]' | head -c 1024
}

sanitize_sql() {
    local input="$1"
    # SQLインジェクション対策: シングルクォートをエスケープ
    echo "${input//\'/\'\'}"
}

# ===== コマンド実装 =====

cmd_demo() {
    log_info "入力値検証関数デモ"
    echo ""

    printf "${C_BOLD}【validate_integer】${C_RESET}\n"
    local test_cases=("42" "-5" "abc" "999" "0")
    for val in "${test_cases[@]}"; do
        printf "  validate_integer '%s' 0 100: " "$val"
        if validate_integer "$val" 0 100 2>/dev/null; then
            printf "${C_GREEN}[PASS]${C_RESET}\n"
        else
            printf "${C_RED}[FAIL]${C_RESET}\n"
        fi
    done

    echo ""
    printf "${C_BOLD}【validate_ip】${C_RESET}\n"
    local ips=("192.168.1.1" "256.0.0.1" "10.0.0.0" "invalid" "::1")
    for ip in "${ips[@]}"; do
        printf "  validate_ip '%s': " "$ip"
        if validate_ip "$ip" 2>/dev/null; then
            printf "${C_GREEN}[VALID]${C_RESET}\n"
        else
            printf "${C_RED}[INVALID]${C_RESET}\n"
        fi
    done

    echo ""
    printf "${C_BOLD}【validate_email】${C_RESET}\n"
    local emails=("user@example.com" "invalid@" "@domain.com" "test+tag@sub.domain.co.jp")
    for email in "${emails[@]}"; do
        printf "  validate_email '%s': " "$email"
        if validate_email "$email" 2>/dev/null; then
            printf "${C_GREEN}[VALID]${C_RESET}\n"
        else
            printf "${C_RED}[INVALID]${C_RESET}\n"
        fi
    done

    echo ""
    printf "${C_BOLD}【sanitize_shell】${C_RESET}\n"
    local dangerous_inputs=("; rm -rf /" "$(cat /etc/passwd)" "test'injection'" 'hello world')
    for input in "${dangerous_inputs[@]}"; do
        local safe
        safe=$(sanitize_shell "$input")
        printf "  入力: %-25s -> サニタイズ済み: %s\n" "'${input:0:25}'" "$safe"
    done

    echo ""
    printf "${C_BOLD}【sanitize_log】${C_RESET}\n"
    printf "  入力: 'line1\\nline2\\r'  -> サニタイズ済み: '%s'\n" "$(sanitize_log $'line1\nline2\r')"
    echo ""
}

cmd_test() {
    log_info "全検証関数のユニットテスト"
    echo ""

    local passed=0 failed=0

    run_test() {
        local desc="$1" expected="$2"
        shift 2
        local result
        if "$@" &>/dev/null; then result=0; else result=1; fi
        if [[ "$result" -eq "$expected" ]]; then
            printf "  ${C_GREEN}[PASS]${C_RESET} %s\n" "$desc"
            (( passed++ ))
        else
            printf "  ${C_RED}[FAIL]${C_RESET} %s\n" "$desc"
            (( failed++ ))
        fi
    }

    run_test "整数 42 (0-100)"       0 validate_integer "42" 0 100
    run_test "整数 -1 (0-100) 失敗"  1 validate_integer "-1" 0 100
    run_test "整数 abc 失敗"         1 validate_integer "abc"
    run_test "IP 192.168.1.1"        0 validate_ip "192.168.1.1"
    run_test "IP 256.0.0.1 失敗"     1 validate_ip "256.0.0.1"
    run_test "メール valid"          0 validate_email "user@example.com"
    run_test "メール invalid 失敗"   1 validate_email "not-an-email"
    run_test "パス ../etc 失敗"      1 validate_path "../etc/passwd"
    run_test "ホスト名 valid"        0 validate_hostname "example.com"
    run_test "ホスト名 invalid 失敗" 1 validate_hostname "invalid!host"

    echo ""
    printf "  結果: ${C_GREEN}PASS: %d${C_RESET}  ${C_RED}FAIL: %d${C_RESET}\n" "$passed" "$failed"
    echo ""
}

parse_arguments() {
    [[ $# -eq 0 ]] && return 0
    case "$1" in
        demo|validate|sanitize|test)
            command_name="$1"; shift ;;
    esac
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -*) error_exit "不明なオプション: $1" ;;
            *) shift ;;
        esac
    done
}

main() {
    parse_arguments "$@"
    case "$command_name" in
        demo)     cmd_demo ;;
        sanitize) cmd_demo ;;
        test)     cmd_test ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
