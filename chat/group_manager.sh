#!/bin/bash
set -euo pipefail

#
# シェルスクリプトチャット - グループマネージャー
# 作成日: 2024
# バージョン: 1.0
#
# グループチャットの作成・管理を行います
#

# ===== 設定（定数） =====
readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"
readonly DEFAULT_CHAT_DIR="/tmp/shell_chat"

# 色定義
readonly C_RESET='\033[0m'
readonly C_BOLD='\033[1m'
readonly C_RED='\033[1;31m'
readonly C_GREEN='\033[1;32m'
readonly C_YELLOW='\033[1;33m'
readonly C_BLUE='\033[1;34m'
readonly C_CYAN='\033[1;36m'
readonly C_DIM='\033[2m'

# ===== グローバル変数 =====
declare chat_dir="${DEFAULT_CHAT_DIR}"
declare current_user="${USER:-anonymous}"

# ===== ヘルパー関数 =====

show_usage() {
    cat <<EOF
${C_CYAN}シェルスクリプトチャット - グループマネージャー${C_RESET}

使用方法: $PROG_NAME [オプション] <コマンド> [引数...]

${C_YELLOW}コマンド:${C_RESET}
  create <グループ名> [説明]     新しいグループを作成
  delete <グループ名>            グループを削除（管理者のみ）
  list                           全グループ一覧を表示
  my                             自分が参加しているグループ一覧
  info <グループ名>              グループ情報を表示
  join <グループ名>              グループに参加
  leave <グループ名>             グループから退出
  invite <グループ名> <ユーザー> ユーザーを招待（管理者のみ）
  kick <グループ名> <ユーザー>   ユーザーを追放（管理者のみ）
  admin <グループ名> <ユーザー>  ユーザーを管理者に昇格
  password <グループ名> [pass]   パスワードを設定/解除
  public <グループ名>            グループを公開に設定
  private <グループ名>           グループを非公開に設定

${C_YELLOW}オプション:${C_RESET}
  -h, --help              このヘルプを表示
  -v, --version           バージョン情報を表示
  -u, --user <name>       操作ユーザー名
  -d, --dir <dir>         チャットデータディレクトリ

${C_YELLOW}例:${C_RESET}
  $PROG_NAME create "開発チーム" "開発メンバー用のチャット"
  $PROG_NAME join "開発チーム"
  $PROG_NAME invite "開発チーム" Alice
  $PROG_NAME password "開発チーム" secret123
  $PROG_NAME list
EOF
}

log_info() {
    echo -e "${C_CYAN}[INFO]${C_RESET} $1"
}

log_success() {
    echo -e "${C_GREEN}[SUCCESS]${C_RESET} $1"
}

log_warning() {
    echo -e "${C_YELLOW}[WARNING]${C_RESET} $1"
}

log_error() {
    echo -e "${C_RED}[ERROR]${C_RESET} $1" >&2
}

error_exit() {
    log_error "$1"
    exit 1
}

# グループディレクトリのパスを取得
get_group_path() {
    local group_name="$1"
    echo "${chat_dir}/groups/${group_name}"
}

# グループが存在するか確認
group_exists() {
    local group_name="$1"
    local group_path
    group_path=$(get_group_path "$group_name")
    [[ -d "$group_path" ]]
}

# ユーザーがグループのメンバーか確認
is_member() {
    local group_name="$1"
    local user="$2"
    local group_path
    group_path=$(get_group_path "$group_name")

    if [[ -f "${group_path}/members.list" ]]; then
        grep -q "^${user}:" "${group_path}/members.list" 2>/dev/null
    else
        return 1
    fi
}

# ユーザーがグループの管理者か確認
is_admin() {
    local group_name="$1"
    local user="$2"
    local group_path
    group_path=$(get_group_path "$group_name")

    if [[ -f "${group_path}/members.list" ]]; then
        grep -q "^${user}:admin" "${group_path}/members.list" 2>/dev/null
    else
        return 1
    fi
}

