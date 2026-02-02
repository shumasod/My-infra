#!/bin/bash
set -euo pipefail

#
# シェルスクリプトチャット - クライアント
# 作成日: 2024
# バージョン: 1.0
#
# TUIベースのチャットクライアント
#

# ===== 設定（定数） =====
readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"
readonly DEFAULT_ROOM_DIR="/tmp/shell_chat"
readonly REFRESH_INTERVAL=1

# 色定義（ANSI エスケープコード）
readonly C_RESET='\033[0m'
readonly C_BOLD='\033[1m'
readonly C_DIM='\033[2m'
readonly C_RED='\033[1;31m'
readonly C_GREEN='\033[1;32m'
readonly C_YELLOW='\033[1;33m'
readonly C_BLUE='\033[1;34m'
readonly C_MAGENTA='\033[1;35m'
readonly C_CYAN='\033[1;36m'
readonly C_WHITE='\033[1;37m'
readonly C_BG_BLUE='\033[44m'
readonly C_BG_GRAY='\033[100m'

# ユーザー名の色パレット
readonly -a USER_COLORS=(
    '\033[1;31m'  # 赤
    '\033[1;32m'  # 緑
    '\033[1;33m'  # 黄
    '\033[1;34m'  # 青
    '\033[1;35m'  # マゼンタ
    '\033[1;36m'  # シアン
    '\033[1;91m'  # 明るい赤
    '\033[1;92m'  # 明るい緑
    '\033[1;93m'  # 明るい黄
    '\033[1;94m'  # 明るい青
    '\033[1;95m'  # 明るいマゼンタ
    '\033[1;96m'  # 明るいシアン
)

# ===== グローバル変数 =====
declare room_dir="${DEFAULT_ROOM_DIR}"
declare room_name="general"
declare user_name=""
declare room_path=""
declare last_line_count=0
declare -i terminal_rows=24
declare -i terminal_cols=80
declare -i chat_height=18
declare running=true

# ===== ヘルパー関数 =====

show_usage() {
    cat <<EOF
シェルスクリプトチャット - クライアント

使用方法: $PROG_NAME [オプション]

オプション:
  -h, --help          このヘルプを表示
  -v, --version       バージョン情報を表示
  -r, --room <name>   参加するルーム名（デフォルト: general）
  -u, --user <name>   ユーザー名（省略時は入力を求められます）
  -d, --dir <dir>     チャットデータディレクトリ

例:
  $PROG_NAME
  $PROG_NAME -r myroom
  $PROG_NAME -r myroom -u Alice
EOF
}

error_exit() {
    echo -e "${C_RED}エラー: $1${C_RESET}" >&2
    exit 1
}

