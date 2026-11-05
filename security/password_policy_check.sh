#!/bin/bash
set -euo pipefail

#
# パスワードポリシー検査ツール
# 作成日: 2026-11-05
# バージョン: 1.0
#
# 脆弱性対応: パスワードポリシーの不備検出・強化
# CVE該当: CWE-521 (Weak Password Requirements), CWE-620 (Unverified Password Change)
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare command_name="audit"

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション]

パスワードポリシーを検査・強化します。

コマンド:
  audit                パスワードポリシー全体監査 (デフォルト)
  users                ユーザーパスワード状態確認
  pam                  PAM設定の確認
  expiry               パスワード有効期限確認
  strength <パスワード> パスワード強度評価
  recommend            推奨設定の表示

オプション:
  -h, --help           このヘルプを表示
  -v, --version        バージョン情報を表示

脆弱性概要:
  CWE-521: 弱いパスワード要件
  CWE-620: パスワード変更の未検証
  CWE-916: 不十分な反復回数のパスワードハッシュ
EOF
}

cmd_audit() {
    log_info "パスワードポリシー監査"
    echo ""

    printf "${C_BOLD}【/etc/login.defs 設定】${C_RESET}\n\n"
    if [[ -f /etc/login.defs ]]; then
        local params=(
            "PASS_MAX_DAYS:90:パスワード最大有効日数"
            "PASS_MIN_DAYS:1:パスワード最小変更間隔"
            "PASS_MIN_LEN:12:パスワード最小長"
            "PASS_WARN_AGE:14:有効期限警告日数"
        )
        for param in "${params[@]}"; do
            local key expected desc
            key=$(echo "$param" | cut -d: -f1)
            expected=$(echo "$param" | cut -d: -f2)
            desc=$(echo "$param" | cut -d: -f3)

            local actual
            actual=$(grep -E "^\s*${key}\s+" /etc/login.defs 2>/dev/null | awk '{print $2}' || echo "未設定")

            printf "  %-35s " "$desc ($key):"
            if [[ "$actual" == "未設定" ]]; then
                printf "${C_YELLOW}[未設定]${C_RESET}\n"
            elif [[ "$actual" -le "$expected" ]] 2>/dev/null; then
                printf "${C_GREEN}[OK] %s${C_RESET}\n" "$actual"
            else
                printf "${C_RED}[要改善] %s (推奨: %s以下)${C_RESET}\n" "$actual" "$expected"
            fi
        done
    else
        log_warning "/etc/login.defs が見つかりません"
    fi
    echo ""

    cmd_pam
    cmd_expiry
}

cmd_users() {
    log_info "ユーザーパスワード状態確認"
    echo ""

    printf "  %-20s %-15s %-15s %s\n" "ユーザー" "状態" "最終変更" "有効期限"
    draw_separator 0 "-"

    while IFS=: read -r username _ uid gid _ _ _; do
        (( uid < 1000 )) && [[ "$username" != "root" ]] && continue

        local shadow_line status last_change expire
        shadow_line=$(getent shadow "$username" 2>/dev/null || echo "")
        if [[ -z "$shadow_line" ]]; then
            status="${C_DIM}shadow なし${C_RESET}"
            last_change="-"
            expire="-"
        else
            local pass_field locked_days
            pass_field=$(echo "$shadow_line" | cut -d: -f2)
            locked_days=$(echo "$shadow_line" | cut -d: -f8)

            if [[ "$pass_field" == "!" || "$pass_field" == "*" || "$pass_field" == "!!" ]]; then
                status="${C_DIM}ロック済み${C_RESET}"
            elif [[ -z "$pass_field" ]]; then
                status="${C_RED}パスワードなし${C_RESET}"
            else
                status="${C_GREEN}有効${C_RESET}"
            fi

            local change_days
            change_days=$(echo "$shadow_line" | cut -d: -f3)
            if [[ -n "$change_days" && "$change_days" != "0" ]]; then
                last_change=$(date -d "1970-01-01 +${change_days} days" "+%Y-%m-%d" 2>/dev/null || echo "N/A")
            else
                last_change="未変更"
            fi

            local max_days
            max_days=$(echo "$shadow_line" | cut -d: -f5)
            if [[ -n "$max_days" && "$max_days" != "99999" && "$max_days" != "" ]]; then
                expire="${max_days}日"
            else
                expire="${C_YELLOW}無期限${C_RESET}"
            fi
        fi

        printf "  %-20s " "$username"
        printf "%-15b " "$status"
        printf "%-15s " "$last_change"
        printf "%b\n" "$expire"
    done < /etc/passwd
    echo ""
}

