#!/bin/bash
set -euo pipefail

#
# 24時間マラソン シミュレーター
# 作成日: 2024
# バージョン: 1.1
#
# 概要:
#   24時間テレビ風の100kmマラソンをシミュレートします
#   リアルタイム進捗表示、ランナーアニメーション、ゴール演出をサポート
#
# 使用例:
#   ./marathon.sh                     # インタラクティブメニュー
#   ./marathon.sh start               # マラソン開始
#   ./marathon.sh demo                # デモモード（高速）
#   ./marathon.sh start -n "山田太郎"
#

# ===== 共通ライブラリ読み込み =====
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

# ===== 設定（定数） =====
readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.1"

# ===== グローバル変数 =====
declare runner_name="ランナー"
declare -i total_distance=100  # km
declare -i time_limit=24       # hours
declare -i current_distance=0
declare -i elapsed_seconds=0
declare running=true
declare -i speed_multiplier=60  # 1秒 = 1分（デモ用）

# 応援メッセージ
readonly -a CHEER_MESSAGES=(
    "がんばれ！"
    "あと少し！"
    "負けないで！"
    "感動をありがとう！"
    "日本中が応援してるよ！"
    "最後まで走りきれ！"
    "君ならできる！"
    "諦めないで！"
    "みんなが待ってる！"
    "ゴールはもうすぐ！"
    "サライが待ってる！"
    "愛は地球を救う！"
    "奇跡を信じて！"
    "感動の涙！"
    "走れ！走れ！"
)

# ===== ヘルパー関数 =====

#
# 使用方法を表示
#
show_usage() {
    cat <<EOF
${C_YELLOW}24時間マラソン シミュレーター${C_RESET} v${VERSION}

使用方法: $PROG_NAME [オプション] [コマンド]

コマンド:
  start             マラソンを開始
  demo              デモモード（高速シミュレーション）
  records           過去の記録を表示

オプション:
  -h, --help        このヘルプを表示
  -v, --version     バージョン情報を表示
  -n, --name <名前> ランナー名を設定
  -d, --distance <km> 距離を設定（デフォルト: 100km）
  -t, --time <時間>  制限時間を設定（デフォルト: 24時間）
  -s, --speed <倍率> 時間の進み方（デモ用、デフォルト: 60）

例:
  $PROG_NAME start
  $PROG_NAME start -n "山田太郎"
  $PROG_NAME demo
  $PROG_NAME start -d 42 -t 6  # フルマラソン
EOF
}

# 共通ライブラリから提供される関数:
# - update_terminal_size, clear_screen, move_cursor
# - hide_cursor, show_cursor, print_center, format_time

# ===== マラソン表示関数 =====

# バナーを表示
show_banner() {
    echo -e "${C_YELLOW}"
    cat <<'EOF'
  ██████╗ ██╗  ██╗██╗  ██╗    ███╗   ███╗ █████╗ ██████╗  █████╗ ████████╗██╗  ██╗ ██████╗ ███╗   ██╗
 ██╔════╝ ██║  ██║██║  ██║    ████╗ ████║██╔══██╗██╔══██╗██╔══██╗╚══██╔══╝██║  ██║██╔═══██╗████╗  ██║
 ███████╗ ███████║███████║    ██╔████╔██║███████║██████╔╝███████║   ██║   ███████║██║   ██║██╔██╗ ██║
 ╚════██║ ╚════██║██╔══██║    ██║╚██╔╝██║██╔══██║██╔══██╗██╔══██║   ██║   ██╔══██║██║   ██║██║╚██╗██║
 ██████╔╝      ██║██║  ██║    ██║ ╚═╝ ██║██║  ██║██║  ██║██║  ██║   ██║   ██║  ██║╚██████╔╝██║ ╚████║
 ╚═════╝       ╚═╝╚═╝  ╚═╝    ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═══╝
EOF
    echo -e "${C_RESET}"
}

