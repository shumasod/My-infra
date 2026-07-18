#!/bin/bash
set -euo pipefail

#
# Ansibleヘルパーツール
# バージョン: 1.0
#
# Ansible プレイブックの実行・確認・インベントリ管理を補助するツール
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"
readonly DEFAULT_INVENTORY="inventory.ini"
readonly DEFAULT_PLAYBOOK="site.yml"

declare action=""
declare inventory="$DEFAULT_INVENTORY"
declare playbook="$DEFAULT_PLAYBOOK"
declare -a tags=()
declare -a limit_hosts=()
declare extra_vars=""
declare dry_run=false
declare verbose=false
declare -i forks=5

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME <アクション> [オプション]

Ansibleプレイブック実行ヘルパー

アクション:
  run       プレイブックを実行
  check     ドライラン (--check モード)
  ping      インベントリ内全ホストに ping
  list      インベントリのホスト一覧
  facts     ホストのファクト情報を取得
  syntax    プレイブックの構文チェック

オプション:
  -h, --help            このヘルプを表示
  -v, --version         バージョン情報を表示
  -i, --inventory FILE  インベントリファイル [デフォルト: $DEFAULT_INVENTORY]
  -p, --playbook FILE   プレイブックファイル [デフォルト: $DEFAULT_PLAYBOOK]
  -t, --tags TAGS       実行タグ (カンマ区切り)
  -l, --limit HOSTS     対象ホスト絞り込み (カンマ区切り)
  -e, --extra-vars VARS 追加変数 (key=value形式)
  -f, --forks NUM       並列実行数 [デフォルト: 5]
  --verbose             詳細ログ出力

例:
  $PROG_NAME run
  $PROG_NAME run -t phase1,phase2 -l web01,web02
  $PROG_NAME check -l db01
  $PROG_NAME ping
  $PROG_NAME facts -l web01

EOF
}

check_ansible() {
    if ! command -v ansible-playbook &>/dev/null; then
        error_exit "ansible-playbook が見つかりません。インストールしてください"
    fi
}

build_playbook_args() {
    local -a args=()
    args+=(-i "$inventory")
    args+=(-f "$forks")

    [[ ${#tags[@]}        -gt 0 ]] && args+=(--tags "$(IFS=','; echo "${tags[*]}")")
    [[ ${#limit_hosts[@]} -gt 0 ]] && args+=(--limit "$(IFS=','; echo "${limit_hosts[*]}")")
    [[ -n "$extra_vars"         ]] && args+=(-e "$extra_vars")
    [[ "$verbose" == true       ]] && args+=(-v)

    echo "${args[@]}"
}

do_run() {
    check_ansible
    [[ ! -f "$playbook"  ]] && error_exit "プレイブックが見つかりません: $playbook"
    [[ ! -f "$inventory" ]] && error_exit "インベントリが見つかりません: $inventory"

    local args
    read -ra args <<< "$(build_playbook_args)"

    log_info "プレイブック実行: $playbook"
    [[ ${#tags[@]}        -gt 0 ]] && log_info "タグ: ${tags[*]}"
    [[ ${#limit_hosts[@]} -gt 0 ]] && log_info "対象: ${limit_hosts[*]}"
    echo ""

    ansible-playbook "${args[@]}" "$playbook"
}

do_check() {
    check_ansible
    [[ ! -f "$playbook"  ]] && error_exit "プレイブックが見つかりません: $playbook"
    [[ ! -f "$inventory" ]] && error_exit "インベントリが見つかりません: $inventory"

    local args
    read -ra args <<< "$(build_playbook_args)"

    log_info "ドライラン: $playbook"
    echo ""

    ansible-playbook "${args[@]}" --check "$playbook"
}

do_ping() {
    check_ansible
    [[ ! -f "$inventory" ]] && error_exit "インベントリが見つかりません: $inventory"

    local pattern="all"
    [[ ${#limit_hosts[@]} -gt 0 ]] && pattern="$(IFS=','; echo "${limit_hosts[*]}")"

    log_info "Ping テスト: $inventory ($pattern)"
    echo ""

    ansible "$pattern" -i "$inventory" -m ping
}

do_list() {
    check_ansible
    [[ ! -f "$inventory" ]] && error_exit "インベントリが見つかりません: $inventory"

    log_info "ホスト一覧: $inventory"
    echo ""

    ansible all -i "$inventory" --list-hosts 2>/dev/null | tail -n +2 | while read -r host; do
        echo "  - $host"
    done
}

do_facts() {
    check_ansible
    [[ ! -f "$inventory" ]] && error_exit "インベントリが見つかりません: $inventory"
    [[ ${#limit_hosts[@]} -eq 0 ]] && error_exit "対象ホストを --limit で指定してください"

    local pattern
    pattern="$(IFS=','; echo "${limit_hosts[*]}")"
    log_info "ファクト取得: $pattern"
    echo ""

    ansible "$pattern" -i "$inventory" -m setup \
        --tree /tmp/ansible_facts_$$ 2>/dev/null || true

    if [[ -d "/tmp/ansible_facts_$$" ]]; then
        for f in "/tmp/ansible_facts_$$/"; do
            local host
            host=$(basename "$f")
            log_info "ホスト: $host"
            jq '.ansible_facts | {
                os: .ansible_distribution,
                version: .ansible_distribution_version,
                hostname: .ansible_hostname,
                cpu_count: .ansible_processor_vcpus,
                memory_mb: .ansible_memtotal_mb
            }' "$f" 2>/dev/null || cat "$f"
        done
        rm -rf "/tmp/ansible_facts_$$"
    fi
}

do_syntax() {
    check_ansible
    [[ ! -f "$playbook"  ]] && error_exit "プレイブックが見つかりません: $playbook"
    [[ ! -f "$inventory" ]] && error_exit "インベントリが見つかりません: $inventory"

    log_info "構文チェック: $playbook"
    if ansible-playbook -i "$inventory" --syntax-check "$playbook"; then
        log_success "構文エラーなし"
    else
        log_error "構文エラーあり"
        exit 1
    fi
}

parse_arguments() {
    [[ $# -eq 0 ]] && { show_usage; exit 0; }
    action="$1"; shift

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -i|--inventory)
                [[ $# -lt 2 ]] && error_exit "--inventory には値が必要です"
                inventory="$2"; shift 2 ;;
            -p|--playbook)
                [[ $# -lt 2 ]] && error_exit "--playbook には値が必要です"
                playbook="$2"; shift 2 ;;
            -t|--tags)
                [[ $# -lt 2 ]] && error_exit "--tags には値が必要です"
                IFS=',' read -ra tags <<< "$2"; shift 2 ;;
            -l|--limit)
                [[ $# -lt 2 ]] && error_exit "--limit には値が必要です"
                IFS=',' read -ra limit_hosts <<< "$2"; shift 2 ;;
            -e|--extra-vars)
                [[ $# -lt 2 ]] && error_exit "--extra-vars には値が必要です"
                extra_vars="$2"; shift 2 ;;
            -f|--forks)
                [[ $# -lt 2 ]] && error_exit "--forks には数値が必要です"
                forks="$2"; shift 2 ;;
            --verbose) verbose=true; shift ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  error_exit "不明な引数: $1" ;;
        esac
    done
}

main() {
    parse_arguments "$@"

    case "$action" in
        run)    do_run ;;
        check)  do_check ;;
        ping)   do_ping ;;
        list)   do_list ;;
        facts)  do_facts ;;
        syntax) do_syntax ;;
        *)      error_exit "不明なアクション: $action。--help を参照してください" ;;
    esac
}

main "$@"
