#!/bin/bash
set -euo pipefail

#
# SSHトンネル管理ツール
# バージョン: 1.0
#
# SSHトンネル(ローカル/リモート/動的)の作成・管理・監視ツール
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"
readonly TUNNEL_DIR="${HOME}/.ssh/tunnels"
readonly PID_DIR="${TUNNEL_DIR}/pids"
readonly CONFIG_FILE="${TUNNEL_DIR}/tunnels.conf"

declare mode="list"
declare tunnel_name=""
declare ssh_host=""
declare ssh_user=""
declare -i ssh_port=22
declare local_port=""
declare remote_host=""
declare remote_port=""
declare tunnel_type="local"
declare -i keepalive=60
declare ssh_key=""

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション] コマンド

SSHトンネル管理ツール

コマンド:
  list              アクティブなトンネル一覧
  start NAME        保存済みトンネルを起動
  stop NAME         トンネルを停止
  status NAME       トンネル状態確認
  add               新しいトンネル設定を追加
  remove NAME       トンネル設定を削除
  watch             全トンネルの監視モード
  log NAME          トンネルログを表示

オプション:
  -h, --help              このヘルプを表示
  -v, --version           バージョン情報を表示
  -n, --name NAME         トンネル名
  -H, --host HOST         SSHサーバーホスト
  -u, --user USER         SSHユーザー名
  -P, --port PORT         SSHポート [デフォルト: 22]
  -L, --local-port PORT   ローカルポート
  -R, --remote-host HOST  リモートホスト
  -r, --remote-port PORT  リモートポート
  -t, --type TYPE         トンネル種別 (local|remote|dynamic) [デフォルト: local]
  -k, --key FILE          SSH秘密鍵ファイル
  -K, --keepalive SEC     キープアライブ間隔 [デフォルト: 60]

例:
  # ローカルポートフォワーディング
  $PROG_NAME add -n mydb -H bastion.example.com -u ec2-user -L 3307 -R db.internal -r 3306

  # リモートポートフォワーディング
  $PROG_NAME add -n expose -H server.example.com -u user -t remote -L 8080 -r 80

  # 動的(SOCKSプロキシ)
  $PROG_NAME add -n socks -H proxy.example.com -u user -t dynamic -L 1080

  $PROG_NAME list
  $PROG_NAME start mydb
  $PROG_NAME stop mydb
  $PROG_NAME watch

EOF
}

init_dirs() {
    mkdir -p "$PID_DIR"
    [[ -f "$CONFIG_FILE" ]] || touch "$CONFIG_FILE"
}

get_pid_file() {
    echo "${PID_DIR}/${1}.pid"
}

get_log_file() {
    echo "${TUNNEL_DIR}/${1}.log"
}

is_running() {
    local name="$1"
    local pid_file
    pid_file=$(get_pid_file "$name")
    if [[ -f "$pid_file" ]]; then
        local pid
        pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            return 0
        else
            rm -f "$pid_file"
        fi
    fi
    return 1
}