# グループが公開か確認
is_public() {
    local group_name="$1"
    local group_path
    group_path=$(get_group_path "$group_name")

    if [[ -f "${group_path}/settings.conf" ]]; then
        grep -q "^public=true" "${group_path}/settings.conf" 2>/dev/null
    else
        return 0  # デフォルトは公開
    fi
}

# パスワードが設定されているか確認
has_password() {
    local group_name="$1"
    local group_path
    group_path=$(get_group_path "$group_name")

    [[ -f "${group_path}/.password" ]] && [[ -s "${group_path}/.password" ]]
}

# パスワードを検証
verify_password() {
    local group_name="$1"
    local password="$2"
    local group_path
    group_path=$(get_group_path "$group_name")

    if [[ -f "${group_path}/.password" ]]; then
        local stored_hash
        stored_hash=$(cat "${group_path}/.password")
        local input_hash
        input_hash=$(echo -n "$password" | sha256sum | cut -d' ' -f1)
        [[ "$stored_hash" == "$input_hash" ]]
    else
        return 0
    fi
}

# システムメッセージを送信
send_system_message() {
    local group_name="$1"
    local message="$2"
    local group_path
    group_path=$(get_group_path "$group_name")
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    if [[ -d "$group_path" ]]; then
        {
            flock -x 200
            echo "[${timestamp}] [SYSTEM] ${message}" >> "${group_path}/messages.log"
        } 200>"${group_path}/.lock"
    fi
}

# ===== グループ管理コマンド =====

# グループを作成
cmd_create() {
    local group_name="$1"
    local description="${2:-}"

    if [[ -z "$group_name" ]]; then
        error_exit "グループ名を指定してください"
    fi

    if group_exists "$group_name"; then
        error_exit "グループ '${group_name}' は既に存在します"
    fi

    local group_path
    group_path=$(get_group_path "$group_name")

    # グループディレクトリを作成
    mkdir -p "$group_path"

    # グループ情報ファイル
    cat > "${group_path}/info.conf" <<EOF
name=${group_name}
description=${description}
created_by=${current_user}
created_at=$(date '+%Y-%m-%d %H:%M:%S')
EOF

    # 設定ファイル
    cat > "${group_path}/settings.conf" <<EOF
public=true
invite_only=false
EOF

    # メンバーリスト（作成者を管理者として追加）
    echo "${current_user}:admin:$(date '+%Y-%m-%d %H:%M:%S')" > "${group_path}/members.list"

    # 招待リスト
    touch "${group_path}/invites.list"

    # メッセージログ
    touch "${group_path}/messages.log"

    # ロックファイル
    touch "${group_path}/.lock"

    send_system_message "$group_name" "グループ '${group_name}' が作成されました（作成者: ${current_user}）"

    echo ""
    echo -e "${C_GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
    echo -e "${C_GREEN}  グループを作成しました${C_RESET}"
    echo -e "${C_GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
    echo ""
    echo "  グループ名: ${group_name}"
    [[ -n "$description" ]] && echo "  説明: ${description}"
    echo "  管理者: ${current_user}"
    echo ""
    echo "  チャットに参加するには:"
    echo "    ./chat_client.sh -r groups/${group_name} -u ${current_user}"
    echo ""
}

# グループを削除
cmd_delete() {
    local group_name="$1"

    if [[ -z "$group_name" ]]; then
        error_exit "グループ名を指定してください"
    fi

    if ! group_exists "$group_name"; then
        error_exit "グループ '${group_name}' は存在しません"
    fi

    if ! is_admin "$group_name" "$current_user"; then
        error_exit "グループを削除する権限がありません（管理者のみ）"
    fi

    local group_path
    group_path=$(get_group_path "$group_name")

    echo -n "グループ '${group_name}' を削除しますか？ [y/N]: "
    read -r confirm

    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        rm -rf "$group_path"
        log_success "グループ '${group_name}' を削除しました"
    else
        log_info "キャンセルしました"
    fi
}