# ランナーのアスキーアート
draw_runner() {
    local frame=$1
    local row=$2
    local col=$3

    move_cursor "$row" "$col"

    case $((frame % 4)) in
        0)
            echo -ne "${C_CYAN}"
            move_cursor "$row" "$col"
            echo -n "   O  "
            move_cursor $((row + 1)) "$col"
            echo -n "  /|\\ "
            move_cursor $((row + 2)) "$col"
            echo -n "  / \\ "
            echo -ne "${C_RESET}"
            ;;
        1)
            echo -ne "${C_CYAN}"
            move_cursor "$row" "$col"
            echo -n "   O  "
            move_cursor $((row + 1)) "$col"
            echo -n "  /|\\ "
            move_cursor $((row + 2)) "$col"
            echo -n "   |  "
            echo -ne "${C_RESET}"
            ;;
        2)
            echo -ne "${C_CYAN}"
            move_cursor "$row" "$col"
            echo -n "   O  "
            move_cursor $((row + 1)) "$col"
            echo -n "  \\|/ "
            move_cursor $((row + 2)) "$col"
            echo -n "  / \\ "
            echo -ne "${C_RESET}"
            ;;
        3)
            echo -ne "${C_CYAN}"
            move_cursor "$row" "$col"
            echo -n "   O  "
            move_cursor $((row + 1)) "$col"
            echo -n "  \\|/ "
            move_cursor $((row + 2)) "$col"
            echo -n "   |  "
            echo -ne "${C_RESET}"
            ;;
    esac
}

# 進捗バーを描画
draw_progress_bar() {
    local current=$1
    local total=$2
    local row=$3
    local width=$((TERM_COLS - 20))

    local filled=$((width * current / total))
    [[ $filled -gt $width ]] && filled=$width
    local empty=$((width - filled))

    move_cursor "$row" 5

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
    echo -n "]"

    local percent=$((100 * current / total))
    printf " %3d%%" "$percent"
}

