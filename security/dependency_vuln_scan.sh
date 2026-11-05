#!/bin/bash
set -euo pipefail

#
# 依存関係脆弱性スキャナー
# 作成日: 2026-11-05
# バージョン: 1.0
#
# 脆弱性対応: 依存パッケージの既知脆弱性検出
# CVE該当: CWE-1104 (Use of Unmaintained Third Party Components)
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare command_name="scan"

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション]

依存関係の脆弱性をスキャンします。

コマンド:
  scan                 全依存関係スキャン (デフォルト)
  check-outdated       古いパッケージの確認
  audit                セキュリティ監査
  report               詳細レポート生成
  tools                ツールバージョン確認

オプション:
  -h, --help           このヘルプを表示
  -v, --version        バージョン情報を表示

脆弱性概要:
  CWE-1104: メンテナンスされていないサードパーティコンポーネント使用
  対策: 定期的なパッケージ更新・CVE追跡
EOF
}

detect_package_manager() {
    if command -v apt &>/dev/null; then echo "apt"
    elif command -v yum &>/dev/null; then echo "yum"
    elif command -v dnf &>/dev/null; then echo "dnf"
    elif command -v pacman &>/dev/null; then echo "pacman"
    elif command -v zypper &>/dev/null; then echo "zypper"
    else echo "unknown"
    fi
}

cmd_scan() {
    log_info "依存関係脆弱性スキャン"
    echo ""

    local pkg_mgr
    pkg_mgr=$(detect_package_manager)
    printf "  パッケージマネージャー: ${C_CYAN}%s${C_RESET}\n\n" "$pkg_mgr"

    # システムパッケージの脆弱性確認
    printf "${C_BOLD}【システムパッケージ脆弱性】${C_RESET}\n\n"
    case "$pkg_mgr" in
        apt)
            if command -v apt-get &>/dev/null; then
                local upgradable
                upgradable=$(apt-get --simulate upgrade 2>/dev/null | grep "^Inst" | wc -l || echo 0)
                printf "  アップグレード可能なパッケージ: "
                if [[ "$upgradable" -gt 0 ]]; then
                    printf "${C_YELLOW}%s 件${C_RESET}\n" "$upgradable"
                else
                    printf "${C_GREEN}0 件${C_RESET}\n"
                fi

                # セキュリティアップデート
                local security_updates
                security_updates=$(apt-get --simulate upgrade 2>/dev/null | grep -i "security" | wc -l || echo 0)
                printf "  セキュリティアップデート: "
                if [[ "$security_updates" -gt 0 ]]; then
                    printf "${C_RED}%s 件 (要対応)${C_RESET}\n" "$security_updates"
                else
                    printf "${C_GREEN}0 件${C_RESET}\n"
                fi
            fi
            ;;
        yum|dnf)
            local updates
            updates=$($pkg_mgr check-update 2>/dev/null | grep -c "^\w" || echo 0)
            printf "  更新可能なパッケージ: %s 件\n" "$updates"
            ;;
    esac
    echo ""

    # Python依存関係
    cmd_python_audit
    # Node.js依存関係
    cmd_node_audit
    # Docker イメージ
    cmd_docker_audit
}