# グループ一覧を表示
cmd_list() {
    local groups_dir="${chat_dir}/groups"

    echo ""
    echo -e "${C_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
    echo -e "${C_CYAN}  グループ一覧${C_RESET}"
    echo -e "${C_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
    echo ""

    if [[ ! -d "$groups_dir" ]]; then
        echo "  グループはありません"
        echo ""
        return 0
    fi

    local found=false
    for group_path in "${groups_dir}"/*/; do
        if [[ -d "$group_path" ]]; then
            found=true
            local group_name
            group_name=$(basename "$group_path")

            local description=""
            local member_count=0
            local is_pub="公開"
            local has_pass=""

            if [[ -f "${group_path}/info.conf" ]]; then
                description=$(grep "^description=" "${group_path}/info.conf" 2>/dev/null | cut -d= -f2-)
            fi

            if [[ -f "${group_path}/members.list" ]]; then
                member_count=$(wc -l < "${group_path}/members.list")
            fi

            if ! is_public "$group_name"; then
                is_pub="非公開"
            fi

            if has_password "$group_name"; then
                has_pass=" 🔒"
            fi

            # 自分がメンバーかどうか
            local member_mark=""
            if is_member "$group_name" "$current_user"; then
                if is_admin "$group_name" "$current_user"; then
                    member_mark=" ${C_YELLOW}★管理者${C_RESET}"
                else
                    member_mark=" ${C_GREEN}✓参加中${C_RESET}"
                fi
            fi

            echo -e "  ${C_BOLD}${group_name}${C_RESET}${has_pass}${member_mark}"
            [[ -n "$description" ]] && echo -e "    ${C_DIM}${description}${C_RESET}"
            echo -e "    ${C_DIM}メンバー: ${member_count}人 | ${is_pub}${C_RESET}"
            echo ""
        fi
    done

    if [[ "$found" == "false" ]]; then
        echo "  グループはありません"
        echo ""
    fi
}

# 自分が参加しているグループ一覧
cmd_my() {
    local groups_dir="${chat_dir}/groups"

    echo ""
    echo -e "${C_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
    echo -e "${C_CYAN}  参加中のグループ（${current_user}）${C_RESET}"
    echo -e "${C_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
    echo ""

    if [[ ! -d "$groups_dir" ]]; then
        echo "  参加しているグループはありません"
        echo ""
        return 0
    fi

    local found=false
    for group_path in "${groups_dir}"/*/; do
        if [[ -d "$group_path" ]]; then
            local group_name
            group_name=$(basename "$group_path")

            if is_member "$group_name" "$current_user"; then
                found=true

                local role="メンバー"
                if is_admin "$group_name" "$current_user"; then
                    role="${C_YELLOW}管理者${C_RESET}"
                fi

                local unread=""
                # 未読メッセージ数（簡易実装）

                echo -e "  ${C_GREEN}●${C_RESET} ${C_BOLD}${group_name}${C_RESET} (${role})"
            fi
        fi
    done

    if [[ "$found" == "false" ]]; then
        echo "  参加しているグループはありません"
    fi
    echo ""
}

# グループ情報を表示
cmd_info() {
    local group_name="$1"

    if [[ -z "$group_name" ]]; then
        error_exit "グループ名を指定してください"
    fi

    if ! group_exists "$group_name"; then
        error_exit "グループ '${group_name}' は存在しません"
    fi

    local group_path
    group_path=$(get_group_path "$group_name")

    echo ""
    echo -e "${C_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
    echo -e "${C_CYAN}  グループ情報: ${group_name}${C_RESET}"
    echo -e "${C_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
    echo ""

    # 基本情報
    if [[ -f "${group_path}/info.conf" ]]; then
        local description created_by created_at
        description=$(grep "^description=" "${group_path}/info.conf" 2>/dev/null | cut -d= -f2-)
        created_by=$(grep "^created_by=" "${group_path}/info.conf" 2>/dev/null | cut -d= -f2-)
        created_at=$(grep "^created_at=" "${group_path}/info.conf" 2>/dev/null | cut -d= -f2-)

        [[ -n "$description" ]] && echo "  説明: ${description}"
        echo "  作成者: ${created_by}"
        echo "  作成日: ${created_at}"
    fi

    # 設定
    local is_pub="公開"
    if ! is_public "$group_name"; then
        is_pub="非公開"
    fi
    echo "  公開設定: ${is_pub}"

    if has_password "$group_name"; then
        echo "  パスワード: 設定済み 🔒"
    fi

    echo ""

    # メンバー一覧
    echo -e "  ${C_BOLD}メンバー一覧:${C_RESET}"
    if [[ -f "${group_path}/members.list" ]]; then
        while IFS=: read -r user role joined_at; do
            local role_display=""
            if [[ "$role" == "admin" ]]; then
                role_display=" ${C_YELLOW}(管理者)${C_RESET}"
            fi
            echo -e "    - ${user}${role_display}"
        done < "${group_path}/members.list"
    fi

    echo ""

    # 招待リスト
    if [[ -f "${group_path}/invites.list" ]] && [[ -s "${group_path}/invites.list" ]]; then
        echo -e "  ${C_BOLD}招待中:${C_RESET}"
        while IFS=: read -r user invited_by invited_at; do
            echo "    - ${user} (招待者: ${invited_by})"
        done < "${group_path}/invites.list"
        echo ""
    fi
}

