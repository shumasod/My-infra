#!/bin/bash
set -euo pipefail

#
# AWS IAM管理ヘルパー
# 作成日: 2026-07-31
# バージョン: 1.0
#
# AWS IAMユーザー・ロール・ポリシーの管理を簡単に行います
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"
readonly REGION="${AWS_REGION:-ap-northeast-1}"

declare command_name="summary"
declare target_name=""
declare output_format="table"

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME <コマンド> [オプション]

AWS IAM管理ツールです。

コマンド:
  summary                アカウントのIAMサマリー
  users                  ユーザー一覧
  roles                  ロール一覧
  policies               カスタムポリシー一覧
  user-detail <ユーザー名> ユーザーの詳細情報
  role-detail <ロール名>  ロールの詳細情報
  mfa-status             MFA未設定ユーザー一覧
  unused                 長期間未使用のアクセスキー検出
  audit                  セキュリティ監査レポート

オプション:
  -h, --help             このヘルプを表示
  -v, --version          バージョン情報を表示
  --format <形式>        出力形式 (table|json) [デフォルト: table]

例:
  $PROG_NAME summary
  $PROG_NAME users
  $PROG_NAME mfa-status
  $PROG_NAME audit
  $PROG_NAME user-detail admin
EOF
}

check_aws() {
    command -v aws &>/dev/null || error_exit "AWS CLI がインストールされていません"
    aws sts get-caller-identity &>/dev/null || error_exit "AWS認証情報が設定されていません"
}

cmd_summary() {
    log_info "IAMサマリーを取得中..."
    echo ""

    local summary
    summary=$(aws iam get-account-summary --query 'SummaryMap' --output json 2>/dev/null)

    echo "$summary" | python3 -c "
import json, sys
data = json.load(sys.stdin)
items = [
    ('ユーザー数',            'Users'),
    ('グループ数',            'Groups'),
    ('ロール数',              'Roles'),
    ('カスタムポリシー数',    'Policies'),
    ('MFA有効デバイス数',     'MFADevices'),
    ('アクセスキー総数',      'AccessKeysPresent'),
    ('アカウントMFA',         'AccountMFAEnabled'),
    ('パスワードポリシー',    'AccountPasswordPolicyExists'),
]
for label, key in items:
    val = data.get(key, 'N/A')
    color = '\033[1;32m' if str(val) not in ('0', 'False', '0') else '\033[1;31m'
    if key in ('AccountMFAEnabled', 'AccountPasswordPolicyExists'):
        color = '\033[1;32m' if val == 1 else '\033[1;31m'
    print(f'  {label:<25}: {color}{val}\033[0m')
" 2>/dev/null
    echo ""
}

cmd_users() {
    log_info "IAMユーザー一覧を取得中..."
    echo ""

    local users
    users=$(aws iam list-users \
        --query 'Users[*].[UserName,CreateDate,PasswordLastUsed]' \
        --output json 2>/dev/null)

    printf "${C_BOLD}%-25s %-15s %-15s %s${C_RESET}\n" "ユーザー名" "作成日" "最終ログイン" "状態"
    printf "%s\n" "$(printf '%.0s─' {1..70})"

    echo "$users" | python3 -c "
import json, sys
from datetime import datetime, timezone
data = json.load(sys.stdin)
now = datetime.now(timezone.utc)
for user in sorted(data, key=lambda x: x[0]):
    name, created, last_used = user[0], user[1][:10], user[2][:10] if user[2] else 'N/A'
    print(f'  {name:<23} {created:<15} {last_used}')
" 2>/dev/null

    local count
    count=$(echo "$users" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null)
    echo ""
    printf "  合計: ${C_GREEN}%s${C_RESET} ユーザー\n\n" "$count"
}

cmd_roles() {
    log_info "IAMロール一覧を取得中..."
    echo ""

    local roles
    roles=$(aws iam list-roles \
        --query 'Roles[*].[RoleName,CreateDate,Description]' \
        --output json 2>/dev/null)

    printf "${C_BOLD}%-35s %-12s %s${C_RESET}\n" "ロール名" "作成日" "説明"
    printf "%s\n" "$(printf '%.0s─' {1..75})"

    echo "$roles" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for role in sorted(data, key=lambda x: x[0]):
    name, created = role[0], role[1][:10]
    desc = (role[2] or '')[:35] if len(role) > 2 else ''
    print(f'  {name:<33} {created:<12} {desc}')
" 2>/dev/null

    local count
    count=$(echo "$roles" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null)
    echo ""
    printf "  合計: ${C_GREEN}%s${C_RESET} ロール\n\n" "$count"
}

