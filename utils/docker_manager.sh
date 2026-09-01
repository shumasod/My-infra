#!/bin/bash
set -euo pipefail

#
# Dockerコンテナ管理ツール
# 作成日: 2026-09-01
# バージョン: 1.0
#
# Dockerコンテナ・イメージ・ボリュームの管理を支援します
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare command_name="status"
declare filter_name=""
declare follow_logs=0
declare tail_lines=50

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション]

Dockerコンテナ・イメージ・ボリュームの管理ツールです。

コマンド:
  status               コンテナ・リソース使用状況 (デフォルト)
  ps                   コンテナ一覧
  images               イメージ一覧
  logs <コンテナ>      コンテナログ表示
  stats                リソース使用状況 (リアルタイム)
  clean                未使用リソース削除
  volumes              ボリューム一覧
  networks             ネットワーク一覧
  inspect <コンテナ>   コンテナ詳細

オプション:
  -h, --help           このヘルプを表示
  -v, --version        バージョン情報を表示
  -n, --name <名前>    コンテナ名フィルタ
  -f, --follow         ログをフォロー
  -t, --tail <行数>    表示するログ行数 [デフォルト: 50]

例:
  $PROG_NAME status
  $PROG_NAME ps
  $PROG_NAME logs myapp -f
  $PROG_NAME clean
  $PROG_NAME inspect myapp
EOF
}

check_docker() {
    if ! command -v docker &>/dev/null; then
        error_exit "docker が見つかりません。インストールしてください"
    fi
    if ! docker info &>/dev/null 2>&1; then
        error_exit "Dockerデーモンが起動していません"
    fi
}

bytes_to_human() {
    python3 -c "
import sys
b = float(sys.argv[1])
for u in ['B','KB','MB','GB','TB']:
    if b < 1024: print(f'{b:.1f}{u}'); break
    b /= 1024
" "$1" 2>/dev/null || echo "${1}B"
}

cmd_status() {
    log_info "Docker環境状況"
    echo ""

    local total running stopped
    total=$(docker ps -a --format '{{.ID}}' | wc -l)
    running=$(docker ps --format '{{.ID}}' | wc -l)
    stopped=$(( total - running ))

    local images volumes
    images=$(docker images --format '{{.ID}}' | wc -l)
    volumes=$(docker volume ls --format '{{.Name}}' | wc -l)

    printf "  %-20s ${C_BOLD}%s${C_RESET}\n" "コンテナ(合計):" "$total"
    printf "  %-20s ${C_GREEN}%s${C_RESET}\n"  "  実行中:"       "$running"
    printf "  %-20s ${C_DIM}%s${C_RESET}\n"    "  停止中:"       "$stopped"
    printf "  %-20s %s\n"                       "イメージ:"       "$images"
    printf "  %-20s %s\n"                       "ボリューム:"     "$volumes"
    echo ""

    if [[ "$running" -gt 0 ]]; then
        printf "${C_BOLD}【実行中コンテナ】${C_RESET}\n\n"
        docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" | \
        while IFS= read -r line; do
            if echo "$line" | grep -q "^NAMES"; then
                printf "${C_CYAN}%s${C_RESET}\n" "$line"
            elif echo "$line" | grep -q "Up"; then
                printf "${C_GREEN}%s${C_RESET}\n" "$line"
            else
                printf "%s\n" "$line"
            fi
        done
    fi
    echo ""
}

cmd_ps() {
    log_info "コンテナ一覧"
    echo ""

    local args=("-a")
    [[ -n "$filter_name" ]] && args+=("--filter" "name=$filter_name")

    docker ps "${args[@]}" --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Size}}" | \
    while IFS= read -r line; do
        if echo "$line" | grep -q "^NAMES"; then
            printf "${C_BOLD}${C_CYAN}%s${C_RESET}\n" "$line"
        elif echo "$line" | grep -q " Up "; then
            printf "${C_GREEN}%s${C_RESET}\n" "$line"
        elif echo "$line" | grep -q "Exited"; then
            printf "${C_DIM}%s${C_RESET}\n" "$line"
        else
            printf "%s\n" "$line"
        fi
    done
    echo ""
}

cmd_images() {
    log_info "イメージ一覧"
    echo ""

    docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}" | \
    while IFS= read -r line; do
        if echo "$line" | grep -q "^REPOSITORY"; then
            printf "${C_BOLD}${C_CYAN}%s${C_RESET}\n" "$line"
        elif echo "$line" | grep -q "<none>"; then
            printf "${C_DIM}%s${C_RESET}\n" "$line"
        else
            printf "%s\n" "$line"
        fi
    done
    echo ""
}

cmd_logs() {
    local container="${1:-}"
    [[ -z "$container" ]] && error_exit "コンテナ名を指定してください"

    log_info "ログ: $container (直近 $tail_lines 行)"
    echo ""

    local args=("--tail" "$tail_lines" "--timestamps")
    (( follow_logs )) && args+=("--follow")

    docker logs "${args[@]}" "$container" 2>&1 | \
    while IFS= read -r line; do
        if echo "$line" | grep -iq "error\|exception\|fatal"; then
            printf "${C_RED}%s${C_RESET}\n" "$line"
        elif echo "$line" | grep -iq "warn"; then
            printf "${C_YELLOW}%s${C_RESET}\n" "$line"
        else
            printf "%s\n" "$line"
        fi
    done
}

