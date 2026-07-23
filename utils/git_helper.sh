#!/bin/bash
set -euo pipefail

#
# Gitヘルパーツール
# バージョン: 1.0
#
# よく使うGit操作を簡略化・可視化するツール
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare action=""
declare branch=""
declare days=30
declare author=""

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME <アクション> [オプション]

Gitヘルパーツール

アクション:
  status    カラー付きステータス表示
  log       グラフ付きログ表示
  branches  ブランチ一覧 (最終コミット日付付き)
  authors   コントリビューター統計
  stash     スタッシュ一覧と操作
  cleanup   マージ済みブランチ削除
  summary   リポジトリサマリー

オプション:
  -h, --help            このヘルプを表示
  -v, --version         バージョン情報を表示
  -b, --branch BRANCH   対象ブランチ
  -d, --days NUM        過去N日 [デフォルト: 30]
  -a, --author NAME     特定の作者でフィルター

例:
  $PROG_NAME status
  $PROG_NAME log
  $PROG_NAME branches
  $PROG_NAME authors -d 90
  $PROG_NAME cleanup

EOF
}

check_git_repo() {
    if ! git rev-parse --git-dir &>/dev/null; then
        error_exit "Gitリポジトリではありません"
    fi
}

do_status() {
    log_info "リポジトリ: $(git remote get-url origin 2>/dev/null || echo '(ローカル)')"
    local current_branch
    current_branch=$(git branch --show-current)
    printf "  現在のブランチ: ${C_CYAN}%s${C_RESET}\n\n" "$current_branch"

    local status_output
    status_output=$(git status --porcelain)

    if [[ -z "$status_output" ]]; then
        log_success "ワーキングツリーはクリーンです"
        return
    fi

    local staged=0 unstaged=0 untracked=0

    while IFS= read -r line; do
        local xy="${line:0:2}"
        local file="${line:3}"
        local color="$C_DIM"
        local label="不明"

        case "$xy" in
            "M ") color="$C_GREEN";  label="ステージ済 (変更)" ;;
            "A ") color="$C_GREEN";  label="ステージ済 (追加)" ;;
            "D ") color="$C_GREEN";  label="ステージ済 (削除)" ;;
            " M") color="$C_YELLOW"; label="未ステージ (変更)" ;;
            " D") color="$C_YELLOW"; label="未ステージ (削除)" ;;
            "??") color="$C_RED";    label="未追跡" ;;
            "MM") color="$C_CYAN";   label="ステージ済+変更" ;;
        esac

        printf "  %b%-20s%b %s\n" "$color" "$label" "$C_RESET" "$file"

        case "$xy" in
            "M "|"A "|"D ") (( staged++ )) || true ;;
            " M"|" D")      (( unstaged++ )) || true ;;
            "??")           (( untracked++ )) || true ;;
        esac
    done <<< "$status_output"

    echo ""
    printf "  ステージ済: %d  未ステージ: %d  未追跡: %d\n" \
        "$staged" "$unstaged" "$untracked"
}

do_log() {
    local log_args=(
        --graph
        --oneline
        --decorate
        --color=always
    )
    [[ -n "$branch" ]] && log_args+=("$branch")
    [[ -n "$author" ]] && log_args+=(--author="$author")
    log_args+=(--since="${days} days ago")

    log_info "コミットログ (過去${days}日)"
    echo ""
    git log "${log_args[@]}" | head -50
}

do_branches() {
    log_info "ブランチ一覧"
    echo ""
    printf "  %-40s %-20s %s\n" "ブランチ名" "最終コミット日" "コミットメッセージ"
    printf "  %s\n" "$(printf '%.0s-' {1..80})"

    local current
    current=$(git branch --show-current)

    git branch -a --sort=-committerdate | while read -r br; do
        local clean_br="${br#  }"
        clean_br="${clean_br#* }"
        [[ "$clean_br" == *"->"* ]] && continue

        local date msg
        date=$(git log -1 --format="%ci" "$clean_br" 2>/dev/null | cut -d' ' -f1 || echo "N/A")
        msg=$(git log -1 --format="%s" "$clean_br" 2>/dev/null | cut -c1-40 || echo "")

        local marker=""
        [[ "$clean_br" == "$current" ]] && marker="${C_GREEN}* ${C_RESET}"

        printf "  %b%-40s%b %-20s %s\n" \
            "${marker:-}" "${clean_br:0:38}" "$C_RESET" "$date" "$msg"
    done | head -30
    echo ""
}

