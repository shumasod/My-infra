#!/bin/bash
set -euo pipefail

#
# Gitリポジトリ統計レポートツール
# 作成日: 2026-07-27
# バージョン: 1.0
#
# Gitリポジトリのコミット・貢献者・ファイル変更の統計を表示します
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare command_name="summary"
declare since_date=""
declare until_date=""
declare author_filter=""
declare repo_path="."
declare top_n=10
declare output_format="pretty"

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション]

Gitリポジトリの統計情報を表示します。

コマンド:
  summary                全体サマリー (デフォルト)
  authors                貢献者別コミット統計
  files                  変更頻度の高いファイル
  timeline               コミットタイムライン (曜日・時間帯別)
  changes                追加/削除行数ランキング
  tags                   タグ一覧と間隔分析

オプション:
  -h, --help             このヘルプを表示
  -v, --version          バージョン情報を表示
  -p, --path <パス>      リポジトリパス [デフォルト: .]
  -n, --top <数>         上位表示件数 [デフォルト: 10]
  --since <日付>         開始日 (例: 2025-01-01)
  --until <日付>         終了日 (例: 2025-12-31)
  --author <名前>        著者でフィルタ
  --format <形式>        出力形式 (pretty|csv) [デフォルト: pretty]

例:
  $PROG_NAME
  $PROG_NAME authors -n 5
  $PROG_NAME files --since 2025-01-01
  $PROG_NAME timeline
  $PROG_NAME changes --author "John"
EOF
}

check_git_repo() {
    if ! git -C "$repo_path" rev-parse --git-dir &>/dev/null; then
        error_exit "Gitリポジトリではありません: $repo_path"
    fi
}

git_log_opts() {
    local opts=()
    [[ -n "$since_date"   ]] && opts+=("--since=$since_date")
    [[ -n "$until_date"   ]] && opts+=("--until=$until_date")
    [[ -n "$author_filter" ]] && opts+=("--author=$author_filter")
    echo "${opts[@]+"${opts[@]}"}"
}

bar() {
    local val=$1
    local max=$2
    local width=${3:-30}
    local filled=$(( val * width / (max > 0 ? max : 1) ))
    printf '%0.s█' $(seq 1 $filled 2>/dev/null) || true
    printf '%0.s░' $(seq 1 $(( width - filled )) 2>/dev/null) || true
}

cmd_summary() {
    log_info "リポジトリサマリーを生成中..."
    echo ""

    local repo_name
    repo_name=$(basename "$(git -C "$repo_path" rev-parse --show-toplevel)")

    local total_commits
    total_commits=$(git -C "$repo_path" rev-list --count HEAD $(git_log_opts) 2>/dev/null || echo 0)

    local total_authors
    total_authors=$(git -C "$repo_path" log --format="%aN" $(git_log_opts) | sort -u | wc -l | tr -d ' ')

    local first_commit
    first_commit=$(git -C "$repo_path" log --reverse --format="%ad" --date=short $(git_log_opts) | head -1)

    local last_commit
    last_commit=$(git -C "$repo_path" log -1 --format="%ad" --date=short $(git_log_opts))

    local total_files
    total_files=$(git -C "$repo_path" ls-files | wc -l | tr -d ' ')

    local total_lines
    total_lines=$(git -C "$repo_path" log --numstat --format="" $(git_log_opts) \
        | awk 'NF==3 && $1~/^[0-9]+$/ {added+=$1; deleted+=$2} END {print added+0 " 追加 / " deleted+0 " 削除"}')

    local current_branch
    current_branch=$(git -C "$repo_path" rev-parse --abbrev-ref HEAD)

    printf "${C_BOLD}${C_CYAN}╔══════════════════════════════════════╗${C_RESET}\n"
    printf "${C_BOLD}${C_CYAN}║   Gitリポジトリ統計レポート          ║${C_RESET}\n"
    printf "${C_BOLD}${C_CYAN}╚══════════════════════════════════════╝${C_RESET}\n"
    echo ""
    printf "  ${C_BOLD}リポジトリ${C_RESET}   : %s\n" "$repo_name"
    printf "  ${C_BOLD}現在のブランチ${C_RESET}: %s\n" "$current_branch"
    printf "  ${C_BOLD}総コミット数${C_RESET} : ${C_GREEN}%s${C_RESET}\n" "$total_commits"
    printf "  ${C_BOLD}貢献者数${C_RESET}     : ${C_CYAN}%s${C_RESET}\n" "$total_authors"
    printf "  ${C_BOLD}追跡ファイル数${C_RESET}: ${C_YELLOW}%s${C_RESET}\n" "$total_files"
    printf "  ${C_BOLD}変更行数${C_RESET}     : %s\n" "$total_lines"
    printf "  ${C_BOLD}期間${C_RESET}         : %s 〜 %s\n" "$first_commit" "$last_commit"
    echo ""
}

