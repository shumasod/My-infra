#!/bin/bash
set -euo pipefail

#
# オープンリダイレクト・SSRF検出ツール
# 作成日: 2026-11-05
# バージョン: 1.0
#
# 脆弱性対応: オープンリダイレクトとSSRF脆弱性の検出
# CVE該当: CWE-601 (URL Redirection to Untrusted Site), CWE-918 (SSRF)
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare command_name="scan"

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション]

オープンリダイレクトとSSRF脆弱性を検出します。

コマンド:
  scan <パス>          脆弱性スキャン (デフォルト)
  validate <URL>       URL安全性検証
  ssrf-check <URL>     SSRFリスク評価
  allowlist            安全なドメインリスト管理

オプション:
  -h, --help           このヘルプを表示
  -v, --version        バージョン情報を表示

脆弱性概要:
  CWE-601: 未検証URLへのリダイレクト
  CWE-918: サーバーサイドリクエストフォージェリ(SSRF)
  対策: URLホワイトリスト・内部IPアドレスのブロック
EOF
}

scan_redirect_patterns() {
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
CYAN   = "\033[1;36m"
RESET  = "\033[0m"
BOLD   = "\033[1m"

patterns = [
    (r'(?:curl|wget)\s+.*\$(?:url|URL|redirect|location|href)',
     "curl/wgetに未検証URLを渡す", "HIGH"),
    (r'(?:curl|wget)\s+.*-L\s+.*\$',
     "curl -L (リダイレクト追従) + 変数URL", "HIGH"),
    (r'(?:curl|wget)\s+.*\$(1|2|@|\*)',
     "curl/wgetにユーザー引数を直接渡す", "HIGH"),
    (r'Location:\s*\$(?![({\[])',
     "Locationヘッダに未検証変数", "CRITICAL"),
    (r'(?:curl|wget)\s+.*http.*\$',
     "HTTP URLに変数を含む", "MEDIUM"),
    (r'(?:open|xdg-open|browse)\s+.*\$',
     "ブラウザ/openコマンドに変数URL", "MEDIUM"),
    (r'(?:ssh|sftp|scp)\s+.*\$(?!HOME|USER|PWD)',
     "SSH接続先に未検証変数", "MEDIUM"),
]

for i, line in enumerate(lines, 1):
    s = line.rstrip()
    if s.lstrip().startswith('#'):
        continue
    for pat, desc, sev in patterns:
        if re.search(pat, s):
            color = "\033[1;35m" if sev == "CRITICAL" else ("\033[1;31m" if sev == "HIGH" else "\033[1;33m")
            print(f"  {color}[{sev}]{RESET} 行{i:4d}: {desc}")
            print(f"    {BOLD}{s.strip()[:80]}{RESET}")
            break
PYEOF
}

cmd_scan() {
    local path="${1:-.}"
    log_info "オープンリダイレクト・SSRF脆弱性スキャン: $path"
    echo ""

    local total=0 issues=0
    while IFS= read -r file; do
        (( total++ ))
        local result
        result=$(scan_redirect_patterns "$file")
        if [[ -n "$result" ]]; then
            (( issues++ ))
            printf "${C_BOLD}%s${C_RESET}\n" "$file"
            echo "$result"
            echo ""
        fi
    done < <(find "$path" -name "*.sh" -type f 2>/dev/null | sort)

    printf "スキャン完了: %d ファイル中 %d 件に脆弱性\n" "$total" "$issues"
    [[ "$issues" -gt 0 ]] && log_error "URL検証を実装してください" || log_success "脆弱性なし"
    echo ""
}