# マラソン画面を描画
draw_marathon_screen() {
    local frame=$1
    local distance_m=$2  # メートル単位
    local elapsed=$3

    clear_screen
    update_terminal_size

    # タイトルバー
    move_cursor 1 1
    echo -ne "${C_BG_YELLOW}${C_RED}${C_BOLD}"
    printf "%-${TERM_COLS}s" "  24時間テレビ「愛は地球を救う」 ${total_distance}kmマラソン"
    echo -ne "${C_RESET}"

    # ランナー情報
    move_cursor 3 1
    print_center "${C_WHITE}${C_BOLD}${runner_name}${C_RESET}" 3

    # 距離表示
    local distance_km
    distance_km=$(echo "scale=2; $distance_m / 1000" | bc)
    move_cursor 5 1
    print_center "${C_YELLOW}${C_BOLD}現在の距離: ${distance_km} km / ${total_distance} km${C_RESET}" 5

    # 進捗バー
    draw_progress_bar "$distance_m" "$((total_distance * 1000))" 7

    # 経過時間と残り時間
    local remaining=$((time_limit * 3600 - elapsed))
    [[ $remaining -lt 0 ]] && remaining=0

    move_cursor 9 1
    local elapsed_str
    elapsed_str=$(format_time "$elapsed")
    local remaining_str
    remaining_str=$(format_time "$remaining")

    print_center "${C_CYAN}経過時間: ${elapsed_str}${C_RESET}    ${C_MAGENTA}残り時間: ${remaining_str}${C_RESET}" 9

    # ランナーのアスキーアート
    local runner_col=$((5 + (TERM_COLS - 15) * distance_m / (total_distance * 1000)))
    [[ $runner_col -gt $((TERM_COLS - 10)) ]] && runner_col=$((TERM_COLS - 10))
    draw_runner "$frame" 12 "$runner_col"

    # コース表示
    move_cursor 15 1
    echo -ne "${C_DIM}"
    echo -n "START "
    for ((i = 0; i < TERM_COLS - 15; i++)); do
        if ((i % 10 == 0)); then
            echo -n "+"
        else
            echo -n "-"
        fi
    done
    echo -n " GOAL"
    echo -ne "${C_RESET}"

    # キロ表示
    move_cursor 16 1
    echo -ne "${C_DIM}"
    printf "%-6s" "0km"
    local markers=$((TERM_COLS - 15))
    for ((i = 1; i <= 4; i++)); do
        local pos=$((6 + markers * i / 4 - 3))
        move_cursor 16 "$pos"
        printf "%dkm" $((total_distance * i / 4))
    done
    echo -ne "${C_RESET}"

    # 応援メッセージ
    local msg_index=$((RANDOM % ${#CHEER_MESSAGES[@]}))
    move_cursor 18 1
    print_center "${C_YELLOW}${C_BOLD}📣 ${CHEER_MESSAGES[$msg_index]} 📣${C_RESET}" 18

    # ステータスバー
    move_cursor "$TERM_ROWS" 1
    echo -ne "${C_BG_BLUE}${C_WHITE}"
    printf "%-${TERM_COLS}s" "  [Space] 応援  [Q] 終了  [+/-] 速度調整"
    echo -ne "${C_RESET}"
}

# ゴール演出
show_goal_celebration() {
    clear_screen
    update_terminal_size

    hide_cursor

    # 花火アニメーション
    for ((i = 0; i < 5; i++)); do
        clear_screen

        move_cursor 3 1
        print_center "${C_YELLOW}${C_BOLD}★☆★☆★☆★☆★☆★☆★☆★☆★☆★☆★${C_RESET}" 3

        move_cursor 5 1
        print_center "${C_RED}${C_BOLD}祝！ゴール！！${C_RESET}" 5

        move_cursor 8 1
        print_center "${C_WHITE}${C_BOLD}${runner_name}${C_RESET}" 8

        move_cursor 10 1
        print_center "${C_CYAN}${total_distance}km 完走おめでとう！${C_RESET}" 10

        local elapsed_str
        elapsed_str=$(format_time "$elapsed_seconds")
        move_cursor 12 1
        print_center "${C_GREEN}タイム: ${elapsed_str}${C_RESET}" 12

        move_cursor 15 1
        print_center "${C_YELLOW}感動をありがとう！${C_RESET}" 15

        # 花火
        local colors=("${C_RED}" "${C_YELLOW}" "${C_GREEN}" "${C_CYAN}" "${C_MAGENTA}")
        for ((j = 0; j < 10; j++)); do
            local row=$((RANDOM % (TERM_ROWS - 10) + 5))
            local col=$((RANDOM % (TERM_COLS - 5) + 3))
            local color="${colors[$((RANDOM % ${#colors[@]}))]}"
            move_cursor "$row" "$col"
            echo -ne "${color}✦${C_RESET}"
        done

        move_cursor 18 1
        print_center "${C_YELLOW}${C_BOLD}★☆★☆★☆★☆★☆★☆★☆★☆★☆★☆★${C_RESET}" 18

        sleep 0.5
    done

    # サライ
    move_cursor 20 1
    print_center "${C_MAGENTA}♪ サライの空へ ♪${C_RESET}" 20

    move_cursor 22 1
    print_center "Enterキーで終了..." 22

    show_cursor
    read -r
}

# タイムオーバー演出
show_timeout() {
    clear_screen

    move_cursor 5 1
    print_center "${C_RED}${C_BOLD}TIME UP...${C_RESET}" 5

    move_cursor 8 1
    print_center "${C_WHITE}${runner_name}${C_RESET}" 8

    local distance_km
    distance_km=$(echo "scale=2; $current_distance / 1000" | bc)
    move_cursor 10 1
    print_center "${C_CYAN}走行距離: ${distance_km} km / ${total_distance} km${C_RESET}" 10

    move_cursor 13 1
    print_center "${C_YELLOW}最後まで諦めない姿に感動しました！${C_RESET}" 13

    move_cursor 16 1
    print_center "Enterキーで終了..." 16

    read -r
}

# ===== マラソン実行 =====

run_marathon() {
    hide_cursor
    trap 'show_cursor; clear_screen; exit 0' INT TERM

    local frame=0
    current_distance=0
    elapsed_seconds=0

    local start_time
    start_time=$(date +%s)

    # 平均速度: 100km / 24h ≈ 4.17 km/h ≈ 1.16 m/s
    # ただしデモ用に調整
    local base_speed=1160  # mm/s (実際の1.16 m/s)

    while $running; do
        # キー入力処理
        if read -rsn1 -t 0.1 key 2>/dev/null; then
            case "$key" in
                q|Q)
                    running=false
                    break
                    ;;
                ' ')
                    # 応援で少しスピードアップ
                    current_distance=$((current_distance + 50))
                    ;;
                '+')
                    speed_multiplier=$((speed_multiplier * 2))
                    [[ $speed_multiplier -gt 3600 ]] && speed_multiplier=3600
                    ;;
                '-')
                    speed_multiplier=$((speed_multiplier / 2))
                    [[ $speed_multiplier -lt 1 ]] && speed_multiplier=1
                    ;;
            esac
        fi

        # 時間更新（デモ用に加速）
        elapsed_seconds=$((elapsed_seconds + speed_multiplier / 10))

        # 距離更新（ランダム要素を加える）
        local speed_variation=$((RANDOM % 200 - 100))  # -100 to +100
        local current_speed=$((base_speed + speed_variation))
        current_distance=$((current_distance + current_speed * speed_multiplier / 10000))

        # 画面更新
        draw_marathon_screen "$frame" "$current_distance" "$elapsed_seconds"

        # ゴール判定
        if [[ $current_distance -ge $((total_distance * 1000)) ]]; then
            current_distance=$((total_distance * 1000))
            show_cursor
            show_goal_celebration
            running=false
            break
        fi

        # タイムオーバー判定
        if [[ $elapsed_seconds -ge $((time_limit * 3600)) ]]; then
            show_cursor
            show_timeout
            running=false
            break
        fi

        ((frame++))
        sleep 0.1
    done

    show_cursor
    clear_screen
}

