#!/bin/bash
set -euo pipefail

#
# Dockerセキュリティ監査ツール
# 作成日: 2026-11-05
# バージョン: 1.0
#
# 脆弱性対応: Dockerコンテナ・イメージのセキュリティ検査
# CVE該当: CWE-250 (Unnecessary Privileges), CWE-732 (Incorrect Permission Assignment)
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare command_name="audit"

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション]

Dockerセキュリティを監査します。

コマンド:
  audit       全体監査 (デフォルト)
  images      イメージのセキュリティ確認
  containers  実行中コンテナのセキュリティ確認
  compose     docker-composeファイルの検査
  secrets     機密情報の検出
  socket      Dockerソケットの露出確認

オプション:
  -h, --help     このヘルプを表示
  -v, --version  バージョン情報を表示

脆弱性概要:
  - 特権コンテナ (--privileged)
  - rootユーザーでの実行
  - Dockerソケットのマウント
  - 機密情報の環境変数設定
EOF
}

check_docker() {
    if ! command -v docker &>/dev/null; then
        log_warning "Dockerがインストールされていません"
        return 1
    fi
    if ! docker info &>/dev/null 2>&1; then
        log_warning "Dockerデーモンが起動していません"
        return 1
    fi
    return 0
}

cmd_audit() {
    log_info "Dockerセキュリティ総合監査"
    echo ""
    check_docker || return
    cmd_containers
    cmd_images
    cmd_socket
}

cmd_containers() {
    log_info "実行中コンテナのセキュリティ確認"
    echo ""
    check_docker || return

    local containers
    containers=$(docker ps -q 2>/dev/null)
    if [[ -z "$containers" ]]; then
        printf "  ${C_DIM}実行中のコンテナなし${C_RESET}\n\n"
        return
    fi

    while IFS= read -r cid; do
        local name image user privileged
        name=$(docker inspect --format '{{.Name}}' "$cid" 2>/dev/null | tr -d '/')
        image=$(docker inspect --format '{{.Config.Image}}' "$cid" 2>/dev/null)
        user=$(docker inspect --format '{{.Config.User}}' "$cid" 2>/dev/null)
        privileged=$(docker inspect --format '{{.HostConfig.Privileged}}' "$cid" 2>/dev/null)

        printf "${C_BOLD}コンテナ: %s (%s)${C_RESET}\n" "$name" "$image"

        # 特権コンテナ
        if [[ "$privileged" == "true" ]]; then
            printf "  ${C_RED}[CRITICAL] --privileged フラグが有効 (ホストアクセス可能)${C_RESET}\n"
        else
            printf "  ${C_GREEN}[OK] 非特権モード${C_RESET}\n"
        fi

        # rootユーザー確認
        if [[ -z "$user" || "$user" == "root" || "$user" == "0" ]]; then
            printf "  ${C_RED}[HIGH] rootユーザーで実行中${C_RESET}\n"
        else
            printf "  ${C_GREEN}[OK] ユーザー: %s${C_RESET}\n" "$user"
        fi

        # Dockerソケットマウント
        local sock_mount
        sock_mount=$(docker inspect --format '{{range .Mounts}}{{.Source}}{{"\n"}}{{end}}' "$cid" 2>/dev/null | grep "docker.sock" || true)
        if [[ -n "$sock_mount" ]]; then
            printf "  ${C_RED}[CRITICAL] Dockerソケットがマウントされています${C_RESET}\n"
        fi

        # 機密情報の環境変数
        local sensitive_envs
        sensitive_envs=$(docker inspect --format '{{range .Config.Env}}{{.}}{{"\n"}}{{end}}' "$cid" 2>/dev/null | \
            grep -iE "password|secret|key|token" | grep -v "^\s*#" | \
            sed 's/=.*/=***MASKED***/' || true)
        if [[ -n "$sensitive_envs" ]]; then
            printf "  ${C_YELLOW}[MEDIUM] 機密情報が環境変数に設定されています:\n${C_RESET}"
            echo "$sensitive_envs" | while IFS= read -r line; do
                printf "    %s\n" "$line"
            done
        fi

        # ケイパビリティ確認
        local caps
        caps=$(docker inspect --format '{{.HostConfig.CapAdd}}' "$cid" 2>/dev/null)
        if [[ "$caps" != "[]" && -n "$caps" ]]; then
            printf "  ${C_YELLOW}[MEDIUM] 追加ケイパビリティ: %s${C_RESET}\n" "$caps"
        fi

        echo ""
    done <<< "$containers"
}

