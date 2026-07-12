#!/bin/bash
set -euo pipefail

#
# デプロイ前チェックリスト
# 作成日: 2026-07-04
# バージョン: 1.0
#
# デプロイ前に必要な確認事項を自動チェックする
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare -i pass=0 warn=0 fail=0 skip=0

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション]

デプロイ前に必要なチェックを実行します。

オプション:
  -h, --help         このヘルプを表示
  -v, --version      バージョン情報を表示
  -e, --env ENV      環境名 (staging/production)
  -b, --branch NAME  対象ブランチ名
  -o, --output FILE  レポートをファイルに保存
  --skip-tests       テストチェックをスキップ
  --skip-git         Gitチェックをスキップ
  --skip-deps        依存関係チェックをスキップ

例:
  $PROG_NAME -e production -b main
  $PROG_NAME -e staging --skip-tests
EOF
}

chk_pass() { echo -e "  ${C_GREEN}[PASS]${C_RESET} $1"; pass=$(( pass + 1 )); }
chk_warn() { echo -e "  ${C_YELLOW}[WARN]${C_RESET} $1"; warn=$(( warn + 1 )); }
chk_fail() { echo -e "  ${C_RED}[FAIL]${C_RESET} $1"; fail=$(( fail + 1 )); }
chk_skip() { echo -e "  ${C_DIM}[SKIP]${C_RESET} $1"; skip=$(( skip + 1 )); }
chk_info() { echo -e "  ${C_CYAN}[INFO]${C_RESET} $1"; }

section() {
    echo ""
    echo -e "  ${C_BOLD}${C_CYAN}── $1 ──${C_RESET}"
    echo ""
}

check_git() {
    local branch="$1"

    section "Git チェック"

    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        chk_fail "Gitリポジトリではありません"
        return
    fi
    chk_pass "Gitリポジトリを確認"

    local current_branch
    current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    if [ -n "$branch" ] && [ "$current_branch" != "$branch" ]; then
        chk_fail "ブランチが違います: 現在=${current_branch} 期待=${branch}"
    else
        chk_pass "ブランチ確認: ${current_branch}"
    fi

    local uncommitted
    uncommitted=$(git status --porcelain 2>/dev/null | wc -l)
    if [ "$uncommitted" -gt 0 ]; then
        chk_warn "未コミットの変更があります: ${uncommitted}件"
    else
        chk_pass "未コミット変更なし"
    fi

    local unpushed
    unpushed=$(git log "@{u}.." 2>/dev/null | wc -l) || unpushed=0
    if [ "$unpushed" -gt 0 ]; then
        chk_warn "未プッシュのコミットがあります: ${unpushed}件"
    else
        chk_pass "全コミットがプッシュ済み"
    fi

    local last_tag
    last_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "なし")
    chk_info "最新タグ: ${last_tag}"
}

