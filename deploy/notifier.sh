#!/bin/bash
set -euo pipefail

#
# デプロイ通知ツール
# バージョン: 1.0
#
# デプロイ完了・失敗をSlack/メールで通知するツール
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare notify_type="slack"
declare status="success"
declare env_name="${DEPLOY_ENV:-production}"
declare app_name="${APP_NAME:-}"
declare version_tag="${VERSION_TAG:-}"
declare message=""
declare webhook_url="${SLACK_WEBHOOK_URL:-}"
declare email_to="${NOTIFY_EMAIL:-}"
declare dry_run=false

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション]

デプロイ通知送信ツール

オプション:
  -h, --help            このヘルプを表示
  -v, --version         バージョン情報を表示
  -t, --type TYPE       通知タイプ (slack|email|both) [デフォルト: slack]
  -s, --status STATUS   デプロイ状態 (success|failure|started) [デフォルト: success]
  -e, --env ENV         環境名 [デフォルト: production]
  -a, --app APP         アプリケーション名
  -V, --ver TAG         バージョンタグ
  -m, --message MSG     追加メッセージ
  -w, --webhook URL     Slack Webhook URL (または SLACK_WEBHOOK_URL 環境変数)
  --email TO            通知先メールアドレス (または NOTIFY_EMAIL 環境変数)
  --dry-run             実際には送信せず内容を表示

例:
  $PROG_NAME -s success -e production -a myapp -V v1.2.3
  $PROG_NAME -s failure -m "DBマイグレーション失敗"
  SLACK_WEBHOOK_URL=https://hooks.slack.com/... $PROG_NAME -s started

EOF
}

get_emoji() {
    case "$status" in
        success) echo "✅" ;;
        failure) echo "❌" ;;
        started) echo "🚀" ;;
        *)       echo "ℹ️" ;;
    esac
}

get_status_jp() {
    case "$status" in
        success) echo "完了" ;;
        failure) echo "失敗" ;;
        started) echo "開始" ;;
        *)       echo "$status" ;;
    esac
}

build_slack_payload() {
    local emoji
    emoji=$(get_emoji)
    local status_jp
    status_jp=$(get_status_jp)
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local hostname
    hostname=$(hostname)

    local title="${emoji} デプロイ${status_jp}"
    local color
    case "$status" in
        success) color="#36a64f" ;;
        failure) color="#ff0000" ;;
        started) color="#439fe0" ;;
        *)       color="#cccccc" ;;
    esac

    local fields="[
        {\"title\": \"環境\", \"value\": \"${env_name}\", \"short\": true}"

    [[ -n "$app_name"    ]] && fields+=",{\"title\": \"アプリ\", \"value\": \"${app_name}\", \"short\": true}"
    [[ -n "$version_tag" ]] && fields+=",{\"title\": \"バージョン\", \"value\": \"${version_tag}\", \"short\": true}"
    fields+=",{\"title\": \"サーバー\", \"value\": \"${hostname}\", \"short\": true}"
    fields+=",{\"title\": \"時刻\", \"value\": \"${timestamp}\", \"short\": true}"
    [[ -n "$message" ]] && fields+=",{\"title\": \"メモ\", \"value\": \"${message}\", \"short\": false}"
    fields+="]"

    cat <<JSON
{
    "attachments": [{
        "title": "${title}",
        "color": "${color}",
        "fields": ${fields},
        "footer": "$PROG_NAME v$VERSION"
    }]
}
JSON
}

send_slack() {
    if [[ -z "$webhook_url" ]]; then
        log_warning "Slack Webhook URL が設定されていません (SLACK_WEBHOOK_URL または --webhook)"
        return 1
    fi

    local payload
    payload=$(build_slack_payload)

    if [[ "$dry_run" == true ]]; then
        log_info "[DRY-RUN] Slack通知:"
        echo "$payload" | jq . 2>/dev/null || echo "$payload"
        return
    fi

    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$webhook_url")

    if [[ "$http_code" == "200" ]]; then
        log_success "Slack通知送信完了"
    else
        log_error "Slack通知送信失敗 (HTTP $http_code)"
        return 1
    fi
}

send_email() {
    if [[ -z "$email_to" ]]; then
        log_warning "通知先メールアドレスが設定されていません"
        return 1
    fi

    if ! command -v mail &>/dev/null && ! command -v sendmail &>/dev/null; then
        log_warning "mail/sendmail コマンドが必要です"
        return 1
    fi

    local emoji
    emoji=$(get_emoji)
    local status_jp
    status_jp=$(get_status_jp)
    local subject="${emoji} [デプロイ${status_jp}] ${app_name:-アプリ} @ ${env_name}"

    local body
    body=$(cat <<BODY
デプロイ通知

状態:       ${status_jp}
環境:       ${env_name}
アプリ:     ${app_name:-N/A}
バージョン: ${version_tag:-N/A}
サーバー:   $(hostname)
時刻:       $(date '+%Y-%m-%d %H:%M:%S')
BODY
)
    [[ -n "$message" ]] && body+=$'\nメモ:       '"$message"

    if [[ "$dry_run" == true ]]; then
        log_info "[DRY-RUN] メール通知:"
        echo "To: $email_to"
        echo "Subject: $subject"
        echo "---"
        echo "$body"
        return
    fi

    echo "$body" | mail -s "$subject" "$email_to"
    log_success "メール通知送信完了: $email_to"
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -t|--type)
                [[ $# -lt 2 ]] && error_exit "--type には値が必要です"
                notify_type="$2"; shift 2 ;;
            -s|--status)
                [[ $# -lt 2 ]] && error_exit "--status には値が必要です"
                status="$2"; shift 2 ;;
            -e|--env)
                [[ $# -lt 2 ]] && error_exit "--env には値が必要です"
                env_name="$2"; shift 2 ;;
            -a|--app)
                [[ $# -lt 2 ]] && error_exit "--app には値が必要です"
                app_name="$2"; shift 2 ;;
            -V|--ver)
                [[ $# -lt 2 ]] && error_exit "--ver には値が必要です"
                version_tag="$2"; shift 2 ;;
            -m|--message)
                [[ $# -lt 2 ]] && error_exit "--message には値が必要です"
                message="$2"; shift 2 ;;
            -w|--webhook)
                [[ $# -lt 2 ]] && error_exit "--webhook には値が必要です"
                webhook_url="$2"; shift 2 ;;
            --email)
                [[ $# -lt 2 ]] && error_exit "--email には値が必要です"
                email_to="$2"; shift 2 ;;
            --dry-run) dry_run=true; shift ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  error_exit "不明な引数: $1" ;;
        esac
    done
}

main() {
    parse_arguments "$@"

    case "$notify_type" in
        slack)
            send_slack ;;
        email)
            send_email ;;
        both)
            send_slack || true
            send_email || true ;;
        *)
            error_exit "不明な通知タイプ: $notify_type (slack|email|both)" ;;
    esac
}

main "$@"
