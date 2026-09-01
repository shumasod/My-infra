#!/bin/bash
set -euo pipefail

#
# 環境設定チェッカー
# 作成日: 2026-09-01
# バージョン: 1.0
#
# システム環境・依存ツール・設定ファイルを検証します
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare command_name="all"
declare config_file=""
declare -i check_passed=0
declare -i check_failed=0
declare -i check_warned=0

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション]

システム環境・依存ツール・設定ファイルを検証します。

コマンド:
  all                  全チェック実行 (デフォルト)
  tools                必須ツールの存在確認
  env                  環境変数の確認
  disk                 ディスク容量チェック
  network              ネットワーク接続確認
  ports                ポート使用状況
  services             サービス起動確認
  config <ファイル>    設定ファイル検証

オプション:
  -h, --help           このヘルプを表示
  -v, --version        バージョン情報を表示
  -c, --config <ファイル> チェック設定ファイル

例:
  $PROG_NAME all
  $PROG_NAME tools
  $PROG_NAME env
  $PROG_NAME config /etc/myapp/config.ini
EOF
}

pass() { printf "  ${C_GREEN}[PASS]${C_RESET} %s\n" "$1"; (( check_passed++ )); }
fail() { printf "  ${C_RED}[FAIL]${C_RESET} %s\n" "$1"; (( check_failed++ )); }
warn() { printf "  ${C_YELLOW}[WARN]${C_RESET} %s\n" "$1"; (( check_warned++ )); }
info() { printf "  ${C_DIM}[INFO]${C_RESET} %s\n" "$1"; }

section() {
    echo ""
    printf "${C_BOLD}${C_CYAN}== %s ==${C_RESET}\n\n" "$1"
}

print_summary() {
    echo ""
    printf "${C_BOLD}【チェック結果サマリー】${C_RESET}\n\n"
    printf "  ${C_GREEN}PASS: %d${C_RESET}   ${C_YELLOW}WARN: %d${C_RESET}   ${C_RED}FAIL: %d${C_RESET}\n\n" \
        "$check_passed" "$check_warned" "$check_failed"

    if (( check_failed > 0 )); then
        log_error "重大な問題が $check_failed 件検出されました"
    elif (( check_warned > 0 )); then
        log_warning "警告が $check_warned 件あります。確認してください"
    else
        log_success "全チェック通過"
    fi
}

cmd_tools() {
    section "必須ツール確認"

    local required_tools=(
        "bash:Bashシェル"
        "git:バージョン管理"
        "curl:HTTPクライアント"
        "wget:ファイルダウンロード"
        "ssh:SSHクライアント"
        "rsync:ファイル同期"
        "tar:アーカイブ"
        "gzip:圧縮"
        "jq:JSON処理"
        "awk:テキスト処理"
        "sed:テキスト編集"
        "grep:テキスト検索"
        "find:ファイル検索"
        "ps:プロセス管理"
        "top:リソース監視"
        "netstat:ネットワーク状態"
        "df:ディスク使用量"
        "du:ディレクトリサイズ"
        "free:メモリ使用量"
        "uname:システム情報"
    )

    local optional_tools=(
        "docker:コンテナ管理"
        "ansible:構成管理"
        "terraform:インフラ管理"
        "python3:Python実行環境"
        "pip3:Pythonパッケージ管理"
        "node:Node.js"
        "npm:npmパッケージ管理"
        "go:Go言語"
        "make:ビルドツール"
        "vim:テキストエディタ"
        "tmux:ターミナルマルチプレクサ"
        "shellcheck:Shellスクリプト静的解析"
        "mysql:MySQLクライアント"
        "psql:PostgreSQLクライアント"
        "redis-cli:Redisクライアント"
        "aws:AWS CLI"
    )

    printf "${C_BOLD}必須ツール:${C_RESET}\n"
    for entry in "${required_tools[@]}"; do
        local tool="${entry%%:*}"
        local desc="${entry##*:}"
        if command -v "$tool" &>/dev/null; then
            local ver
            ver=$(command -v "$tool" | head -1)
            pass "$desc ($tool)"
        else
            fail "$desc ($tool) — 未インストール"
        fi
    done

    echo ""
    printf "${C_BOLD}オプションツール:${C_RESET}\n"
    for entry in "${optional_tools[@]}"; do
        local tool="${entry%%:*}"
        local desc="${entry##*:}"
        if command -v "$tool" &>/dev/null; then
            pass "$desc ($tool)"
        else
            warn "$desc ($tool) — 未インストール"
        fi
    done
}

