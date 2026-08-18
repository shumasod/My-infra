#!/bin/bash
set -euo pipefail

#
# Nginxアクセスログ解析ツール
# 作成日: 2026-07-31
# バージョン: 1.0
#
# Nginxのアクセスログを詳細に分析しレポートを生成します
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"
readonly DEFAULT_LOG="/var/log/nginx/access.log"

declare command_name="summary"
declare log_file="$DEFAULT_LOG"
declare top_n=10
declare since_time=""
declare output_format="pretty"
declare filter_status=""
declare filter_ip=""

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション] [ログファイル]

Nginxアクセスログの解析ツールです。

コマンド:
  summary [ファイル]     サマリーレポート (デフォルト)
  ips [ファイル]         IPアドレスランキング
  urls [ファイル]        URLランキング
  status [ファイル]      HTTPステータスコード分布
  errors [ファイル]      エラーログ抽出
  timeline [ファイル]    時間帯別アクセス数
  agents [ファイル]      ユーザーエージェント分析
  bandwidth [ファイル]   帯域幅分析

オプション:
  -h, --help             このヘルプを表示
  -v, --version          バージョン情報を表示
  -n, --top <数>         上位表示件数 [デフォルト: 10]
  --since <日時>         指定日時以降のみ (例: "2025-01-01")
  --status <コード>      ステータスコードでフィルタ (例: 404)
  --ip <IPアドレス>      IPアドレスでフィルタ
  --format <形式>        出力形式 (pretty|csv|json) [デフォルト: pretty]

例:
  $PROG_NAME summary /var/log/nginx/access.log
  $PROG_NAME ips -n 20
  $PROG_NAME errors --status 500
  $PROG_NAME timeline
  $PROG_NAME bandwidth -n 5
EOF
}

check_log() {
    [[ ! -f "$log_file" ]] && error_exit "ログファイルが見つかりません: $log_file"
    [[ ! -r "$log_file" ]] && error_exit "ログファイルを読み取れません: $log_file"
}

bar_chart() {
    local val=$1 max=$2 width=${3:-30}
    local filled=$(( max > 0 ? val * width / max : 0 ))
    printf "${C_CYAN}"
    printf '%0.s█' $(seq 1 $filled 2>/dev/null) || true
    printf "${C_RESET}"
    printf '%0.s░' $(seq 1 $(( width - filled )) 2>/dev/null) || true
}

parse_log() {
    local filter_args=""
    [[ -n "$since_time" ]] && filter_args="$filter_args | grep \"$since_time\""
    [[ -n "$filter_status" ]] && filter_args="$filter_args | awk '\$9==\"$filter_status\"'"
    [[ -n "$filter_ip" ]]     && filter_args="$filter_args | grep \"^$filter_ip \""
    cat "$log_file"
}

cmd_summary() {
    check_log
    log_info "ログファイルを解析中: $log_file"
    echo ""

    parse_log | python3 - "$top_n" <<'PYEOF'
import sys, re
from collections import Counter
from datetime import datetime

top_n = int(sys.argv[1])
lines = sys.stdin.readlines()
total = len(lines)

# nginx combined log format
pattern = re.compile(
    r'(\S+) \S+ \S+ \[([^\]]+)\] "(\S+) (\S+) \S+" (\d+) (\d+)'
)

ips = Counter()
urls = Counter()
statuses = Counter()
methods = Counter()
total_bytes = 0
errors = 0
parsed = 0

for line in lines:
    m = pattern.match(line)
    if not m:
        continue
    parsed += 1
    ip, ts, method, url, status, size = m.groups()
    ips[ip] += 1
    urls[url] += 1
    statuses[status] += 1
    methods[method] += 1
    try:
        total_bytes += int(size)
    except:
        pass
    if status.startswith(('4','5')):
        errors += 1

RED = '\033[1;31m'
GREEN = '\033[1;32m'
YELLOW = '\033[1;33m'
CYAN = '\033[1;36m'
BOLD = '\033[1m'
DIM = '\033[2m'
RESET = '\033[0m'

print(f'{BOLD}=== Nginxアクセスログ サマリー ==={RESET}')
print(f'{DIM}ファイル: {sys.stdin.name if hasattr(sys.stdin,"name") else "stdin"}{RESET}')
print()
print(f'  総リクエスト数: {BOLD}{total:,}{RESET}')
print(f'  解析成功数    : {parsed:,}')
print(f'  エラー数      : {RED if errors > 0 else GREEN}{errors:,}{RESET} ({errors*100//total if total>0 else 0}%)')
print(f'  転送量        : {total_bytes/1024/1024:.2f} MB')
print(f'  ユニークIP数  : {len(ips):,}')
print()

print(f'{BOLD}【HTTPメソッド分布】{RESET}')
for method, count in methods.most_common():
    pct = count*100//total if total > 0 else 0
    print(f'  {CYAN}{method:<8}{RESET} {count:>8,} ({pct:>3}%)')
print()

print(f'{BOLD}【ステータスコード分布】{RESET}')
for status, count in sorted(statuses.items()):
    pct = count*100//total if total > 0 else 0
    color = GREEN if status.startswith('2') else YELLOW if status.startswith('3') else RED
    print(f'  {color}{status}{RESET} {count:>8,} ({pct:>3}%)')
print()

print(f'{BOLD}【上位{top_n}IPアドレス】{RESET}')
max_ip = max(ips.values()) if ips else 1
for ip, count in ips.most_common(top_n):
    pct = count*100//total if total > 0 else 0
    print(f'  {CYAN}{ip:<18}{RESET} {count:>7,} ({pct:>3}%)')
print()

print(f'{BOLD}【上位{top_n}URL】{RESET}')
for url, count in urls.most_common(top_n):
    pct = count*100//total if total > 0 else 0
    print(f'  {count:>7,} ({pct:>3}%) {url[:60]}')
PYEOF
}

