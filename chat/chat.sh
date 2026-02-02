#!/bin/bash
set -euo pipefail

#
# シェルスクリプトチャット - ランチャー
# 作成日: 2024
# バージョン: 1.0
#
# チャットサーバー/クライアントを簡単に起動するためのランチャー
#

# ===== 設定（定数） =====
readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 色定義
readonly C_RESET='\033[0m'
readonly C_BOLD='\033[1m'
readonly C_RED='\033[1;31m'
readonly C_GREEN='\033[1;32m'
readonly C_YELLOW='\033[1;33m'
readonly C_BLUE='\033[1;34m'
readonly C_CYAN='\033[1;36m'
readonly C_BG_BLUE='\033[44m'
readonly C_WHITE='\033[1;37m'

# ===== ヘルパー関数 =====

show_banner() {
    echo -e "${C_CYAN}"
    cat <<'EOF'
  ____  _          _ _    ____ _           _
 / ___|| |__   ___| | |  / ___| |__   __ _| |_
 \___ \| '_ \ / _ \ | | | |   | '_ \ / _` | __|
  ___) | | | |  __/ | | | |___| | | | (_| | |_
 |____/|_| |_|\___|_|_|  \____|_| |_|\__,_|\__|

EOF
    echo -e "${C_RESET}"
    echo -e "${C_BOLD}シェルスクリプト同士でチャットができるツール${C_RESET}"
    echo -e "Version ${VERSION}"
    echo ""
}

show_usage() {
    show_banner
    cat <<EOF
${C_YELLOW}使用方法:${C_RESET}
  $PROG_NAME [コマンド] [オプション]

${C_YELLOW}コマンド:${C_RESET}
  server    サーバーモードで起動
  client    クライアントモードで起動
  quick     サーバーを起動してクライアントに接続（クイックスタート）
  demo      デモモード（複数ウィンドウを自動起動）
  help      このヘルプを表示

${C_YELLOW}例:${C_RESET}
  ${C_GREEN}# サーバーを起動${C_RESET}
  $PROG_NAME server start myroom

  ${C_GREEN}# クライアントで参加${C_RESET}
  $PROG_NAME client -r myroom -u Alice

  ${C_GREEN}# クイックスタート（サーバー+クライアント）${C_RESET}
  $PROG_NAME quick

  ${C_GREEN}# デモモード（tmuxで複数ウィンドウ）${C_RESET}
  $PROG_NAME demo

${C_YELLOW}詳細なヘルプ:${C_RESET}
  $PROG_NAME server --help
  $PROG_NAME client --help
EOF
}

show_menu() {
    show_banner
    echo -e "${C_YELLOW}何をしますか？${C_RESET}"
    echo ""
    echo "  1) チャットルームを作成する（サーバー）"
    echo "  2) チャットルームに参加する（クライアント）"
    echo "  3) クイックスタート（ルーム作成 + 参加）"
    echo "  4) デモモード（複数ウィンドウ）"
    echo "  5) ルーム一覧を表示"
    echo "  6) ヘルプを表示"
    echo "  q) 終了"
    echo ""
    echo -n "選択 [1-6, q]: "
}

# クイックスタート
quick_start() {
    local room_name="${1:-general}"

    echo -e "${C_CYAN}クイックスタート${C_RESET}"
    echo ""

    # サーバーを起動
    echo -e "${C_GREEN}[1/2]${C_RESET} チャットルームを作成中..."
    "${SCRIPT_DIR}/chat_server.sh" start "${room_name}" 2>/dev/null || true

    echo ""
    echo -e "${C_GREEN}[2/2]${C_RESET} チャットに参加します..."
    echo ""
    sleep 1

    # クライアントを起動
    "${SCRIPT_DIR}/chat_client.sh" -r "${room_name}"
}

# デモモード（tmuxを使用）
demo_mode() {
    local room_name="demo_room"

    # tmuxの存在確認
    if ! command -v tmux &> /dev/null; then
        echo -e "${C_RED}エラー: tmux がインストールされていません${C_RESET}"
        echo ""
        echo "デモモードには tmux が必要です。"
        echo "インストール: sudo apt install tmux"
        echo ""
        echo "代わりに複数のターミナルを開いて以下を実行してください:"
        echo ""
        echo "ターミナル1（サーバー）:"
        echo "  ${SCRIPT_DIR}/chat_server.sh start ${room_name}"
        echo ""
        echo "ターミナル2（クライアント1）:"
        echo "  ${SCRIPT_DIR}/chat_client.sh -r ${room_name} -u Alice"
        echo ""
        echo "ターミナル3（クライアント2）:"
        echo "  ${SCRIPT_DIR}/chat_client.sh -r ${room_name} -u Bob"
        exit 1
    fi

    echo -e "${C_CYAN}デモモードを開始します${C_RESET}"
    echo ""

    # サーバーを起動
    "${SCRIPT_DIR}/chat_server.sh" start "${room_name}" 2>/dev/null || true

    # tmuxセッションを作成
    local session_name="shell_chat_demo"

    # 既存のセッションを削除
    tmux kill-session -t "${session_name}" 2>/dev/null || true

    # 新しいセッションを作成
    tmux new-session -d -s "${session_name}" -n "Alice"
    tmux send-keys -t "${session_name}:Alice" "${SCRIPT_DIR}/chat_client.sh -r ${room_name} -u Alice" Enter

    # 2つ目のウィンドウを追加
    tmux new-window -t "${session_name}" -n "Bob"
    tmux send-keys -t "${session_name}:Bob" "${SCRIPT_DIR}/chat_client.sh -r ${room_name} -u Bob" Enter

    # 3つ目のウィンドウを追加
    tmux new-window -t "${session_name}" -n "Charlie"
    tmux send-keys -t "${session_name}:Charlie" "${SCRIPT_DIR}/chat_client.sh -r ${room_name} -u Charlie" Enter

    echo -e "${C_GREEN}tmuxセッション '${session_name}' を作成しました${C_RESET}"
    echo ""
    echo "セッションに接続するには:"
    echo "  tmux attach -t ${session_name}"
    echo ""
    echo "ウィンドウの切り替え: Ctrl+B → 数字キー (0, 1, 2)"
    echo "セッション終了: Ctrl+B → D (デタッチ) または各ウィンドウで /quit"
    echo ""

    # セッションにアタッチ
    tmux attach -t "${session_name}"

    # 終了後にルームを停止
    "${SCRIPT_DIR}/chat_server.sh" stop "${room_name}" 2>/dev/null || true
}

# インタラクティブメニュー
interactive_menu() {
    while true; do
        clear
        show_menu
        read -r choice

        case "$choice" in
            1)
                clear
                echo -e "${C_CYAN}チャットルームを作成${C_RESET}"
                echo ""
                echo -n "ルーム名を入力 [general]: "
                read -r room_name
                room_name="${room_name:-general}"
                "${SCRIPT_DIR}/chat_server.sh" start "${room_name}"
                echo ""
                echo "Enterキーで続行..."
                read -r
                ;;
            2)
                clear
                echo -e "${C_CYAN}チャットルームに参加${C_RESET}"
                echo ""
                # ルーム一覧を表示
                "${SCRIPT_DIR}/chat_server.sh" list
                echo ""
                echo -n "参加するルーム名 [general]: "
                read -r room_name
                room_name="${room_name:-general}"
                echo -n "ユーザー名: "
                read -r user_name
                if [[ -z "${user_name}" ]]; then
                    user_name="User_$$"
                fi
                "${SCRIPT_DIR}/chat_client.sh" -r "${room_name}" -u "${user_name}"
                ;;
            3)
                clear
                echo -n "ルーム名を入力 [general]: "
                read -r room_name
                room_name="${room_name:-general}"
                quick_start "${room_name}"
                ;;
            4)
                clear
                demo_mode
                ;;
            5)
                clear
                "${SCRIPT_DIR}/chat_server.sh" list
                echo ""
                echo "Enterキーで続行..."
                read -r
                ;;
            6)
                clear
                show_usage
                echo ""
                echo "Enterキーで続行..."
                read -r
                ;;
            q|Q)
                echo ""
                echo "終了します。"
                exit 0
                ;;
            *)
                echo ""
                echo -e "${C_RED}無効な選択です${C_RESET}"
                sleep 1
                ;;
        esac
    done
}

# ===== メイン処理 =====

main() {
    # 引数がない場合はインタラクティブメニュー
    if [[ $# -eq 0 ]]; then
        interactive_menu
        exit 0
    fi

    local command="$1"
    shift

    case "${command}" in
        server)
            "${SCRIPT_DIR}/chat_server.sh" "$@"
            ;;
        client)
            "${SCRIPT_DIR}/chat_client.sh" "$@"
            ;;
        quick)
            quick_start "$@"
            ;;
        demo)
            demo_mode
            ;;
        help|--help|-h)
            show_usage
            ;;
        version|--version|-v)
            echo "$PROG_NAME version $VERSION"
            ;;
        *)
            echo -e "${C_RED}不明なコマンド: ${command}${C_RESET}"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

# スクリプト実行
main "$@"