cmd_python_audit() {
    printf "${C_BOLD}【Python パッケージ確認】${C_RESET}\n\n"

    if ! command -v pip3 &>/dev/null && ! command -v pip &>/dev/null; then
        printf "  ${C_DIM}pip が見つかりません${C_RESET}\n\n"
        return
    fi

    local pip_cmd="pip3"
    command -v pip3 &>/dev/null || pip_cmd="pip"

    # 既知の脆弱性を持つパッケージリスト
    python3 - <<'PYEOF'
import subprocess, re

RED    = "\033[1;31m"
YELLOW = "\033[1;33m"
GREEN  = "\033[1;32m"
RESET  = "\033[0m"

# 既知の脆弱バージョン (簡易データベース)
known_vulnerable = {
    'requests':      ('2.28.0', 'HTTPSリクエスト検証の問題'),
    'urllib3':       ('1.26.5', 'SSRF・ヘッダインジェクション'),
    'pyyaml':        ('5.4',    'RCE脆弱性 (yaml.load)'),
    'paramiko':      ('2.7.2',  '認証バイパス'),
    'cryptography':  ('3.4.6',  '暗号実装の問題'),
    'pillow':        ('9.0',    '画像解析の脆弱性'),
    'django':        ('3.2',    'SQLインジェクション'),
    'flask':         ('2.0',    'セッション固定'),
    'sqlalchemy':    ('1.4',    'SQLインジェクション'),
    'jinja2':        ('3.0',    'サンドボックスエスケープ'),
    'setuptools':    ('65.5.1', 'コードインジェクション'),
    'wheel':         ('0.38.1', 'パス操作'),
}

try:
    result = subprocess.run(['pip3', 'list', '--format=columns'],
                           capture_output=True, text=True, timeout=30)
    if result.returncode != 0:
        result = subprocess.run(['pip', 'list', '--format=columns'],
                               capture_output=True, text=True, timeout=30)

    installed = {}
    for line in result.stdout.splitlines()[2:]:
        parts = line.split()
        if len(parts) >= 2:
            installed[parts[0].lower()] = parts[1]

    found_vuln = False
    for pkg, (min_ver, desc) in known_vulnerable.items():
        if pkg in installed:
            ver = installed[pkg]
            # 簡易バージョン比較
            try:
                from packaging import version
                if version.parse(ver) < version.parse(min_ver):
                    print(f"  {RED}[脆弱]{RESET} {pkg} {ver} < {min_ver}: {desc}")
                    found_vuln = True
            except ImportError:
                print(f"  {YELLOW}[要確認]{RESET} {pkg} {ver} (推奨: {min_ver}+): {desc}")
                found_vuln = True

    if not found_vuln:
        print(f"  {GREEN}既知の脆弱パッケージは検出されませんでした{RESET}")

    print(f"\n  インストール済みパッケージ数: {len(installed)}")

except Exception as e:
    print(f"  確認失敗: {e}")
PYEOF
    echo ""
}