cmd_stats() {
    log_info "リソース使用状況 (Ctrl+C で終了)"
    echo ""
    docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"
}

cmd_clean() {
    log_info "未使用Dockerリソース確認"
    echo ""

    local stopped_count
    stopped_count=$(docker ps -a -q --filter status=exited | wc -l)
    local dangling_count
    dangling_count=$(docker images -q --filter dangling=true | wc -l)
    local unused_vol
    unused_vol=$(docker volume ls -q --filter dangling=true | wc -l)

    printf "  停止中コンテナ: %s\n" "$stopped_count"
    printf "  dangling イメージ: %s\n" "$dangling_count"
    printf "  未使用ボリューム: %s\n" "$unused_vol"
    echo ""

    if ! confirm "未使用リソースを削除しますか？"; then
        log_info "キャンセルしました"
        return
    fi

    log_info "削除中..."
    docker system prune -f 2>&1 | tail -5
    log_success "クリーンアップ完了"
    echo ""
}

cmd_volumes() {
    log_info "ボリューム一覧"
    echo ""
    docker volume ls --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}" | \
    while IFS= read -r line; do
        if echo "$line" | grep -q "^VOLUME"; then
            printf "${C_BOLD}${C_CYAN}%s${C_RESET}\n" "$line"
        else
            printf "%s\n" "$line"
        fi
    done
    echo ""
}

cmd_networks() {
    log_info "ネットワーク一覧"
    echo ""
    docker network ls --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}" | \
    while IFS= read -r line; do
        if echo "$line" | grep -q "^NETWORK"; then
            printf "${C_BOLD}${C_CYAN}%s${C_RESET}\n" "$line"
        elif echo "$line" | grep -q "bridge\|host\|none"; then
            printf "${C_DIM}%s${C_RESET}\n" "$line"
        else
            printf "${C_GREEN}%s${C_RESET}\n" "$line"
        fi
    done
    echo ""
}

cmd_inspect() {
    local container="${1:-}"
    [[ -z "$container" ]] && error_exit "コンテナ名を指定してください"

    log_info "コンテナ詳細: $container"
    echo ""

    docker inspect "$container" 2>/dev/null | python3 - "$container" <<'PYEOF'
import sys, json

container = sys.argv[1]
content = sys.stdin.read()
try:
    data = json.loads(content)[0]
except:
    print("  コンテナ情報を取得できませんでした")
    sys.exit(0)

CYAN  = "\033[1;36m"
GREEN = "\033[1;32m"
RESET = "\033[0m"

def p(label, val):
    print(f"  {CYAN}{label:<22}{RESET} {val}")

cfg = data.get("Config", {})
state = data.get("State", {})
net = data.get("NetworkSettings", {})
mounts = data.get("Mounts", [])

p("名前",       data.get("Name", "").lstrip("/"))
p("イメージ",   cfg.get("Image", "N/A"))
p("状態",       state.get("Status", "N/A"))
p("開始時刻",   state.get("StartedAt", "N/A")[:19])
p("再起動回数", state.get("RestartCount", 0))
p("IPアドレス", net.get("IPAddress", "N/A"))

ports = net.get("Ports", {})
port_list = [f"{h[0]['HostPort']}->{c}" for c, h in ports.items() if h]
p("ポートマッピング", ", ".join(port_list) or "なし")

envs = [e for e in cfg.get("Env", []) if not any(s in e for s in ["PASSWORD","SECRET","TOKEN","KEY"])]
if envs:
    print(f"\n  {CYAN}環境変数:{RESET}")
    for e in envs[:8]:
        print(f"    {e}")

if mounts:
    print(f"\n  {CYAN}マウント:{RESET}")
    for m in mounts[:5]:
        print(f"    {m.get('Source','')} -> {m.get('Destination','')}")
PYEOF
    echo ""
}

parse_arguments() {
    [[ $# -eq 0 ]] && return 0
    case "$1" in
        status|ps|images|logs|stats|clean|volumes|networks|inspect)
            command_name="$1"; shift ;;
    esac

    local positional=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)     show_usage; exit 0 ;;
            -v|--version)  echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -n|--name)     [[ $# -lt 2 ]] && error_exit "--name には値が必要です"; filter_name="$2"; shift 2 ;;
            -f|--follow)   follow_logs=1; shift ;;
            -t|--tail)     [[ $# -lt 2 ]] && error_exit "--tail には値が必要です"; tail_lines="$2"; shift 2 ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  positional+=("$1"); shift ;;
        esac
    done
    POSITIONAL=("${positional[@]+"${positional[@]}"}")
}

declare -a POSITIONAL=()

main() {
    parse_arguments "$@"
    check_docker
    case "$command_name" in
        status)   cmd_status ;;
        ps)       cmd_ps ;;
        images)   cmd_images ;;
        logs)     cmd_logs     "${POSITIONAL[0]:-}" ;;
        stats)    cmd_stats ;;
        clean)    cmd_clean ;;
        volumes)  cmd_volumes ;;
        networks) cmd_networks ;;
        inspect)  cmd_inspect  "${POSITIONAL[0]:-}" ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