# グループに参加
cmd_join() {
    local group_name="$1"

    if [[ -z "$group_name" ]]; then
        error_exit "グループ名を指定してください"
    fi

    if ! group_exists "$group_name"; then
        error_exit "グループ '${group_name}' は存在しません"
    fi

    if is_member "$group_name" "$current_user"; then
        log_info "既にグループ '${group_name}' のメンバーです"
        return 0
    fi

    local group_path
    group_path=$(get_group_path "$group_name")

    # 非公開グループの場合、招待されているか確認
    if ! is_public "$group_name"; then
        if ! grep -q "^${current_user}:" "${group_path}/invites.list" 2>/dev/null; then
            error_exit "このグループは非公開です。招待が必要です。"
        fi
    fi

    # パスワードが設定されている場合
    if has_password "$group_name"; then
        echo -n "パスワードを入力してください: "
        read -rs password
        echo ""

        if ! verify_password "$group_name" "$password"; then
            error_exit "パスワードが正しくありません"
        fi
    fi

    # メンバーリストに追加
    {
        flock -x 200
        echo "${current_user}:member:$(date '+%Y-%m-%d %H:%M:%S')" >> "${group_path}/members.list"
        # 招待リストから削除
        grep -v "^${current_user}:" "${group_path}/invites.list" > "${group_path}/invites.list.tmp" 2>/dev/null || true
        mv "${group_path}/invites.list.tmp" "${group_path}/invites.list"
    } 200>"${group_path}/.lock"

    send_system_message "$group_name" "${current_user} がグループに参加しました"

    log_success "グループ '${group_name}' に参加しました"
    echo ""
    echo "チャットに参加するには:"
    echo "  ./chat_client.sh -r groups/${group_name} -u ${current_user}"
}

# グループから退出
cmd_leave() {
    local group_name="$1"

    if [[ -z "$group_name" ]]; then
        error_exit "グループ名を指定してください"
    fi

    if ! group_exists "$group_name"; then
        error_exit "グループ '${group_name}' は存在しません"
    fi

    if ! is_member "$group_name" "$current_user"; then
        error_exit "グループ '${group_name}' のメンバーではありません"
    fi

    local group_path
    group_path=$(get_group_path "$group_name")

    # メンバーリストから削除
    {
        flock -x 200
        grep -v "^${current_user}:" "${group_path}/members.list" > "${group_path}/members.list.tmp" 2>/dev/null || true
        mv "${group_path}/members.list.tmp" "${group_path}/members.list"
    } 200>"${group_path}/.lock"

    send_system_message "$group_name" "${current_user} がグループから退出しました"

    log_success "グループ '${group_name}' から退出しました"
}