cmd_validate() {
    local url="${1:-}"
    [[ -z "$url" ]] && error_exit "URLを指定してください"

    log_info "URL安全性検証: $url"
    echo ""

    python3 - "$url" <<'PYEOF'
import sys, re
from urllib.parse import urlparse

url = sys.argv[1]

GREEN  = "\033[1;32m"
RED    = "\033[1;31m"
YELLOW = "\033[1;33m"
RESET  = "\033[0m"

issues = []

try:
    parsed = urlparse(url)
    scheme   = parsed.scheme
    hostname = parsed.hostname or ""
    port     = parsed.port
    path     = parsed.path

    print(f"  スキーム:    {scheme}")
    print(f"  ホスト名:    {hostname}")
    print(f"  ポート:      {port or 'デフォルト'}")
    print(f"  パス:        {path}")
    print()

    # 危険なスキーム
    if scheme in ('file', 'dict', 'gopher', 'ftp', 'ldap', 'ldaps'):
        issues.append(("CRITICAL", f"危険なスキーム: {scheme}"))
    if scheme not in ('http', 'https', 'file', 'ftp', 'dict', 'gopher', 'ldap', 'ldaps', ''):
        issues.append(("HIGH", f"未知のスキーム: {scheme}"))

    # プライベート/内部IPアドレス (SSRF)
    private_ranges = [
        r'^127\.',           # loopback
        r'^10\.',            # Class A private
        r'^172\.(1[6-9]|2[0-9]|3[01])\.',  # Class B private
        r'^192\.168\.',      # Class C private
        r'^169\.254\.',      # link-local
        r'^::1$',            # IPv6 loopback
        r'^fc00:',           # IPv6 unique local
        r'^0\.',             # 0.x.x.x
    ]
    for pat in private_ranges:
        if re.search(pat, hostname):
            issues.append(("CRITICAL", f"内部/プライベートIPアドレス: {hostname} (SSRF攻撃に使用可能)"))
            break

    # メタデータサービス
    metadata_ips = ['169.254.169.254', '100.100.100.200', 'metadata.google.internal']
    if hostname in metadata_ips:
        issues.append(("CRITICAL", f"クラウドメタデータサービス: {hostname}"))

    # localhost
    if hostname in ('localhost', '0.0.0.0'):
        issues.append(("CRITICAL", f"ローカルホスト参照: {hostname}"))

    # パストラバーサル in URL
    if '..' in path:
        issues.append(("HIGH", "パストラバーサルをURLに含む"))

    # URLエンコードされたバイパス試行
    if re.search(r'%2[Ee]|%2[Ff]|%40|%00', url):
        issues.append(("HIGH", "URLエンコードによるバイパス試行の可能性"))

    if issues:
        print(f"  {RED}[危険] 以下の問題を検出:{RESET}")
        for sev, msg in issues:
            color = "\033[1;35m" if sev == "CRITICAL" else RED
            print(f"    {color}[{sev}]{RESET} {msg}")
    else:
        print(f"  {GREEN}[OK] 明らかな問題は検出されませんでした{RESET}")
        print(f"  ※ ドメイン許可リストによる追加検証を推奨します")

except Exception as e:
    print(f"  {RED}URL解析エラー: {e}{RESET}")
PYEOF
    echo ""
}

cmd_ssrf_check() {
    local url="${1:-}"
    [[ -z "$url" ]] && error_exit "URLを指定してください"

    log_info "SSRF リスク評価: $url"
    echo ""

    # 内部リソースへのアクセス確認 (読み取り専用テスト)
    python3 - "$url" <<'PYEOF'
import sys, re, socket
from urllib.parse import urlparse

url = sys.argv[1]
RED    = "\033[1;31m"
GREEN  = "\033[1;32m"
YELLOW = "\033[1;33m"
RESET  = "\033[0m"

parsed = urlparse(url)
hostname = parsed.hostname or ""

# DNS解決してIPを取得
try:
    resolved_ips = socket.getaddrinfo(hostname, None)
    ips = list(set(r[4][0] for r in resolved_ips))
    print(f"  解決済みIP: {', '.join(ips)}")

    for ip in ips:
        # RFC1918プライベートアドレスチェック
        if re.match(r'^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.)', ip):
            print(f"  {RED}[SSRF危険] 内部ネットワークIPに解決: {ip}{RESET}")
        elif re.match(r'^127\.|^::1', ip):
            print(f"  {RED}[SSRF危険] ループバックIPに解決: {ip}{RESET}")
        elif ip == '169.254.169.254':
            print(f"  {RED}[SSRF CRITICAL] AWSメタデータサービスIP: {ip}{RESET}")
        else:
            print(f"  {GREEN}[OK] 外部IP: {ip}{RESET}")
except socket.gaierror:
    print(f"  {YELLOW}DNS解決失敗: {hostname}{RESET}")
PYEOF
    echo ""
}

cmd_allowlist() {
    log_info "安全なドメイン許可リスト設定例"
    echo ""

    cat <<'ALLOWLIST'
  # シェルスクリプトでのURL許可リスト実装例

  ALLOWED_DOMAINS=(
    "api.example.com"
    "cdn.example.com"
    "storage.example.com"
  )

  validate_url() {
    local url="$1"
    local hostname
    hostname=$(python3 -c "from urllib.parse import urlparse; print(urlparse('${url}').hostname or '')")

    # 許可リスト確認
    for domain in "${ALLOWED_DOMAINS[@]}"; do
      if [[ "$hostname" == "$domain" || "$hostname" == *".${domain}" ]]; then
        return 0
      fi
    done

    log_error "許可されていないドメイン: $hostname"
    return 1
  }

  # 使用例
  if validate_url "$user_input_url"; then
    curl "$user_input_url"
  fi

ALLOWLIST
    echo ""
}

parse_arguments() {
    [[ $# -eq 0 ]] && return 0
    case "$1" in
        scan|validate|ssrf-check|allowlist)
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
        scan)       cmd_scan      "${POSITIONAL[0]:-.}" ;;
        validate)   cmd_validate  "${POSITIONAL[0]:-}" ;;
        ssrf-check) cmd_ssrf_check "${POSITIONAL[0]:-}" ;;
        allowlist)  cmd_allowlist ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
