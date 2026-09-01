#!/bin/bash
set -euo pipefail

#
# EC2インスタンス スケジューラー
# 作成日: 2026-09-01
# バージョン: 1.0
#
# EC2インスタンスの起動・停止をスケジュール管理します
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare command_name="list"
declare aws_profile="${AWS_PROFILE:-default}"
declare aws_region="${AWS_DEFAULT_REGION:-ap-northeast-1}"
declare tag_key="Schedule"
declare dry_run=0
declare output_format="text"

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション]

EC2インスタンスのスケジュール管理ツールです。

コマンド:
  list                 インスタンス一覧と状態表示 (デフォルト)
  start <ID...>        インスタンスを起動
  stop <ID...>         インスタンスを停止
  schedule             スケジュールタグに基づいて自動制御
  status <ID>          インスタンス詳細状態
  costs                インスタンス別コスト推計
  stale                長期停止インスタンスを検出

オプション:
  -h, --help           このヘルプを表示
  -v, --version        バージョン情報を表示
  --profile <名前>     AWSプロファイル
  --region <リージョン> AWSリージョン [デフォルト: ap-northeast-1]
  --tag <キー>         スケジュールタグキー [デフォルト: Schedule]
  -n, --dry-run        実行せず確認のみ
  -f, --format <形式>  出力形式 (text|json) [デフォルト: text]

スケジュールタグの書式:
  start=08:00;stop=20:00        平日8:00起動、20:00停止
  start=09:00;stop=18:00;tz=JST タイムゾーン指定
  always-on                     常時起動
  always-off                    常時停止

例:
  $PROG_NAME list
  $PROG_NAME start i-1234567890abcdef0
  $PROG_NAME stop i-1234567890abcdef0 i-0987654321fedcba0
  $PROG_NAME schedule --dry-run
  $PROG_NAME stale
EOF
}

aws_cmd() {
    aws --profile "$aws_profile" --region "$aws_region" "$@"
}

get_instance_name() {
    local id="$1"
    local tags="$2"
    echo "$tags" | python3 - <<PYEOF
import sys, json
tags = json.loads(sys.stdin.read().strip() or "[]")
for t in tags:
    if t.get("Key") == "Name":
        print(t.get("Value", ""))
        sys.exit(0)
print("")
PYEOF
}

cmd_list() {
    log_info "EC2インスタンス一覧"
    echo ""

    local result
    result=$(aws_cmd ec2 describe-instances \
        --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,State.Name,LaunchTime,Tags,Placement.AvailabilityZone]' \
        --output json 2>/dev/null) || {
        log_error "EC2インスタンス情報を取得できませんでした"
        return 1
    }

    printf "${C_BOLD}  %-22s %-15s %-12s %-12s %-15s %s${C_RESET}\n" \
        "インスタンスID" "タイプ" "状態" "起動時刻" "AZ" "名前"
    printf "  %s\n" "$(printf '%.0s─' {1..90})"

    echo "$result" | python3 - "$tag_key" <<'PYEOF'
import sys, json
from datetime import datetime
tag_key = sys.argv[1]
data = json.load(sys.stdin)

GREEN  = "\033[1;32m"
YELLOW = "\033[1;33m"
RED    = "\033[1;31m"
DIM    = "\033[2m"
CYAN   = "\033[1;36m"
RESET  = "\033[0m"

for reservation in data:
    for inst in reservation:
        if len(inst) < 6: continue
        iid, itype, state, launch, tags, az = inst
        name = ""
        schedule = ""
        for t in (tags or []):
            if t["Key"] == "Name":     name = t["Value"]
            if t["Key"] == tag_key:    schedule = t["Value"]

        launch_str = launch[:10] if launch else "N/A"

        color = GREEN if state == "running" else YELLOW if state == "stopped" else RED

        sched_str = f" [{schedule}]" if schedule else ""
        print(f"  {CYAN}{iid:<22}{RESET} {itype:<15} {color}{state:<12}{RESET} {launch_str:<12} {az:<15} {name[:20]}{DIM}{sched_str}{RESET}")
