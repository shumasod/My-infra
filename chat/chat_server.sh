#!/bin/bash
set -euo pipefail

#
# シェルスクリプトチャット - サーバー
# 作成日: 2024
# バージョン: 1.1
#
# 概要:
#   チャットルームを管理し、メッセージを配信します
#   ファイルベースでルーム管理を行い、複数クライアントの接続をサポート
#
# 使用例:
#   ./chat_server.sh start             # generalルームを開始
#   ./chat_server.sh start myroom      # myroomルームを開始
#   ./chat_server.sh list              # アクティブなルーム一覧
#   ./chat_server.sh stop myroom       # ルームを停止
#

# ===== 共通ライブラリ読み込み =====
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

# ===== 設定（定数） =====
readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.1"
readonly DEFAULT_ROOM_DIR="/tmp/shell_chat"
readonly MAX_MESSAGES=100

# ===== グローバル変数 =====
declare room_dir="${DEFAULT_ROOM_DIR}"
declare room_name="general"

# ===== ヘルパー関数 =====

#
# 使用方法を表示
#
show_usage() {
    cat <<EOF
${C_CYAN}シェルスクリプトチャット - サーバー${C_RESET}

使用方法: $PROG_NAME [オプション] <コマンド>

コマンド:
  start [ルーム名]    チャットルームを開始（デフォルト: general）
  stop [ルーム名]     チャットルームを停止
  list                アクティブなルーム一覧を表示
  clean               全てのチャットデータを削除

オプション:
  -h, --help          このヘルプを表示
  -v, --version       バージョン情報を表示
  -d, --dir <dir>     チャットデータディレクトリ（デフォルト: ${DEFAULT_ROOM_DIR}）

例:
  $PROG_NAME start
  $PROG_NAME start myroom
  $PROG_NAME list
  $PROG_NAME stop myroom
EOF
}

# log_info, log_success, log_warning, log_error, error_exit は共通ライブラリから提供

# ===== ルーム管理関数 =====

# ルームディレクトリを初期化
init_room() {
    local room="$1"
    local room_path="${room_dir}/${room}"

    mkdir -p "${room_path}"

    # メッセージファイル
    touch "${room_path}/messages.log"
    # 参加者リスト
    touch "${room_path}/users.list"
    # ルーム情報
    echo "${room}" > "${room_path}/room.info"
    echo "$(date +%s)" >> "${room_path}/room.info"
    # ロックファイル
    touch "${room_path}/.lock"

    log_success "ルーム '${room}' を作成しました: ${room_path}"
}

#
# ルームを開始
# 引数: $1=ルーム名
#
start_room() {
    local room="$1"
    local room_path="${room_dir}/${room}"

    if [[ -d "${room_path}" ]]; then
        log_warning "ルーム '${room}' は既に存在します"
        return 0
    fi

    init_room "${room}"

    # システムメッセージを追加
    add_system_message "${room}" "チャットルーム '${room}' が開始されました"

    echo ""
    echo -e "${C_GREEN}=================================${C_RESET}"
    echo -e "${C_GREEN}  チャットルーム開始${C_RESET}"
    echo -e "${C_GREEN}=================================${C_RESET}"
    echo ""
    echo "ルーム名: ${room}"
    echo "パス: ${room_path}"
    echo ""
    echo "クライアントから参加するには:"
    echo "  ./chat_client.sh -r ${room}"
    echo ""
}

# ルームを停止
stop_room() {
    local room="$1"
    local room_path="${room_dir}/${room}"

    if [[ ! -d "${room_path}" ]]; then
        log_error "ルーム '${room}' は存在しません"
        return 1
    fi

    # システムメッセージを追加
    add_system_message "${room}" "チャットルーム '${room}' が終了しました"

    # 少し待ってから削除（メッセージが読まれるように）
    sleep 1

    rm -rf "${room_path}"
    log_success "ルーム '${room}' を停止しました"
}

# システムメッセージを追加
add_system_message() {
    local room="$1"
    local message="$2"
    local room_path="${room_dir}/${room}"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    {
        flock -x 200
        echo "[${timestamp}] [SYSTEM] ${message}" >> "${room_path}/messages.log"
    } 200>"${room_path}/.lock"
}

#
# アクティブなルーム一覧を表示
#
list_rooms() {
    echo ""
    echo -e "${C_CYAN}=== アクティブなチャットルーム ===${C_RESET}"
    echo ""

    if [[ ! -d "${room_dir}" ]]; then
        echo "チャットルームはありません"
        return 0
    fi

    local found=false
    for room_path in "${room_dir}"/*/; do
        if [[ -d "${room_path}" ]]; then
            found=true
            local current_room_name
            current_room_name=$(basename "${room_path}")
            local user_count=0
            local msg_count=0

            if [[ -f "${room_path}/users.list" ]]; then
                user_count=$(wc -l < "${room_path}/users.list" 2>/dev/null || echo "0")
            fi
            if [[ -f "${room_path}/messages.log" ]]; then
                msg_count=$(wc -l < "${room_path}/messages.log" 2>/dev/null || echo "0")
            fi

            echo -e "  ${C_GREEN}●${C_RESET} ${current_room_name}"
            echo "    参加者: ${user_count} 人"
            echo "    メッセージ: ${msg_count} 件"
            echo ""
        fi
    done

    if [[ "${found}" == "false" ]]; then
        echo "チャットルームはありません"
    fi
}

# 全データを削除
clean_all() {
    if [[ -d "${room_dir}" ]]; then
        rm -rf "${room_dir}"
        log_success "全てのチャットデータを削除しました"
    else
        log_info "削除するデータはありません"
    fi
}

# ===== 引数解析 =====

parse_arguments() {
    local command=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_usage
                exit 0
                ;;
            -v|--version)
                echo "$PROG_NAME version $VERSION"
                exit 0
                ;;
            -d|--dir)
                [[ $# -lt 2 ]] && error_exit "--dir には値が必要です"
                room_dir="$2"
                shift 2
                ;;
            start|stop|list|clean)
                command="$1"
                shift
                if [[ $# -gt 0 && ! "$1" =~ ^- ]]; then
                    room_name="$1"
                    shift
                fi
                ;;
            -*)
                error_exit "不明なオプション: $1"
                ;;
            *)
                if [[ -z "${command}" ]]; then
                    error_exit "不明なコマンド: $1"
                fi
                shift
                ;;
        esac
    done

    if [[ -z "${command}" ]]; then
        show_usage
        exit 1
    fi

    # コマンド実行
    case "${command}" in
        start)
            start_room "${room_name}"
            ;;
        stop)
            stop_room "${room_name}"
            ;;
        list)
            list_rooms
            ;;
        clean)
            clean_all
            ;;
    esac
}

# ===== メイン処理 =====

main() {
    if [[ $# -eq 0 ]]; then
        show_usage
        exit 1
    fi

    parse_arguments "$@"
}

# スクリプト実行
main "$@"
