#!/bin/bash
#
# 共通ユーティリティライブラリ
# 作成日: 2024
# バージョン: 1.0
#
# このファイルは各スクリプトから source されることを想定しています
# 使用方法: source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
#

# 二重読み込み防止
[[ -n "${_COMMON_SH_LOADED:-}" ]] && return 0
readonly _COMMON_SH_LOADED=1

# ============================================================================
# 色定義（ANSIエスケープシーケンス）
# ============================================================================

# リセット・スタイル
readonly C_RESET='\033[0m'
readonly C_BOLD='\033[1m'
readonly C_DIM='\033[2m'
readonly C_ITALIC='\033[3m'
readonly C_UNDERLINE='\033[4m'
readonly C_BLINK='\033[5m'
readonly C_REVERSE='\033[7m'

# 前景色（太字）
readonly C_BLACK='\033[1;30m'
readonly C_RED='\033[1;31m'
readonly C_GREEN='\033[1;32m'
readonly C_YELLOW='\033[1;33m'
readonly C_BLUE='\033[1;34m'
readonly C_MAGENTA='\033[1;35m'
readonly C_CYAN='\033[1;36m'
readonly C_WHITE='\033[1;37m'

# 明るい前景色
readonly C_BRIGHT_RED='\033[1;91m'
readonly C_BRIGHT_GREEN='\033[1;92m'
readonly C_BRIGHT_YELLOW='\033[1;93m'
readonly C_BRIGHT_BLUE='\033[1;94m'
readonly C_BRIGHT_MAGENTA='\033[1;95m'
readonly C_BRIGHT_CYAN='\033[1;96m'

# 背景色
readonly C_BG_BLACK='\033[40m'
readonly C_BG_RED='\033[41m'
readonly C_BG_GREEN='\033[42m'
readonly C_BG_YELLOW='\033[43m'
readonly C_BG_BLUE='\033[44m'
readonly C_BG_MAGENTA='\033[45m'
readonly C_BG_CYAN='\033[46m'
readonly C_BG_WHITE='\033[47m'
readonly C_BG_GRAY='\033[100m'

