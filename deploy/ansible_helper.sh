#!/bin/bash
set -euo pipefail

#
# Ansibleヘルパーツール
# 作成日: 2026-09-01
# バージョン: 1.0
#
# Ansibleの実行・ホスト管理・プレイブック検証を支援します
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare command_name="status"
declare inventory_file="inventory.ini"
declare playbook_file="site.yml"
declare target_host=""
declare target_tag=""
declare dry_run=0
declare vault_pass_file=""
declare extra_vars=""

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション]

Ansible実行・管理ヘルパーツールです。

コマンド:
  status               インベントリと疎通確認 (デフォルト)
  ping [ホスト]        ホストへのping確認
  run [プレイブック]   プレイブック実行
  check                チェックモード (ドライラン)
  facts <ホスト>       ホストのfacts収集
  adhoc <コマンド>     アドホックコマンド実行
  lint <プレイブック>  プレイブック構文チェック
  graph                プレイブックのタスクグラフ

オプション:
  -h, --help           このヘルプを表示
  -v, --version        バージョン情報を表示
  -i, --inventory <ファイル> インベントリファイル [デフォルト: inventory.ini]
  -p, --playbook <ファイル>  プレイブックファイル [デフォルト: site.yml]
  -l, --limit <ホスト> 実行対象を限定
  -t, --tags <タグ>    実行タグを指定
  -n, --dry-run        チェックモード (変更なし)
  --vault <ファイル>   Vault パスワードファイル
  -e, --extra <変数>   追加変数 (key=value)

例:
  $PROG_NAME status
  $PROG_NAME ping all
  $PROG_NAME run site.yml --tags phase1
  $PROG_NAME check -l webservers
  $PROG_NAME facts web01
  $PROG_NAME adhoc "uptime" -l all
  $PROG_NAME lint site.yml
EOF
}

ansible_base_args() {
    local args=("-i" "$inventory_file")
    [[ -n "$vault_pass_file" ]] && args+=("--vault-password-file" "$vault_pass_file")
    [[ -n "$extra_vars" ]] && args+=("-e" "$extra_vars")
    echo "${args[@]}"
}

check_ansible() {
    if ! command -v ansible &>/dev/null; then
        error_exit "ansible が見つかりません。インストールしてください"
    fi
    if [[ ! -f "$inventory_file" ]]; then
        log_warning "インベントリファイルが見つかりません: $inventory_file"
    fi
}

parse_inventory() {
    local inv="$1"
    python3 - "$inv" <<'PYEOF'
import sys, re

inv_file = sys.argv[1]
try:
    with open(inv_file) as f:
        content = f.read()
except FileNotFoundError:
    print(f"  ファイルが見つかりません: {inv_file}")
    sys.exit(0)

GREEN  = "\033[1;32m"
CYAN   = "\033[1;36m"
YELLOW = "\033[1;33m"
RESET  = "\033[0m"
BOLD   = "\033[1m"

current_group = "ungrouped"
groups = {}
for line in content.splitlines():
    line = line.strip()
    if not line or line.startswith('#'):
        continue
    m = re.match(r'^\[([^\]]+)\]', line)
    if m:
        current_group = m.group(1)
        if ':vars' not in current_group and ':children' not in current_group:
            groups.setdefault(current_group, [])
    elif '=' not in line and current_group and ':vars' not in current_group and ':children' not in current_group:
        groups.setdefault(current_group, []).append(line.split()[0])

for group, hosts in sorted(groups.items()):
    print(f"  {CYAN}[{group}]{RESET}  ({len(hosts)} ホスト)")
    for h in hosts[:5]:
        print(f"    {YELLOW}•{RESET} {h}")
    if len(hosts) > 5:
        print(f"    {YELLOW}• ... 他 {len(hosts)-5} ホスト{RESET}")
PYEOF
}

cmd_status() {
    log_info "Ansible環境状況"
    echo ""

    local ansible_version
    ansible_version=$(ansible --version 2>/dev/null | head -1 || echo "N/A")
    printf "  %-20s %s\n" "Ansibleバージョン:" "$ansible_version"
    printf "  %-20s %s\n" "インベントリ:"      "$inventory_file"
    printf "  %-20s %s\n" "プレイブック:"      "$playbook_file"
    echo ""

    printf "${C_BOLD}【インベントリ構成】${C_RESET}\n\n"
    if [[ -f "$inventory_file" ]]; then
        parse_inventory "$inventory_file"
    else
        log_warning "インベントリファイルが見つかりません: $inventory_file"
    fi
    echo ""
}