cmd_authors() {
    log_info "貢献者統計を集計中..."
    echo ""

    declare -A author_commits
    declare -A author_added
    declare -A author_deleted

    while IFS='|' read -r author added deleted; do
        [[ -z "$author" ]] && continue
        author_commits["$author"]=$(( ${author_commits["$author"]:-0} + 1 ))
        author_added["$author"]=$(( ${author_added["$author"]:-0} + ${added:-0} ))
        author_deleted["$author"]=$(( ${author_deleted["$author"]:-0} + ${deleted:-0} ))
    done < <(git -C "$repo_path" log --format="COMMIT|%aN" --numstat $(git_log_opts) \
        | awk '
            /^COMMIT\|/ { author=substr($0,8); next }
            NF==3 && $1~/^[0-9]+$/ { print author "|" $1 "|" $2 }
        ')

    local total_commits=0
    for a in "${!author_commits[@]}"; do
        total_commits=$(( total_commits + author_commits["$a"] ))
    done

    printf "${C_BOLD}%-25s %8s %6s %8s %8s${C_RESET}\n" "著者" "コミット" "%" "追加行" "削除行"
    printf "%s\n" "$(printf '%.0s─' {1..60})"

    local count=0
    for author in $(for a in "${!author_commits[@]}"; do echo "${author_commits[$a]} $a"; done | sort -rn | awk '{print $2}'); do
        [[ $count -ge $top_n ]] && break
        local commits=${author_commits["$author"]}
        local pct=$(( commits * 100 / (total_commits > 0 ? total_commits : 1) ))
        local added=${author_added["$author"]:-0}
        local deleted=${author_deleted["$author"]:-0}
        printf "  ${C_CYAN}%-23s${C_RESET} %8d %5d%% ${C_GREEN}%+8d${C_RESET} ${C_RED}%+8d${C_RESET}\n" \
            "$author" "$commits" "$pct" "$added" "-$deleted"
        ((count++))
    done
    echo ""
}

cmd_files() {
    log_info "変更頻度の高いファイルを集計中..."
    echo ""

    printf "${C_BOLD}%-45s %8s${C_RESET}\n" "ファイル" "変更回数"
    printf "%s\n" "$(printf '%.0s─' {1..60})"

    local max_count=1
    local -a file_counts=()

    while IFS=' ' read -r count file; do
        file_counts+=("$count $file")
        [[ $count -gt $max_count ]] && max_count=$count
    done < <(git -C "$repo_path" log --format="" --name-only $(git_log_opts) \
        | grep -v '^$' | sort | uniq -c | sort -rn | head -"$top_n")

    local rank=1
    for entry in "${file_counts[@]}"; do
        local count="${entry%% *}"
        local file="${entry#* }"
        local b
        b=$(bar "$count" "$max_count" 20)
        printf "  ${C_YELLOW}%2d.${C_RESET} %-42s ${C_GREEN}%4d${C_RESET} %s\n" \
            "$rank" "$file" "$count" "$b"
        ((rank++))
    done
    echo ""
}

cmd_timeline() {
    log_info "コミットタイムラインを生成中..."
    echo ""

    declare -A dow_count hour_count
    for d in Mon Tue Wed Thu Fri Sat Sun; do dow_count["$d"]=0; done
    for h in $(seq 0 23); do hour_count[$h]=0; done

    while IFS= read -r line; do
        local dow="${line%% *}"
        local hour="${line#* }"
        hour="${hour%%:*}"
        hour="${hour#0}"
        dow_count["$dow"]=$(( ${dow_count["$dow"]:-0} + 1 ))
        hour_count[$hour]=$(( ${hour_count[$hour]:-0} + 1 ))
    done < <(git -C "$repo_path" log --format="%ad" --date=format:'%a %H:%M' $(git_log_opts))

    local max_dow=1
    for d in Mon Tue Wed Thu Fri Sat Sun; do
        [[ ${dow_count[$d]:-0} -gt $max_dow ]] && max_dow=${dow_count[$d]}
    done

    printf "${C_BOLD}【曜日別コミット数】${C_RESET}\n"
    local days=(Mon Tue Wed Thu Fri Sat Sun)
    local day_ja=(月 火 水 木 金 土 日)
    for i in "${!days[@]}"; do
        local d="${days[$i]}"
        local ja="${day_ja[$i]}"
        local cnt=${dow_count[$d]:-0}
        local b
        b=$(bar "$cnt" "$max_dow" 25)
        printf "  %s(%s) ${C_CYAN}%s${C_RESET} %d\n" "$d" "$ja" "$b" "$cnt"
    done

    echo ""

    local max_hour=1
    for h in $(seq 0 23); do
        [[ ${hour_count[$h]:-0} -gt $max_hour ]] && max_hour=${hour_count[$h]}
    done

    printf "${C_BOLD}【時間帯別コミット数】${C_RESET}\n"
    for h in $(seq 0 23); do
        local cnt=${hour_count[$h]:-0}
        local b
        b=$(bar "$cnt" "$max_hour" 20)
        printf "  %02d時 ${C_YELLOW}%s${C_RESET} %d\n" "$h" "$b" "$cnt"
    done
    echo ""
}

cmd_changes() {
    log_info "変更行数ランキングを集計中..."
    echo ""

    printf "${C_BOLD}%-40s %10s %10s %10s${C_RESET}\n" "コミット" "追加行" "削除行" "合計"
    printf "%s\n" "$(printf '%.0s─' {1..75})"

    local count=0
    git -C "$repo_path" log --format="%h %s" --numstat $(git_log_opts) \
    | awk '
        /^[0-9a-f]{7} / { hash=$1; sub(/^[0-9a-f]{7} /,""); msg=$0; added=0; deleted=0; next }
        NF==3 && $1~/^[0-9]+$/ { added+=$1; deleted+=$2 }
        /^$/ && hash!="" { print added+deleted " " added " " deleted " " hash " " msg; hash="" }
    ' | sort -rn | head -"$top_n" | while IFS=' ' read -r total added deleted hash msg; do
        printf "  ${C_DIM}%s${C_RESET} %-35s ${C_GREEN}+%6d${C_RESET} ${C_RED}-%6d${C_RESET} %7d\n" \
            "$hash" "${msg:0:35}" "$added" "$deleted" "$total"
    done
    echo ""
}

cmd_tags() {
    log_info "タグ一覧を取得中..."
    echo ""

    local tags
    tags=$(git -C "$repo_path" tag --sort=-version:refname | head -20)

    if [[ -z "$tags" ]]; then
        log_info "タグが見つかりません"
        return
    fi

    printf "${C_BOLD}%-20s %-12s %s${C_RESET}\n" "タグ名" "日付" "コミット"
    printf "%s\n" "$(printf '%.0s─' {1..55})"

    echo "$tags" | while IFS= read -r tag; do
        local date
        date=$(git -C "$repo_path" log -1 --format="%ad" --date=short "$tag" 2>/dev/null || echo "N/A")
        local hash
        hash=$(git -C "$repo_path" rev-parse --short "$tag^{commit}" 2>/dev/null || echo "N/A")
        printf "  ${C_GREEN}%-18s${C_RESET} %-12s ${C_DIM}%s${C_RESET}\n" "$tag" "$date" "$hash"
    done
    echo ""
}

parse_arguments() {
    [[ $# -eq 0 ]] && return 0

    # 最初の引数がコマンドかチェック
    case "$1" in
        summary|authors|files|timeline|changes|tags)
            command_name="$1"
            shift
            ;;
    esac

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
            -p|--path)
                [[ $# -lt 2 ]] && error_exit "--path には値が必要です"
                repo_path="$2"
                shift 2
                ;;
            -n|--top)
                [[ $# -lt 2 ]] && error_exit "--top には値が必要です"
                top_n="$2"
                shift 2
                ;;
            --since)
                [[ $# -lt 2 ]] && error_exit "--since には値が必要です"
                since_date="$2"
                shift 2
                ;;
            --until)
                [[ $# -lt 2 ]] && error_exit "--until には値が必要です"
                until_date="$2"
                shift 2
                ;;
            --author)
                [[ $# -lt 2 ]] && error_exit "--author には値が必要です"
                author_filter="$2"
                shift 2
                ;;
            --format)
                [[ $# -lt 2 ]] && error_exit "--format には値が必要です"
                output_format="$2"
                shift 2
                ;;
            -*)
                error_exit "不明なオプション: $1"
                ;;
            *)
                error_exit "不明な引数: $1"
                ;;
        esac
    done
}

main() {
    parse_arguments "$@"
    check_git_repo

    case "$command_name" in
        summary)  cmd_summary ;;
        authors)  cmd_authors ;;
        files)    cmd_files ;;
        timeline) cmd_timeline ;;
        changes)  cmd_changes ;;
        tags)     cmd_tags ;;
        *)        error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