cmd_images() {
    log_info "Dockerイメージのセキュリティ確認"
    echo ""
    check_docker || return

    # latest タグの使用確認
    printf "${C_BOLD}【latestタグの使用】${C_RESET}\n"
    local latest_count
    latest_count=$(docker images --format "{{.Repository}}:{{.Tag}}" 2>/dev/null | grep -c ":latest" || true)
    if [[ "$latest_count" -gt 0 ]]; then
        printf "  ${C_YELLOW}[MEDIUM] latestタグのイメージ: %d件 (固定バージョン推奨)${C_RESET}\n" "$latest_count"
        docker images --format "{{.Repository}}:{{.Tag}}" 2>/dev/null | grep ":latest" | \
        while IFS= read -r img; do
            printf "    • %s\n" "$img"
        done
    else
        printf "  ${C_GREEN}[OK] latestタグなし${C_RESET}\n"
    fi

    echo ""
    printf "${C_BOLD}【古いイメージ (30日以上)】${C_RESET}\n"
    docker images --format "{{.Repository}}:{{.Tag}}\t{{.CreatedSince}}" 2>/dev/null | \
    grep -E "[0-9]+ months? ago|[0-9]+ years? ago" | head -10 | \
    while IFS=$'\t' read -r img age; do
        printf "  ${C_YELLOW}[INFO]${C_RESET} %-40s %s\n" "$img" "$age"
    done || printf "  ${C_GREEN}[OK] 古いイメージなし${C_RESET}\n"
    echo ""
}

cmd_compose() {
    log_info "docker-composeファイルのセキュリティ検査"
    echo ""

    local compose_files
    while IFS= read -r f; do
        printf "${C_BOLD}%s${C_RESET}\n" "$f"

        python3 - "$f" <<'PYEOF'
import sys, re

filepath = sys.argv[1]
try:
    with open(filepath) as f:
        content = f.read()
        lines = content.splitlines()
except:
    sys.exit(0)

RED    = "\033[1;31m"
YELLOW = "\033[1;33m"
GREEN  = "\033[1;32m"
RESET  = "\033[0m"

checks = [
    (r'privileged:\s*true',                        "特権モード有効",          "CRITICAL"),
    (r'/var/run/docker\.sock',                      "Dockerソケットマウント",  "CRITICAL"),
    (r'user:\s*root',                              "rootユーザー指定",        "HIGH"),
    (r'(?:password|secret|key):\s*[^\$\{][^\s]+', "機密情報のハードコード",  "HIGH"),
    (r'network_mode:\s*host',                      "ホストネットワークモード", "HIGH"),
    (r'pid:\s*host',                               "ホストPIDネームスペース", "HIGH"),
    (r'- SYS_ADMIN',                              "SYS_ADMINケイパビリティ", "HIGH"),
    (r'- NET_ADMIN',                              "NET_ADMINケイパビリティ", "MEDIUM"),
    (r'read_only:\s*false',                        "書き込み可能ファイルシステム", "LOW"),
]

findings = []
for i, line in enumerate(lines, 1):
    for pat, desc, sev in checks:
        if re.search(pat, line, re.IGNORECASE):
            findings.append((i, line.strip(), desc, sev))
            break

if findings:
    for lineno, line, desc, sev in findings:
        color = "\033[1;35m" if sev == "CRITICAL" else (RED if sev == "HIGH" else YELLOW)
        print(f"  {color}[{sev}]{RESET} 行{lineno}: {desc}")
        print(f"    {line[:80]}")
else:
    print(f"  {GREEN}[OK] セキュリティ問題なし{RESET}")
PYEOF
        echo ""
    done < <(find . -name "docker-compose*.yml" -o -name "docker-compose*.yaml" 2>/dev/null)
}