cmd_ping() {
    local target="${1:-all}"
    log_info "Ping確認: $target"
    echo ""

    local base_args=()
    read -ra base_args <<< "$(ansible_base_args)"

    ansible "$target" "${base_args[@]}" -m ping 2>/dev/null | \
    while IFS= read -r line; do
        if echo "$line" | grep -q "SUCCESS"; then
            printf "${C_GREEN}%s${C_RESET}\n" "$line"
        elif echo "$line" | grep -q "FAILED\|UNREACHABLE"; then
            printf "${C_RED}%s${C_RESET}\n" "$line"
        else
            printf "${C_DIM}%s${C_RESET}\n" "$line"
        fi
    done
    echo ""
}

cmd_run() {
    local pb="${1:-$playbook_file}"
    [[ ! -f "$pb" ]] && error_exit "プレイブックが見つかりません: $pb"

    log_info "プレイブック実行: $pb"
    (( dry_run )) && log_warning "チェックモード: 実際には変更しません"
    echo ""

    local args=()
    read -ra args <<< "$(ansible_base_args)"
    [[ -n "$target_host" ]] && args+=("-l" "$target_host")
    [[ -n "$target_tag"  ]] && args+=("--tags" "$target_tag")
    (( dry_run ))            && args+=("--check")

    local start_time
    start_time=$(date +%s)

    ansible-playbook "$pb" "${args[@]}" 2>&1 | \
    while IFS= read -r line; do
        if echo "$line" | grep -q "^PLAY\|^TASK"; then
            printf "${C_BOLD}${C_CYAN}%s${C_RESET}\n" "$line"
        elif echo "$line" | grep -q "ok:"; then
            printf "${C_GREEN}%s${C_RESET}\n" "$line"
        elif echo "$line" | grep -q "changed:"; then
            printf "${C_YELLOW}%s${C_RESET}\n" "$line"
        elif echo "$line" | grep -q "failed:\|FAILED\|ERROR"; then
            printf "${C_RED}%s${C_RESET}\n" "$line"
        elif echo "$line" | grep -q "PLAY RECAP"; then
            printf "\n${C_BOLD}%s${C_RESET}\n" "$line"
        else
            printf "${C_DIM}%s${C_RESET}\n" "$line"
        fi
    done

    local end_time
    end_time=$(date +%s)
    echo ""
    log_success "完了: $(( end_time - start_time ))秒"
}

cmd_check() {
    dry_run=1
    cmd_run "${1:-$playbook_file}"
}

cmd_facts() {
    local host="${1:-}"
    [[ -z "$host" ]] && error_exit "ホストを指定してください"

    log_info "Facts収集: $host"
    echo ""

    local base_args=()
    read -ra base_args <<< "$(ansible_base_args)"

    ansible "$host" "${base_args[@]}" -m setup 2>/dev/null | \
    python3 - "$host" <<'PYEOF'
import sys, json, re

host = sys.argv[1]
content = sys.stdin.read()
m = re.search(r'\{.*\}', content, re.DOTALL)
if not m:
    print("  Factsを取得できませんでした")
    sys.exit(0)

try:
    data = json.loads(m.group(0))
    facts = data.get("ansible_facts", data)
except:
    print("  JSONパース失敗")
    sys.exit(0)

CYAN  = "\033[1;36m"
GREEN = "\033[1;32m"
RESET = "\033[0m"

interesting = [
    ("ホスト名",        "ansible_hostname"),
    ("OS",              "ansible_distribution"),
    ("OSバージョン",    "ansible_distribution_version"),
    ("カーネル",        "ansible_kernel"),
    ("アーキテクチャ",  "ansible_architecture"),
    ("CPU数",           "ansible_processor_vcpus"),
    ("メモリ(MB)",      "ansible_memtotal_mb"),
    ("IPアドレス",      "ansible_default_ipv4"),
    ("Python",          "ansible_python_version"),
]

for label, key in interesting:
    val = facts.get(key, "N/A")
    if isinstance(val, dict):
        val = val.get("address", val.get("interface", str(val)))
    print(f"  {CYAN}{label:<20}{RESET} {val}")
PYEOF
    echo ""
}