cmd_pam() {
    log_info "PAMパスワード設定確認"
    echo ""

    local pam_files=("/etc/pam.d/common-password" "/etc/pam.d/system-auth" "/etc/pam.d/password-auth")
    local found=0

    for pam_file in "${pam_files[@]}"; do
        [[ ! -f "$pam_file" ]] && continue
        (( found++ ))
        printf "${C_BOLD}%s${C_RESET}\n" "$pam_file"

        local has_pwquality has_minlen has_remember
        has_pwquality=$(grep -c "pam_pwquality\|pam_cracklib" "$pam_file" 2>/dev/null || true)
        has_minlen=$(grep -oE "minlen=[0-9]+" "$pam_file" 2>/dev/null | head -1 || echo "")
        has_remember=$(grep -oE "remember=[0-9]+" "$pam_file" 2>/dev/null | head -1 || echo "")

        if [[ "$has_pwquality" -gt 0 ]]; then
            printf "  ${C_GREEN}[OK] パスワード品質チェック有効${C_RESET}\n"
        else
            printf "  ${C_RED}[危険] パスワード品質チェックなし${C_RESET}\n"
        fi

        if [[ -n "$has_minlen" ]]; then
            local minlen_val="${has_minlen#minlen=}"
            if [[ "$minlen_val" -ge 12 ]] 2>/dev/null; then
                printf "  ${C_GREEN}[OK] 最小文字数: %s${C_RESET}\n" "$minlen_val"
            else
                printf "  ${C_RED}[危険] 最小文字数が短い: %s (推奨: 12以上)${C_RESET}\n" "$minlen_val"
            fi
        else
            printf "  ${C_YELLOW}[未設定] 最小文字数制限なし${C_RESET}\n"
        fi

        if [[ -n "$has_remember" ]]; then
            printf "  ${C_GREEN}[OK] パスワード履歴: %s${C_RESET}\n" "$has_remember"
        else
            printf "  ${C_YELLOW}[未設定] パスワード履歴管理なし${C_RESET}\n"
        fi
        echo ""
    done

    [[ "$found" -eq 0 ]] && log_warning "PAM設定ファイルが見つかりません"
}

cmd_expiry() {
    log_info "パスワード有効期限確認"
    echo ""

    local expired=0 expiring=0
    while IFS=: read -r username _ uid _ _ _ _; do
        (( uid < 1000 )) && [[ "$username" != "root" ]] && continue

        local shadow_line
        shadow_line=$(getent shadow "$username" 2>/dev/null || echo "")
        [[ -z "$shadow_line" ]] && continue

        local pass_field change_days max_days
        pass_field=$(echo "$shadow_line" | cut -d: -f2)
        [[ "$pass_field" == "!" || "$pass_field" == "*" ]] && continue

        change_days=$(echo "$shadow_line" | cut -d: -f3)
        max_days=$(echo "$shadow_line" | cut -d: -f5)

        [[ -z "$change_days" || -z "$max_days" || "$max_days" == "99999" ]] && continue
        [[ "$change_days" == "0" ]] && continue

        local today_days expire_days days_left
        today_days=$(( $(date +%s) / 86400 ))
        expire_days=$(( change_days + max_days ))
        days_left=$(( expire_days - today_days ))

        if [[ "$days_left" -lt 0 ]]; then
            printf "  ${C_RED}[期限切れ]${C_RESET} %-20s %d日前に期限切れ\n" "$username" "$((-days_left))"
            (( expired++ ))
        elif [[ "$days_left" -lt 30 ]]; then
            printf "  ${C_YELLOW}[期限間近]${C_RESET} %-20s あと%d日\n" "$username" "$days_left"
            (( expiring++ ))
        fi
    done < /etc/passwd

    if [[ "$expired" -eq 0 && "$expiring" -eq 0 ]]; then
        log_success "期限切れ・期限間近のパスワードなし"
    fi
    echo ""
}

