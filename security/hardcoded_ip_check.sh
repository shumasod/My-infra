#!/bin/bash
set -euo pipefail

#
# ハードコードIPアドレス検出ツール
# 作成日: 2026-11-05
# バージョン: 1.0
#
# 脆弱性対応: ハードコードされたIPアドレス・エンドポイントの検出
# CVE該当: CWE-1255 (Comparison Logic Error), CWE-668 (Exposure of Resource to Wrong Sphere)
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare command_name="scan"

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション]

ハードコードされたIPアドレスや内部エンドポイントを検出します。

コマンド:
  scan <パス>          ハードコードIP検出 (デフォルト)
  classify <IP>        IPアドレス分類
  report <パス>        詳細レポート

オプション:
  -h, --help           このヘルプを表示
  -v, --version        バージョン情報を表示

脆弱性概要:
  CWE-668: 不適切なリソース公開
  対策: 設定ファイル・環境変数への外出し
EOF
}

scan_hardcoded_ips() {
    local file="$1"
    python3 - "$file" <<'PYEOF'
import sys, re

filepath = sys.argv[1]
try:
    with open(filepath, errors='replace') as f:
        lines = f.readlines()
except:
    sys.exit(0)

RED    = "\033[1;31m"
YELLOW = "\033[1;33m"
GREEN  = "\033[1;32m"
CYAN   = "\033[1;36m"
RESET  = "\033[0m"
BOLD   = "\033[1m"

# IPv4パターン
ipv4_pat = re.compile(
    r'\b((?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}'
    r'(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))\b'
)

# 除外パターン (バージョン番号等のFP)
exclude_pats = [
    r'^\s*#',               # コメント行
    r'version\s*=',         # バージョン番号
    r'[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+[-+]',  # バージョン
    r'255\.255\.',           # サブネットマスク
    r'0\.0\.0\.0',          # ワイルドカード (別途チェック)
]

def classify_ip(ip):
    parts = list(map(int, ip.split('.')))
    if parts[0] == 10:
        return "プライベート (Class A)", "MEDIUM"
    if parts[0] == 172 and 16 <= parts[1] <= 31:
        return "プライベート (Class B)", "MEDIUM"
    if parts[0] == 192 and parts[1] == 168:
        return "プライベート (Class C)", "MEDIUM"
    if parts[0] == 127:
        return "ループバック", "LOW"
    if parts[0] == 169 and parts[1] == 254:
        return "リンクローカル / メタデータ", "HIGH"
    if parts[0] == 0:
        return "ルート (0.x.x.x)", "LOW"
    return "パブリックIP", "MEDIUM"

findings = []
for i, line in enumerate(lines, 1):
    # 除外チェック
    skip = any(re.search(ex, line) for ex in exclude_pats)
    if skip:
        continue

    for m in ipv4_pat.finditer(line):
        ip = m.group(1)
        # ハードコード判定 (変数への代入や関数引数)
        context = line.strip()
        if re.search(r'\$\{' + re.escape(ip), context):
            continue
        ip_class, sev = classify_ip(ip)
        findings.append((i, context[:80], ip, ip_class, sev))

for lineno, context, ip, ip_class, sev in findings:
    color = RED if sev in ("HIGH", "CRITICAL") else YELLOW
    print(f"  {color}[{sev}]{RESET} 行{lineno:4d}: {BOLD}{ip}{RESET} ({ip_class})")
    print(f"    {context}")
PYEOF
}

cmd_scan() {
    local path="${1:-.}"
    log_info "ハードコードIPアドレス検出: $path"
    echo ""

    local total=0 issues=0
    while IFS= read -r file; do
        (( total++ ))
        local result
        result=$(scan_hardcoded_ips "$file")
        if [[ -n "$result" ]]; then
            (( issues++ ))
            printf "${C_BOLD}%s${C_RESET}\n" "$file"
            echo "$result"
            echo ""
        fi
    done < <(find "$path" \( -name "*.sh" -o -name "*.conf" -o -name "*.yml" -o -name "*.yaml" \) -type f 2>/dev/null | sort)

    printf "スキャン完了: %d ファイル中 %d 件にハードコードIP\n" "$total" "$issues"
    echo ""
    if [[ "$issues" -gt 0 ]]; then
        printf "${C_BOLD}【推奨対応】${C_RESET}\n\n"
        cat <<'FIX'
  # 【危険】ハードコード
  SERVER_IP="192.168.1.100"

  # 【安全】環境変数から取得
  SERVER_IP="${SERVER_IP:-192.168.1.100}"

  # 【安全】設定ファイルから読み込み
  source /etc/myapp/config.sh

  # 【安全】コマンドライン引数
  SERVER_IP="${1:-}"
  [[ -z "$SERVER_IP" ]] && error_exit "SERVER_IP を指定してください"
FIX
        echo ""
    else
        log_success "ハードコードIPアドレスなし"
    fi
}

cmd_classify() {
    local ip="${1:-}"
    [[ -z "$ip" ]] && error_exit "IPアドレスを指定してください"

    log_info "IPアドレス分類: $ip"
    echo ""

    python3 - "$ip" <<'PYEOF'
import sys, re, socket

ip = sys.argv[1]
RED    = "\033[1;31m"
GREEN  = "\033[1;32m"
YELLOW = "\033[1;33m"
CYAN   = "\033[1;36m"
RESET  = "\033[0m"

ipv4_pat = re.compile(r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$')
m = ipv4_pat.match(ip)
if not m:
    print(f"  {RED}無効なIPv4アドレス: {ip}{RESET}")
    sys.exit(1)

a, b, c, d = map(int, m.groups())

if any(x > 255 for x in [a, b, c, d]):
    print(f"  {RED}無効なIPv4アドレス (範囲外): {ip}{RESET}")
    sys.exit(1)

classifications = []
if a == 10: classifications.append(("プライベート (RFC 1918)", "10.0.0.0/8", YELLOW))
elif a == 172 and 16 <= b <= 31: classifications.append(("プライベート (RFC 1918)", "172.16.0.0/12", YELLOW))
elif a == 192 and b == 168: classifications.append(("プライベート (RFC 1918)", "192.168.0.0/16", YELLOW))
elif a == 127: classifications.append(("ループバック", "127.0.0.0/8", CYAN))
elif a == 169 and b == 254:
    classifications.append(("リンクローカル / AWSメタデータ", "169.254.0.0/16", RED))
    if ip == '169.254.169.254':
        classifications.append(("AWS EC2 インスタンスメタデータ", "危険!", RED))
elif a == 0: classifications.append(("このネットワーク (RFC 1122)", "0.0.0.0/8", CYAN))
elif a >= 224: classifications.append(("マルチキャスト/予約済み", f"{a}.0.0.0/4", CYAN))
else: classifications.append(("パブリックアドレス", "グローバル到達可能", GREEN))

for desc, range_info, color in classifications:
    print(f"  {color}種別: {desc}{RESET}")
    print(f"  範囲: {range_info}")

# リバースDNS
try:
    hostname = socket.gethostbyaddr(ip)[0]
    print(f"  ホスト名: {hostname}")
except:
    print(f"  ホスト名: (解決不可)")
PYEOF
    echo ""
}

parse_arguments() {
    [[ $# -eq 0 ]] && return 0
    case "$1" in
        scan|classify|report)
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
        scan)     cmd_scan     "${POSITIONAL[0]:-.}" ;;
        classify) cmd_classify "${POSITIONAL[0]:-}" ;;
        report)   cmd_scan     "${POSITIONAL[0]:-.}" ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