# ユーザー名からハッシュを計算して色を決定
get_user_color() {
    local name="$1"
    local hash=0
    local i

    for ((i=0; i<${#name}; i++)); do
        hash=$((hash + $(printf '%d' "'${name:i:1}")))
    done

    local color_index=$((hash % ${#USER_COLORS[@]}))
    echo "${USER_COLORS[color_index]}"
}

# ターミナルサイズを取得
update_terminal_size() {
    terminal_rows=$(tput lines 2>/dev/null || echo 24)
    terminal_cols=$(tput cols 2>/dev/null || echo 80)
    chat_height=$((terminal_rows - 6))
    if [[ $chat_height -lt 5 ]]; then
        chat_height=5
    fi
}

# 画面をクリア
clear_screen() {
    printf '\033[2J\033[H'
}

# カーソルを移動
move_cursor() {
    local row=$1
    local col=$2
    printf '\033[%d;%dH' "$row" "$col"
}

# 行をクリア
clear_line() {
    printf '\033[2K'
}

# ===== UI描画関数 =====

# ヘッダーを描画
draw_header() {
    local title="シェルスクリプトチャット"
    local room_info="ルーム: ${room_name}"
    local user_info="ユーザー: ${user_name}"

    move_cursor 1 1
    echo -ne "${C_BG_BLUE}${C_WHITE}${C_BOLD}"
    printf "%-${terminal_cols}s" " ${title}"
    echo -ne "${C_RESET}"

    move_cursor 2 1
    echo -ne "${C_BG_GRAY}${C_WHITE}"
    printf "%-${terminal_cols}s" " ${room_info} | ${user_info} | Ctrl+C: 終了"
    echo -ne "${C_RESET}"
}

# 区切り線を描画
draw_separator() {
    local row=$1
    move_cursor "$row" 1
    echo -ne "${C_DIM}"
    printf '%.0s─' $(seq 1 "$terminal_cols")
    echo -ne "${C_RESET}"
}

# メッセージエリアを描画
draw_messages() {
    local start_row=4
    local end_row=$((start_row + chat_height - 1))

    # メッセージファイルを読み込み
    if [[ ! -f "${room_path}/messages.log" ]]; then
        return
    fi

    local messages
    messages=$(tail -n "$chat_height" "${room_path}/messages.log" 2>/dev/null || true)

    local row=$start_row
    while IFS= read -r line && [[ $row -le $end_row ]]; do
        move_cursor "$row" 1
        clear_line

        # メッセージをパース [timestamp] [user] message
        if [[ "$line" =~ ^\[([^\]]+)\]\ \[([^\]]+)\]\ (.*)$ ]]; then
            local timestamp="${BASH_REMATCH[1]}"
            local sender="${BASH_REMATCH[2]}"
            local message="${BASH_REMATCH[3]}"

            # 時刻を短縮形式に
            local short_time
            short_time=$(echo "$timestamp" | sed 's/.*\([0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}\).*/\1/')

            if [[ "$sender" == "SYSTEM" ]]; then
                echo -ne " ${C_DIM}${short_time}${C_RESET} ${C_YELLOW}★ ${message}${C_RESET}"
            else
                local user_color
                user_color=$(get_user_color "$sender")
                echo -ne " ${C_DIM}${short_time}${C_RESET} ${user_color}${sender}${C_RESET}: ${message}"
            fi
        else
            echo -ne " $line"
        fi

        ((row++))
    done <<< "$messages"

    # 残りの行をクリア
    while [[ $row -le $end_row ]]; do
        move_cursor "$row" 1
        clear_line
        ((row++))
    done
}

# 入力エリアを描画
draw_input_area() {
    local input_row=$((terminal_rows - 2))

    draw_separator "$((input_row - 1))"

    move_cursor "$input_row" 1
    clear_line
    echo -ne " ${C_GREEN}>${C_RESET} "
}

# 全体を描画
draw_screen() {
    update_terminal_size
    draw_header
    draw_messages
    draw_input_area
}

# ===== チャット機能 =====

# ユーザーをルームに登録
join_room() {
    if [[ ! -d "${room_path}" ]]; then
        error_exit "ルーム '${room_name}' が存在しません。先にサーバーを起動してください。"
    fi

    # ユーザーリストに追加
    {
        flock -x 200
        # 既存のエントリを削除して追加
        grep -v "^${user_name}$" "${room_path}/users.list" > "${room_path}/users.list.tmp" 2>/dev/null || true
        mv "${room_path}/users.list.tmp" "${room_path}/users.list"
        echo "${user_name}" >> "${room_path}/users.list"
    } 200>"${room_path}/.lock"

    # 入室メッセージを送信
    send_system_message "${user_name} が入室しました"
}

# ユーザーをルームから削除
leave_room() {
    if [[ -d "${room_path}" ]]; then
        # 退室メッセージを送信
        send_system_message "${user_name} が退室しました"

        # ユーザーリストから削除
        {
            flock -x 200
            grep -v "^${user_name}$" "${room_path}/users.list" > "${room_path}/users.list.tmp" 2>/dev/null || true
            mv "${room_path}/users.list.tmp" "${room_path}/users.list"
        } 200>"${room_path}/.lock"
    fi
}

# メッセージを送信
send_message() {
    local message="$1"

    if [[ -z "$message" ]]; then
        return
    fi

    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    {
        flock -x 200
        echo "[${timestamp}] [${user_name}] ${message}" >> "${room_path}/messages.log"
    } 200>"${room_path}/.lock"
}

# システムメッセージを送信
send_system_message() {
    local message="$1"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    {
        flock -x 200
        echo "[${timestamp}] [SYSTEM] ${message}" >> "${room_path}/messages.log"
    } 200>"${room_path}/.lock"
}

# クリーンアップ処理
cleanup() {
    running=false
    leave_room
    # カーソルを表示
    tput cnorm 2>/dev/null || true
    # 画面をクリア
    clear_screen
    move_cursor 1 1
    echo "チャットを終了しました。"
    exit 0
}

# メッセージ監視（バックグラウンド）
watch_messages() {
    while $running; do
        if [[ ! -d "${room_path}" ]]; then
            echo -e "\n${C_RED}ルームが終了しました${C_RESET}"
            running=false
            kill -INT $$ 2>/dev/null || true
            break
        fi

        draw_messages
        draw_input_area

        sleep "$REFRESH_INTERVAL"
    done
}

# ===== メインループ =====

run_chat() {
    # シグナルハンドラ設定
    trap cleanup EXIT INT TERM

    # カーソルを非表示
    tput civis 2>/dev/null || true

    # 初期画面描画
    clear_screen
    draw_screen

    # ルームに参加
    join_room

    # メッセージ監視を開始（バックグラウンド）
    watch_messages &
    local watcher_pid=$!

    # カーソルを表示（入力用）
    tput cnorm 2>/dev/null || true

    # 入力ループ
    local input_row=$((terminal_rows - 2))
    while $running; do
        move_cursor "$input_row" 5
        clear_line
        move_cursor "$input_row" 1
        echo -ne " ${C_GREEN}>${C_RESET} "

        # 入力を読み取り
        local message=""
        if read -r message; then
            if [[ -n "$message" ]]; then
                case "$message" in
                    /quit|/exit|/q)
                        running=false
                        ;;
                    /users)
                        # ユーザー一覧を表示
                        local users
                        users=$(cat "${room_path}/users.list" 2>/dev/null | tr '\n' ', ' | sed 's/,$//')
                        send_system_message "現在の参加者: ${users}"
                        ;;
                    /help)
                        send_system_message "コマンド: /quit, /users, /help"
                        ;;
                    /*)
                        send_system_message "不明なコマンド: $message"
                        ;;
                    *)
                        send_message "$message"
                        ;;
                esac
            fi
        else
            running=false
        fi
    done

    # バックグラウンドプロセスを終了
    kill "$watcher_pid" 2>/dev/null || true
    wait "$watcher_pid" 2>/dev/null || true
}

# ===== 引数解析 =====

parse_arguments() {
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
            -r|--room)
                [[ $# -lt 2 ]] && error_exit "--room には値が必要です"
                room_name="$2"
                shift 2
                ;;
            -u|--user)
                [[ $# -lt 2 ]] && error_exit "--user には値が必要です"
                user_name="$2"
                shift 2
                ;;
            -d|--dir)
                [[ $# -lt 2 ]] && error_exit "--dir には値が必要です"
                room_dir="$2"
                shift 2
                ;;
            -*)
                error_exit "不明なオプション: $1"
                ;;
            *)
                error_exit "不明な引数: $1"
                ;;
        esac
    done

    room_path="${room_dir}/${room_name}"
}

# ===== メイン処理 =====

main() {
    parse_arguments "$@"

    # ルームの存在確認
    if [[ ! -d "${room_path}" ]]; then
        echo -e "${C_RED}エラー: ルーム '${room_name}' が存在しません${C_RESET}"
        echo ""
        echo "先にサーバーでルームを作成してください:"
        echo "  ./chat_server.sh start ${room_name}"
        exit 1
    fi

    # ユーザー名が未設定の場合は入力を求める
    if [[ -z "${user_name}" ]]; then
        echo -e "${C_CYAN}シェルスクリプトチャット${C_RESET}"
        echo ""
        echo -n "ユーザー名を入力してください: "
        read -r user_name
        if [[ -z "${user_name}" ]]; then
            user_name="User_$$"
        fi
    fi

    # 入力モードを設定
    if [[ -t 0 ]]; then
        # インタラクティブモード
        run_chat
    else
        error_exit "インタラクティブモードが必要です"
    fi
}

# スクリプト実行
main "$@"