cmd_secrets() {
    log_info "Dockerfileの機密情報検出"
    echo ""

    local found=0
    while IFS= read -r dockerfile; do
        local result
        result=$(python3 - "$dockerfile" <<'PYEOF'
import sys, re

filepath = sys.argv[1]
try:
    with open(filepath) as f:
        lines = f.readlines()
except:
    sys.exit(0)

RED    = "\033[1;31m"
YELLOW = "\033[1;33m"
RESET  = "\033[0m"

patterns = [
    (r'(?i)(?:password|passwd|secret|token|key|api_key)\s*=\s*\S+', "機密情報の直接設定", "CRITICAL"),
    (r'(?i)ARG\s+(?:password|secret|token|key)\s*=', "機密ARG変数のデフォルト値", "HIGH"),
    (r'(?i)ENV\s+(?:password|secret|token|key)\s+\S+', "機密ENV変数のハードコード", "HIGH"),
    (r'(?i)RUN\s+.*(?:curl|wget).*(?:password|token)=', "コマンドに機密情報", "HIGH"),
    (r'ADD\s+.*\.(?:key|pem|p12|pfx)', "秘密鍵ファイルの追加", "CRITICAL"),
    (r'COPY\s+.*\.(?:key|pem|p12|pfx)', "秘密鍵ファイルのコピー", "CRITICAL"),
]

findings = []
for i, line in enumerate(lines, 1):
    s = line.rstrip()
    if s.lstrip().startswith('#'):
        continue
    for pat, desc, sev in patterns:
        if re.search(pat, s):
            findings.append((i, s.strip(), desc, sev))
            break

for lineno, line, desc, sev in findings:
    color = "\033[1;35m" if sev == "CRITICAL" else RED
    print(f"  {color}[{sev}]{RESET} 行{lineno}: {desc}")
    print(f"    {line[:80]}")
PYEOF
)
        if [[ -n "$result" ]]; then
            (( found++ ))
            printf "${C_BOLD}%s${C_RESET}\n" "$dockerfile"
            echo "$result"
            echo ""
        fi
    done < <(find . -name "Dockerfile*" -type f 2>/dev/null)

    [[ "$found" -eq 0 ]] && log_success "Dockerfileに機密情報なし"
    echo ""
}

cmd_socket() {
    log_info "Dockerソケット露出確認"
    echo ""

    local sock="/var/run/docker.sock"
    if [[ -S "$sock" ]]; then
        local perms owner
        perms=$(stat -c "%a" "$sock" 2>/dev/null || echo "???")
        owner=$(stat -c "%U:%G" "$sock" 2>/dev/null || echo "???")
        printf "  Dockerソケット: %s\n" "$sock"
        printf "  パーミッション: %s\n" "$perms"
        printf "  所有者: %s\n" "$owner"

        # world-readable/writable チェック
        if [[ "${perms: -1}" -ge 6 ]] 2>/dev/null; then
            printf "  ${C_RED}[CRITICAL] Dockerソケットが全ユーザーからアクセス可能${C_RESET}\n"
        else
            printf "  ${C_GREEN}[OK] アクセス制限あり${C_RESET}\n"
        fi

        # コンテナからマウントされているか確認
        if check_docker 2>/dev/null; then
            local mounted_containers
            mounted_containers=$(docker ps -q 2>/dev/null | xargs -I{} docker inspect --format '{{.Name}} {{range .Mounts}}{{.Source}}{{end}}' {} 2>/dev/null | grep "docker.sock" || true)
            if [[ -n "$mounted_containers" ]]; then
                printf "  ${C_RED}[CRITICAL] ソケットをマウントしているコンテナ:${C_RESET}\n"
                echo "$mounted_containers" | while IFS= read -r line; do
                    printf "    %s\n" "$line"
                done
            fi
        fi
    else
        printf "  ${C_DIM}Dockerソケットが見つかりません${C_RESET}\n"
    fi
    echo ""
}

parse_arguments() {
    [[ $# -eq 0 ]] && return 0
    case "$1" in
        audit|images|containers|compose|secrets|socket)
            command_name="$1"; shift ;;
    esac
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -*) error_exit "不明なオプション: $1" ;;
            *) shift ;;
        esac
    done
}

main() {
    parse_arguments "$@"
    case "$command_name" in
        audit)      cmd_audit ;;
        images)     cmd_images ;;
        containers) cmd_containers ;;
        compose)    cmd_compose ;;
        secrets)    cmd_secrets ;;
        socket)     cmd_socket ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