cmd_env() {
    section "環境変数確認"

    local important_vars=(
        "HOME:ホームディレクトリ"
        "PATH:実行ファイルパス"
        "SHELL:デフォルトシェル"
        "USER:ユーザー名"
        "LANG:言語設定"
        "TZ:タイムゾーン"
    )

    local optional_vars=(
        "AWS_DEFAULT_REGION:AWSデフォルトリージョン"
        "AWS_PROFILE:AWSプロファイル"
        "ANSIBLE_HOSTS:Ansibleインベントリ"
        "DOCKER_HOST:Dockerホスト"
        "KUBECONFIG:Kubernetesconfig"
        "GOPATH:Goパス"
        "JAVA_HOME:Javaホーム"
        "EDITOR:デフォルトエディタ"
        "TERM:ターミナルタイプ"
    )

    printf "${C_BOLD}重要な環境変数:${C_RESET}\n"
    for entry in "${important_vars[@]}"; do
        local var="${entry%%:*}"
        local desc="${entry##*:}"
        local val="${!var:-}"
        if [[ -n "$val" ]]; then
            pass "$desc (${var}=${val})"
        else
            fail "$desc (${var}) — 未設定"
        fi
    done

    echo ""
    printf "${C_BOLD}オプション環境変数:${C_RESET}\n"
    for entry in "${optional_vars[@]}"; do
        local var="${entry%%:*}"
        local desc="${entry##*:}"
        local val="${!var:-}"
        if [[ -n "$val" ]]; then
            info "$desc (${var}=${val})"
        else
            warn "$desc (${var}) — 未設定"
        fi
    done
}

cmd_disk() {
    section "ディスク容量確認"

    local warn_threshold=80
    local crit_threshold=90

    df -h | tail -n +2 | grep -v "tmpfs\|devtmpfs\|udev" | \
    while IFS= read -r line; do
        local usage fs
        usage=$(echo "$line" | awk '{print $5}' | tr -d '%')
        fs=$(echo "$line" | awk '{print $6}')
        [[ -z "$usage" ]] && continue
        if (( usage >= crit_threshold )); then
            fail "$fs: ${usage}% 使用中 (危険)"
        elif (( usage >= warn_threshold )); then
            warn "$fs: ${usage}% 使用中 (警告)"
        else
            pass "$fs: ${usage}% 使用中"
        fi
    done

    echo ""
    local mem_used mem_total
    if command -v free &>/dev/null; then
        mem_total=$(free -m | awk '/^Mem:/{print $2}')
        mem_used=$(free -m | awk '/^Mem:/{print $3}')
        local mem_pct=$(( mem_used * 100 / mem_total ))
        if (( mem_pct >= 90 )); then
            fail "メモリ: ${mem_pct}% 使用中 (${mem_used}/${mem_total}MB)"
        elif (( mem_pct >= 75 )); then
            warn "メモリ: ${mem_pct}% 使用中 (${mem_used}/${mem_total}MB)"
        else
            pass "メモリ: ${mem_pct}% 使用中 (${mem_used}/${mem_total}MB)"
        fi
    fi
}

cmd_network() {
    section "ネットワーク接続確認"

    local endpoints=(
        "8.8.8.8:Google DNS"
        "1.1.1.1:Cloudflare DNS"
    )

    printf "${C_BOLD}疎通確認:${C_RESET}\n"
    for entry in "${endpoints[@]}"; do
        local host="${entry%%:*}"
        local desc="${entry##*:}"
        if ping -c 1 -W 3 "$host" &>/dev/null 2>&1; then
            pass "$desc ($host)"
        else
            fail "$desc ($host) — 到達不可"
        fi
    done

    echo ""
    printf "${C_BOLD}DNS解決:${C_RESET}\n"
    local domains=("google.com" "github.com")
    for domain in "${domains[@]}"; do
        if getent hosts "$domain" &>/dev/null 2>&1 || host "$domain" &>/dev/null 2>&1; then
            pass "DNS解決: $domain"
        else
            fail "DNS解決失敗: $domain"
        fi
    done

    echo ""
    printf "${C_BOLD}インターフェース:${C_RESET}\n"
    if command -v ip &>/dev/null; then
        ip -o link show up | awk '{print $2}' | tr -d ':' | grep -v "^lo$" | \
        while IFS= read -r iface; do
            local ip_addr
            ip_addr=$(ip -o -4 addr show "$iface" 2>/dev/null | awk '{print $4}' | head -1 || echo "N/A")
            info "インターフェース $iface: $ip_addr"
        done
    fi
}

