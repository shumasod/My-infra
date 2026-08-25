#!/bin/bash
set -euo pipefail

#
# AWSコストレポートツール
# 作成日: 2026-08-25
# バージョン: 1.0
#
# AWS Cost Explorerを使用してコストを分析・レポートします
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare command_name="summary"
declare aws_profile="${AWS_PROFILE:-default}"
declare aws_region="${AWS_DEFAULT_REGION:-ap-northeast-1}"
declare days=30
declare output_format="text"
declare granularity="MONTHLY"

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション]

AWSコスト分析・レポートツールです。

コマンド:
  summary              月別コストサマリー (デフォルト)
  service              サービス別コスト内訳
  daily                日別コスト推移
  forecast             コスト予測
  budget               予算アラート確認
  tag <タグキー>       タグ別コスト分析
  idle                 アイドルリソース検出

オプション:
  -h, --help           このヘルプを表示
  -v, --version        バージョン情報を表示
  --profile <名前>     AWSプロファイル [デフォルト: default]
  --region <リージョン> AWSリージョン [デフォルト: ap-northeast-1]
  -d, --days <日数>    分析期間(日) [デフォルト: 30]
  -f, --format <形式>  出力形式 (text|json|csv) [デフォルト: text]

例:
  $PROG_NAME summary
  $PROG_NAME service --days 90
  $PROG_NAME daily --days 14
  $PROG_NAME forecast
  $PROG_NAME tag Environment
  $PROG_NAME idle --region us-east-1
EOF
}

aws_cmd() {
    aws --profile "$aws_profile" --region "$aws_region" "$@"
}

get_date_range() {
    local d="${1:-$days}"
    local end_date
    end_date=$(date +%Y-%m-01)
    local start_date
    start_date=$(date -d "$end_date -${d} days" +%Y-%m-01 2>/dev/null || \
                 date -v "-${d}d" +%Y-%m-01 2>/dev/null || echo "")
    echo "$start_date $end_date"
}

format_usd() {
    local amount="$1"
    printf "$%.2f" "$amount" 2>/dev/null || echo "\$$amount"
}

cmd_summary() {
    log_info "AWSコストサマリー (過去${days}日間)"
    echo ""

    local date_range
    read -r start_date end_date <<< "$(get_date_range)"

    local result
    result=$(aws_cmd ce get-cost-and-usage \
        --time-period "Start=${start_date},End=${end_date}" \
        --granularity MONTHLY \
        --metrics "BlendedCost" \
        --output json 2>/dev/null) || {
        log_error "コスト情報を取得できませんでした"
        return 1
    }

    printf "${C_BOLD}【月別コスト (${start_date} 〜 ${end_date})】${C_RESET}\n\n"
    printf "${C_BOLD}  %-12s %15s${C_RESET}\n" "期間" "コスト (USD)"
    printf "  %s\n" "$(printf '%.0s─' {1..30})"

    echo "$result" | python3 - <<'PYEOF'
import sys, json
data = json.load(sys.stdin)
total = 0.0
for period in data.get("ResultsByTime", []):
    start = period["TimePeriod"]["Start"][:7]
    amount = float(period["Total"]["BlendedCost"]["Amount"])
    total += amount
    color = "\033[1;32m" if amount < 100 else "\033[1;33m" if amount < 500 else "\033[1;31m"
    reset = "\033[0m"
    print(f"  {color}{start:<12}{reset} {color}${amount:>14.2f}{reset}")
print(f"  {'─'*30}")
print(f"  {'合計':<12} ${total:>14.2f}")
PYEOF
    echo ""
}

