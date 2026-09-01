#!/bin/bash
set -euo pipefail

#
# Gitリポジトリ管理ヘルパー
# 作成日: 2026-09-01
# バージョン: 1.0
#
# Gitの操作を視覚的に支援するツールです
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare command_name="status"
declare num_commits=20
declare branch_pattern=""

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション]

Git操作を視覚的に支援するツールです。

コマンド:
  status               リポジトリ状態サマリー (デフォルト)
  log                  コミットログ (グラフ付き)
  branches             ブランチ一覧と状態
  stash                スタッシュ一覧
  remotes              リモート一覧
  contributors         コントリビュータ統計
  cleanup              マージ済みブランチ削除
  large                大きなファイル検出
  stats                コミット統計

オプション:
  -h, --help           このヘルプを表示
  -v, --version        バージョン情報を表示
  -n, --num <件数>     表示件数 [デフォルト: 20]
  -b, --branch <パターン> ブランチフィルタ

例:
  $PROG_NAME status
  $PROG_NAME log -n 50
  $PROG_NAME branches
  $PROG_NAME cleanup
  $PROG_NAME contributors
EOF
}

check_git() {
    if ! command -v git &>/dev/null; then
        error_exit "git が見つかりません"
    fi
    if ! git rev-parse --git-dir &>/dev/null 2>&1; then
        error_exit "Gitリポジトリではありません"
    fi
}

cmd_status() {
    log_info "リポジトリ状態"
    echo ""

    local repo_root
    repo_root=$(git rev-parse --show-toplevel)
    local branch
    branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "HEAD detached")
    local remote_url
    remote_url=$(git remote get-url origin 2>/dev/null || echo "なし")

    printf "  %-20s %s\n" "リポジトリ:"   "$repo_root"
    printf "  %-20s ${C_CYAN}%s${C_RESET}\n" "現在のブランチ:" "$branch"
    printf "  %-20s %s\n" "リモート:"     "$remote_url"

    local upstream_info=""
    if git rev-parse "@{u}" &>/dev/null 2>&1; then
        local ahead behind
        ahead=$(git rev-list "@{u}..HEAD" --count 2>/dev/null || echo 0)
        behind=$(git rev-list "HEAD..@{u}" --count 2>/dev/null || echo 0)
        upstream_info="${C_GREEN}↑${ahead}${C_RESET} ${C_YELLOW}↓${behind}${C_RESET}"
        printf "  %-20s %b\n" "リモートとの差分:" "$upstream_info"
    fi
    echo ""

    printf "${C_BOLD}【作業ツリー】${C_RESET}\n\n"

    local staged unstaged untracked
    staged=$(git diff --cached --name-only | wc -l)
    unstaged=$(git diff --name-only | wc -l)
    untracked=$(git ls-files --others --exclude-standard | wc -l)

    printf "  %-20s ${C_GREEN}%s ファイル${C_RESET}\n"  "ステージ済み:"   "$staged"
    printf "  %-20s ${C_YELLOW}%s ファイル${C_RESET}\n" "未ステージ:"     "$unstaged"
    printf "  %-20s ${C_DIM}%s ファイル${C_RESET}\n"    "未追跡:"         "$untracked"
    echo ""

    if [[ "$staged" -gt 0 || "$unstaged" -gt 0 ]]; then
        git status --short | head -20 | while IFS= read -r line; do
            local indicator="${line:0:2}"
            case "$indicator" in
                "M "|"A "|"D ") printf "  ${C_GREEN}%s${C_RESET}\n" "$line" ;;
                " M"|" D")      printf "  ${C_YELLOW}%s${C_RESET}\n" "$line" ;;
                "??")           printf "  ${C_DIM}%s${C_RESET}\n" "$line" ;;
                *)              printf "  %s\n" "$line" ;;
            esac
        done
        echo ""
    fi
}

