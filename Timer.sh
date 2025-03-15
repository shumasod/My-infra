#!/bin/bash
#
# 高機能カウントダウンタイマー
# 作成日: 2025-03-13
# バージョン: 1.1
#
# 指定された時間をカウントダウン表示するスクリプト
# 進捗バーと残り時間を表示し、時間になったら通知します
#

# ===== 設定（定数） =====
readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.1"
readonly PROG_BAR_WIDTH=30       # プログレスバーの長さ
readonly PROG_BAR_CHAR_DONE="█"  # 完了部分の文字
readonly PROG_BAR_CHAR_TODO="░"  # 未完了部分の文字
readonly UPDATE_INTERVAL=1       # 画面更新間隔（秒）
readonly DEFAULT_BEEP_COUNT=3    # 終了時のビープ音回数

# ===== 変数 =====
timer_minutes=0
timer_title="タイマー"
quiet_mode=false
no_beep=false
no_clear=false
beep_count=$DEFAULT_BEEP_COUNT

# ===== 関数 =====

# 使用方法を表示
show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション] <分>

カウントダウンタイマーを表示します。指定された時間をカウントダウンし、
プログレスバーと残り時間を表示します。時間になったら通知します。

引数:
  <分>                   カウントダウンする時間（分）

オプション:
  -h, --help             このヘルプメッセージを表示して終了
  -v, --version          バージョン情報を表示して終了
  -t, --title <タイトル>  タイマーのタイトルを指定 (デフォルト: "$timer_title")
  -q, --quiet            最小限の出力（終了時のみ通知）
  -n, --no-beep          終了時にビープ音を鳴らさない
  -c, --no-clear         画面クリアを行わない
  -b, --beeps <回数>     終了時のビープ音の回数 (デフォルト: $DEFAULT_BEEP_COUNT)

例:
  $PROG_NAME 5                  # 5分のタイマーを開始
  $PROG_NAME -t "休憩時間" 15    # 「休憩時間」というタイトルで15分のタイマーを開始
  $PROG_NAME --no-beep 3        # ビープ音なしで3分のタイマーを開始
EOF
}

# バージョン情報を表示
show_version() {
    echo "$PROG_NAME version $VERSION"
}

# エラーメッセージを表示
show_error() {
    echo "エラー: $1" >&2
    echo "詳しい使用方法は「$PROG_NAME --help」を参照してください" >&2
}

# 画面をクリア
clear_screen() {
    if [ "$no_clear" = false ]; then
        clear
    else
        # 画面クリアしない場合は、カーソルを先頭行に移動
        echo -en "\r\033[K"
    fi
}

# プログレスバーを作成
create_progress_bar() {
    local progress=$1
    local width=$2
    local char_done=$3
    local char_todo=$4
    local result=""
    
    for (( i=0; i<width; i++ )); do
        if [ $i -lt $progress ]; then
            result+="$char_done"
        else
            result+="$char_todo"
        fi
    done
    
    echo "$result"
}

# 時間を見やすい形式に変換
format_time() {
    local seconds=$1
    local hours=$(( seconds / 3600 ))
    local minutes=$(( (seconds % 3600) / 60 ))
    local secs=$(( seconds % 60 ))
    
    if [ $hours -gt 0 ]; then
        printf "%d時間%02d分%02d秒" $hours $minutes $secs
    else
        printf "%d分%02d秒" $minutes $secs
    fi
}

# ビープ音を鳴らす
play_beep() {
    local count=$1
    
    if [ "$no_beep" = false ]; then
        for (( i=0; i<count; i++ )); do
            echo -en "\a"  # ビープ音
            sleep 0.5
        done
    fi
}

# 終了時の通知
show_finish_notification() {
    clear_screen
    echo "=========================="
    echo "    時間になりました！    "
    echo "=========================="
    echo
    echo "$timer_title が完了しました"
    echo
    
    play_beep "$beep_count"
}

# シグナルハンドラ（Ctrl+C）
handle_interrupt() {
    clear_screen
    echo "タイマーが中断されました"
    exit 130  # 128 + SIGINT(2)
}

# メインのカウントダウン処理
run_countdown() {
    local minutes=$1
    local title=$2
    
    # 時間の計算
    local total_seconds=$(( minutes * 60 ))
    local end_time=$(( $(date +%s) + total_seconds ))
    local start_time=$(date +%s)
    
    # 初期値が大きすぎないかチェック
    if [ $total_seconds -gt 86400 ]; then  # 24時間を超える場合
        show_error "時間が長すぎます (最大24時間)"
        exit 1
    fi
    
    clear_screen
    
    # 静かモードの場合は最小限の表示
    if [ "$quiet_mode" = true ]; then
        echo "$title: $(format_time $total_seconds) のタイマーを開始しました"
        echo "バックグラウンドで実行中..."
        sleep $total_seconds
        show_finish_notification
        return
    fi
    
    # カウントダウンループ
    while true; do
        # 現在時刻と残り時間を計算
        local current_time=$(date +%s)
        local elapsed_seconds=$(( current_time - start_time ))
        local remaining_seconds=$(( end_time - current_time ))
        
        # 終了判定
        if [ $remaining_seconds -le 0 ]; then
            break
        fi
        
        # 進捗状況を計算
        local progress=$(( elapsed_seconds * PROG_BAR_WIDTH / total_seconds ))
        local percentage=$(( elapsed_seconds * 100 / total_seconds ))
        
        # プログレスバーを作成
        local progress_bar=$(create_progress_bar $progress $PROG_BAR_WIDTH "$PROG_BAR_CHAR_DONE" "$PROG_BAR_CHAR_TODO")
        
        # 残り時間と進捗を表示
        clear_screen
        echo "==== $title ===="
        echo
        echo "残り時間: $(format_time $remaining_seconds)"
        echo "経過時間: $(format_time $elapsed_seconds)"
        echo "合計時間: $(format_time $total_seconds)"
        echo
        echo "[$progress_bar] $percentage%"
        echo
        echo "Ctrl+C で中断"
        
        # 残り時間に応じて更新間隔を調整
        if [ $remaining_seconds -gt 10 ]; then
            sleep $UPDATE_INTERVAL
        else
            # 残り10秒未満は0.5秒ごとに更新
            sleep 0.5
        fi
    done
    
    show_finish_notification
}

# ===== メイン処理 =====

# シグナルハンドラを設定
trap handle_interrupt INT

# コマンドライン引数の解析
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
            shift
            if [ $# -lt 1 ]; then
                show_error "--title オプションには値が必要です"
                exit 1
            fi
            timer_title="$1"
            shift
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
            shift
            if [ $# -lt 1 ]; then
                show_error "--beeps オプションには値が必要です"
                exit 1
            fi
            if ! [[ $1 =~ ^[0-9]+$ ]]; then
                show_error "ビープ回数は数字である必要があります"
                exit 1
            fi
            beep_count=$1
            shift
            ;;
        -*)
            show_error "不明なオプション: $1"
            exit 1
            ;;
        *)
            # 非オプション引数は時間（分）として解釈
            if ! [[ $1 =~ ^[0-9]+$ ]]; then
                show_error "分は数字である必要があります"
                exit 1
            fi
            
            if [ $1 -eq 0 ]; then
                show_error "時間は1分以上である必要があります"
                exit 1
            fi
            
            timer_minutes=$1
            shift
            ;;
    esac
done

# 分の引数が指定されていない場合はエラー
if [ $timer_minutes -eq 0 ]; then
    show_error "時間（分）を指定してください"
    show_usage
    exit 1
fi

# カウントダウンを開始
run_countdown "$timer_minutes" "$timer_title"

exit 0