do_list() {
    log_info "SSHトンネル一覧"
    echo ""

    if [[ ! -f "$CONFIG_FILE" ]] || [[ ! -s "$CONFIG_FILE" ]]; then
        log_warning "登録されたトンネルがありません"
        echo "  $PROG_NAME add でトンネルを追加してください"
        echo ""
        return 0
    fi

    printf "  ${C_BOLD}%-15s %-8s %-20s %-10s %-20s${C_RESET}\n" \
        "名前" "種別" "SSH接続先" "ローカルポート" "リモート"
    printf "  %s\n" "$(printf '%.0s-' {1..75})"

    while IFS='|' read -r name type user host port lport rhost rport key; do
        [[ -z "$name" || "$name" =~ ^# ]] && continue
        local status_str
        if is_running "$name"; then
            status_str="${C_GREEN}●稼働中${C_RESET}"
        else
            status_str="${C_RED}○停止中${C_RESET}"
        fi
        local remote_str=""
        [[ -n "$rhost" ]] && remote_str="${rhost}:${rport}"
        printf "  %-15s %-8s %-20s %-10s %-20s %b\n" \
            "$name" "$type" "${user}@${host}:${port}" "$lport" "$remote_str" "$status_str"
    done < "$CONFIG_FILE"

    echo ""
}

do_add() {
    [[ -z "$tunnel_name" ]] && error_exit "トンネル名を -n で指定してください"
    [[ -z "$ssh_host" ]] && error_exit "SSHホストを -H で指定してください"
    [[ -z "$local_port" ]] && error_exit "ローカルポートを -L で指定してください"

    if [[ "$tunnel_type" != "dynamic" ]]; then
        [[ -z "$remote_port" ]] && error_exit "リモートポートを -r で指定してください"
    fi

    # 重複チェック
    if grep -q "^${tunnel_name}|" "$CONFIG_FILE" 2>/dev/null; then
        error_exit "トンネル名 '$tunnel_name' はすでに存在します"
    fi

    local user="${ssh_user:-$(whoami)}"
    local rhost="${remote_host:-localhost}"
    local rport="${remote_port:-$local_port}"

    echo "${tunnel_name}|${tunnel_type}|${user}|${ssh_host}|${ssh_port}|${local_port}|${rhost}|${rport}|${ssh_key}" >> "$CONFIG_FILE"
    log_success "トンネル設定を追加しました: $tunnel_name"

    echo ""
    echo "  種別: $tunnel_type"
    echo "  SSH: ${user}@${ssh_host}:${ssh_port}"
    echo "  ローカルポート: $local_port"
    [[ "$tunnel_type" != "dynamic" ]] && echo "  リモート: ${rhost}:${rport}"
    echo ""
}

do_start() {
    local name="${tunnel_name:-$1}"
    [[ -z "$name" ]] && error_exit "トンネル名を指定してください"

    if is_running "$name"; then
        log_warning "トンネル '$name' はすでに起動中です"
        return 0
    fi

    local config_line
    config_line=$(grep "^${name}|" "$CONFIG_FILE" 2>/dev/null || true)
    [[ -z "$config_line" ]] && error_exit "トンネル設定が見つかりません: $name"

    IFS='|' read -r _name type user host port lport rhost rport key <<< "$config_line"

    local log_file
    log_file=$(get_log_file "$name")
    local pid_file
    pid_file=$(get_pid_file "$name")

    local ssh_opts=(-f -N -o StrictHostKeyChecking=accept-new
        -o ServerAliveInterval="$keepalive"
        -o ServerAliveCountMax=3
        -o ExitOnForwardFailure=yes
        -p "$port")

    [[ -n "$key" ]] && ssh_opts+=(-i "$key")

    case "$type" in
        local)
            ssh_opts+=(-L "${lport}:${rhost}:${rport}")
            ;;
        remote)
            ssh_opts+=(-R "${rport}:localhost:${lport}")
            ;;
        dynamic)
            ssh_opts+=(-D "$lport")
            ;;
    esac

    ssh "${ssh_opts[@]}" "${user}@${host}" > "$log_file" 2>&1

    # PID取得 (ssh -f はバックグラウンドで動く)
    sleep 1
    local pid
    pid=$(pgrep -f "ssh.*${host}.*${lport}" | head -1 || true)
    if [[ -n "$pid" ]]; then
        echo "$pid" > "$pid_file"
        log_success "トンネル '$name' を起動しました (PID: $pid)"
    else
        log_error "トンネルの起動に失敗しました"
        cat "$log_file"
        return 1
    fi
}

do_stop() {
    local name="${tunnel_name:-$1}"
    [[ -z "$name" ]] && error_exit "トンネル名を指定してください"

    if ! is_running "$name"; then
        log_warning "トンネル '$name' は停止中です"
        return 0
    fi

    local pid_file
    pid_file=$(get_pid_file "$name")
    local pid
    pid=$(cat "$pid_file")

    kill "$pid" 2>/dev/null && rm -f "$pid_file"
    log_success "トンネル '$name' を停止しました (PID: $pid)"
}

do_status() {
    local name="${tunnel_name:-$1}"
    [[ -z "$name" ]] && error_exit "トンネル名を指定してください"

    log_info "トンネル状態: $name"
    echo ""

    local config_line
    config_line=$(grep "^${name}|" "$CONFIG_FILE" 2>/dev/null || true)
    [[ -z "$config_line" ]] && error_exit "トンネル設定が見つかりません: $name"

    IFS='|' read -r _name type user host port lport rhost rport key <<< "$config_line"

    printf "  %-15s %s\n" "種別:" "$type"
    printf "  %-15s %s@%s:%s\n" "SSH接続先:" "$user" "$host" "$port"
    printf "  %-15s %s\n" "ローカルポート:" "$lport"
    [[ "$type" != "dynamic" ]] && printf "  %-15s %s:%s\n" "リモート:" "$rhost" "$rport"

    if is_running "$name"; then
        local pid_file
        pid_file=$(get_pid_file "$name")
        local pid
        pid=$(cat "$pid_file")
        printf "  %-15s ${C_GREEN}稼働中${C_RESET} (PID: %s)\n" "状態:" "$pid"
    else
        printf "  %-15s ${C_RED}停止中${C_RESET}\n" "状態:"
    fi
    echo ""
}

