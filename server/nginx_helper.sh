#!/bin/bash
set -euo pipefail

#
# Nginx管理ヘルパー
# バージョン: 1.0
#
# Nginxの設定確認・サイト管理・ログ解析を行うツール
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"
readonly NGINX_CONF_DIR="${NGINX_CONF_DIR:-/etc/nginx}"
readonly NGINX_SITES_AVAILABLE="${NGINX_CONF_DIR}/sites-available"
readonly NGINX_SITES_ENABLED="${NGINX_CONF_DIR}/sites-enabled"
readonly NGINX_ACCESS_LOG="${NGINX_ACCESS_LOG:-/var/log/nginx/access.log}"
readonly NGINX_ERROR_LOG="${NGINX_ERROR_LOG:-/var/log/nginx/error.log}"

declare mode="status"
declare site_name=""
declare -i top_n=10
declare log_file=""

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション] コマンド

Nginx管理ヘルパー

コマンド:
  status            Nginxの状態確認
  reload            設定をリロード (nginx -s reload)
  test              設定ファイルの構文チェック
  sites             サイト一覧 (enabled/disabled)
  enable SITE       サイトを有効化
  disable SITE      サイトを無効化
  log               アクセスログ解析 (Top IP/URL/Status)
  errors            エラーログの最新エントリ表示
  connections       現在の接続状態
  version           Nginxバージョン情報

オプション:
  -h, --help        このヘルプを表示
  -v, --version     バージョン情報を表示
  -n, --top NUM     上位N件表示 [デフォルト: 10]
  -l, --log FILE    解析するログファイル

例:
  $PROG_NAME status
  $PROG_NAME sites
  $PROG_NAME enable myapp.conf
  $PROG_NAME log -n 20
  $PROG_NAME errors

EOF
}

check_nginx() {
    if ! command -v nginx &>/dev/null; then
        error_exit "Nginxがインストールされていません"
    fi
}

do_status() {
    check_nginx
    log_info "Nginx状態"
    echo ""

    # プロセス確認
    local pid_count
    pid_count=$(pgrep -c nginx 2>/dev/null || echo 0)
    if (( pid_count > 0 )); then
        printf "  %-20s ${C_GREEN}稼働中${C_RESET} (プロセス数: %d)\n" "状態:" "$pid_count"
    else
        printf "  %-20s ${C_RED}停止中${C_RESET}\n" "状態:"
    fi

    # バージョン
    local ver
    ver=$(nginx -v 2>&1 | grep -oE 'nginx/[0-9.]+' || echo "unknown")
    printf "  %-20s %s\n" "バージョン:" "$ver"

    # 設定ファイル
    printf "  %-20s %s\n" "設定ディレクトリ:" "$NGINX_CONF_DIR"

    # 有効サイト数
    local enabled_count=0
    [[ -d "$NGINX_SITES_ENABLED" ]] && enabled_count=$(find "$NGINX_SITES_ENABLED" -type l | wc -l)
    printf "  %-20s %d\n" "有効サイト数:" "$enabled_count"

    # Worker設定
    local workers
    workers=$(grep -r "worker_processes" "${NGINX_CONF_DIR}/nginx.conf" 2>/dev/null | head -1 | awk '{print $2}' | tr -d ';' || echo "unknown")
    printf "  %-20s %s\n" "Workerプロセス:" "$workers"

    echo ""

    # 接続統計 (nginx stub status が有効な場合)
    if curl -s "http://localhost/nginx_status" &>/dev/null; then
        log_info "接続統計:"
        curl -s "http://localhost/nginx_status" | sed 's/^/  /'
        echo ""
    fi
}

do_test() {
    check_nginx
    log_info "設定ファイル構文チェック"
    echo ""

    if nginx -t 2>&1 | sed 's/^/  /'; then
        log_success "設定ファイルの構文は正常です"
    else
        log_error "設定ファイルにエラーがあります"
        return 1
    fi
    echo ""
}

do_reload() {
    check_nginx

    log_info "設定をリロードします..."
    nginx -t 2>/dev/null || error_exit "構文エラーがあります。先に nginx test で確認してください"

    if systemctl reload nginx 2>/dev/null || nginx -s reload 2>/dev/null; then
        log_success "Nginxの設定をリロードしました"
    else
        error_exit "リロードに失敗しました"
    fi
}

