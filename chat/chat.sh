#!/bin/bash
set -euo pipefail

#
# シェルスクリプトチャット - ランチャー
# 作成日: 2024
# バージョン: 2.1
#
# 概要:
#   チャットサーバー/クライアント/グループを簡単に管理するためのランチャー
#   インタラクティブメニューまたはコマンドラインから操作可能
#
# 使用例:
#   ./chat.sh                  # インタラクティブメニュー
#   ./chat.sh quick            # クイックスタート
#   ./chat.sh group create "開発チーム"
#

# ===== 共通ライブラリ読み込み =====
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

# ===== 設定（定数） =====
readonly PROG_NAME=$(basename "$0")
readonly VERSION="2.1"
readonly DEFAULT_CHAT_DIR="/tmp/shell_chat"

# ===== グローバル変数 =====
declare current_user="${USER:-anonymous}"

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
    echo -e "Version ${VERSION} ${C_DIM}(グループチャット対応)${C_RESET}"
    echo ""
}

show_usage() {
    show_banner
    cat <<EOF
${C_YELLOW}使用方法:${C_RESET}
  $PROG_NAME [コマンド] [オプション]

${C_YELLOW}基本コマンド:${C_RESET}
  server              サーバーモードで起動
  client              クライアントモードで起動
  quick               クイックスタート（ルーム作成 + 参加）
  demo                デモモード（複数ウィンドウを自動起動）

${C_YELLOW}グループチャットコマンド:${C_RESET}
  group               グループ管理（サブコマンド有り）
  groups              グループ一覧を表示
  join <グループ名>   グループに参加してチャット開始

${C_YELLOW}その他:${C_RESET}
  help                このヘルプを表示

${C_YELLOW}例:${C_RESET}
  ${C_GREEN}# 通常のチャットルーム${C_RESET}
  $PROG_NAME quick

  ${C_GREEN}# グループを作成${C_RESET}
  $PROG_NAME group create "開発チーム" "開発者用チャット"

  ${C_GREEN}# グループに参加してチャット${C_RESET}
  $PROG_NAME join "開発チーム"

  ${C_GREEN}# グループ管理${C_RESET}
  $PROG_NAME group invite "開発チーム" Alice
  $PROG_NAME group password "開発チーム" secret123

${C_YELLOW}詳細なヘルプ:${C_RESET}
  $PROG_NAME group --help
  $PROG_NAME server --help
  $PROG_NAME client --help
EOF
}

show_menu() {
    show_banner
    echo -e "${C_YELLOW}何をしますか？${C_RESET}"
    echo ""
    echo -e "  ${C_BOLD}--- 通常チャット ---${C_RESET}"
    echo "  1) チャットルームを作成する（サーバー）"
    echo "  2) チャットルームに参加する（クライアント）"
    echo "  3) クイックスタート（ルーム作成 + 参加）"
    echo ""
    echo -e "  ${C_BOLD}--- グループチャット ---${C_RESET}"
    echo "  4) グループを作成する"
    echo "  5) グループに参加する"
    echo "  6) グループ一覧を表示"
    echo "  7) グループを管理する"
    echo ""
    echo -e "  ${C_BOLD}--- その他 ---${C_RESET}"
    echo "  8) デモモード（複数ウィンドウ）"
    echo "  9) ヘルプを表示"
    echo "  q) 終了"
    echo ""
    echo -e "  ${C_DIM}現在のユーザー: ${current_user}${C_RESET}"
    echo ""
    echo -n "選択 [1-9, q]: "
}

# グループ管理サブメニュー
show_group_menu() {
    clear
    echo -e "${C_MAGENTA}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  グループ管理"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${C_RESET}"
    echo ""
    echo "  1) グループ情報を表示"
    echo "  2) メンバーを招待"
    echo "  3) メンバーを追放"
    echo "  4) 管理者に昇格"
    echo "  5) パスワードを設定/解除"
    echo "  6) 公開/非公開を切り替え"
    echo "  7) グループを削除"
    echo "  b) 戻る"
    echo ""
    echo -n "選択 [1-7, b]: "
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
    "${SCRIPT_DIR}/chat_client.sh" -r "${room_name}" -u "${current_user}"
}