cmd_log() {
    log_info "コミットログ (直近 $num_commits 件)"
    echo ""

    git log --oneline --graph --decorate --color=always -n "$num_commits" | \
    while IFS= read -r line; do
        if echo "$line" | grep -q "HEAD"; then
            printf "${C_BOLD}${C_CYAN}%s${C_RESET}\n" "$line"
        elif echo "$line" | grep -q "tag:"; then
            printf "${C_YELLOW}%s${C_RESET}\n" "$line"
        else
            printf "%s\n" "$line"
        fi
    done
    echo ""
}

cmd_branches() {
    log_info "ブランチ一覧"
    echo ""

    local current
    current=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")

    printf "${C_BOLD}【ローカルブランチ】${C_RESET}\n\n"
    git branch -v | while IFS= read -r line; do
        if echo "$line" | grep -q "^\*"; then
            printf "${C_GREEN}%s${C_RESET}\n" "$line"
        elif echo "$line" | grep -q "\[gone\]"; then
            printf "${C_DIM}%s${C_RESET}\n" "$line"
        else
            printf "%s\n" "$line"
        fi
    done

    echo ""
    printf "${C_BOLD}【リモートブランチ】${C_RESET}\n\n"
    git branch -r | grep -v "HEAD" | head -20 | while IFS= read -r line; do
        printf "  ${C_DIM}%s${C_RESET}\n" "$line"
    done
    echo ""
}

cmd_stash() {
    log_info "スタッシュ一覧"
    echo ""

    local count
    count=$(git stash list | wc -l)
    printf "  合計: %s 件\n\n" "$count"

    if [[ "$count" -eq 0 ]]; then
        printf "  ${C_DIM}スタッシュはありません${C_RESET}\n"
    else
        git stash list | while IFS= read -r line; do
            printf "  ${C_YELLOW}%s${C_RESET}\n" "$line"
        done
    fi
    echo ""
}

cmd_remotes() {
    log_info "リモート一覧"
    echo ""
    git remote -v | awk '!seen[$0]++' | while IFS= read -r line; do
        printf "  ${C_CYAN}%s${C_RESET}\n" "$line"
    done
    echo ""
}

cmd_contributors() {
    log_info "コントリビュータ統計"
    echo ""

    git log --format="%aN" | sort | uniq -c | sort -rn | head -20 | \
    python3 - <<'PYEOF'
import sys

lines = sys.stdin.read().strip().splitlines()
if not lines:
    print("  コミット履歴がありません")
    sys.exit(0)

CYAN  = "\033[1;36m"
GREEN = "\033[1;32m"
RESET = "\033[0m"
BOLD  = "\033[1m"

total = sum(int(l.strip().split()[0]) for l in lines)
max_count = int(lines[0].strip().split()[0])

print(f"  {BOLD}{'コントリビュータ':<25} {'コミット数':>10}   {'割合':>6}   グラフ{RESET}\n")
for line in lines:
    parts = line.strip().split(None, 1)
    count = int(parts[0])
    name = parts[1] if len(parts) > 1 else "unknown"
    pct = count / total * 100
    bar_len = int(count / max_count * 30)
    bar = "█" * bar_len
    print(f"  {CYAN}{name:<25}{RESET} {count:>10}   {pct:>5.1f}%   {GREEN}{bar}{RESET}")
print(f"\n  合計コミット数: {total}")
PYEOF
    echo ""
}

cmd_cleanup() {
    log_info "マージ済みブランチ確認"
    echo ""

    local main_branch
    main_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|.*/||' || echo "main")

    local merged_branches
    merged_branches=$(git branch --merged "$main_branch" 2>/dev/null | grep -v "^\*\|$main_branch\|master\|main\|develop" || true)

    if [[ -z "$merged_branches" ]]; then
        log_success "削除対象のブランチはありません"
        echo ""
        return
    fi

    printf "削除対象ブランチ:\n"
    echo "$merged_branches" | while IFS= read -r b; do
        printf "  ${C_YELLOW}%s${C_RESET}\n" "$b"
    done
    echo ""

    if ! confirm "これらのブランチを削除しますか？"; then
        log_info "キャンセルしました"
        return
    fi

    echo "$merged_branches" | while IFS= read -r b; do
        git branch -d "$b" && log_success "削除: $b"
    done
    echo ""
}