# ユーザーを招待
cmd_invite() {
    local group_name="$1"
    local target_user="$2"

    if [[ -z "$group_name" ]] || [[ -z "$target_user" ]]; then
        error_exit "グループ名とユーザー名を指定してください"
    fi

    if ! group_exists "$group_name"; then
        error_exit "グループ '${group_name}' は存在しません"
    fi

    if ! is_admin "$group_name" "$current_user"; then
        error_exit "招待する権限がありません（管理者のみ）"
    fi

    if is_member "$group_name" "$target_user"; then
        error_exit "${target_user} は既にメンバーです"
    fi

    local group_path
    group_path=$(get_group_path "$group_name")

    # 既に招待されているか確認
    if grep -q "^${target_user}:" "${group_path}/invites.list" 2>/dev/null; then
        log_warning "${target_user} は既に招待済みです"
        return 0
    fi

    # 招待リストに追加
    {
        flock -x 200
        echo "${target_user}:${current_user}:$(date '+%Y-%m-%d %H:%M:%S')" >> "${group_path}/invites.list"
    } 200>"${group_path}/.lock"

    send_system_message "$group_name" "${current_user} が ${target_user} を招待しました"

    log_success "${target_user} をグループ '${group_name}' に招待しました"
}

# ユーザーを追放
cmd_kick() {
    local group_name="$1"
    local target_user="$2"

    if [[ -z "$group_name" ]] || [[ -z "$target_user" ]]; then
        error_exit "グループ名とユーザー名を指定してください"
    fi

    if ! group_exists "$group_name"; then
        error_exit "グループ '${group_name}' は存在しません"
    fi

    if ! is_admin "$group_name" "$current_user"; then
        error_exit "追放する権限がありません（管理者のみ）"
    fi

    if ! is_member "$group_name" "$target_user"; then
        error_exit "${target_user} はメンバーではありません"
    fi

    if [[ "$target_user" == "$current_user" ]]; then
        error_exit "自分自身を追放することはできません"
    fi

    local group_path
    group_path=$(get_group_path "$group_name")

    # メンバーリストから削除
    {
        flock -x 200
        grep -v "^${target_user}:" "${group_path}/members.list" > "${group_path}/members.list.tmp" 2>/dev/null || true
        mv "${group_path}/members.list.tmp" "${group_path}/members.list"
    } 200>"${group_path}/.lock"

    send_system_message "$group_name" "${target_user} が ${current_user} によって追放されました"

    log_success "${target_user} をグループ '${group_name}' から追放しました"
}

# 管理者に昇格
cmd_admin() {
    local group_name="$1"
    local target_user="$2"

    if [[ -z "$group_name" ]] || [[ -z "$target_user" ]]; then
        error_exit "グループ名とユーザー名を指定してください"
    fi

    if ! group_exists "$group_name"; then
        error_exit "グループ '${group_name}' は存在しません"
    fi

    if ! is_admin "$group_name" "$current_user"; then
        error_exit "権限を変更する権限がありません（管理者のみ）"
    fi

    if ! is_member "$group_name" "$target_user"; then
        error_exit "${target_user} はメンバーではありません"
    fi

    if is_admin "$group_name" "$target_user"; then
        log_info "${target_user} は既に管理者です"
        return 0
    fi

    local group_path
    group_path=$(get_group_path "$group_name")

    # 権限を更新
    {
        flock -x 200
        local joined_at
        joined_at=$(grep "^${target_user}:" "${group_path}/members.list" | cut -d: -f3-)
        grep -v "^${target_user}:" "${group_path}/members.list" > "${group_path}/members.list.tmp"
        echo "${target_user}:admin:${joined_at}" >> "${group_path}/members.list.tmp"
        mv "${group_path}/members.list.tmp" "${group_path}/members.list"
    } 200>"${group_path}/.lock"

    send_system_message "$group_name" "${target_user} が管理者に昇格しました"

    log_success "${target_user} を管理者に昇格しました"
}

