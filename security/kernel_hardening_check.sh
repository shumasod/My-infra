#!/bin/bash
set -euo pipefail

#
# カーネルセキュリティ設定確認ツール
# 作成日: 2026-11-05
# バージョン: 1.0
#
# 脆弱性対応: カーネルの安全でないデフォルト設定の検出・修正
# CVE該当: CWE-693 (Protection Mechanism Failure)
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare command_name="check"
declare fix_mode=0

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション]

カーネルのセキュリティ設定を確認・強化します。

コマンド:
  check      カーネルセキュリティ設定確認 (デフォルト)
  sysctl     sysctl パラメータの確認
  aslr       ASLR (アドレス空間配置ランダム化) 確認
  apparmor   AppArmor の状態確認
  selinux    SELinux の状態確認
  modules    危険なカーネルモジュール確認
  report     セキュリティレポート生成

オプション:
  -h, --help     このヘルプを表示
  -v, --version  バージョン情報を表示
  --fix          修正コマンドを適用 (要root)

脆弱性概要:
  CWE-693: 保護機構の失敗
  対策: ASLR有効化, カーネルパラメータ強化
EOF
}

check_sysctl() {
    local key="$1"
    sysctl -n "$key" 2>/dev/null || echo "N/A"
}

cmd_check() {
    log_info "カーネルセキュリティ設定確認"
    echo ""

    local kernel_version
    kernel_version=$(uname -r)
    printf "  カーネルバージョン: %s\n\n" "$kernel_version"

    cmd_sysctl
    cmd_aslr
}

cmd_sysctl() {
    log_info "sysctl セキュリティパラメータ確認"
    echo ""

    # パラメータ: (key, 推奨値, 説明, 重大度)
    local checks=(
        "kernel.randomize_va_space:2:ASLR有効:HIGH"
        "kernel.dmesg_restrict:1:dmesgアクセス制限:MEDIUM"
        "kernel.kptr_restrict:2:カーネルポインタ非公開:HIGH"
        "kernel.yama.ptrace_scope:1:ptrace制限:HIGH"
        "kernel.perf_event_paranoid:3:perfイベント制限:MEDIUM"
        "fs.suid_dumpable:0:SUID時のコアダンプ無効:HIGH"
        "fs.protected_symlinks:1:シンボリックリンク保護:HIGH"
        "fs.protected_hardlinks:1:ハードリンク保護:HIGH"
        "net.ipv4.conf.all.accept_redirects:0:ICMP リダイレクト拒否:MEDIUM"
        "net.ipv4.conf.all.accept_source_route:0:ソースルート無効:MEDIUM"
        "net.ipv4.conf.all.rp_filter:1:リバースパスフィルタ:MEDIUM"
        "net.ipv4.conf.all.log_martians:1:不正パケットログ:LOW"
        "net.ipv4.icmp_echo_ignore_broadcasts:1:ブロードキャストping無視:LOW"
        "net.ipv4.tcp_syncookies:1:SYNクッキー有効:HIGH"
        "net.ipv6.conf.all.accept_redirects:0:IPv6リダイレクト拒否:MEDIUM"
        "net.ipv6.conf.all.accept_source_route:0:IPv6ソースルート無効:MEDIUM"
    )

    local pass_count=0 fail_count=0 warn_count=0

    printf "  ${C_BOLD}%-50s %-12s %-12s %s${C_RESET}\n" "パラメータ" "現在値" "推奨値" "状態"
    draw_separator 0 "-"

    for check in "${checks[@]}"; do
        local key expected desc sev
        key=$(echo "$check" | cut -d: -f1)
        expected=$(echo "$check" | cut -d: -f2)
        desc=$(echo "$check" | cut -d: -f3)
        sev=$(echo "$check" | cut -d: -f4)

        local actual
        actual=$(check_sysctl "$key")

        printf "  %-50s %-12s %-12s " "$key" "$actual" "$expected"

        if [[ "$actual" == "$expected" ]]; then
            printf "${C_GREEN}[OK]${C_RESET}\n"
            (( pass_count++ ))
        elif [[ "$actual" == "N/A" ]]; then
            printf "${C_DIM}[N/A]${C_RESET}\n"
        else
            case "$sev" in
                HIGH)   printf "${C_RED}[FAIL]${C_RESET}\n"; (( fail_count++ )) ;;
                MEDIUM) printf "${C_YELLOW}[WARN]${C_RESET}\n"; (( warn_count++ )) ;;
                LOW)    printf "${C_DIM}[INFO]${C_RESET}\n" ;;
            esac
        fi
    done

    echo ""
    printf "  結果: ${C_GREEN}PASS:%d${C_RESET}  ${C_RED}FAIL:%d${C_RESET}  ${C_YELLOW}WARN:%d${C_RESET}\n\n" \
        "$pass_count" "$fail_count" "$warn_count"

    if (( fix_mode && fail_count > 0 )); then
        log_info "修正コマンド生成..."
        echo ""
        for check in "${checks[@]}"; do
            local key expected
            key=$(echo "$check" | cut -d: -f1)
            expected=$(echo "$check" | cut -d: -f2)
            local actual
            actual=$(check_sysctl "$key")
            if [[ "$actual" != "$expected" && "$actual" != "N/A" ]]; then
                printf "  sysctl -w %s=%s\n" "$key" "$expected"
            fi
        done
        echo ""
    fi
}