cmd_strength() {
    local password="${1:-}"
    [[ -z "$password" ]] && error_exit "パスワードを指定してください"

    log_info "パスワード強度評価"
    echo ""

    python3 - "$password" <<'PYEOF'
import sys, re, math

password = sys.argv[1]

GREEN  = "\033[1;32m"
RED    = "\033[1;31m"
YELLOW = "\033[1;33m"
CYAN   = "\033[1;36m"
RESET  = "\033[0m"

score = 0
feedback = []

# 長さ
length = len(password)
if length >= 16:   score += 3; feedback.append(("OK", f"長さ: {length}文字 (優良)"))
elif length >= 12: score += 2; feedback.append(("OK", f"長さ: {length}文字 (良好)"))
elif length >= 8:  score += 1; feedback.append(("WARN", f"長さ: {length}文字 (推奨: 12文字以上)"))
else:              feedback.append(("FAIL", f"長さ: {length}文字 (短すぎる)"))

# 文字種
if re.search(r'[a-z]', password): score += 1
else: feedback.append(("FAIL", "小文字なし"))
if re.search(r'[A-Z]', password): score += 1
else: feedback.append(("FAIL", "大文字なし"))
if re.search(r'[0-9]', password): score += 1
else: feedback.append(("FAIL", "数字なし"))
if re.search(r'[!@#$%^&*()_+\-=\[\]{};:\'"\\|,.<>\/?]', password): score += 2
else: feedback.append(("WARN", "記号なし"))

# 連続文字
if re.search(r'(.)\1{2,}', password): feedback.append(("WARN", "同じ文字の連続あり"))
if re.search(r'(012|123|234|345|456|567|678|789|abc|bcd|cde)', password.lower()):
    feedback.append(("WARN", "連続した文字列あり"))

# よくあるパスワード
common = ['password', 'pass123', 'admin', '12345678', 'qwerty']
if password.lower() in common:
    score = 0
    feedback.append(("FAIL", "よく使われるパスワードです"))

# エントロピー
charset = 0
if re.search(r'[a-z]', password): charset += 26
if re.search(r'[A-Z]', password): charset += 26
if re.search(r'[0-9]', password): charset += 10
if re.search(r'[^a-zA-Z0-9]', password): charset += 32
if charset > 0:
    entropy = length * math.log2(charset)
    feedback.append(("INFO", f"推定エントロピー: {entropy:.1f} bits"))

# スコア表示
max_score = 8
pct = score / max_score * 100
if score >= 7:    level, color = "非常に強い", GREEN
elif score >= 5:  level, color = "強い",     GREEN
elif score >= 3:  level, color = "普通",     YELLOW
else:             level, color = "弱い",     RED

bar = "█" * score + "░" * (max_score - score)
print(f"  強度: {color}{level}{RESET}  [{color}{bar}{RESET}]  {score}/{max_score}")
print()
for status, msg in feedback:
    if status == "OK":   print(f"  {GREEN}✓{RESET} {msg}")
    elif status == "WARN": print(f"  {YELLOW}△{RESET} {msg}")
    elif status == "FAIL": print(f"  {RED}✗{RESET} {msg}")
    else: print(f"  → {msg}")
PYEOF
    echo ""
}

cmd_recommend() {
    log_info "パスワードポリシー推奨設定"
    echo ""

    cat <<'RECOMMEND'
  【/etc/login.defs 推奨設定】

  PASS_MAX_DAYS   90      # 90日で期限切れ
  PASS_MIN_DAYS   1       # 1日は変更不可
  PASS_MIN_LEN    12      # 最小12文字
  PASS_WARN_AGE   14      # 14日前に警告

  【PAM pwquality 推奨設定 (/etc/security/pwquality.conf)】

  minlen = 12             # 最小12文字
  minclass = 3            # 最低3種の文字クラス
  maxrepeat = 2           # 同一文字の連続は2まで
  maxsequence = 3         # 連続文字は3まで
  difok = 5               # 旧パスワードと5文字異なること
  gecoscheck = 1          # ユーザー名を含まない
  dictcheck = 1           # 辞書チェック有効
  usercheck = 1           # ユーザー名チェック
  badwords = password passwort senha

  【PAM remember 推奨設定 (/etc/pam.d/common-password)】

  password required pam_pwhistory.so remember=12  # 過去12回を記憶

RECOMMEND

    log_success "設定適用後: authconfig --updateall または pam-auth-update"
    echo ""
}

parse_arguments() {
    [[ $# -eq 0 ]] && return 0
    case "$1" in
        audit|users|pam|expiry|strength|recommend)
            command_name="$1"; shift ;;
    esac
    local positional=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  positional+=("$1"); shift ;;
        esac
    done
    POSITIONAL=("${positional[@]+"${positional[@]}"}")
}

declare -a POSITIONAL=()

main() {
    parse_arguments "$@"
    case "$command_name" in
        audit)     cmd_audit ;;
        users)     cmd_users ;;
        pam)       cmd_pam ;;
        expiry)    cmd_expiry ;;
        strength)  cmd_strength  "${POSITIONAL[0]:-}" ;;
        recommend) cmd_recommend ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