cmd_service() {
    log_info "サービス別コスト内訳"
    echo ""

    local date_range
    read -r start_date end_date <<< "$(get_date_range)"

    local result
    result=$(aws_cmd ce get-cost-and-usage \
        --time-period "Start=${start_date},End=${end_date}" \
        --granularity MONTHLY \
        --metrics "BlendedCost" \
        --group-by "Type=DIMENSION,Key=SERVICE" \
        --output json 2>/dev/null) || {
        log_error "サービス別コスト情報を取得できませんでした"
        return 1
    }

    printf "${C_BOLD}【サービス別コスト (${start_date} 〜 ${end_date})】${C_RESET}\n\n"
    printf "${C_BOLD}  %-40s %15s %8s${C_RESET}\n" "サービス" "コスト (USD)" "割合"
    printf "  %s\n" "$(printf '%.0s─' {1..65})"

    echo "$result" | python3 - <<'PYEOF'
import sys, json
data = json.load(sys.stdin)
services = {}
for period in data.get("ResultsByTime", []):
    for group in period.get("Groups", []):
        svc = group["Keys"][0]
        amount = float(group["Metrics"]["BlendedCost"]["Amount"])
        services[svc] = services.get(svc, 0) + amount

total = sum(services.values())
sorted_svcs = sorted(services.items(), key=lambda x: -x[1])

CYAN   = "\033[1;36m"
GREEN  = "\033[1;32m"
YELLOW = "\033[1;33m"
RED    = "\033[1;31m"
DIM    = "\033[2m"
RESET  = "\033[0m"

for svc, amount in sorted_svcs:
    if amount < 0.01: continue
    pct = amount * 100 / total if total > 0 else 0
    color = GREEN if amount < 10 else YELLOW if amount < 100 else RED
    bar_len = int(pct / 4)
    bar = "█" * bar_len
    print(f"  {CYAN}{svc[:38]:<40}{RESET} {color}${amount:>14.2f}{RESET}  {color}{pct:>5.1f}%{RESET}  {DIM}{bar}{RESET}")

print(f"  {'─'*65}")
print(f"  {'合計':<40} ${total:>14.2f}")
PYEOF
    echo ""
}

cmd_daily() {
    log_info "日別コスト推移 (過去${days}日間)"
    echo ""

    local end_date
    end_date=$(date +%Y-%m-%d)
    local start_date
    start_date=$(date -d "-${days} days" +%Y-%m-%d 2>/dev/null || echo "")

    local result
    result=$(aws_cmd ce get-cost-and-usage \
        --time-period "Start=${start_date},End=${end_date}" \
        --granularity DAILY \
        --metrics "BlendedCost" \
        --output json 2>/dev/null) || {
        log_error "日別コスト情報を取得できませんでした"
        return 1
    }

    printf "${C_BOLD}【日別コスト (${start_date} 〜 ${end_date})】${C_RESET}\n\n"

    echo "$result" | python3 - <<'PYEOF'
import sys, json
data = json.load(sys.stdin)
periods = []
for period in data.get("ResultsByTime", []):
    date = period["TimePeriod"]["Start"]
    amount = float(period["Total"]["BlendedCost"]["Amount"])
    periods.append((date, amount))

if not periods:
    print("  データがありません")
    sys.exit(0)

max_amount = max(a for _, a in periods) if periods else 1
if max_amount == 0: max_amount = 1

GREEN  = "\033[1;32m"
YELLOW = "\033[1;33m"
RED    = "\033[1;31m"
RESET  = "\033[0m"

for date, amount in periods:
    bar_len = int(amount * 40 / max_amount)
    color = GREEN if amount < 10 else YELLOW if amount < 50 else RED
    bar = "█" * bar_len
    print(f"  {date}  {color}${amount:>8.2f}{RESET}  {color}{bar}{RESET}")

total = sum(a for _, a in periods)
avg = total / len(periods) if periods else 0
print(f"\n  合計: ${total:.2f}  平均: ${avg:.2f}/日")
PYEOF
    echo ""
}