cmd_mfa_status() {
    log_info "MFA設定状況を確認中..."
    echo ""

    local users
    users=$(aws iam list-users --query 'Users[*].UserName' --output json 2>/dev/null)

    printf "${C_BOLD}%-30s %s${C_RESET}\n" "ユーザー名" "MFA状態"
    printf "%s\n" "$(printf '%.0s─' {1..50})"

    local no_mfa_count=0
    echo "$users" | python3 -c "import json,sys; [print(u) for u in json.load(sys.stdin)]" 2>/dev/null | \
    while IFS= read -r user; do
        local mfa_count
        mfa_count=$(aws iam list-mfa-devices --user-name "$user" \
            --query 'length(MFADevices)' --output text 2>/dev/null || echo 0)
        if [[ "${mfa_count:-0}" -gt 0 ]]; then
            printf "  ${C_GREEN}%-28s${C_RESET} ${C_GREEN}✓ 有効 (%d台)${C_RESET}\n" "$user" "$mfa_count"
        else
            printf "  ${C_RED}%-28s${C_RESET} ${C_RED}✗ 未設定${C_RESET}\n" "$user"
        fi
    done
    echo ""
}

cmd_unused() {
    log_info "未使用アクセスキーを検出中..."
    echo ""

    local users
    users=$(aws iam list-users --query 'Users[*].UserName' --output json 2>/dev/null)

    printf "${C_BOLD}%-25s %-20s %-12s %s${C_RESET}\n" "ユーザー" "アクセスキーID" "最終使用" "状態"
    printf "%s\n" "$(printf '%.0s─' {1..75})"

    local days_threshold=90

    echo "$users" | python3 -c "import json,sys; [print(u) for u in json.load(sys.stdin)]" 2>/dev/null | \
    while IFS= read -r user; do
        local keys
        keys=$(aws iam list-access-keys --user-name "$user" \
            --query 'AccessKeyMetadata[*].[AccessKeyId,Status,CreateDate]' \
            --output json 2>/dev/null)

        echo "$keys" | python3 - "$user" "$days_threshold" <<'PYEOF'
import json, sys
from datetime import datetime, timezone
data = json.load(sys.stdin)
user = sys.argv[1]
threshold = int(sys.argv[2])
now = datetime.now(timezone.utc)
for key in data:
    key_id, status, created = key
    try:
        last_used = __import__('subprocess').run(
            ['aws', 'iam', 'get-access-key-last-used', '--access-key-id', key_id,
             '--query', 'AccessKeyLastUsed.LastUsedDate', '--output', 'text'],
            capture_output=True, text=True
        ).stdout.strip()
    except:
        last_used = 'N/A'
    days = 'N/A'
    color_st = '\033[2m' if status == 'Inactive' else ''
    if last_used and last_used != 'None' and last_used != 'N/A':
        try:
            lu_dt = datetime.fromisoformat(last_used.replace('Z','+00:00'))
            days = (now - lu_dt).days
            color_st = '\033[1;31m' if days > threshold else '\033[1;32m'
        except:
            pass
    print(f'  {color_st}{user:<23} {key_id:<20} {str(days)+"日前":<12} {status}\033[0m')
PYEOF
    done
    echo ""
}

cmd_user_detail() {
    [[ -z "$target_name" ]] && error_exit "ユーザー名を指定してください"

    log_info "ユーザー詳細: $target_name"
    echo ""

    # 基本情報
    local user_info
    user_info=$(aws iam get-user --user-name "$target_name" \
        --query 'User' --output json 2>/dev/null) || error_exit "ユーザーが見つかりません: $target_name"

    echo "$user_info" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(f'  ユーザー名  : {d[\"UserName\"]}')
print(f'  ARN         : {d[\"Arn\"]}')
print(f'  作成日      : {d[\"CreateDate\"][:10]}')
print(f'  UserID      : {d[\"UserId\"]}')
" 2>/dev/null

    # グループ
    echo ""
    printf "${C_BOLD}【所属グループ】${C_RESET}\n"
    aws iam list-groups-for-user --user-name "$target_name" \
        --query 'Groups[*].GroupName' --output text 2>/dev/null | \
        tr '\t' '\n' | while IFS= read -r g; do printf "  - %s\n" "$g"; done

    # アタッチされたポリシー
    echo ""
    printf "${C_BOLD}【アタッチされたポリシー】${C_RESET}\n"
    aws iam list-attached-user-policies --user-name "$target_name" \
        --query 'AttachedPolicies[*].PolicyName' --output text 2>/dev/null | \
        tr '\t' '\n' | while IFS= read -r p; do printf "  - ${C_CYAN}%s${C_RESET}\n" "$p"; done

    echo ""
}