cmd_ports() {
    section "ポート使用状況"

    local common_ports=(
        "22:SSH"
        "80:HTTP"
        "443:HTTPS"
        "3306:MySQL"
        "5432:PostgreSQL"
        "6379:Redis"
        "27017:MongoDB"
        "8080:HTTP代替"
        "8443:HTTPS代替"
    )

    if command -v ss &>/dev/null; then
        local listening
        listening=$(ss -tlnp 2>/dev/null | awk 'NR>1{print $4}' | grep -oP ':\K[0-9]+' | sort -un)

        printf "${C_BOLD}使用中ポート:${C_RESET}\n"
        for entry in "${common_ports[@]}"; do
            local port="${entry%%:*}"
            local desc="${entry##*:}"
            if echo "$listening" | grep -qx "$port"; then
                info "ポート $port ($desc): 使用中"
            else
                pass "ポート $port ($desc): 空き"
            fi
        done

        echo ""
        local total
        total=$(echo "$listening" | wc -l)
        info "合計リスニングポート数: $total"
    else
        warn "ss コマンドが見つかりません"
    fi
}

cmd_services() {
    section "サービス起動確認"

    local common_services=(
        "sshd:SSHサービス"
        "cron:CRONサービス"
        "rsyslog:システムログ"
        "NetworkManager:ネットワーク管理"
        "docker:Dockerデーモン"
        "nginx:Nginxウェブサーバー"
        "apache2:Apacheウェブサーバー"
        "mysql:MySQLデータベース"
        "postgresql:PostgreSQLデータベース"
        "redis:Redisキャッシュ"
    )

    if ! command -v systemctl &>/dev/null; then
        warn "systemctl が見つかりません。systemdが使用できない環境です"
        return
    fi

    for entry in "${common_services[@]}"; do
        local svc="${entry%%:*}"
        local desc="${entry##*:}"
        if systemctl is-enabled "$svc" &>/dev/null 2>&1; then
            if systemctl is-active --quiet "$svc" 2>/dev/null; then
                pass "$desc ($svc): 実行中"
            else
                fail "$desc ($svc): 停止中"
            fi
        fi
    done
}

cmd_config() {
    local cfg="${1:-$config_file}"
    [[ -z "$cfg" ]] && error_exit "設定ファイルを指定してください"

    section "設定ファイル検証: $cfg"

    if [[ ! -f "$cfg" ]]; then
        fail "ファイルが見つかりません: $cfg"
        return
    fi

    pass "ファイル存在確認"

    local perms
    perms=$(stat -c "%a" "$cfg" 2>/dev/null || stat -f "%p" "$cfg" 2>/dev/null | tail -c 4)
    info "パーミッション: $perms"

    if [[ "${perms: -1}" != "0" ]]; then
        warn "他のユーザーに読み取り権限があります (パーミッション: $perms)"
    fi

    if grep -qiE "password\s*=\s*.+" "$cfg" 2>/dev/null; then
        fail "平文パスワードが含まれている可能性があります"
    else
        pass "平文パスワードは検出されず"
    fi

    if grep -qiE "^\s*(secret|token|key)\s*=\s*[^$]" "$cfg" 2>/dev/null; then
        warn "秘密情報が含まれている可能性があります"
    fi

    local line_count
    line_count=$(wc -l < "$cfg")
    info "行数: $line_count"
}

cmd_all() {
    log_info "全環境チェック実行"
    cmd_tools
    cmd_env
    cmd_disk
    cmd_network
    cmd_ports
    cmd_services
    print_summary
}

parse_arguments() {
    [[ $# -eq 0 ]] && return 0
    case "$1" in
        all|tools|env|disk|network|ports|services|config)
            command_name="$1"; shift ;;
    esac

    local positional=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -c|--config)  [[ $# -lt 2 ]] && error_exit "--config には値が必要です"; config_file="$2"; shift 2 ;;
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
        all)      cmd_all ;;
        tools)    cmd_tools;    print_summary ;;
        env)      cmd_env;      print_summary ;;
        disk)     cmd_disk;     print_summary ;;
        network)  cmd_network;  print_summary ;;
        ports)    cmd_ports;    print_summary ;;
        services) cmd_services; print_summary ;;
        config)   cmd_config "${POSITIONAL[0]:-}"; print_summary ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