cmd_forecast() {
    log_info "コスト予測"
    echo ""

    local start_date end_date
    start_date=$(date +%Y-%m-%d)
    end_date=$(date -d "+90 days" +%Y-%m-%d 2>/dev/null || date +%Y-%m-%d)

    local result
    result=$(aws_cmd ce get-cost-forecast \
        --time-period "Start=${start_date},End=${end_date}" \
        --granularity MONTHLY \
        --metric BLENDED_COST \
        --output json 2>/dev/null) || {
        log_error "コスト予測を取得できませんでした (Cost Explorerが有効か確認してください)"
        return 1
    }

    printf "${C_BOLD}【コスト予測 (${start_date} 〜 ${end_date})】${C_RESET}\n\n"

    echo "$result" | python3 - <<'PYEOF'
import sys, json
data = json.load(sys.stdin)
total = data.get("Total", {})
mean = float(total.get("Amount", 0))
print(f"  予測合計 (90日): ${mean:.2f}")
print()
for period in data.get("ForecastResultsByTime", []):
    start = period["TimePeriod"]["Start"][:7]
    mean_p = float(period["MeanValue"])
    low  = float(period.get("PredictionIntervalLowerBound", mean_p * 0.9))
    high = float(period.get("PredictionIntervalUpperBound", mean_p * 1.1))
    print(f"  {start}  ${mean_p:.2f}  (${low:.2f} 〜 ${high:.2f})")
PYEOF
    echo ""
}

cmd_budget() {
    log_info "予算アラート確認"
    echo ""

    local account_id
    account_id=$(aws_cmd sts get-caller-identity --query Account --output text 2>/dev/null || echo "")

    if [[ -z "$account_id" ]]; then
        log_error "AWSアカウントIDを取得できませんでした"
        return 1
    fi

    local result
    result=$(aws_cmd budgets describe-budgets \
        --account-id "$account_id" \
        --output json 2>/dev/null) || {
        log_error "予算情報を取得できませんでした"
        return 1
    }

    echo "$result" | python3 - <<'PYEOF'
import sys, json
data = json.load(sys.stdin)
budgets = data.get("Budgets", [])
if not budgets:
    print("  予算が設定されていません")
    sys.exit(0)

GREEN  = "\033[1;32m"
YELLOW = "\033[1;33m"
RED    = "\033[1;31m"
RESET  = "\033[0m"
BOLD   = "\033[1m"

print(f"  {BOLD}{'予算名':<30} {'上限':>12} {'実績':>12} {'予測':>12} 状態{RESET}")
print(f"  {'─'*70}")

for b in budgets:
    name = b["BudgetName"][:28]
    limit = float(b["BudgetLimit"]["Amount"])
    actual = float(b.get("CalculatedSpend", {}).get("ActualSpend", {}).get("Amount", 0))
    forecast = float(b.get("CalculatedSpend", {}).get("ForecastedSpend", {}).get("Amount", 0))
    pct = actual * 100 / limit if limit > 0 else 0
    color = GREEN if pct < 70 else YELLOW if pct < 90 else RED
    print(f"  {name:<30} {color}${limit:>11.2f} ${actual:>11.2f} ${forecast:>11.2f}{RESET}  {color}{pct:.1f}%{RESET}")
PYEOF
    echo ""
}

cmd_tag() {
    local tag_key="${1:-Environment}"
    log_info "タグ別コスト分析 (タグキー: $tag_key)"
    echo ""

    local date_range
    read -r start_date end_date <<< "$(get_date_range)"

    local result
    result=$(aws_cmd ce get-cost-and-usage \
        --time-period "Start=${start_date},End=${end_date}" \
        --granularity MONTHLY \
        --metrics "BlendedCost" \
        --group-by "Type=TAG,Key=${tag_key}" \
        --output json 2>/dev/null) || {
        log_error "タグ別コスト情報を取得できませんでした"
        return 1
    }

    printf "${C_BOLD}【タグ別コスト: ${tag_key} (${start_date} 〜 ${end_date})】${C_RESET}\n\n"
    printf "${C_BOLD}  %-25s %15s${C_RESET}\n" "タグ値" "コスト (USD)"
    printf "  %s\n" "$(printf '%.0s─' {1..42})"

    echo "$result" | python3 - "$tag_key" <<'PYEOF'
import sys, json
tag_key = sys.argv[1]
data = json.load(sys.stdin)
tags = {}
for period in data.get("ResultsByTime", []):
    for group in period.get("Groups", []):
        tag_val = group["Keys"][0].replace(f"{tag_key}$", "")
        if not tag_val: tag_val = "(タグなし)"
        amount = float(group["Metrics"]["BlendedCost"]["Amount"])
        tags[tag_val] = tags.get(tag_val, 0) + amount

CYAN  = "\033[1;36m"
GREEN = "\033[1;32m"
RESET = "\033[0m"
for tag, amount in sorted(tags.items(), key=lambda x: -x[1]):
    if amount < 0.01: continue
    print(f"  {CYAN}{tag[:23]:<25}{RESET} {GREEN}${amount:>14.2f}{RESET}")
PYEOF
    echo ""
}