# グループクイックスタート
group_quick_start() {
    local group_name="$1"

    if [[ -z "$group_name" ]]; then
        echo -n "グループ名を入力: "
        read -r group_name
        if [[ -z "$group_name" ]]; then
            echo -e "${C_RED}グループ名が必要です${C_RESET}"
            return 1
        fi
    fi

    # グループが存在しない場合は作成
    local group_path="${DEFAULT_CHAT_DIR}/groups/${group_name}"
    if [[ ! -d "$group_path" ]]; then
        echo -e "${C_YELLOW}グループ '${group_name}' が存在しません。作成しますか？ [Y/n]:${C_RESET} "
        read -r create_confirm
        if [[ ! "$create_confirm" =~ ^[Nn]$ ]]; then
            "${SCRIPT_DIR}/group_manager.sh" -u "${current_user}" create "$group_name"
        else
            return 1
        fi
    fi

    # グループに参加していない場合は参加
    if ! grep -q "^${current_user}:" "${group_path}/members.list" 2>/dev/null; then
        "${SCRIPT_DIR}/group_manager.sh" -u "${current_user}" join "$group_name"
    fi

    echo ""
    echo -e "${C_GREEN}グループチャットに参加します...${C_RESET}"
    sleep 1

    # クライアントを起動（グループ用パス）
    "${SCRIPT_DIR}/chat_client.sh" -r "groups/${group_name}" -u "${current_user}"
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
        return 1
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

# グループデモモード
group_demo_mode() {
    local group_name="demo_group"

    # tmuxの存在確認
    if ! command -v tmux &> /dev/null; then
        echo -e "${C_RED}エラー: tmux がインストールされていません${C_RESET}"
        return 1
    fi

    echo -e "${C_CYAN}グループチャットデモモードを開始します${C_RESET}"
    echo ""

    # グループを作成
    "${SCRIPT_DIR}/group_manager.sh" -u "Alice" create "${group_name}" "デモ用グループ" 2>/dev/null || true

    # メンバーを追加
    "${SCRIPT_DIR}/group_manager.sh" -u "Alice" invite "${group_name}" "Bob" 2>/dev/null || true
    "${SCRIPT_DIR}/group_manager.sh" -u "Alice" invite "${group_name}" "Charlie" 2>/dev/null || true
    "${SCRIPT_DIR}/group_manager.sh" -u "Bob" join "${group_name}" 2>/dev/null || true
    "${SCRIPT_DIR}/group_manager.sh" -u "Charlie" join "${group_name}" 2>/dev/null || true

    # tmuxセッションを作成
    local session_name="shell_group_demo"

    # 既存のセッションを削除
    tmux kill-session -t "${session_name}" 2>/dev/null || true

    # 新しいセッションを作成
    tmux new-session -d -s "${session_name}" -n "Alice"
    tmux send-keys -t "${session_name}:Alice" "${SCRIPT_DIR}/chat_client.sh -r groups/${group_name} -u Alice" Enter

    tmux new-window -t "${session_name}" -n "Bob"
    tmux send-keys -t "${session_name}:Bob" "${SCRIPT_DIR}/chat_client.sh -r groups/${group_name} -u Bob" Enter

    tmux new-window -t "${session_name}" -n "Charlie"
    tmux send-keys -t "${session_name}:Charlie" "${SCRIPT_DIR}/chat_client.sh -r groups/${group_name} -u Charlie" Enter

    echo -e "${C_GREEN}tmuxセッション '${session_name}' を作成しました${C_RESET}"
    echo ""

    # セッションにアタッチ
    tmux attach -t "${session_name}"
}

# グループ管理インタラクティブ
group_management_menu() {
    while true; do
        show_group_menu
        read -r choice

        case "$choice" in
            1)
                clear
                "${SCRIPT_DIR}/group_manager.sh" -u "${current_user}" list
                echo ""
                echo -n "情報を表示するグループ名: "
                read -r group_name
                if [[ -n "$group_name" ]]; then
                    "${SCRIPT_DIR}/group_manager.sh" -u "${current_user}" info "$group_name"
                fi
                echo ""
                echo "Enterキーで続行..."
                read -r
                ;;
            2)
                clear
                echo -e "${C_CYAN}メンバーを招待${C_RESET}"
                echo ""
                "${SCRIPT_DIR}/group_manager.sh" -u "${current_user}" my
                echo -n "グループ名: "
                read -r group_name
                echo -n "招待するユーザー名: "
                read -r invite_user
                if [[ -n "$group_name" ]] && [[ -n "$invite_user" ]]; then
                    "${SCRIPT_DIR}/group_manager.sh" -u "${current_user}" invite "$group_name" "$invite_user"
                fi
                echo ""
                echo "Enterキーで続行..."
                read -r
                ;;
            3)
                clear
                echo -e "${C_CYAN}メンバーを追放${C_RESET}"
                echo ""
                echo -n "グループ名: "
                read -r group_name
                if [[ -n "$group_name" ]]; then
                    "${SCRIPT_DIR}/group_manager.sh" -u "${current_user}" info "$group_name"
                    echo -n "追放するユーザー名: "
                    read -r kick_user
                    if [[ -n "$kick_user" ]]; then
                        "${SCRIPT_DIR}/group_manager.sh" -u "${current_user}" kick "$group_name" "$kick_user"
                    fi
                fi
                echo ""
                echo "Enterキーで続行..."
                read -r
                ;;
            4)
                clear
                echo -e "${C_CYAN}管理者に昇格${C_RESET}"
                echo ""
                echo -n "グループ名: "
                read -r group_name
                echo -n "昇格するユーザー名: "
                read -r admin_user
                if [[ -n "$group_name" ]] && [[ -n "$admin_user" ]]; then
                    "${SCRIPT_DIR}/group_manager.sh" -u "${current_user}" admin "$group_name" "$admin_user"
                fi
                echo ""
                echo "Enterキーで続行..."
                read -r
                ;;
            5)
                clear
                echo -e "${C_CYAN}パスワード設定${C_RESET}"
                echo ""
                echo -n "グループ名: "
                read -r group_name
                echo -n "パスワード（空欄で解除）: "
                read -rs password
                echo ""
                if [[ -n "$group_name" ]]; then
                    "${SCRIPT_DIR}/group_manager.sh" -u "${current_user}" password "$group_name" "$password"
                fi
                echo ""
                echo "Enterキーで続行..."
                read -r
                ;;
            6)
                clear
                echo -e "${C_CYAN}公開/非公開の切り替え${C_RESET}"
                echo ""
                echo -n "グループ名: "
                read -r group_name
                echo "1) 公開にする"
                echo "2) 非公開にする（招待制）"
                echo -n "選択: "
                read -r pub_choice
                if [[ -n "$group_name" ]]; then
                    if [[ "$pub_choice" == "1" ]]; then
                        "${SCRIPT_DIR}/group_manager.sh" -u "${current_user}" public "$group_name"
                    elif [[ "$pub_choice" == "2" ]]; then
                        "${SCRIPT_DIR}/group_manager.sh" -u "${current_user}" private "$group_name"
                    fi
                fi
                echo ""
                echo "Enterキーで続行..."
                read -r
                ;;
            7)
                clear
                echo -e "${C_RED}グループを削除${C_RESET}"
                echo ""
                "${SCRIPT_DIR}/group_manager.sh" -u "${current_user}" my
                echo ""
                echo -n "削除するグループ名: "
                read -r group_name
                if [[ -n "$group_name" ]]; then
                    "${SCRIPT_DIR}/group_manager.sh" -u "${current_user}" delete "$group_name"
                fi
                echo ""
                echo "Enterキーで続行..."
                read -r
                ;;
            b|B)
                return
                ;;
            *)
                echo ""
                echo -e "${C_RED}無効な選択です${C_RESET}"
                sleep 1
                ;;
        esac
    done
}