do_sites() {
    log_info "Nginxサイト一覧"
    echo ""

    if [[ ! -d "$NGINX_SITES_AVAILABLE" ]]; then
        log_warning "sites-availableディレクトリが見つかりません: $NGINX_SITES_AVAILABLE"
        return 0
    fi

    printf "  ${C_BOLD}%-35s %-10s${C_RESET}\n" "サイト名" "状態"
    printf "  %s\n" "$(printf '%.0s-' {1..48})"

    for f in "${NGINX_SITES_AVAILABLE}"/*; do
        [[ ! -f "$f" ]] && continue
        local name
        name=$(basename "$f")
        local enabled_path="${NGINX_SITES_ENABLED}/${name}"

        if [[ -L "$enabled_path" ]]; then
            printf "  %-35s ${C_GREEN}有効${C_RESET}\n" "$name"
        else
            printf "  %-35s ${C_DIM}無効${C_RESET}\n" "$name"
        fi
    done
    echo ""
}

do_enable() {
    [[ -z "$site_name" ]] && error_exit "サイト名を指定してください"
    check_nginx

    local src="${NGINX_SITES_AVAILABLE}/${site_name}"
    local dst="${NGINX_SITES_ENABLED}/${site_name}"

    [[ ! -f "$src" ]] && error_exit "設定ファイルが見つかりません: $src"
    [[ -L "$dst" ]] && { log_warning "すでに有効化されています: $site_name"; return 0; }

    ln -s "$src" "$dst"
    log_success "有効化しました: $site_name"

    nginx -t 2>/dev/null && {
        confirm "Nginxをリロードしますか?" "y" && do_reload
    } || {
        log_error "設定エラーがあります。シンボリックリンクを削除します"
        rm -f "$dst"
    }
}

do_disable() {
    [[ -z "$site_name" ]] && error_exit "サイト名を指定してください"

    local dst="${NGINX_SITES_ENABLED}/${site_name}"
    [[ ! -L "$dst" ]] && { log_warning "有効化されていません: $site_name"; return 0; }

    rm -f "$dst"
    log_success "無効化しました: $site_name"
    confirm "Nginxをリロードしますか?" "y" && do_reload || true
}

do_log() {
    local access_log="${log_file:-$NGINX_ACCESS_LOG}"
    [[ ! -f "$access_log" ]] && error_exit "ログファイルが見つかりません: $access_log"

    log_info "アクセスログ解析: $access_log"
    echo ""

    # Top IP
    log_info "アクセス数 Top${top_n} IPアドレス:"
    awk '{print $1}' "$access_log" | sort | uniq -c | sort -rn | head -"$top_n" | \
        awk '{printf "  %6d  %s\n", $1, $2}'
    echo ""

    # Top URL
    log_info "アクセス数 Top${top_n} URL:"
    awk '{print $7}' "$access_log" | sort | uniq -c | sort -rn | head -"$top_n" | \
        awk '{printf "  %6d  %s\n", $1, $2}'
    echo ""

    # ステータスコード集計
    log_info "HTTPステータスコード集計:"
    awk '{print $9}' "$access_log" | sort | uniq -c | sort -rn | \
    while read -r count code; do
        local color="$C_RESET"
        case "${code:0:1}" in
            2) color="$C_GREEN" ;;
            3) color="$C_CYAN" ;;
            4) color="$C_YELLOW" ;;
            5) color="$C_RED" ;;
        esac
        printf "  ${color}%6d  %s${C_RESET}\n" "$count" "$code"
    done
    echo ""

    # 総リクエスト数
    local total
    total=$(wc -l < "$access_log")
    printf "  総リクエスト数: ${C_BOLD}%d${C_RESET}\n" "$total"
    echo ""
}

do_errors() {
    local error_log="${log_file:-$NGINX_ERROR_LOG}"
    [[ ! -f "$error_log" ]] && error_exit "エラーログが見つかりません: $error_log"

    log_info "Nginxエラーログ (最新${top_n}件): $error_log"
    echo ""

    tail -"$top_n" "$error_log" | while IFS= read -r line; do
        if echo "$line" | grep -qi "crit\|emerg\|alert"; then
            printf "  ${C_RED}%s${C_RESET}\n" "$line"
        elif echo "$line" | grep -qi "error"; then
            printf "  ${C_YELLOW}%s${C_RESET}\n" "$line"
        else
            printf "  ${C_DIM}%s${C_RESET}\n" "$line"
        fi
    done
    echo ""
}

do_connections() {
    log_info "現在のNginx接続状態"
    echo ""

    if command -v ss &>/dev/null; then
        local http_count https_count established_count
        http_count=$(ss -tn 'sport = :80' 2>/dev/null | tail -n +2 | wc -l || echo 0)
        https_count=$(ss -tn 'sport = :443' 2>/dev/null | tail -n +2 | wc -l || echo 0)
        established_count=$(ss -tn state established 2>/dev/null | tail -n +2 | wc -l || echo 0)

        printf "  %-20s %d\n" "HTTP (port 80):" "$http_count"
        printf "  %-20s %d\n" "HTTPS (port 443):" "$https_count"
        printf "  %-20s %d\n" "確立済み接続:" "$established_count"
    else
        log_warning "ssコマンドが見つかりません"
    fi

    echo ""
    log_info "TIME_WAIT / ESTABLISHED 分布:"
    ss -tn 2>/dev/null | awk 'NR>1{print $1}' | sort | uniq -c | sort -rn | \
        awk '{printf "  %6d  %s\n", $1, $2}'
    echo ""
}

do_version() {
    check_nginx
    nginx -V 2>&1 | sed 's/^/  /'
    echo ""
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -n|--top)     [[ $# -lt 2 ]] && error_exit "-n には値が必要です"; top_n="$2"; shift 2 ;;
            -l|--log)     [[ $# -lt 2 ]] && error_exit "-l には値が必要です"; log_file="$2"; shift 2 ;;
            status|test|reload|sites|log|errors|connections|version) mode="$1"; shift ;;
            enable)
                mode="enable"
                [[ $# -ge 2 && ! "$2" =~ ^- ]] && { site_name="$2"; shift; }
                shift
                ;;
            disable)
                mode="disable"
                [[ $# -ge 2 && ! "$2" =~ ^- ]] && { site_name="$2"; shift; }
                shift
                ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  shift ;;
        esac
    done
}

main() {
    parse_arguments "$@"

    case "$mode" in
        status)      do_status ;;
        test)        do_test ;;
        reload)      do_reload ;;
        sites)       do_sites ;;
        enable)      do_enable ;;
        disable)     do_disable ;;
        log)         do_log ;;
        errors)      do_errors ;;
        connections) do_connections ;;
        version)     do_version ;;
        *)           error_exit "不明なコマンド: $mode" ;;
    esac
}

main "$@"