cmd_idle() {
    log_info "アイドルリソース検出"
    echo ""

    printf "${C_BOLD}【停止中のEC2インスタンス】${C_RESET}\n\n"
    aws_cmd ec2 describe-instances \
        --filters "Name=instance-state-name,Values=stopped" \
        --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,Tags[?Key==`Name`].Value|[0],LaunchTime]' \
        --output text 2>/dev/null | \
    while IFS=$'\t' read -r id type name launched; do
        printf "  ${C_YELLOW}%-20s${C_RESET} %-12s %-25s %s\n" \
            "$id" "$type" "${name:-N/A}" "${launched:0:10}"
    done || log_warning "EC2情報を取得できませんでした"

    echo ""
    printf "${C_BOLD}【未使用EIP (Elastic IP)】${C_RESET}\n\n"
    aws_cmd ec2 describe-addresses \
        --query 'Addresses[?AssociationId==null].[PublicIp,AllocationId]' \
        --output text 2>/dev/null | \
    while IFS=$'\t' read -r ip alloc; do
        printf "  ${C_RED}%-20s${C_RESET} %s\n" "$ip" "$alloc"
    done || log_warning "EIP情報を取得できませんでした"

    echo ""
    printf "${C_BOLD}【未接続EBSボリューム】${C_RESET}\n\n"
    aws_cmd ec2 describe-volumes \
        --filters "Name=status,Values=available" \
        --query 'Volumes[*].[VolumeId,Size,VolumeType,CreateTime]' \
        --output text 2>/dev/null | \
    while IFS=$'\t' read -r vid size vtype created; do
        printf "  ${C_YELLOW}%-25s${C_RESET} %5s GB  %-10s %s\n" \
            "$vid" "$size" "$vtype" "${created:0:10}"
    done || log_warning "EBSボリューム情報を取得できませんでした"
    echo ""
}

parse_arguments() {
    [[ $# -eq 0 ]] && return 0
    case "$1" in
        summary|service|daily|forecast|budget|tag|idle)
            command_name="$1"; shift ;;
    esac

    local positional=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            --profile)    [[ $# -lt 2 ]] && error_exit "--profile には値が必要です"; aws_profile="$2"; shift 2 ;;
            --region)     [[ $# -lt 2 ]] && error_exit "--region には値が必要です"; aws_region="$2"; shift 2 ;;
            -d|--days)    [[ $# -lt 2 ]] && error_exit "--days には値が必要です"; days="$2"; shift 2 ;;
            -f|--format)  [[ $# -lt 2 ]] && error_exit "--format には値が必要です"; output_format="$2"; shift 2 ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  positional+=("$1"); shift ;;
        esac
    done
    POSITIONAL=("${positional[@]+"${positional[@]}"}")
}

declare -a POSITIONAL=()

main() {
    parse_arguments "$@"

    if ! command -v aws &>/dev/null; then
        error_exit "AWS CLI が見つかりません"
    fi

    case "$command_name" in
        summary)  cmd_summary ;;
        service)  cmd_service ;;
        daily)    cmd_daily ;;
        forecast) cmd_forecast ;;
        budget)   cmd_budget ;;
        tag)      cmd_tag "${POSITIONAL[0]:-Environment}" ;;
        idle)     cmd_idle ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