# インタラクティブメニュー
interactive_menu() {
    # ユーザー名を確認
    echo -e "${C_CYAN}ユーザー名を入力してください [${current_user}]:${C_RESET} "
    read -r input_user
    if [[ -n "$input_user" ]]; then
        current_user="$input_user"
    fi

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
                "${SCRIPT_DIR}/chat_server.sh" list
                echo ""
                echo -n "参加するルーム名 [general]: "
                read -r room_name
                room_name="${room_name:-general}"
                "${SCRIPT_DIR}/chat_client.sh" -r "${room_name}" -u "${current_user}"
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
                echo -e "${C_MAGENTA}グループを作成${C_RESET}"
                echo ""
                echo -n "グループ名: "
                read -r group_name
                echo -n "説明（省略可）: "
                read -r group_desc
                if [[ -n "$group_name" ]]; then
                    "${SCRIPT_DIR}/group_manager.sh" -u "${current_user}" create "$group_name" "$group_desc"
                fi
                echo ""
                echo "Enterキーで続行..."
                read -r
                ;;
            5)
                clear
                echo -e "${C_MAGENTA}グループに参加${C_RESET}"
                echo ""
                "${SCRIPT_DIR}/group_manager.sh" -u "${current_user}" list
                echo ""
                echo -n "参加するグループ名: "
                read -r group_name
                if [[ -n "$group_name" ]]; then
                    group_quick_start "$group_name"
                fi
                ;;
            6)
                clear
                "${SCRIPT_DIR}/group_manager.sh" -u "${current_user}" list
                echo ""
                echo -e "${C_DIM}参加中のグループ:${C_RESET}"
                "${SCRIPT_DIR}/group_manager.sh" -u "${current_user}" my
                echo ""
                echo "Enterキーで続行..."
                read -r
                ;;
            7)
                group_management_menu
                ;;
            8)
                clear
                echo "1) 通常チャットデモ"
                echo "2) グループチャットデモ"
                echo -n "選択: "
                read -r demo_choice
                if [[ "$demo_choice" == "1" ]]; then
                    demo_mode
                elif [[ "$demo_choice" == "2" ]]; then
                    group_demo_mode
                fi
                ;;
            9)
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
        group)
            "${SCRIPT_DIR}/group_manager.sh" -u "${current_user}" "$@"
            ;;
        groups)
            "${SCRIPT_DIR}/group_manager.sh" -u "${current_user}" list
            ;;
        join)
            group_quick_start "$@"
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