# パスワードを設定
cmd_password() {
    local group_name="$1"
    local password="${2:-}"

    if [[ -z "$group_name" ]]; then
        error_exit "グループ名を指定してください"
    fi

    if ! group_exists "$group_name"; then
        error_exit "グループ '${group_name}' は存在しません"
    fi

    if ! is_admin "$group_name" "$current_user"; then
        error_exit "パスワードを設定する権限がありません（管理者のみ）"
    fi

    local group_path
    group_path=$(get_group_path "$group_name")

    if [[ -z "$password" ]]; then
        # パスワードを解除
        rm -f "${group_path}/.password"
        log_success "グループ '${group_name}' のパスワードを解除しました"
    else
        # パスワードを設定（ハッシュ化）
        echo -n "$password" | sha256sum | cut -d' ' -f1 > "${group_path}/.password"
        log_success "グループ '${group_name}' にパスワードを設定しました"
    fi
}

# 公開に設定
cmd_public() {
    local group_name="$1"

    if [[ -z "$group_name" ]]; then
        error_exit "グループ名を指定してください"
    fi

    if ! group_exists "$group_name"; then
        error_exit "グループ '${group_name}' は存在しません"
    fi

    if ! is_admin "$group_name" "$current_user"; then
        error_exit "設定を変更する権限がありません（管理者のみ）"
    fi

    local group_path
    group_path=$(get_group_path "$group_name")

    # 設定を更新
    if [[ -f "${group_path}/settings.conf" ]]; then
        sed -i 's/^public=.*/public=true/' "${group_path}/settings.conf"
    else
        echo "public=true" > "${group_path}/settings.conf"
    fi

    log_success "グループ '${group_name}' を公開に設定しました"
}

# 非公開に設定
cmd_private() {
    local group_name="$1"

    if [[ -z "$group_name" ]]; then
        error_exit "グループ名を指定してください"
    fi

    if ! group_exists "$group_name"; then
        error_exit "グループ '${group_name}' は存在しません"
    fi

    if ! is_admin "$group_name" "$current_user"; then
        error_exit "設定を変更する権限がありません（管理者のみ）"
    fi

    local group_path
    group_path=$(get_group_path "$group_name")

    # 設定を更新
    if [[ -f "${group_path}/settings.conf" ]]; then
        sed -i 's/^public=.*/public=false/' "${group_path}/settings.conf"
    else
        echo "public=false" > "${group_path}/settings.conf"
    fi

    log_success "グループ '${group_name}' を非公開に設定しました（招待制）"
}

# ===== 引数解析 =====

parse_arguments() {
    local command=""
    local args=()

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
            -u|--user)
                [[ $# -lt 2 ]] && error_exit "--user には値が必要です"
                current_user="$2"
                shift 2
                ;;
            -d|--dir)
                [[ $# -lt 2 ]] && error_exit "--dir には値が必要です"
                chat_dir="$2"
                shift 2
                ;;
            create|delete|list|my|info|join|leave|invite|kick|admin|password|public|private)
                command="$1"
                shift
                # 残りの引数を収集
                while [[ $# -gt 0 ]] && [[ ! "$1" =~ ^- ]]; do
                    args+=("$1")
                    shift
                done
                ;;
            -*)
                error_exit "不明なオプション: $1"
                ;;
            *)
                error_exit "不明なコマンド: $1"
                ;;
        esac
    done

    if [[ -z "${command}" ]]; then
        show_usage
        exit 1
    fi

    # グループディレクトリを作成
    mkdir -p "${chat_dir}/groups"

    # コマンド実行
    case "${command}" in
        create)   cmd_create "${args[@]:-}" ;;
        delete)   cmd_delete "${args[0]:-}" ;;
        list)     cmd_list ;;
        my)       cmd_my ;;
        info)     cmd_info "${args[0]:-}" ;;
        join)     cmd_join "${args[0]:-}" ;;
        leave)    cmd_leave "${args[0]:-}" ;;
        invite)   cmd_invite "${args[0]:-}" "${args[1]:-}" ;;
        kick)     cmd_kick "${args[0]:-}" "${args[1]:-}" ;;
        admin)    cmd_admin "${args[0]:-}" "${args[1]:-}" ;;
        password) cmd_password "${args[0]:-}" "${args[1]:-}" ;;
        public)   cmd_public "${args[0]:-}" ;;
        private)  cmd_private "${args[0]:-}" ;;
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