# ユーザー名の色パレット（チャット用）
readonly -a USER_COLOR_PALETTE=(
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

# ============================================================================
# ターミナル操作関数
# ============================================================================

# ターミナルサイズを格納するグローバル変数
declare -gi TERM_ROWS=24
declare -gi TERM_COLS=80

#
# ターミナルサイズを更新
# グローバル変数 TERM_ROWS, TERM_COLS を更新
#
update_terminal_size() {
    TERM_ROWS=$(tput lines 2>/dev/null || echo 24)
    TERM_COLS=$(tput cols 2>/dev/null || echo 80)
}

#
# 画面をクリア
#
clear_screen() {
    printf '\033[2J\033[H'
}

#
# カーソルを指定位置に移動
# 引数: $1=行 $2=列
#
move_cursor() {
    local row="${1:?行を指定してください}"
    local col="${2:?列を指定してください}"
    printf '\033[%d;%dH' "$row" "$col"
}

#
# 現在行をクリア
#
clear_line() {
    printf '\033[2K'
}

#
# カーソルを非表示
#
hide_cursor() {
    tput civis 2>/dev/null || true
}

#
# カーソルを表示
#
show_cursor() {
    tput cnorm 2>/dev/null || true
}

#
# 行を指定位置で区切り線を描画
# 引数: $1=行 $2=文字（デフォルト: ─）
#
draw_separator() {
    local row="$1"
    local char="${2:-─}"

    move_cursor "$row" 1
    echo -ne "${C_DIM}"
    for ((i = 0; i < TERM_COLS; i++)); do
        echo -n "$char"
    done
    echo -ne "${C_RESET}"
}

# ============================================================================
# テキスト表示関数
# ============================================================================

#
# テキストを中央揃えで表示
# 引数: $1=テキスト $2=行（省略可） $3=色（省略可）
#
print_center() {
    local text="$1"
    local row="${2:-}"
    local color="${3:-}"

    # ANSIエスケープシーケンスを除去してテキスト長を計算
    local plain_text
    plain_text=$(echo -e "$text" | sed 's/\x1b\[[0-9;]*m//g')
    local text_len=${#plain_text}
    local col=$(( (TERM_COLS - text_len) / 2 ))
    [[ $col -lt 1 ]] && col=1

    if [[ -n "$row" ]]; then
        move_cursor "$row" "$col"
    fi

    if [[ -n "$color" ]]; then
        echo -ne "${color}${text}${C_RESET}"
    else
        echo -ne "$text"
    fi
}

#
# テキストを右揃えで表示
# 引数: $1=テキスト $2=行（省略可） $3=色（省略可）
#
print_right() {
    local text="$1"
    local row="${2:-}"
    local color="${3:-}"

    local plain_text
    plain_text=$(echo -e "$text" | sed 's/\x1b\[[0-9;]*m//g')
    local text_len=${#plain_text}
    local col=$((TERM_COLS - text_len - 1))
    [[ $col -lt 1 ]] && col=1

    if [[ -n "$row" ]]; then
        move_cursor "$row" "$col"
    fi

    if [[ -n "$color" ]]; then
        echo -ne "${color}${text}${C_RESET}"
    else
        echo -ne "$text"
    fi
}

# ============================================================================
# ロギング関数
# ============================================================================

#
# 情報メッセージを表示
# 引数: $1=メッセージ
#
log_info() {
    echo -e "${C_CYAN}[INFO]${C_RESET} $1"
}

#
# 成功メッセージを表示
# 引数: $1=メッセージ
#
log_success() {
    echo -e "${C_GREEN}[SUCCESS]${C_RESET} $1"
}

#
# 警告メッセージを表示
# 引数: $1=メッセージ
#
log_warning() {
    echo -e "${C_YELLOW}[WARNING]${C_RESET} $1"
}

#
# エラーメッセージを表示（標準エラー出力）
# 引数: $1=メッセージ
#
log_error() {
    echo -e "${C_RED}[ERROR]${C_RESET} $1" >&2
}

#
# デバッグメッセージを表示（DEBUG=1 の場合のみ）
# 引数: $1=メッセージ
#
log_debug() {
    if [[ "${DEBUG:-0}" == "1" ]]; then
        echo -e "${C_DIM}[DEBUG]${C_RESET} $1" >&2
    fi
}

#
# エラーメッセージを表示して終了
# 引数: $1=メッセージ $2=終了コード（デフォルト: 1）
#
error_exit() {
    local message="${1:?メッセージを指定してください}"
    local exit_code="${2:-1}"

    log_error "$message"
    exit "$exit_code"
}

# ============================================================================
# 時間・日付フォーマット関数
# ============================================================================

#
# 秒数を HH:MM:SS 形式にフォーマット
# 引数: $1=秒数
# 出力: フォーマットされた時間文字列
#
format_time() {
    local seconds="${1:?秒数を指定してください}"
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))
    printf "%02d:%02d:%02d" "$hours" "$minutes" "$secs"
}

#
# 秒数を MM:SS 形式にフォーマット
# 引数: $1=秒数
# 出力: フォーマットされた時間文字列
#
format_time_short() {
    local seconds="${1:?秒数を指定してください}"
    local minutes=$((seconds / 60))
    local secs=$((seconds % 60))
    printf "%02d:%02d" "$minutes" "$secs"
}

#
# 現在のタイムスタンプを取得
# 出力: YYYY-MM-DD HH:MM:SS 形式
#
get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

#
# 現在の年を取得
#
get_current_year() {
    date '+%Y'
}

# ============================================================================
# ユーティリティ関数
# ============================================================================

#
# ユーザー名からハッシュを計算して色を決定
# 引数: $1=ユーザー名
# 出力: ANSIカラーコード
#
get_user_color() {
    local name="${1:?ユーザー名を指定してください}"
    local hash=0

    for ((i = 0; i < ${#name}; i++)); do
        hash=$((hash + $(printf '%d' "'${name:i:1}")))
    done

    local color_index=$((hash % ${#USER_COLOR_PALETTE[@]}))
    echo "${USER_COLOR_PALETTE[color_index]}"
}

#
# 確認プロンプトを表示
# 引数: $1=メッセージ $2=デフォルト値（Y/N）
# 戻り値: 0=Yes, 1=No
#
confirm() {
    local message="${1:?メッセージを指定してください}"
    local default="${2:-N}"

    local prompt
    if [[ "$default" =~ ^[Yy] ]]; then
        prompt="[Y/n]"
    else
        prompt="[y/N]"
    fi

    echo -n "$message $prompt: "
    read -r response

    if [[ -z "$response" ]]; then
        response="$default"
    fi

    [[ "$response" =~ ^[Yy] ]]
}

#
# プログレスバーを描画
# 引数: $1=現在値 $2=最大値 $3=幅（デフォルト: 50）
#
draw_progress_bar() {
    local current="${1:?現在値を指定してください}"
    local total="${2:?最大値を指定してください}"
    local width="${3:-50}"

    local filled=$((width * current / total))
    [[ $filled -gt $width ]] && filled=$width
    local empty=$((width - filled))

    local percent=$((100 * current / total))
    [[ $percent -gt 100 ]] && percent=100

    echo -n "["
    echo -ne "${C_GREEN}"
    for ((i = 0; i < filled; i++)); do
        echo -n "█"
    done
    echo -ne "${C_RESET}${C_DIM}"
    for ((i = 0; i < empty; i++)); do
        echo -n "░"
    done
    echo -ne "${C_RESET}"
    printf "] %3d%%" "$percent"
}

#
# スピナーを表示（バックグラウンド処理用）
# 使用例:
#   show_spinner &
#   SPINNER_PID=$!
#   long_running_command
#   kill $SPINNER_PID 2>/dev/null
#
show_spinner() {
    local chars='|/-\'
    local i=0

    while true; do
        printf '\r%s' "${chars:i++%${#chars}:1}"
        sleep 0.1
    done
}

#
# ファイルロックを取得してコマンドを実行
# 引数: $1=ロックファイル $@=実行するコマンド
#
with_file_lock() {
    local lock_file="${1:?ロックファイルを指定してください}"
    shift

    {
        flock -x 200
        "$@"
    } 200>"$lock_file"
}

# ============================================================================
# 初期化
# ============================================================================

# ライブラリ読み込み時にターミナルサイズを初期化
update_terminal_size