PYEOF
    echo ""
}

cmd_start() {
    local ids=("$@")
    [[ ${#ids[@]} -eq 0 ]] && error_exit "インスタンスIDを指定してください"

    log_info "インスタンス起動: ${ids[*]}"
    (( dry_run )) && { log_warning "[DRY-RUN] 実際には起動しません"; return; }

    aws_cmd ec2 start-instances --instance-ids "${ids[@]}" \
        --query 'StartingInstances[*].[InstanceId,CurrentState.Name]' \
        --output text 2>/dev/null | while IFS=$'\t' read -r id state; do
        printf "  ${C_GREEN}%s${C_RESET} -> %s\n" "$id" "$state"
    done || log_error "起動失敗"

    log_success "起動リクエスト送信完了"
}

cmd_stop() {
    local ids=("$@")
    [[ ${#ids[@]} -eq 0 ]] && error_exit "インスタンスIDを指定してください"

    log_info "インスタンス停止: ${ids[*]}"
    (( dry_run )) && { log_warning "[DRY-RUN] 実際には停止しません"; return; }

    if ! confirm "インスタンスを停止しますか？" "n"; then
        log_warning "キャンセルしました"
        return
    fi

    aws_cmd ec2 stop-instances --instance-ids "${ids[@]}" \
        --query 'StoppingInstances[*].[InstanceId,CurrentState.Name]' \
        --output text 2>/dev/null | while IFS=$'\t' read -r id state; do
        printf "  ${C_YELLOW}%s${C_RESET} -> %s\n" "$id" "$state"
    done || log_error "停止失敗"

    log_success "停止リクエスト送信完了"
}

cmd_schedule() {
    log_info "スケジュールタグに基づいて自動制御"
    (( dry_run )) && log_warning "DRY-RUNモード: 実際には変更しません"
    echo ""

    local current_hour
    current_hour=$(date +%H)
    local current_min
    current_min=$(date +%M)
    local current_time="${current_hour}:${current_min}"

    local result
    result=$(aws_cmd ec2 describe-instances \
        --filters "Name=tag-key,Values=${tag_key}" \
        --query 'Reservations[*].Instances[*].[InstanceId,State.Name,Tags]' \
        --output json 2>/dev/null) || {
        log_error "インスタンス情報を取得できませんでした"
        return 1
    }

    echo "$result" | python3 - "$tag_key" "$current_time" "$dry_run" <<'PYEOF'
import sys, json, re
tag_key = sys.argv[1]
current_time = sys.argv[2]
dry_run = sys.argv[3] == "1"

data = json.load(sys.stdin)
ch, cm = map(int, current_time.split(":"))

GREEN  = "\033[1;32m"
YELLOW = "\033[1;33m"
RED    = "\033[1;31m"
DIM    = "\033[2m"
RESET  = "\033[0m"

to_start = []
to_stop  = []

for reservation in data:
    for inst in reservation:
        if len(inst) < 3: continue
        iid, state, tags = inst
        schedule = ""
        name = ""
        for t in (tags or []):
            if t["Key"] == tag_key:   schedule = t["Value"]
            if t["Key"] == "Name":    name = t["Value"]

        if not schedule: continue
        if schedule == "always-on":
            if state != "running":
                to_start.append((iid, name, "always-on"))
            continue
        if schedule == "always-off":
            if state == "running":
                to_stop.append((iid, name, "always-off"))
            continue

        m = re.search(r'start=(\d{2}:\d{2})', schedule)
        start_t = m.group(1) if m else None
        m = re.search(r'stop=(\d{2}:\d{2})', schedule)
        stop_t  = m.group(1) if m else None

        if start_t and state == "stopped":
            sh, sm = map(int, start_t.split(":"))
            if ch == sh and cm >= sm:
                to_start.append((iid, name, start_t))
        if stop_t and state == "running":
            sh, sm = map(int, stop_t.split(":"))
            if ch == sh and cm >= sm:
                to_stop.append((iid, name, stop_t))

print(f"  現在時刻: {current_time}\n")
if to_start:
    print(f"  {GREEN}起動対象:{RESET}")
    for iid, name, t in to_start:
        print(f"    {iid} ({name}) [{t}]")
if to_stop:
    print(f"  {YELLOW}停止対象:{RESET}")
    for iid, name, t in to_stop:
        print(f"    {iid} ({name}) [{t}]")
if not to_start and not to_stop:
    print(f"  {DIM}現時点でスケジュール対象のインスタンスはありません{RESET}")

if not dry_run:
    import subprocess
    for iid, name, t in to_start:
        subprocess.run(["aws", "ec2", "start-instances", "--instance-ids", iid], capture_output=True)
        print(f"  -> 起動: {iid}")
    for iid, name, t in to_stop:
        subprocess.run(["aws", "ec2", "stop-instances", "--instance-ids", iid], capture_output=True)
        print(f"  -> 停止: {iid}")
PYEOF
    echo ""
}

cmd_status() {
    local id="${1:-}"
    [[ -z "$id" ]] && error_exit "インスタンスIDを指定してください"

    log_info "インスタンス詳細: $id"
    echo ""

    aws_cmd ec2 describe-instances --instance-ids "$id" \
        --query 'Reservations[0].Instances[0]' \
        --output json 2>/dev/null | python3 - <<'PYEOF'
import sys, json
data = json.load(sys.stdin)
if not data: sys.exit(1)

CYAN  = "\033[1;36m"
GREEN = "\033[1;32m"
RESET = "\033[0m"

tags = {t["Key"]: t["Value"] for t in (data.get("Tags") or [])}

fields = [
    ("インスタンスID",     data.get("InstanceId", "N/A")),
    ("名前",               tags.get("Name", "N/A")),
    ("インスタンスタイプ", data.get("InstanceType", "N/A")),
    ("状態",               data.get("State", {}).get("Name", "N/A")),
    ("AZ",                 data.get("Placement", {}).get("AvailabilityZone", "N/A")),
    ("パブリックIP",       data.get("PublicIpAddress", "N/A")),
    ("プライベートIP",     data.get("PrivateIpAddress", "N/A")),
    ("起動時刻",           (data.get("LaunchTime") or "N/A")[:19]),
    ("AMI ID",             data.get("ImageId", "N/A")),
    ("キーペア",           data.get("KeyName", "N/A")),
    ("VPC ID",             data.get("VpcId", "N/A")),
]
for k, v in fields:
    print(f"  {CYAN}{k:<20}{RESET} {v}")
PYEOF
    echo ""
}

cmd_costs() {
    log_info "インスタンス別コスト推計"
    echo ""

    local -A hourly_rates=(
        ["t3.micro"]="0.0104" ["t3.small"]="0.0208" ["t3.medium"]="0.0416"
        ["t3.large"]="0.0832" ["t3.xlarge"]="0.1664" ["m5.large"]="0.096"
        ["m5.xlarge"]="0.192" ["c5.large"]="0.085"  ["r5.large"]="0.126"
    )

    aws_cmd ec2 describe-instances \
        --filters "Name=instance-state-name,Values=running" \
        --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,LaunchTime,Tags]' \
        --output json 2>/dev/null | python3 - <<'PYEOF'
import sys, json
from datetime import datetime, timezone

data = json.load(sys.stdin)
hourly = {"t3.micro":0.0104,"t3.small":0.0208,"t3.medium":0.0416,
          "t3.large":0.0832,"t3.xlarge":0.1664,"m5.large":0.096,
          "m5.xlarge":0.192,"c5.large":0.085,"r5.large":0.126}

CYAN  = "\033[1;36m"
GREEN = "\033[1;32m"
BOLD  = "\033[1m"
RESET = "\033[0m"

print(f"  {BOLD}{'名前':<25} {'タイプ':<15} {'稼働時間':>10} {'推計コスト':>12}{RESET}")
print(f"  {'─'*65}")

total = 0.0
for res in data:
    for inst in res:
        if len(inst) < 4: continue
        iid, itype, launch, tags = inst
        name = ""
        for t in (tags or []):
            if t["Key"] == "Name": name = t["Value"]

        launch_dt = datetime.fromisoformat(launch.replace("Z","+00:00"))
        now = datetime.now(timezone.utc)
        hours = (now - launch_dt).total_seconds() / 3600
        rate = hourly.get(itype, 0.05)
        cost = hours * rate
        total += cost

        print(f"  {CYAN}{name[:23]:<25}{RESET} {itype:<15} {hours:>10.1f}h {GREEN}${cost:>11.2f}{RESET}")

print(f"  {'─'*65}")
print(f"  {'合計':<40} {GREEN}${total:>11.2f}{RESET}")
PYEOF
    echo ""
}

cmd_stale() {
    log_info "長期停止インスタンス検出 (30日以上)"
    echo ""

    aws_cmd ec2 describe-instances \
        --filters "Name=instance-state-name,Values=stopped" \
        --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,StateTransitionReason,Tags]' \
        --output json 2>/dev/null | python3 - <<'PYEOF'
import sys, json, re
from datetime import datetime, timezone

data = json.load(sys.stdin)

YELLOW = "\033[1;33m"
RED    = "\033[1;31m"
DIM    = "\033[2m"
RESET  = "\033[0m"

print(f"  {'インスタンスID':<22} {'タイプ':<15} {'停止日':>12} {'名前'}")
print(f"  {'─'*65}")

for res in data:
    for inst in res:
        if len(inst) < 4: continue
        iid, itype, reason, tags = inst
        name = ""
        for t in (tags or []):
            if t["Key"] == "Name": name = t["Value"]

        m = re.search(r'\((\d{4}-\d{2}-\d{2})', reason or "")
        if m:
            stopped_dt = datetime.strptime(m.group(1), "%Y-%m-%d").replace(tzinfo=timezone.utc)
            days = (datetime.now(timezone.utc) - stopped_dt).days
            color = RED if days > 90 else YELLOW
            print(f"  {color}{iid:<22}{RESET} {itype:<15} {m.group(1):>12} {name[:20]}")
        else:
            print(f"  {DIM}{iid:<22}{RESET} {itype:<15} {'不明':>12} {name[:20]}")
PYEOF
    echo ""
}

parse_arguments() {
    [[ $# -eq 0 ]] && return 0
    case "$1" in
        list|start|stop|schedule|status|costs|stale)
            command_name="$1"; shift ;;
    esac

    local positional=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            --profile)    [[ $# -lt 2 ]] && error_exit "--profile には値が必要です"; aws_profile="$2"; shift 2 ;;
            --region)     [[ $# -lt 2 ]] && error_exit "--region には値が必要です"; aws_region="$2"; shift 2 ;;
            --tag)        [[ $# -lt 2 ]] && error_exit "--tag には値が必要です"; tag_key="$2"; shift 2 ;;
            -n|--dry-run) dry_run=1; shift ;;
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
        list)     cmd_list ;;
        start)    cmd_start "${POSITIONAL[@]+"${POSITIONAL[@]}"}" ;;
        stop)     cmd_stop  "${POSITIONAL[@]+"${POSITIONAL[@]}"}" ;;
        schedule) cmd_schedule ;;
        status)   cmd_status "${POSITIONAL[0]:-}" ;;
        costs)    cmd_costs ;;
        stale)    cmd_stale ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