cmd_aslr() {
    log_info "ASLR (アドレス空間配置ランダム化) 確認"
    echo ""

    local aslr_val
    aslr_val=$(cat /proc/sys/kernel/randomize_va_space 2>/dev/null || echo "N/A")

    printf "  ASLR値 (randomize_va_space): "
    case "$aslr_val" in
        0) printf "${C_RED}0 [無効 - CRITICAL]${C_RESET}\n" ;;
        1) printf "${C_YELLOW}1 [共有ライブラリのみランダム化]${C_RESET}\n" ;;
        2) printf "${C_GREEN}2 [完全ランダム化 - 推奨]${C_RESET}\n" ;;
        *) printf "${C_DIM}%s [不明]${C_RESET}\n" "$aslr_val" ;;
    esac

    echo ""
    # スタック保護確認
    printf "  ${C_BOLD}バイナリ保護状態サンプル:${C_RESET}\n"
    for binary in /bin/ls /usr/bin/ssh /usr/bin/sudo; do
        [[ ! -f "$binary" ]] && continue
        if command -v readelf &>/dev/null; then
            local nx pie
            nx=$(readelf -l "$binary" 2>/dev/null | grep -c "GNU_STACK.*RW " || echo 0)
            pie=$(file "$binary" 2>/dev/null | grep -c "pie" || echo 0)
            printf "  %-30s NX:%s PIE:%s\n" "$binary" \
                "$( [[ "$nx" -gt 0 ]] && echo "${C_GREEN}有効${C_RESET}" || echo "${C_RED}無効${C_RESET}" )" \
                "$( [[ "$pie" -gt 0 ]] && echo "${C_GREEN}有効${C_RESET}" || echo "${C_YELLOW}無効${C_RESET}" )"
        fi
    done
    echo ""
}

cmd_apparmor() {
    log_info "AppArmor 状態確認"
    echo ""

    if ! command -v apparmor_status &>/dev/null && ! command -v aa-status &>/dev/null; then
        log_warning "AppArmor がインストールされていません"
        echo ""
        return
    fi

    local status_cmd="apparmor_status"
    command -v aa-status &>/dev/null && status_cmd="aa-status"

    local output
    output=$("$status_cmd" 2>/dev/null || echo "")

    if echo "$output" | grep -q "apparmor module is loaded"; then
        log_success "AppArmor: 有効"
        local enforced
        enforced=$(echo "$output" | grep -c "enforce" || echo 0)
        local complain
        complain=$(echo "$output" | grep -c "complain" || echo 0)
        printf "  強制モードプロファイル: %s\n" "$enforced"
        printf "  通知モードプロファイル: %s\n" "$complain"
    else
        log_warning "AppArmor: 無効または未起動"
    fi
    echo ""
}

cmd_selinux() {
    log_info "SELinux 状態確認"
    echo ""

    if ! command -v getenforce &>/dev/null; then
        log_warning "SELinux がインストールされていません"
        echo ""
        return
    fi

    local status
    status=$(getenforce 2>/dev/null || echo "N/A")

    printf "  SELinux モード: "
    case "$status" in
        Enforcing)  printf "${C_GREEN}%s (推奨)${C_RESET}\n" "$status" ;;
        Permissive) printf "${C_YELLOW}%s (ログのみ、強制なし)${C_RESET}\n" "$status" ;;
        Disabled)   printf "${C_RED}%s (無効)${C_RESET}\n" "$status" ;;
        *)          printf "${C_DIM}%s${C_RESET}\n" "$status" ;;
    esac

    if [[ -f /etc/selinux/config ]]; then
        local config_mode
        config_mode=$(grep "^SELINUX=" /etc/selinux/config 2>/dev/null | cut -d= -f2 || echo "N/A")
        printf "  設定ファイル値:  %s\n" "$config_mode"
    fi
    echo ""
}

cmd_modules() {
    log_info "危険なカーネルモジュール確認"
    echo ""

    local dangerous_modules=("udf" "cramfs" "freevxfs" "jffs2" "hfs" "hfsplus" "squashfs")

    printf "${C_BOLD}【無効化推奨モジュール】${C_RESET}\n\n"
    for mod in "${dangerous_modules[@]}"; do
        printf "  %-20s " "$mod"
        if lsmod 2>/dev/null | grep -q "^$mod"; then
            printf "${C_YELLOW}[ロード済み - 無効化推奨]${C_RESET}\n"
        else
            printf "${C_GREEN}[未ロード]${C_RESET}\n"
        fi
    done
    echo ""
}

parse_arguments() {
    [[ $# -eq 0 ]] && return 0
    case "$1" in
        check|sysctl|aslr|apparmor|selinux|modules|report)
            command_name="$1"; shift ;;
    esac
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            --fix)        fix_mode=1; shift ;;
            -*) error_exit "不明なオプション: $1" ;;
            *) shift ;;
        esac
    done
}

main() {
    parse_arguments "$@"
    case "$command_name" in
        check)    cmd_check ;;
        sysctl)   cmd_sysctl ;;
        aslr)     cmd_aslr ;;
        apparmor) cmd_apparmor ;;
        selinux)  cmd_selinux ;;
        modules)  cmd_modules ;;
        report)   cmd_check; cmd_apparmor; cmd_selinux; cmd_modules ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
