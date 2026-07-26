#!/bin/bash
set -euo pipefail

#
# ファイアウォール管理ツール
# バージョン: 1.0
#
# iptables/ufw のルール管理・確認を行うツール
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"
readonly RULES_BACKUP_DIR="${HOME}/.firewall_backups"

declare mode="status"
declare backend="auto"
declare -i port_num=0
declare proto="tcp"
declare source_ip=""
declare dest_ip=""
declare action_type="ACCEPT"
declare chain="INPUT"
declare comment=""
declare dry_run=false

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション] コマンド

ファイアウォール管理ツール (iptables/ufw)

コマンド:
  status            現在のルール一覧表示
  allow PORT        ポートを許可
  deny PORT         ポートを拒否
  delete RULE       ルールを削除 (番号指定)
  backup            ルールをバックアップ
  restore FILE      バックアップから復元
  reset             全ルールをリセット (要注意)
  check IP          IPアドレスへのアクセス確認

オプション:
  -h, --help              このヘルプを表示
  -v, --version           バージョン情報を表示
  -b, --backend BACKEND   バックエンド (iptables|ufw|auto) [デフォルト: auto]
  -p, --proto PROTO       プロトコル (tcp|udp|both) [デフォルト: tcp]
  -s, --source IP         送信元IPアドレス/CIDR
  -d, --dest IP           宛先IPアドレス/CIDR
  -c, --comment TEXT      ルールのコメント
  --dry-run               実際の変更を行わずシミュレート

例:
  $PROG_NAME status
  $PROG_NAME allow 80
  $PROG_NAME allow 443 -p tcp -s 192.168.1.0/24
  $PROG_NAME deny 23
  $PROG_NAME allow 8080-8090
  $PROG_NAME backup
  $PROG_NAME check 8.8.8.8

EOF
}

detect_backend() {
    if [[ "$backend" != "auto" ]]; then
        echo "$backend"
        return
    fi

    if command -v ufw &>/dev/null && ufw status 2>/dev/null | grep -q "Status:"; then
        echo "ufw"
    elif command -v iptables &>/dev/null; then
        echo "iptables"
    else
        error_exit "iptables も ufw も見つかりません"
    fi
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_warning "このコマンドはroot権限が必要です。sudoで実行してください"
    fi
}

do_status() {
    local be
    be=$(detect_backend)
    log_info "ファイアウォール状態 (バックエンド: $be)"
    echo ""

    case "$be" in
        ufw)
            if ufw status numbered 2>/dev/null | head -50 | while IFS= read -r line; do
                if echo "$line" | grep -qE "ALLOW|DENY|REJECT"; then
                    if echo "$line" | grep -qE "ALLOW"; then
                        printf "${C_GREEN}%s${C_RESET}\n" "$line"
                    else
                        printf "${C_RED}%s${C_RESET}\n" "$line"
                    fi
                else
                    echo "$line"
                fi
            done; then
                :
            fi
            ;;
        iptables)
            printf "  ${C_BOLD}=== INPUT チェーン ===${C_RESET}\n"
            iptables -L INPUT -n --line-numbers -v 2>/dev/null | \
            while IFS= read -r line; do
                if echo "$line" | grep -qE "^[0-9]"; then
                    if echo "$line" | grep -qi "ACCEPT"; then
                        printf "  ${C_GREEN}%s${C_RESET}\n" "$line"
                    elif echo "$line" | grep -qi "DROP\|REJECT"; then
                        printf "  ${C_RED}%s${C_RESET}\n" "$line"
                    else
                        printf "  %s\n" "$line"
                    fi
                else
                    printf "  ${C_BOLD}%s${C_RESET}\n" "$line"
                fi
            done

            echo ""
            printf "  ${C_BOLD}=== OUTPUT チェーン ===${C_RESET}\n"
            iptables -L OUTPUT -n --line-numbers 2>/dev/null | head -20 | sed 's/^/  /'
            ;;
    esac
    echo ""
}

do_allow() {
    local port="$1"
    check_root
    local be
    be=$(detect_backend)

    log_info "許可ルール追加: ポート $port/$proto"
    [[ -n "$source_ip" ]] && log_info "送信元: $source_ip"

    if $dry_run; then
        log_info "[DRY RUN] 実際の変更はスキップします"
        return 0
    fi

    case "$be" in
        ufw)
            local ufw_proto=""
            case "$proto" in
                tcp|udp) ufw_proto="/$proto" ;;
                both) ufw_proto="" ;;
            esac

            if [[ -n "$source_ip" ]]; then
                ufw allow from "$source_ip" to any port "$port" proto "$proto" 2>/dev/null
            else
                ufw allow "${port}${ufw_proto}" 2>/dev/null
            fi
            ;;
        iptables)
            local -a ipt_opts=(-A INPUT -j ACCEPT)

            if [[ -n "$source_ip" ]]; then
                ipt_opts+=(-s "$source_ip")
            fi

            if [[ "$proto" == "both" ]]; then
                iptables -A INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null
                iptables -A INPUT -p udp --dport "$port" -j ACCEPT 2>/dev/null
            else
                iptables -A INPUT -p "$proto" --dport "$port" "${ipt_opts[@]}" 2>/dev/null
            fi

            [[ -n "$comment" ]] && iptables -A INPUT -p "$proto" --dport "$port" \
                -m comment --comment "$comment" -j ACCEPT 2>/dev/null || true
            ;;
    esac

    log_success "ルールを追加しました: ポート $port/$proto ALLOW"
}