do_remove() {
    local name="${tunnel_name:-$1}"
    [[ -z "$name" ]] && error_exit "トンネル名を指定してください"

    if is_running "$name"; then
        confirm "トンネルが稼働中です。停止して削除しますか?" "n" || { log_info "キャンセル"; return 0; }
        do_stop "$name"
    fi

    sed -i "/^${name}|/d" "$CONFIG_FILE"
    rm -f "$(get_pid_file "$name")" "$(get_log_file "$name")"
    log_success "トンネル設定を削除しました: $name"
}

do_watch() {
    log_info "トンネル監視モード (q で終了)"
    echo ""

    while true; do
        clear_screen
        print_center "SSHトンネル監視" 1 "$C_CYAN"
        draw_separator 2

        local row=4
        move_cursor $row 2
        printf "${C_BOLD}%-15s %-8s %-20s %s${C_RESET}\n" "名前" "種別" "接続先" "状態"
        (( row++ )) || true
        move_cursor $row 2
        printf "%s\n" "$(printf '%.0s-' {1..55})"
        (( row++ )) || true

        while IFS='|' read -r name type user host port lport rhost rport key; do
            [[ -z "$name" || "$name" =~ ^# ]] && continue
            move_cursor $row 2
            if is_running "$name"; then
                printf "${C_GREEN}%-15s${C_RESET} %-8s %-20s ${C_GREEN}●稼働中${C_RESET}\n" \
                    "$name" "$type" "${user}@${host}"
            else
                printf "${C_RED}%-15s${C_RESET} %-8s %-20s ${C_RED}○停止中${C_RESET}\n" \
                    "$name" "$type" "${user}@${host}"
            fi
            (( row++ )) || true
        done < "$CONFIG_FILE"

        move_cursor $row 2
        printf "${C_DIM}更新: $(date '+%H:%M:%S')  q=終了  r=再読込${C_RESET}"

        read -rsn1 -t 5 key 2>/dev/null || true
        case "${key:-}" in
            q|Q) break ;;
        esac
    done
    clear_screen
}

do_log() {
    local name="${tunnel_name:-$1}"
    [[ -z "$name" ]] && error_exit "トンネル名を指定してください"

    local log_file
    log_file=$(get_log_file "$name")

    if [[ ! -f "$log_file" ]]; then
        log_warning "ログファイルがありません: $log_file"
        return 0
    fi

    log_info "ログ: $name"
    echo ""
    cat "$log_file"
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -n|--name)    [[ $# -lt 2 ]] && error_exit "-n には値が必要です"; tunnel_name="$2"; shift 2 ;;
            -H|--host)    [[ $# -lt 2 ]] && error_exit "-H には値が必要です"; ssh_host="$2"; shift 2 ;;
            -u|--user)    [[ $# -lt 2 ]] && error_exit "-u には値が必要です"; ssh_user="$2"; shift 2 ;;
            -P|--port)    [[ $# -lt 2 ]] && error_exit "-P には値が必要です"; ssh_port="$2"; shift 2 ;;
            -L|--local-port)   [[ $# -lt 2 ]] && error_exit "-L には値が必要です"; local_port="$2"; shift 2 ;;
            -R|--remote-host)  [[ $# -lt 2 ]] && error_exit "-R には値が必要です"; remote_host="$2"; shift 2 ;;
            -r|--remote-port)  [[ $# -lt 2 ]] && error_exit "-r には値が必要です"; remote_port="$2"; shift 2 ;;
            -t|--type)    [[ $# -lt 2 ]] && error_exit "-t には値が必要です"; tunnel_type="$2"; shift 2 ;;
            -k|--key)     [[ $# -lt 2 ]] && error_exit "-k には値が必要です"; ssh_key="$2"; shift 2 ;;
            -K|--keepalive) [[ $# -lt 2 ]] && error_exit "-K には値が必要です"; keepalive="$2"; shift 2 ;;
            list|add|watch) mode="$1"; shift ;;
            start|stop|status|remove|log)
                mode="$1"
                [[ $# -ge 2 && ! "$2" =~ ^- ]] && { tunnel_name="$2"; shift; }
                shift
                ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  shift ;;
        esac
    done
}

main() {
    init_dirs
    parse_arguments "$@"

    case "$mode" in
        list)   do_list ;;
        add)    do_add ;;
        start)  do_start "$tunnel_name" ;;
        stop)   do_stop "$tunnel_name" ;;
        status) do_status "$tunnel_name" ;;
        remove) do_remove "$tunnel_name" ;;
        watch)  do_watch ;;
        log)    do_log "$tunnel_name" ;;
        *)      error_exit "不明なコマンド: $mode" ;;
    esac
}

main "$@"