cmd_timeline() {
    check_log
    log_info "時間帯別アクセス分析"
    echo ""

    parse_log | python3 - <<'PYEOF'
import sys, re
from collections import Counter

pattern = re.compile(r'\[(\d{2}/\w+/\d{4}):(\d{2}):\d{2}:\d{2}')
hours = Counter()

for line in sys.stdin:
    m = pattern.search(line)
    if m:
        hours[int(m.group(2))] += 1

if not hours:
    print('  データが見つかりません')
    sys.exit(0)

max_count = max(hours.values())
CYAN = '\033[1;36m'
GREEN = '\033[1;32m'
YELLOW = '\033[1;33m'
RED = '\033[1;31m'
RESET = '\033[0m'
BOLD = '\033[1m'

print(f'{BOLD}時間帯   リクエスト数  グラフ{RESET}')
print('─' * 60)

for h in range(24):
    count = hours.get(h, 0)
    filled = count * 40 // max_count if max_count > 0 else 0
    color = RED if count >= max_count*0.8 else YELLOW if count >= max_count*0.5 else CYAN
    bar = '█' * filled + '░' * (40 - filled)
    print(f'  {h:02d}時  {count:>7,}  {color}{bar}{RESET}')
PYEOF
}

cmd_errors() {
    check_log
    log_info "エラーリクエスト抽出"
    echo ""

    local status="${filter_status:-[45][0-9][0-9]}"

    printf "${C_BOLD}%-18s %-8s %-45s %s${C_RESET}\n" "IPアドレス" "ステータス" "URL" "時刻"
    printf "%s\n" "$(printf '%.0s─' {1..85})"

    parse_log | awk -v status="$status" '
        $9 ~ status {
            ip=$1
            gsub(/[\[\]]/, "", $4)
            time=$4
            status_code=$9
            url=$7
            printf "  %-16s %-8s %-45s %s\n", ip, status_code, substr(url,1,45), time
        }
    ' | head -$(( top_n * 5 )) | while IFS= read -r line; do
        local status_field
        status_field=$(echo "$line" | awk '{print $2}')
        if [[ "${status_field:0:1}" == "5" ]]; then
            printf "${C_RED}%s${C_RESET}\n" "$line"
        else
            printf "${C_YELLOW}%s${C_RESET}\n" "$line"
        fi
    done
    echo ""
}