# デモモード
demo_mode() {
    speed_multiplier=360  # 高速モード
    run_marathon
}

# インタラクティブメニュー
interactive_menu() {
    while true; do
        clear_screen
        show_banner

        echo ""
        echo -e "${C_YELLOW}24時間マラソン シミュレーター${C_RESET}"
        echo ""
        echo "  1) マラソンを開始（リアルタイム）"
        echo "  2) デモモード（高速シミュレーション）"
        echo "  3) 設定を変更"
        echo "  4) ヘルプ"
        echo "  q) 終了"
        echo ""
        echo -e "  ${C_DIM}現在の設定:${C_RESET}"
        echo -e "    ランナー: ${C_CYAN}${runner_name}${C_RESET}"
        echo -e "    距離: ${C_CYAN}${total_distance}km${C_RESET}"
        echo -e "    制限時間: ${C_CYAN}${time_limit}時間${C_RESET}"
        echo ""
        echo -n "選択 [1-4, q]: "

        read -r choice

        case "$choice" in
            1)
                run_marathon
                ;;
            2)
                demo_mode
                ;;
            3)
                clear_screen
                echo -e "${C_CYAN}設定変更${C_RESET}"
                echo ""
                echo -n "ランナー名 [${runner_name}]: "
                read -r new_name
                [[ -n "$new_name" ]] && runner_name="$new_name"

                echo -n "距離（km） [${total_distance}]: "
                read -r new_distance
                [[ -n "$new_distance" ]] && total_distance="$new_distance"

                echo -n "制限時間（時間） [${time_limit}]: "
                read -r new_time
                [[ -n "$new_time" ]] && time_limit="$new_time"

                echo ""
                echo -e "${C_GREEN}設定を更新しました${C_RESET}"
                sleep 1
                ;;
            4)
                clear_screen
                show_usage
                echo ""
                echo "Enterキーで戻る..."
                read -r
                ;;
            q|Q)
                echo ""
                echo "また会おう！"
                exit 0
                ;;
            *)
                echo -e "${C_RED}無効な選択です${C_RESET}"
                sleep 1
                ;;
        esac
    done
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
            -n|--name)
                [[ $# -lt 2 ]] && { echo "エラー: --name には値が必要です"; exit 1; }
                runner_name="$2"
                shift 2
                ;;
            -d|--distance)
                [[ $# -lt 2 ]] && { echo "エラー: --distance には値が必要です"; exit 1; }
                total_distance="$2"
                shift 2
                ;;
            -t|--time)
                [[ $# -lt 2 ]] && { echo "エラー: --time には値が必要です"; exit 1; }
                time_limit="$2"
                shift 2
                ;;
            -s|--speed)
                [[ $# -lt 2 ]] && { echo "エラー: --speed には値が必要です"; exit 1; }
                speed_multiplier="$2"
                shift 2
                ;;
            start|demo|records)
                command="$1"
                shift
                ;;
            *)
                echo "不明なオプション: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    case "$command" in
        start)
            run_marathon
            ;;
        demo)
            demo_mode
            ;;
        records)
            echo "過去の記録機能は準備中です"
            ;;
        "")
            interactive_menu
            ;;
    esac
}

# ===== メイン処理 =====

main() {
    parse_arguments "$@"
}

# スクリプト実行
main "$@"