do_authors() {
    log_info "コントリビューター統計 (過去${days}日)"
    echo ""
    printf "  %-30s %-10s %s\n" "作者" "コミット数" "割合"
    printf "  %s\n" "$(printf '%.0s-' {1..55})"

    local total
    total=$(git log --since="${days} days ago" --oneline | wc -l)
    (( total == 0 )) && { log_info "コミットなし"; return; }

    git log --since="${days} days ago" --format="%an" | \
    sort | uniq -c | sort -rn | head -10 | \
    while read -r count name; do
        local pct=$(( count * 100 / total ))
        local bar
        bar=$(printf '%.0s█' $(seq 1 $(( pct / 5 + 1 ))))
        printf "  %-30s %-10d %s %d%%\n" "$name" "$count" "$bar" "$pct"
    done
    echo ""
    printf "  合計: %d コミット\n\n" "$total"
}

do_stash() {
    local count
    count=$(git stash list | wc -l)

    log_info "スタッシュ一覧 (${count}件)"
    echo ""

    if [[ $count -eq 0 ]]; then
        log_info "スタッシュはありません"
        return
    fi

    git stash list | while IFS= read -r line; do
        echo "  $line"
    done

    echo ""
    printf "操作 (pop/drop/clear/skip): "
    local op; read -r op
    case "$op" in
        pop)   git stash pop;   log_success "スタッシュを適用しました" ;;
        drop)  git stash drop;  log_success "最新スタッシュを削除しました" ;;
        clear) git stash clear; log_success "全スタッシュを削除しました" ;;
        *)     log_info "スキップしました" ;;
    esac
}

do_cleanup() {
    local default_branch
    default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|.*origin/||' || echo "main")

    log_info "マージ済みブランチ削除 (基準: $default_branch)"
    echo ""

    local merged_branches
    merged_branches=$(git branch --merged "$default_branch" | grep -v -E "^\*|$default_branch|main|master" || true)

    if [[ -z "$merged_branches" ]]; then
        log_success "削除対象のブランチはありません"
        return
    fi

    echo "削除対象:"
    echo "$merged_branches" | while read -r br; do
        echo "  - $br"
    done

    echo ""
    printf "削除しますか? [y/N]: "
    local ans; read -r ans
    if [[ "$ans" =~ ^[yY]$ ]]; then
        echo "$merged_branches" | xargs git branch -d
        log_success "削除完了"
    else
        log_info "キャンセルしました"
    fi
}

do_summary() {
    log_info "リポジトリサマリー"
    echo ""

    local repo_name
    repo_name=$(basename "$(git rev-parse --show-toplevel)")
    local total_commits
    total_commits=$(git rev-list --count HEAD 2>/dev/null || echo "N/A")
    local total_files
    total_files=$(git ls-files | wc -l)
    local total_branches
    total_branches=$(git branch -a | wc -l)
    local first_commit
    first_commit=$(git log --reverse --format="%ci" | head -1 | cut -d' ' -f1)
    local last_commit
    last_commit=$(git log -1 --format="%ci" | cut -d' ' -f1)

    printf "  リポジトリ:     %s\n" "$repo_name"
    printf "  総コミット数:   %s\n" "$total_commits"
    printf "  追跡ファイル数: %s\n" "$total_files"
    printf "  ブランチ数:     %s\n" "$total_branches"
    printf "  初回コミット:   %s\n" "$first_commit"
    printf "  最終コミット:   %s\n" "$last_commit"

    echo ""
    log_info "言語別ファイル数:"
    git ls-files | grep '\.' | awk -F. '{print $NF}' | sort | uniq -c | \
    sort -rn | head -10 | while read -r cnt ext; do
        printf "    %-15s %d ファイル\n" ".$ext" "$cnt"
    done
    echo ""
}

parse_arguments() {
    [[ $# -eq 0 ]] && { show_usage; exit 0; }
    action="$1"; shift

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -b|--branch)  [[ $# -lt 2 ]] && error_exit "--branch には値が必要です"; branch="$2"; shift 2 ;;
            -d|--days)    [[ $# -lt 2 ]] && error_exit "--days には数値が必要です"; days="$2"; shift 2 ;;
            -a|--author)  [[ $# -lt 2 ]] && error_exit "--author には値が必要です"; author="$2"; shift 2 ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  error_exit "不明な引数: $1" ;;
        esac
    done
}

main() {
    parse_arguments "$@"
    check_git_repo

    case "$action" in
        status)   do_status ;;
        log)      do_log ;;
        branches) do_branches ;;
        authors)  do_authors ;;
        stash)    do_stash ;;
        cleanup)  do_cleanup ;;
        summary)  do_summary ;;
        *)        error_exit "不明なアクション: $action。--help を参照してください" ;;
    esac
}

main "$@"
