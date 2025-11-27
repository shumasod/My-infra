#!/bin/bash
set -euo pipefail

#
# 高機能カウントダウンタイマー
# 作成日: 2025-03-13
# バージョン: 2.0
#
# 指定された時間をカウントダウン表示するスクリプト
# 進捗バーと残り時間を表示し、時間になったら通知します
#

# ===== 設定（定数） =====
readonly PROG_NAME=$(basename "$0")
readonly VERSION="2.0"
readonly PROG_BAR_WIDTH=30
readonly PROG_BAR_CHAR_DONE="█"
readonly PROG_BAR_CHAR_TODO="░"
readonly UPDATE_INTERVAL=1
readonly DEFAULT_BEEP_COUNT=3
readonly MAX_HOURS=24

# 色定義
readonly COLOR_TITLE='\033[1;36m'    # シアン（太字）
readonly COLOR_TIME='\033[1;32m'     # 緑（太字）
readonly COLOR_PROGRESS='\033[1;33m' # 黄色（太字）
readonly COLOR_ERROR='\033[1;31m'    # 赤（太字）
readonly COLOR_SUCCESS='\033[1;32m'  # 緑（太字）
readonly COLOR_RESET='\033[0m'

# ===== グローバル変数 =====
declare -i timer_minutes=0
declare timer_title="タイマー"
declare -i beep_count=$DEFAULT_BEEP_COUNT
declare quiet_mode=false
declare no_beep=false
declare no_clear=false

# ===== ヘルパー関数 =====

# 使用方法を表示
show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション] <分>

カウントダウンタイマーを表示します。指定された時間をカウントダウンし、
プログレスバーと残り時間を表示します。時間になったら通知します。

引数:
  <分>                   カウントダウンする時間（分）[1-1440]

オプション:
  -h, --help             このヘルプメッセージを表示して終了
  -v, --version          バージョン情報を表示して終了
  -t, --title <タイトル>  タイマーのタイトルを指定
  -q, --quiet            最小限の出力（終了時のみ通知）
  -n, --no-beep          終了時にビープ音を鳴らさない
  -c, --no-clear         画面クリアを行わない
  -b, --beeps <回数>     終了時のビープ音の回数 [0-10]

例:
  $PROG_NAME 5                    # 5分のタイマーを開始
  $PROG_NAME -t "休憩時間" 15      # タイトル付きで15分のタイマー
  $PROG_NAME --no-beep 3          # ビープ音なしで3分のタイマー
  $PROG_NAME -q 30                # 静かモードで30分のタイマー

終了コード:
  0    正常終了
  1    エラー（引数不正、時間切れなど）
  130  ユーザーによる中断（Ctrl+C）
EOF
}

# バージョン情報を表示
show_version() {
    echo "$PROG_NAME version $VERSION"
}

# エラーメッセージを表示して終了
error_exit() {
    echo -e "${COLOR_ERROR}エラー: $1${COLOR_RESET}" >&2
    echo "詳しい使用方法は「$PROG_NAME --help」を参照してください" >&2
    exit 1
}

# 数値検証
validate_number() {
    local value="$1"
    local min="$2"
    local max="$3"
    local name="$4"
    
    if ! [[ $value =~ ^[0-9]+$ ]]; then
        error_exit "${name}は数字である必要があります: $value"
    fi
    
    if [ "$value" -lt "$min" ] || [ "$value" -gt "$max" ]; then
        error_exit "${name}は${min}から${max}の範囲で指定してください: $value"
    fi
}

# 画面をクリア
clear_screen() {
    if [ "$no_clear" = false ]; then
        clear
    else
        echo -en "\r\033[K"
    fi
}

# ===== 表示関連関数 =====

# プログレスバーを作成
create_progress_bar() {
    local -i progress=$1
    local -i width=$2
    local result=""
    
    # 範囲チェック
    progress=$(( progress > width ? width : progress ))
    progress=$(( progress < 0 ? 0 : progress ))
    
    result="${PROG_BAR_CHAR_DONE}"
    printf "%${progress}s" | tr ' ' "${PROG_BAR_CHAR_DONE: -1}"
    printf "%$((width - progress))s" | tr ' ' "${PROG_BAR_CHAR_TODO: -1}"
}

# 時間を見やすい形式に変換
format_time() {
    local -i seconds=$1
    local -i hours=$((seconds / 3600))
    local -i minutes=$(((seconds % 3600) / 60))
    local -i secs=$((seconds % 60))
    
    if [ $hours -gt 0 ]; then
        printf "%d時間%02d分%02d秒" $hours $minutes $secs
    elif [ $minutes -gt 0 ]; then
        printf "%d分%02d秒" $minutes $secs
    else
        printf "%d秒" $secs
    fi
}

