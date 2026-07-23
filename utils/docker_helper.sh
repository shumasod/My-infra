#!/bin/bash
set -euo pipefail

#
# Dockerヘルパーツール
# バージョン: 1.0
#
# Dockerコンテナ・イメージ・ボリュームの管理を簡略化するツール
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare action=""
declare filter=""
declare container=""

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME <アクション> [オプション]

Dockerヘルパーツール

アクション:
  ps        コンテナ一覧 (見やすく整形)
  images    イメージ一覧
  stats     コンテナリソース使用状況
  logs      コンテナログ表示
  clean     不要リソース一括削除
  inspect   コンテナ詳細情報
  exec      コンテナ内でコマンド実行
  compose   docker compose 操作

オプション:
  -h, --help            このヘルプを表示
  -v, --version         バージョン情報を表示
  -f, --filter FILTER   フィルター (name/image/status)
  -c, --container NAME  対象コンテナ名/ID

例:
  $PROG_NAME ps
  $PROG_NAME stats
  $PROG_NAME logs -c myapp
  $PROG_NAME clean
  $PROG_NAME exec -c myapp bash

EOF
}

check_docker() {
    if ! command -v docker &>/dev/null; then
        error_exit "docker コマンドが見つかりません"
    fi
    if ! docker info &>/dev/null; then
        error_exit "Docker デーモンが起動していません"
    fi
}

do_ps() {
    log_info "コンテナ一覧"
    echo ""
    printf "  %-20s %-30s %-15s %-20s %s\n" \
        "コンテナ名" "イメージ" "状態" "作成日" "ポート"
    printf "  %s\n" "$(printf '%.0s-' {1..95})"

    docker ps -a --format "{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.CreatedAt}}\t{{.Ports}}" | \
    while IFS=$'\t' read -r name image status created ports; do
        local status_color
        case "$status" in
            Up*)      status_color="$C_GREEN" ;;
            Exited*)  status_color="$C_RED" ;;
            Paused*)  status_color="$C_YELLOW" ;;
            *)        status_color="$C_DIM" ;;
        esac

        printf "  %-20s %-30s %b%-15s%b %-20s %s\n" \
            "${name:0:18}" "${image:0:28}" \
            "$status_color" "${status:0:13}" "$C_RESET" \
            "${created:0:18}" "${ports:0:30}"
    done
    echo ""
}

do_images() {
    log_info "イメージ一覧"
    echo ""
    printf "  %-30s %-15s %-15s %s\n" "リポジトリ" "タグ" "サイズ" "作成日"
    printf "  %s\n" "$(printf '%.0s-' {1..75})"

    docker images --format "{{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}" | \
    while IFS=$'\t' read -r repo tag size created; do
        printf "  %-30s %-15s %-15s %s\n" \
            "${repo:0:28}" "${tag:0:13}" "$size" "${created:0:20}"
    done
    echo ""
}

do_stats() {
    log_info "コンテナリソース使用状況 (Ctrl+C で終了)"
    echo ""
    docker stats --format \
        "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}"
}

do_logs() {
    [[ -z "$container" ]] && error_exit "--container でコンテナ名を指定してください"
    log_info "ログ: $container"
    docker logs --tail 100 -f "$container"
}

do_clean() {
    log_warning "不要なDockerリソースを削除します"
    echo ""

    local stopped_containers
    stopped_containers=$(docker ps -aq --filter status=exited | wc -l)
    local dangling_images
    dangling_images=$(docker images -f dangling=true -q | wc -l)
    local unused_volumes
    unused_volumes=$(docker volume ls -f dangling=true -q | wc -l)

    printf "  停止済みコンテナ: %d\n" "$stopped_containers"
    printf "  未使用イメージ:   %d\n" "$dangling_images"
    printf "  未使用ボリューム: %d\n" "$unused_volumes"
    echo ""

    printf "削除しますか? [y/N]: "
    local ans; read -r ans
    [[ ! "$ans" =~ ^[yY]$ ]] && { log_info "キャンセルしました"; return; }

    docker system prune -f
    log_success "クリーンアップ完了"
    docker system df
}

do_inspect() {
    [[ -z "$container" ]] && error_exit "--container でコンテナ名を指定してください"
    log_info "詳細情報: $container"
    echo ""

    local info
    info=$(docker inspect "$container" 2>/dev/null) || error_exit "コンテナが見つかりません: $container"

    echo "$info" | jq -r '.[0] | {
        Name: .Name,
        Status: .State.Status,
        Image: .Config.Image,
        StartedAt: .State.StartedAt,
        IPAddress: .NetworkSettings.IPAddress,
        Ports: .NetworkSettings.Ports,
        Env: .Config.Env,
        Mounts: [.Mounts[].Source]
    }' 2>/dev/null || echo "$info" | head -50
}

do_exec() {
    [[ -z "$container" ]] && error_exit "--container でコンテナ名を指定してください"
    local cmd="${1:-bash}"
    log_info "実行: $container → $cmd"
    docker exec -it "$container" "$cmd"
}

do_compose() {
    if ! command -v docker &>/dev/null; then
        error_exit "docker コマンドが必要です"
    fi

    log_info "docker compose 操作"
    echo ""
    echo "  利用可能な操作:"
    echo "  1) up       - サービス起動"
    echo "  2) down     - サービス停止"
    echo "  3) ps       - サービス状態"
    echo "  4) logs     - ログ表示"
    echo "  5) pull     - イメージ更新"
    echo ""
    printf "選択 [1-5]: "
    local choice; read -r choice

    case "$choice" in
        1) docker compose up -d ;;
        2) docker compose down ;;
        3) docker compose ps ;;
        4) docker compose logs --tail 50 ;;
        5) docker compose pull ;;
        *) log_info "スキップしました" ;;
    esac
}

parse_arguments() {
    [[ $# -eq 0 ]] && { show_usage; exit 0; }
    action="$1"; shift

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -f|--filter)  [[ $# -lt 2 ]] && error_exit "--filter には値が必要です"; filter="$2"; shift 2 ;;
            -c|--container) [[ $# -lt 2 ]] && error_exit "--container には値が必要です"; container="$2"; shift 2 ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  break ;;
        esac
    done
    remaining=("$@")
}

declare -a remaining=()

main() {
    parse_arguments "$@"
    check_docker

    case "$action" in
        ps)      do_ps ;;
        images)  do_images ;;
        stats)   do_stats ;;
        logs)    do_logs ;;
        clean)   do_clean ;;
        inspect) do_inspect ;;
        exec)    do_exec "${remaining[0]:-bash}" ;;
        compose) do_compose ;;
        *)       error_exit "不明なアクション: $action。--help を参照してください" ;;
    esac
}

main "$@"