cmd_adhoc() {
    local cmd_str="${1:-}"
    [[ -z "$cmd_str" ]] && error_exit "実行するコマンドを指定してください"
    local target="${target_host:-all}"

    log_info "アドホックコマンド: $cmd_str (対象: $target)"
    echo ""

    local base_args=()
    read -ra base_args <<< "$(ansible_base_args)"

    ansible "$target" "${base_args[@]}" -m shell -a "$cmd_str" 2>/dev/null | \
    while IFS= read -r line; do
        if echo "$line" | grep -q "SUCCESS"; then
            printf "${C_GREEN}%s${C_RESET}\n" "$line"
        elif echo "$line" | grep -q "FAILED"; then
            printf "${C_RED}%s${C_RESET}\n" "$line"
        elif echo "$line" | grep -q "stdout:"; then
            printf "${C_CYAN}%s${C_RESET}\n" "$line"
        else
            printf "%s\n" "$line"
        fi
    done
    echo ""
}

cmd_lint() {
    local pb="${1:-$playbook_file}"
    log_info "構文チェック: $pb"
    echo ""

    local base_args=()
    read -ra base_args <<< "$(ansible_base_args)"

    if ansible-playbook "${base_args[@]}" --syntax-check "$pb" 2>&1; then
        log_success "構文チェック: 問題なし"
    else
        log_error "構文エラーが見つかりました"
    fi

    if command -v ansible-lint &>/dev/null; then
        echo ""
        log_info "ansible-lint 実行中..."
        ansible-lint "$pb" 2>&1 | head -30 || true
    fi
    echo ""
}

cmd_graph() {
    local pb="${1:-$playbook_file}"
    [[ ! -f "$pb" ]] && error_exit "プレイブックが見つかりません: $pb"

    log_info "タスクグラフ: $pb"
    echo ""

    local base_args=()
    read -ra base_args <<< "$(ansible_base_args)"

    ansible-playbook "${base_args[@]}" --list-tasks "$pb" 2>/dev/null | \
    while IFS= read -r line; do
        if echo "$line" | grep -q "^PLAY\|playbook:"; then
            printf "${C_BOLD}${C_CYAN}%s${C_RESET}\n" "$line"
        elif echo "$line" | grep -q "TASK\|task:"; then
            printf "  ${C_YELLOW}%s${C_RESET}\n" "$line"
        else
            printf "${C_DIM}%s${C_RESET}\n" "$line"
        fi
    done
    echo ""
}

parse_arguments() {
    [[ $# -eq 0 ]] && return 0
    case "$1" in
        status|ping|run|check|facts|adhoc|lint|graph)
            command_name="$1"; shift ;;
    esac

    local positional=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)     show_usage; exit 0 ;;
            -v|--version)  echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -i|--inventory) [[ $# -lt 2 ]] && error_exit "--inventory には値が必要です"; inventory_file="$2"; shift 2 ;;
            -p|--playbook) [[ $# -lt 2 ]] && error_exit "--playbook には値が必要です"; playbook_file="$2"; shift 2 ;;
            -l|--limit)    [[ $# -lt 2 ]] && error_exit "--limit には値が必要です"; target_host="$2"; shift 2 ;;
            -t|--tags)     [[ $# -lt 2 ]] && error_exit "--tags には値が必要です"; target_tag="$2"; shift 2 ;;
            -n|--dry-run)  dry_run=1; shift ;;
            --vault)       [[ $# -lt 2 ]] && error_exit "--vault には値が必要です"; vault_pass_file="$2"; shift 2 ;;
            -e|--extra)    [[ $# -lt 2 ]] && error_exit "--extra には値が必要です"; extra_vars="$2"; shift 2 ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  positional+=("$1"); shift ;;
        esac
    done
    POSITIONAL=("${positional[@]+"${positional[@]}"}")
}

declare -a POSITIONAL=()

main() {
    parse_arguments "$@"
    check_ansible
    case "$command_name" in
        status) cmd_status ;;
        ping)   cmd_ping   "${POSITIONAL[0]:-all}" ;;
        run)    cmd_run    "${POSITIONAL[0]:-$playbook_file}" ;;
        check)  cmd_check  "${POSITIONAL[0]:-$playbook_file}" ;;
        facts)  cmd_facts  "${POSITIONAL[0]:-}" ;;
        adhoc)  cmd_adhoc  "${POSITIONAL[0]:-}" ;;
        lint)   cmd_lint   "${POSITIONAL[0]:-$playbook_file}" ;;
        graph)  cmd_graph  "${POSITIONAL[0]:-$playbook_file}" ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