# タイマー情報を表示
display_timer_info() {
    local -i remaining=$1
    local -i elapsed=$2
    local -i total=$3
    local title="$4"
    
    local -i progress=$((elapsed * PROG_BAR_WIDTH / total))
    local -i percentage=$((elapsed * 100 / total))
    local progress_bar
    progress_bar=$(create_progress_bar "$progress" "$PROG_BAR_WIDTH")
    
    clear_screen
    echo -e "${COLOR_TITLE}==== $title ====${COLOR_RESET}"
    echo
    echo -e "${COLOR_TIME}残り時間:${COLOR_RESET} $(format_time "$remaining")"
    echo -e "経過時間: $(format_time "$elapsed")"
    echo -e "合計時間: $(format_time "$total")"
    echo
    echo -e "${COLOR_PROGRESS}[$progress_bar] $percentage%${COLOR_RESET}"
    echo
    echo "Ctrl+C で中断"
}

# ビープ音を鳴らす
play_beep() {
    local -i count=$1
    
    if [ "$no_beep" = false ]; then
        for (( i=0; i<count; i++ )); do
            echo -en "\a"
            sleep 0.5
        done
    fi
}

# 終了時の通知
show_finish_notification() {
    clear_screen
    echo -e "${COLOR_SUCCESS}"
    echo "╔══════════════════════════════╗"
    echo "║                              ║"
    echo "║    時間になりました！        ║"
    echo "║                              ║"
    echo "╚══════════════════════════════╝"
    echo -e "${COLOR_RESET}"
    echo
    echo "$timer_title が完了しました"
    echo "完了時刻: $(date '+%Y-%m-%d %H:%M:%S')"
    echo
    
    play_beep "$beep_count"
}

# ===== シグナルハンドラ =====

# Ctrl+C 割り込み処理
handle_interrupt() {
    clear_screen
    echo -e "${COLOR_ERROR}タイマーが中断されました${COLOR_RESET}"
    exit 130
}

# ===== メインロジック =====

# カウントダウン処理（静かモード）
run_countdown_quiet() {
    local -i total_seconds=$1
    local title="$2"
    
    echo -e "${COLOR_TIME}$title: $(format_time "$total_seconds") のタイマーを開始しました${COLOR_RESET}"
    echo "バックグラウンドで実行中... (Ctrl+C で中断)"
    
    sleep "$total_seconds"
    show_finish_notification
}

# カウントダウン処理（通常モード）
run_countdown_normal() {
    local -i total_seconds=$1
    local title="$2"
    local -i end_time start_time
    
    end_time=$(($(date +%s) + total_seconds))
    start_time=$(date +%s)
    
    while true; do
        local -i current_time elapsed_seconds remaining_seconds
        
        current_time=$(date +%s)
        elapsed_seconds=$((current_time - start_time))
        remaining_seconds=$((end_time - current_time))
        
        # 終了判定
        if [ $remaining_seconds -le 0 ]; then
            break
        fi
        
        # 表示更新
        display_timer_info "$remaining_seconds" "$elapsed_seconds" "$total_seconds" "$title"
        
        # 更新間隔（残り10秒未満は0.5秒ごと）
        if [ $remaining_seconds -gt 10 ]; then
            sleep "$UPDATE_INTERVAL"
        else
            sleep 0.5
        fi
    done
    
    show_finish_notification
}

# メインのカウントダウン処理
run_countdown() {
    local -i minutes=$1
    local title="$2"
    local -i total_seconds=$((minutes * 60))
    local -i max_seconds=$((MAX_HOURS * 3600))
    
    # 最大時間チェック
    if [ $total_seconds -gt $max_seconds ]; then
        error_exit "時間が長すぎます (最大${MAX_HOURS}時間)"
    fi
    
    clear_screen
    
    # モード別処理
    if [ "$quiet_mode" = true ]; then
        run_countdown_quiet "$total_seconds" "$title"
    else
        run_countdown_normal "$total_seconds" "$title"
    fi
}

# ===== 引数解析 =====

parse_arguments() {
    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help)
                show_usage
                exit 0
                ;;
            -v|--version)
                show_version
                exit 0
                ;;
            -t|--title)
                [ $# -lt 2 ] && error_exit "--title オプションには値が必要です"
                timer_title="$2"
                shift 2
                ;;
            -q|--quiet)
                quiet_mode=true
                shift
                ;;
            -n|--no-beep)
                no_beep=true
                shift
                ;;
            -c|--no-clear)
                no_clear=true
                shift
                ;;
            -b|--beeps)
                [ $# -lt 2 ] && error_exit "--beeps オプションには値が必要です"
                validate_number "$2" 0 10 "ビープ回数"
                beep_count=$2
                shift 2
                ;;
            -*)
                error_exit "不明なオプション: $1"
                ;;
            *)
                validate_number "$1" 1 1440 "時間（分）"
                timer_minutes=$1
                shift
                ;;
        esac
    done
    
    # 必須引数チェック
    if [ $timer_minutes -eq 0 ]; then
        error_exit "時間（分）を指定してください"
    fi
}

# ===== メイン処理 =====

main() {
    # シグナルハンドラ設定
    trap handle_interrupt INT TERM
    
    # 引数解析
    parse_arguments "$@"
    
    # カウントダウン開始
    run_countdown "$timer_minutes" "$timer_title"
    
    exit 0
}

# スクリプト実行
main "$@"