check_tests() {
    section "テスト チェック"

    if [ -f "package.json" ]; then
        if grep -q '"test"' package.json 2>/dev/null; then
            chk_info "npm test が定義されています"
        else
            chk_warn "package.json にテストスクリプトがありません"
        fi
    elif [ -f "Makefile" ]; then
        if grep -q "^test:" Makefile 2>/dev/null; then
            chk_info "Makefile に test ターゲットがあります"
        else
            chk_warn "Makefile に test ターゲットがありません"
        fi
    elif [ -d "tests" ] || [ -d "test" ] || [ -d "spec" ]; then
        chk_pass "テストディレクトリが存在します"
    else
        chk_warn "テスト定義が見つかりません"
    fi

    if [ -d ".github/workflows" ]; then
        local wf_count
        wf_count=$(ls .github/workflows/*.yml 2>/dev/null | wc -l)
        chk_pass "CIワークフロー: ${wf_count}件"
    else
        chk_warn "GitHub Actions ワークフローがありません"
    fi
}

check_dependencies() {
    section "依存関係 チェック"

    if [ -f "package.json" ] && [ -f "package-lock.json" ]; then
        local pkg_time lock_time
        pkg_time=$(stat -c %Y package.json 2>/dev/null)
        lock_time=$(stat -c %Y package-lock.json 2>/dev/null)
        if [ "$pkg_time" -gt "$lock_time" ]; then
            chk_warn "package.json が package-lock.json より新しい（npm install が必要かも）"
        else
            chk_pass "package-lock.json が最新"
        fi
    fi

    if [ -f "requirements.txt" ]; then
        chk_info "Python requirements.txt が存在します"
    fi

    if [ -f "Gemfile.lock" ]; then
        chk_pass "Gemfile.lock が存在します"
    fi

    if [ -f "go.sum" ]; then
        chk_pass "go.sum が存在します"
    fi

    if [ -f "Cargo.lock" ]; then
        chk_pass "Cargo.lock が存在します"
    fi

    if ! grep -rq "password\|secret\|api_key\|token" .env 2>/dev/null; then
        chk_pass ".env ファイルに機密情報の露出なし（または存在しない）"
    fi
}

check_environment() {
    local env="$1"

    section "環境 チェック"

    chk_info "対象環境: ${env:-未指定}"
    chk_info "ホスト名: $(hostname)"
    chk_info "実行日時: $(get_timestamp)"
    chk_info "実行ユーザー: $(whoami)"

    if [ -f ".env.${env}" ] 2>/dev/null; then
        chk_pass ".env.${env} が存在します"
    elif [ -f ".env" ]; then
        chk_warn ".env.${env} がなく .env を使用"
    else
        chk_warn "環境設定ファイルが見つかりません"
    fi

    local disk_usage
    disk_usage=$(df -h . 2>/dev/null | tail -1 | awk '{print $5}' | tr -d '%')
    if [[ "$disk_usage" =~ ^[0-9]+$ ]]; then
        if [ "$disk_usage" -ge 90 ]; then
            chk_fail "ディスク使用率が危険: ${disk_usage}%"
        elif [ "$disk_usage" -ge 80 ]; then
            chk_warn "ディスク使用率が高い: ${disk_usage}%"
        else
            chk_pass "ディスク使用率: ${disk_usage}%"
        fi
    fi
}

show_summary() {
    local output_file="$1"
    echo ""
    echo -e "  ${C_DIM}$(printf '%.0s─' {1..50})${C_RESET}"
    echo ""
    printf "  ${C_BOLD}チェック結果:${C_RESET}  ${C_GREEN}PASS:%d${C_RESET}  ${C_YELLOW}WARN:%d${C_RESET}  ${C_RED}FAIL:%d${C_RESET}  ${C_DIM}SKIP:%d${C_RESET}\n" \
        "$pass" "$warn" "$fail" "$skip"
    echo ""

    if [ "$fail" -gt 0 ]; then
        print_center "デプロイを中止してください！($fail 件の致命的エラー)" 0 "${C_BOLD}${C_RED}"
    elif [ "$warn" -gt 0 ]; then
        print_center "警告を確認してからデプロイしてください" 0 "${C_BOLD}${C_YELLOW}"
    else
        print_center "デプロイの準備ができています！" 0 "${C_BOLD}${C_GREEN}"
    fi
    echo ""

    if [ -n "$output_file" ]; then
        {
            echo "# デプロイ前チェックレポート"
            echo "# 生成日時: $(get_timestamp)"
            echo "# PASS:${pass}  WARN:${warn}  FAIL:${fail}  SKIP:${skip}"
        } > "$output_file"
        log_success "レポートを保存: $output_file"
    fi
}

main() {
    local env=""
    local branch=""
    local output_file=""
    local skip_tests=false
    local skip_git=false
    local skip_deps=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -e|--env)     [[ $# -lt 2 ]] && error_exit "--env には環境名が必要です"; env="$2"; shift 2 ;;
            -b|--branch)  [[ $# -lt 2 ]] && error_exit "--branch にはブランチ名が必要です"; branch="$2"; shift 2 ;;
            -o|--output)  [[ $# -lt 2 ]] && error_exit "--output にはファイル名が必要です"; output_file="$2"; shift 2 ;;
            --skip-tests) skip_tests=true; shift ;;
            --skip-git)   skip_git=true; shift ;;
            --skip-deps)  skip_deps=true; shift ;;
            *) error_exit "不明なオプション: $1" ;;
        esac
    done

    echo ""
    print_center "デプロイ前チェックリスト" 0 "${C_BOLD}${C_CYAN}"
    print_center "$(get_timestamp)" 0 "$C_DIM"

    if ! "$skip_git"; then
        check_git "$branch"
    else
        chk_skip "Gitチェック（スキップ）"
    fi

    if ! "$skip_tests"; then
        check_tests
    else
        chk_skip "テストチェック（スキップ）"
    fi

    if ! "$skip_deps"; then
        check_dependencies
    else
        chk_skip "依存関係チェック（スキップ）"
    fi

    check_environment "$env"
    show_summary "$output_file"

    [ "$fail" -gt 0 ] && exit 1
    exit 0
}

main "$@"