cmd_large() {
    log_info "大きなファイル検出 (上位20件)"
    echo ""

    git rev-list --objects --all 2>/dev/null | \
    git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' 2>/dev/null | \
    awk '/^blob/ {print $3, $4}' | sort -rn | head -20 | \
    python3 - <<'PYEOF'
import sys

CYAN  = "\033[1;36m"
RESET = "\033[0m"
BOLD  = "\033[1m"

def fmt(b):
    b = float(b)
    for u in ['B','KB','MB','GB']:
        if b < 1024: return f"{b:.1f}{u}"
        b /= 1024
    return f"{b:.1f}TB"

print(f"  {BOLD}{'サイズ':>10}  ファイルパス{RESET}\n")
for line in sys.stdin:
    parts = line.strip().split(None, 1)
    if len(parts) == 2:
        size, path = parts
        print(f"  {CYAN}{fmt(size):>10}{RESET}  {path}")
PYEOF
    echo ""
}

cmd_stats() {
    log_info "コミット統計"
    echo ""

    local total_commits
    total_commits=$(git rev-list --count HEAD 2>/dev/null || echo 0)
    local first_commit
    first_commit=$(git log --reverse --format="%ai" | head -1 | cut -d' ' -f1 || echo "N/A")
    local last_commit
    last_commit=$(git log -1 --format="%ai" | cut -d' ' -f1 || echo "N/A")

    printf "  %-20s %s\n" "総コミット数:"     "$total_commits"
    printf "  %-20s %s\n" "最初のコミット:"   "$first_commit"
    printf "  %-20s %s\n" "最新のコミット:"   "$last_commit"
    echo ""

    printf "${C_BOLD}【月別コミット数 (直近12ヶ月)】${C_RESET}\n\n"
    git log --format="%ai" | cut -c1-7 | sort | uniq -c | tail -12 | \
    python3 - <<'PYEOF'
import sys
lines = sys.stdin.read().strip().splitlines()
if not lines:
    sys.exit(0)
GREEN = "\033[1;32m"
RESET = "\033[0m"
max_c = max(int(l.split()[0]) for l in lines)
for line in lines:
    parts = line.strip().split(None, 1)
    count, month = int(parts[0]), parts[1]
    bar = "█" * int(count / max_c * 30)
    print(f"  {month}  {GREEN}{bar}{RESET} {count}")
PYEOF
    echo ""
}

parse_arguments() {
    [[ $# -eq 0 ]] && return 0
    case "$1" in
        status|log|branches|stash|remotes|contributors|cleanup|large|stats)
            command_name="$1"; shift ;;
    esac

    local positional=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -n|--num)     [[ $# -lt 2 ]] && error_exit "--num には値が必要です"; num_commits="$2"; shift 2 ;;
            -b|--branch)  [[ $# -lt 2 ]] && error_exit "--branch には値が必要です"; branch_pattern="$2"; shift 2 ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  positional+=("$1"); shift ;;
        esac
    done
    POSITIONAL=("${positional[@]+"${positional[@]}"}")
}

declare -a POSITIONAL=()

main() {
    parse_arguments "$@"
    check_git
    case "$command_name" in
        status)       cmd_status ;;
        log)          cmd_log ;;
        branches)     cmd_branches ;;
        stash)        cmd_stash ;;
        remotes)      cmd_remotes ;;
        contributors) cmd_contributors ;;
        cleanup)      cmd_cleanup ;;
        large)        cmd_large ;;
        stats)        cmd_stats ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