cmd_bandwidth() {
    check_log
    log_info "帯域幅分析"
    echo ""

    parse_log | python3 - "$top_n" <<'PYEOF'
import sys, re
from collections import defaultdict

top_n = int(sys.argv[1])
pattern = re.compile(r'"(\S+) (\S+) \S+" \d+ (\d+)')
url_bytes = defaultdict(int)
ip_bytes = defaultdict(int)

for line in sys.stdin:
    m = pattern.search(line)
    if m:
        method, url, size = m.groups()
        try:
            sz = int(size)
            url_bytes[url] += sz
            ip = line.split()[0]
            ip_bytes[ip] += sz
        except:
            pass

BOLD = '\033[1m'
CYAN = '\033[1;36m'
RESET = '\033[0m'

def fmt_bytes(b):
    if b >= 1073741824: return f'{b/1073741824:.2f} GB'
    if b >= 1048576: return f'{b/1048576:.2f} MB'
    if b >= 1024: return f'{b/1024:.2f} KB'
    return f'{b} B'

total = sum(url_bytes.values())
print(f'  総転送量: {BOLD}{fmt_bytes(total)}{RESET}\n')

print(f'{BOLD}【転送量上位{top_n} URL】{RESET}')
for url, sz in sorted(url_bytes.items(), key=lambda x: -x[1])[:top_n]:
    pct = sz*100//total if total > 0 else 0
    print(f'  {fmt_bytes(sz):>12} ({pct:>3}%) {url[:55]}')

print()
print(f'{BOLD}【転送量上位{top_n} IPアドレス】{RESET}')
for ip, sz in sorted(ip_bytes.items(), key=lambda x: -x[1])[:top_n]:
    pct = sz*100//total if total > 0 else 0
    print(f'  {CYAN}{ip:<18}{RESET} {fmt_bytes(sz):>12} ({pct:>3}%)')
PYEOF
}

cmd_agents() {
    check_log
    log_info "ユーザーエージェント分析"
    echo ""

    parse_log | awk -F'"' '{print $6}' | \
    sort | uniq -c | sort -rn | head -"$top_n" | \
    while read -r count agent; do
        local color="$C_WHITE"
        echo "$agent" | grep -qi "bot\|crawler\|spider" && color="$C_YELLOW"
        echo "$agent" | grep -qi "curl\|wget\|python\|go-http" && color="$C_CYAN"
        printf "  ${C_GREEN}%6d${C_RESET} ${color}%s${C_RESET}\n" "$count" "${agent:0:70}"
    done
    echo ""
}

cmd_ips() {
    check_log
    log_info "IPアドレスランキング"
    echo ""

    parse_log | awk '{print $1}' | \
    sort | uniq -c | sort -rn | head -"$top_n" | \
    awk '{printf "%7d %s\n", $1, $2}' | \
    while read -r count ip; do
        printf "  ${C_GREEN}%7d${C_RESET} ${C_CYAN}%s${C_RESET}\n" "$count" "$ip"
    done
    echo ""
}

cmd_status() {
    check_log
    log_info "HTTPステータスコード分布"
    echo ""

    parse_log | awk '{print $9}' | grep -E '^[0-9]{3}$' | \
    sort | uniq -c | sort -rn | \
    awk '{printf "%6d %s\n", $1, $2}' | \
    while read -r count status; do
        local color="$C_GREEN"
        [[ "${status:0:1}" == "3" ]] && color="$C_CYAN"
        [[ "${status:0:1}" == "4" ]] && color="$C_YELLOW"
        [[ "${status:0:1}" == "5" ]] && color="$C_RED"
        printf "  ${color}%s${C_RESET} %6d\n" "$status" "$count"
    done
    echo ""
}

cmd_urls() {
    check_log
    log_info "URLランキング"
    echo ""

    parse_log | awk '{print $7}' | \
    sort | uniq -c | sort -rn | head -"$top_n" | \
    awk '{printf "%7d %s\n", $1, $2}' | \
    while read -r count url; do
        printf "  ${C_GREEN}%7d${C_RESET} %s\n" "$count" "${url:0:70}"
    done
    echo ""
}

parse_arguments() {
    [[ $# -eq 0 ]] && return 0
    case "$1" in
        summary|ips|urls|status|errors|timeline|agents|bandwidth)
            command_name="$1"; shift ;;
    esac

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -n|--top)     [[ $# -lt 2 ]] && error_exit "--top には値が必要です"; top_n="$2"; shift 2 ;;
            --since)      [[ $# -lt 2 ]] && error_exit "--since には値が必要です"; since_time="$2"; shift 2 ;;
            --status)     [[ $# -lt 2 ]] && error_exit "--status には値が必要です"; filter_status="$2"; shift 2 ;;
            --ip)         [[ $# -lt 2 ]] && error_exit "--ip には値が必要です"; filter_ip="$2"; shift 2 ;;
            --format)     [[ $# -lt 2 ]] && error_exit "--format には値が必要です"; output_format="$2"; shift 2 ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  [[ -f "$1" ]] && log_file="$1" || error_exit "ファイルが見つかりません: $1"; shift ;;
        esac
    done
}

main() {
    parse_arguments "$@"
    case "$command_name" in
        summary)   cmd_summary ;;
        ips)       cmd_ips ;;
        urls)      cmd_urls ;;
        status)    cmd_status ;;
        errors)    cmd_errors ;;
        timeline)  cmd_timeline ;;
        agents)    cmd_agents ;;
        bandwidth) cmd_bandwidth ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