cmd_audit() {
    log_info "IAMセキュリティ監査を実行中..."
    echo ""

    printf "${C_BOLD}【IAMセキュリティ監査レポート】${C_RESET}\n"
    printf "${C_DIM}実行日時: $(get_timestamp)${C_RESET}\n\n"

    # パスワードポリシー確認
    printf "${C_BOLD}1. パスワードポリシー${C_RESET}\n"
    local pass_policy
    pass_policy=$(aws iam get-account-password-policy --output json 2>/dev/null) || pass_policy="{}"
    echo "$pass_policy" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin).get('PasswordPolicy', {})
    checks = [
        ('最小文字数', 'MinimumPasswordLength', 14, '>='),
        ('大文字必須', 'RequireUppercaseCharacters', True, '=='),
        ('小文字必須', 'RequireLowercaseCharacters', True, '=='),
        ('数字必須',   'RequireNumbers', True, '=='),
        ('記号必須',   'RequireSymbols', True, '=='),
        ('パスワード再利用防止', 'PasswordReusePrevention', 5, '>='),
    ]
    for label, key, expected, op in checks:
        val = d.get(key)
        ok = (val >= expected if op == '>=' else val == expected) if val is not None else False
        icon = '✓' if ok else '✗'
        color = '\033[1;32m' if ok else '\033[1;31m'
        print(f'  {color}{icon} {label}: {val}\033[0m')
except Exception as e:
    print(f'  \033[1;31m✗ パスワードポリシーが設定されていません\033[0m')
" 2>/dev/null

    echo ""
    printf "${C_BOLD}2. rootアカウント${C_RESET}\n"
    local summary
    summary=$(aws iam get-account-summary --query 'SummaryMap' --output json 2>/dev/null)
    echo "$summary" | python3 -c "
import json, sys
d = json.load(sys.stdin)
mfa = d.get('AccountMFAEnabled', 0)
keys = d.get('AccountAccessKeysPresent', 0)
print(f'  {chr(10004) if mfa else chr(10008)} rootアカウントMFA: {\"有効\" if mfa else \"未設定\"}')
print(f'  {chr(10004) if not keys else chr(10008)} rootアクセスキー: {\"なし\" if not keys else \"存在 (削除推奨)\"}')
" 2>/dev/null

    echo ""
    printf "${C_BOLD}3. MFA未設定ユーザー${C_RESET}\n"
    local users
    users=$(aws iam list-users --query 'Users[*].UserName' --output json 2>/dev/null)
    local no_mfa=0
    while IFS= read -r user; do
        local mfa_count
        mfa_count=$(aws iam list-mfa-devices --user-name "$user" \
            --query 'length(MFADevices)' --output text 2>/dev/null || echo 0)
        [[ "${mfa_count:-0}" -eq 0 ]] && {
            printf "  ${C_RED}✗ %s${C_RESET}\n" "$user"
            (( no_mfa++ )) || true
        }
    done < <(echo "$users" | python3 -c "import json,sys; [print(u) for u in json.load(sys.stdin)]" 2>/dev/null)
    [[ $no_mfa -eq 0 ]] && printf "  ${C_GREEN}✓ 全ユーザーMFA設定済み${C_RESET}\n"

    echo ""
    log_success "監査完了"
}

parse_arguments() {
    [[ $# -eq 0 ]] && return 0
    case "$1" in
        summary|users|roles|policies|user-detail|role-detail|mfa-status|unused|audit)
            command_name="$1"; shift ;;
    esac

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            --format)     [[ $# -lt 2 ]] && error_exit "--format には値が必要です"; output_format="$2"; shift 2 ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  target_name="$1"; shift ;;
        esac
    done
}

main() {
    parse_arguments "$@"
    check_aws
    case "$command_name" in
        summary)     cmd_summary ;;
        users)       cmd_users ;;
        roles)       cmd_roles ;;
        mfa-status)  cmd_mfa_status ;;
        unused)      cmd_unused ;;
        user-detail) cmd_user_detail ;;
        audit)       cmd_audit ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