do_deny() {
    local port="$1"
    check_root
    local be
    be=$(detect_backend)

    log_info "拒否ルール追加: ポート $port/$proto"

    if $dry_run; then
        log_info "[DRY RUN] 実際の変更はスキップします"
        return 0
    fi

    case "$be" in
        ufw)
            if [[ -n "$source_ip" ]]; then
                ufw deny from "$source_ip" to any port "$port" 2>/dev/null
            else
                ufw deny "$port/$proto" 2>/dev/null
            fi
            ;;
        iptables)
            if [[ "$proto" == "both" ]]; then
                iptables -A INPUT -p tcp --dport "$port" -j DROP 2>/dev/null
                iptables -A INPUT -p udp --dport "$port" -j DROP 2>/dev/null
            else
                iptables -A INPUT -p "$proto" --dport "$port" -j DROP 2>/dev/null
            fi
            ;;
    esac

    log_success "ルールを追加しました: ポート $port/$proto DENY"
}

do_backup() {
    mkdir -p "$RULES_BACKUP_DIR"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local be
    be=$(detect_backend)

    local backup_file="${RULES_BACKUP_DIR}/firewall_${timestamp}_${be}.bak"

    case "$be" in
        ufw)
            ufw status verbose 2>/dev/null > "$backup_file"
            ;;
        iptables)
            iptables-save 2>/dev/null > "$backup_file"
            ;;
    esac

    log_success "バックアップ完了: $backup_file"
}

do_check() {
    local ip="$1"
    log_info "アクセス確認: $ip"
    echo ""

    local be
    be=$(detect_backend)

    case "$be" in
        ufw)
            ufw status 2>/dev/null | grep -E "ALLOW|DENY" | while IFS= read -r line; do
                echo "  $line"
            done
            ;;
        iptables)
            log_info "iptables の $ip からのルール:"
            iptables -L INPUT -n 2>/dev/null | grep -E "$ip|0\.0\.0\.0|ACCEPT|DROP" | \
                head -20 | sed 's/^/  /' || echo "  一致するルールなし"
            ;;
    esac

    echo ""
    log_info "ルーティング確認:"
    ip route get "$ip" 2>/dev/null | sed 's/^/  /' || true
    echo ""
}

do_reset() {
    check_root
    log_warning "全ファイアウォールルールをリセットします"
    confirm "本当にリセットしますか？ (SSH接続が切断される可能性があります)" "n" || {
        log_info "キャンセル"
        return 0
    }

    if $dry_run; then
        log_info "[DRY RUN] リセットをスキップします"
        return 0
    fi

    local be
    be=$(detect_backend)
    case "$be" in
        ufw)
            ufw reset 2>/dev/null
            ;;
        iptables)
            iptables -F
            iptables -X
            iptables -P INPUT ACCEPT
            iptables -P OUTPUT ACCEPT
            iptables -P FORWARD ACCEPT
            ;;
    esac

    log_success "ファイアウォールルールをリセットしました"
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -b|--backend) [[ $# -lt 2 ]] && error_exit "-b には値が必要です"; backend="$2"; shift 2 ;;
            -p|--proto)   [[ $# -lt 2 ]] && error_exit "-p には値が必要です"; proto="$2"; shift 2 ;;
            -s|--source)  [[ $# -lt 2 ]] && error_exit "-s には値が必要です"; source_ip="$2"; shift 2 ;;
            -d|--dest)    [[ $# -lt 2 ]] && error_exit "-d には値が必要です"; dest_ip="$2"; shift 2 ;;
            -c|--comment) [[ $# -lt 2 ]] && error_exit "-c には値が必要です"; comment="$2"; shift 2 ;;
            --dry-run)    dry_run=true; shift ;;
            status|backup|reset) mode="$1"; shift ;;
            allow)
                mode="allow"
                [[ $# -ge 2 && ! "$2" =~ ^- ]] && { port_num="$2"; shift; }
                shift
                ;;
            deny)
                mode="deny"
                [[ $# -ge 2 && ! "$2" =~ ^- ]] && { port_num="$2"; shift; }
                shift
                ;;
            check)
                mode="check"
                [[ $# -ge 2 && ! "$2" =~ ^- ]] && { source_ip="$2"; shift; }
                shift
                ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  shift ;;
        esac
    done
}

main() {
    parse_arguments "$@"

    case "$mode" in
        status) do_status ;;
        allow)  [[ -z "$port_num" || "$port_num" == "0" ]] && error_exit "ポート番号を指定してください"; do_allow "$port_num" ;;
        deny)   [[ -z "$port_num" || "$port_num" == "0" ]] && error_exit "ポート番号を指定してください"; do_deny "$port_num" ;;
        backup) do_backup ;;
        reset)  do_reset ;;
        check)  [[ -z "$source_ip" ]] && error_exit "IPアドレスを指定してください"; do_check "$source_ip" ;;
        *)      error_exit "不明なコマンド: $mode" ;;
    esac
}

main "$@"