cmd_node_audit() {
    printf "${C_BOLD}【Node.js パッケージ確認】${C_RESET}\n\n"

    if ! command -v npm &>/dev/null; then
        printf "  ${C_DIM}npm が見つかりません${C_RESET}\n\n"
        return
    fi

    # package.json を探してnpm auditを実行
    local pkg_json_count
    pkg_json_count=$(find . -name "package.json" -not -path "*/node_modules/*" 2>/dev/null | wc -l)

    if [[ "$pkg_json_count" -eq 0 ]]; then
        printf "  ${C_DIM}package.json が見つかりません${C_RESET}\n\n"
        return
    fi

    printf "  package.json: %s 件検出\n" "$pkg_json_count"
    find . -name "package.json" -not -path "*/node_modules/*" 2>/dev/null | head -3 | \
    while IFS= read -r pkgjson; do
        local dir
        dir=$(dirname "$pkgjson")
        printf "  スキャン: %s\n" "$pkgjson"
        if [[ -d "$dir/node_modules" ]]; then
            local audit_result
            audit_result=$(cd "$dir" && npm audit --json 2>/dev/null | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    vulns = data.get('metadata', {}).get('vulnerabilities', {})
    total = sum(vulns.values())
    if total > 0:
        print(f'    脆弱性: 合計{total}件 (critical:{vulns.get(\"critical\",0)}, high:{vulns.get(\"high\",0)})')
    else:
        print('    脆弱性なし')
except: print('    監査結果解析失敗')
" 2>/dev/null || echo "    npm audit 実行失敗")
            echo "$audit_result"
        fi
    done
    echo ""
}

cmd_docker_audit() {
    printf "${C_BOLD}【Docker イメージ確認】${C_RESET}\n\n"

    if ! command -v docker &>/dev/null; then
        printf "  ${C_DIM}Docker が見つかりません${C_RESET}\n\n"
        return
    fi

    if ! docker info &>/dev/null 2>&1; then
        printf "  ${C_DIM}Dockerデーモンが起動していません${C_RESET}\n\n"
        return
    fi

    local image_count
    image_count=$(docker images --format "{{.Repository}}" 2>/dev/null | wc -l)
    printf "  ローカルイメージ数: %s\n\n" "$image_count"

    # 古いイメージの確認
    printf "  ${C_BOLD}古いイメージ (30日以上):${C_RESET}\n"
    docker images --format "{{.Repository}}:{{.Tag}}\t{{.CreatedSince}}" 2>/dev/null | \
    grep -E "[0-9]+ months? ago|[0-9]+ years? ago" | head -10 | \
    while IFS=$'\t' read -r name age; do
        printf "  ${C_YELLOW}[古い]${C_RESET} %-40s %s\n" "$name" "$age"
    done || printf "  ${C_GREEN}古いイメージなし${C_RESET}\n"
    echo ""
}

cmd_check_outdated() {
    log_info "古いパッケージ確認"
    echo ""

    local pkg_mgr
    pkg_mgr=$(detect_package_manager)

    case "$pkg_mgr" in
        apt)
            printf "${C_BOLD}【apt アップグレード可能パッケージ (上位20件)】${C_RESET}\n\n"
            apt list --upgradable 2>/dev/null | grep -v "^Listing" | head -20 | \
            while IFS= read -r line; do
                if echo "$line" | grep -qi "security"; then
                    printf "  ${C_RED}[セキュリティ]${C_RESET} %s\n" "$line"
                else
                    printf "  ${C_YELLOW}[更新あり]${C_RESET} %s\n" "$line"
                fi
            done
            ;;
        yum|dnf)
            printf "${C_BOLD}【%s アップデート可能パッケージ】${C_RESET}\n\n" "$pkg_mgr"
            $pkg_mgr list updates 2>/dev/null | tail -n +2 | head -20 | \
            while IFS= read -r line; do
                printf "  %s\n" "$line"
            done
            ;;
        *)
            log_warning "パッケージマネージャーがサポートされていません: $pkg_mgr"
            ;;
    esac
    echo ""
}

cmd_tools() {
    log_info "主要ツールのバージョン確認"
    echo ""

    local tools=(
        "bash:シェル"
        "openssl:SSL/TLS"
        "ssh:SSH"
        "curl:HTTPクライアント"
        "wget:ファイルダウンロード"
        "git:バージョン管理"
        "python3:Python"
        "pip3:Pythonパッケージ"
        "node:Node.js"
        "npm:npm"
        "docker:コンテナ"
        "ansible:構成管理"
    )

    for entry in "${tools[@]}"; do
        local cmd="${entry%%:*}"
        local desc="${entry##*:}"
        if command -v "$cmd" &>/dev/null; then
            local ver
            ver=$("$cmd" --version 2>&1 | head -1 | grep -oE '[0-9]+\.[0-9]+\.?[0-9]*' | head -1 || echo "不明")
            printf "  ${C_GREEN}%-12s${C_RESET} %-20s %s\n" "$cmd" "($desc)" "$ver"
        else
            printf "  ${C_DIM}%-12s${C_RESET} %-20s 未インストール\n" "$cmd" "($desc)"
        fi
    done
    echo ""
}

parse_arguments() {
    [[ $# -eq 0 ]] && return 0
    case "$1" in
        scan|check-outdated|audit|report|tools)
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
        scan)           cmd_scan ;;
        check-outdated) cmd_check_outdated ;;
        audit)          cmd_scan ;;
        report)         cmd_scan; cmd_tools ;;
        tools)          cmd_tools ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
