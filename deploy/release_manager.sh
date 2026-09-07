#!/bin/bash
set -euo pipefail

#
# リリース管理ツール
# バージョン: 1.0
#
# セマンティックバージョニングに基づくリリース管理ツール
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"
readonly CHANGELOG_FILE="CHANGELOG.md"
readonly VERSION_FILE="${VERSION_FILE:-VERSION}"

declare mode="current"
declare bump_type="patch"
declare release_tag=""
declare dry_run=false
declare push_after=false
declare pre_release=""
declare changelog_entry=""

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション] コマンド

リリース管理ツール (セマンティックバージョニング)

コマンド:
  current           現在のバージョンを表示
  bump TYPE         バージョンを上げる (major|minor|patch)
  tag NAME          リリースタグを作成
  changelog         CHANGELOGを更新
  list              リリース履歴一覧
  diff VERSION      指定バージョンからの差分表示
  check             リリース前チェックリスト

オプション:
  -h, --help              このヘルプを表示
  -v, --version           バージョン情報を表示
  -t, --type TYPE         バンプ種別 (major|minor|patch) [デフォルト: patch]
  -p, --pre-release STR   プレリリース識別子 (alpha|beta|rc)
  -m, --message MSG       CHANGELOG エントリ
  --push                  変更後にgit push
  --dry-run               実際の変更を行わずシミュレート

セマンティックバージョニング:
  major: 後方互換性のない変更 (1.0.0 → 2.0.0)
  minor: 後方互換性のある新機能 (1.0.0 → 1.1.0)
  patch: バグ修正 (1.0.0 → 1.0.1)

例:
  $PROG_NAME current
  $PROG_NAME bump patch
  $PROG_NAME bump minor -m "新機能追加"
  $PROG_NAME bump major --pre-release rc.1
  $PROG_NAME list
  $PROG_NAME diff v1.0.0
  $PROG_NAME check

EOF
}

get_current_version() {
    if [[ -f "$VERSION_FILE" ]]; then
        cat "$VERSION_FILE" | tr -d '[:space:]'
    else
        git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo "0.0.0"
    fi
}

parse_version() {
    local ver="$1"
    ver="${ver#v}"
    local pre_rel=""
    if [[ "$ver" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)(-(.+))?$ ]]; then
        echo "${BASH_REMATCH[1]} ${BASH_REMATCH[2]} ${BASH_REMATCH[3]} ${BASH_REMATCH[5]:-}"
    else
        error_exit "無効なバージョン形式: $ver (X.Y.Z 形式必須)"
    fi
}

bump_version() {
    local current="$1"
    local type="$2"
    local pre="$3"

    local parts
    read -r major minor patch pre_old <<< "$(parse_version "$current")"

    case "$type" in
        major) (( major++ )) || true; minor=0; patch=0 ;;
        minor) (( minor++ )) || true; patch=0 ;;
        patch) (( patch++ )) || true ;;
        *)     error_exit "無効なバンプ種別: $type" ;;
    esac

    local new_ver="${major}.${minor}.${patch}"
    [[ -n "$pre" ]] && new_ver="${new_ver}-${pre}"
    echo "$new_ver"
}

do_current() {
    local ver
    ver=$(get_current_version)
    log_info "現在のバージョン"
    echo ""

    local parts
    read -r major minor patch pre_rel <<< "$(parse_version "$ver")"

    printf "  %-20s ${C_BOLD}v%s${C_RESET}\n" "バージョン:" "$ver"
    printf "  %-20s %s\n" "Major:" "$major"
    printf "  %-20s %s\n" "Minor:" "$minor"
    printf "  %-20s %s\n" "Patch:" "$patch"
    [[ -n "$pre_rel" ]] && printf "  %-20s %s\n" "プレリリース:" "$pre_rel"

    # タグの存在確認
    if git tag -l "v${ver}" 2>/dev/null | grep -q "v${ver}"; then
        printf "  %-20s ${C_GREEN}存在します${C_RESET}\n" "Gitタグ:"
    else
        printf "  %-20s ${C_YELLOW}タグなし${C_RESET}\n" "Gitタグ:"
    fi

    # コミット数 (最後のタグから)
    local last_tag commits_since
    last_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
    if [[ -n "$last_tag" ]]; then
        commits_since=$(git rev-list "${last_tag}..HEAD" --count 2>/dev/null || echo 0)
        printf "  %-20s %d コミット\n" "タグ後コミット数:" "$commits_since"
    fi
    echo ""
}

do_bump() {
    local current
    current=$(get_current_version)
    local new_ver
    new_ver=$(bump_version "$current" "$bump_type" "$pre_release")

    log_info "バージョンバンプ: v${current} → v${new_ver}"
    echo ""

    if $dry_run; then
        log_info "[DRY RUN] 実際の変更はスキップします"
        printf "  新バージョン: ${C_BOLD}v%s${C_RESET}\n" "$new_ver"
        return 0
    fi

    echo "$new_ver" > "$VERSION_FILE"
    log_success "VERSIONファイルを更新: $new_ver"

    # CHANGELOG更新
    if [[ -n "$changelog_entry" ]]; then
        update_changelog "$new_ver" "$changelog_entry"
    fi

    # git コミット
    git add "$VERSION_FILE" 2>/dev/null || true
    [[ -f "$CHANGELOG_FILE" ]] && git add "$CHANGELOG_FILE" 2>/dev/null || true
    git commit -m "chore: バージョンを v${new_ver} にバンプ" 2>/dev/null && \
        log_success "コミット完了"

    # タグ作成
    git tag -a "v${new_ver}" -m "Release v${new_ver}" 2>/dev/null && \
        log_success "タグを作成: v${new_ver}"

    if $push_after; then
        git push origin HEAD 2>/dev/null && log_success "プッシュ完了"
        git push origin "v${new_ver}" 2>/dev/null && log_success "タグをプッシュ"
    fi

    echo ""
    printf "  新バージョン: ${C_GREEN}${C_BOLD}v%s${C_RESET}\n" "$new_ver"
    echo ""
}

update_changelog() {
    local ver="$1"
    local entry="$2"
    local date_str
    date_str=$(date '+%Y-%m-%d')

    local new_section="## [${ver}] - ${date_str}

### 変更内容
- ${entry}

"

    if [[ -f "$CHANGELOG_FILE" ]]; then
        local existing
        existing=$(cat "$CHANGELOG_FILE")
        echo "${new_section}${existing}" > "$CHANGELOG_FILE"
    else
        cat > "$CHANGELOG_FILE" <<EOF
# CHANGELOG

このプロジェクトの変更履歴を記録します。
セマンティックバージョニング (https://semver.org) に従います。

${new_section}
EOF
    fi

    log_success "CHANGELOGを更新しました"
}

do_list() {
    log_info "リリース履歴"
    echo ""

    local tags
    tags=$(git tag -l "v*" --sort=-version:refname 2>/dev/null | head -20 || echo "")

    if [[ -z "$tags" ]]; then
        log_warning "タグが見つかりません"
        return 0
    fi

    printf "  ${C_BOLD}%-20s %-25s %s${C_RESET}\n" "バージョン" "日時" "コミット"
    printf "  %s\n" "$(printf '%.0s-' {1..65})"

    while IFS= read -r tag; do
        local tag_date
        tag_date=$(git log -1 --format='%ai' "$tag" 2>/dev/null | cut -d' ' -f1,2 | cut -d'.' -f1 || echo "unknown")
        local commit
        commit=$(git log -1 --format='%h %s' "$tag" 2>/dev/null | cut -c1-35 || echo "")
        printf "  ${C_CYAN}%-20s${C_RESET} %-25s %s\n" "$tag" "$tag_date" "$commit"
    done <<< "$tags"
    echo ""
}

do_diff() {
    local from_tag="$1"
    [[ -z "$from_tag" ]] && error_exit "比較元バージョンを指定してください"

    [[ ! "$from_tag" =~ ^v ]] && from_tag="v${from_tag}"

    log_info "差分: ${from_tag} → HEAD"
    echo ""

    if ! git rev-parse "$from_tag" &>/dev/null; then
        error_exit "タグが見つかりません: $from_tag"
    fi

    local commits
    commits=$(git log "${from_tag}..HEAD" --oneline --no-merges 2>/dev/null || echo "")

    if [[ -z "$commits" ]]; then
        log_info "差分なし (${from_tag}と同じ)"
        return 0
    fi

    local count
    count=$(echo "$commits" | wc -l)
    printf "  ${C_BOLD}%d件のコミット:${C_RESET}\n\n" "$count"

    echo "$commits" | while IFS= read -r line; do
        local hash="${line%% *}"
        local msg="${line#* }"

        local color="$C_RESET"
        if echo "$msg" | grep -qi "^feat\|機能追加"; then
            color="$C_GREEN"
        elif echo "$msg" | grep -qi "^fix\|バグ修正"; then
            color="$C_YELLOW"
        elif echo "$msg" | grep -qi "^break\|後方非互換"; then
            color="$C_RED"
        fi

        printf "  ${C_DIM}%s${C_RESET} ${color}%s${C_RESET}\n" "$hash" "$msg"
    done
    echo ""
}

do_check() {
    log_info "リリース前チェックリスト"
    echo ""

    local -i passed=0 failed=0 warned=0

    check_item() {
        local label="$1"
        local status="$2"
        local detail="${3:-}"
        case "$status" in
            OK)   printf "  ${C_GREEN}✓${C_RESET} %-35s ${C_GREEN}OK${C_RESET} %s\n" "$label" "$detail"; (( passed++ )) || true ;;
            FAIL) printf "  ${C_RED}✗${C_RESET} %-35s ${C_RED}FAIL${C_RESET} %s\n" "$label" "$detail"; (( failed++ )) || true ;;
            WARN) printf "  ${C_YELLOW}⚠${C_RESET} %-35s ${C_YELLOW}WARN${C_RESET} %s\n" "$label" "$detail"; (( warned++ )) || true ;;
        esac
    }

    # Gitの状態
    local dirty_files
    dirty_files=$(git status --porcelain 2>/dev/null | wc -l)
    if (( dirty_files == 0 )); then
        check_item "未コミット変更なし" "OK"
    else
        check_item "未コミット変更なし" "FAIL" "(${dirty_files}ファイル未コミット)"
    fi

    # ブランチ確認
    local current_branch
    current_branch=$(git branch --show-current 2>/dev/null || echo "unknown")
    if [[ "$current_branch" == "main" || "$current_branch" == "master" ]]; then
        check_item "mainブランチ上" "OK" "($current_branch)"
    else
        check_item "mainブランチ上" "WARN" "現在: $current_branch"
    fi

    # VERSIONファイル
    if [[ -f "$VERSION_FILE" ]]; then
        local ver
        ver=$(cat "$VERSION_FILE")
        check_item "VERSIONファイル存在" "OK" "($ver)"
    else
        check_item "VERSIONファイル存在" "WARN" "VERSIONファイルが見つかりません"
    fi

    # CHANGELOG
    if [[ -f "$CHANGELOG_FILE" ]]; then
        check_item "CHANGELOG存在" "OK"
    else
        check_item "CHANGELOG存在" "WARN" "CHANGELOGがありません"
    fi

    # テスト (存在すれば)
    if [[ -f "Makefile" ]] && grep -q "test" Makefile 2>/dev/null; then
        check_item "テスト設定" "OK" "(Makefile)"
    elif [[ -f "package.json" ]] && grep -q '"test"' package.json 2>/dev/null; then
        check_item "テスト設定" "OK" "(npm test)"
    else
        check_item "テスト設定" "WARN" "テスト設定が見つかりません"
    fi

    # リモートとの同期
    local behind
    behind=$(git rev-list "HEAD..origin/$(git branch --show-current 2>/dev/null)" --count 2>/dev/null || echo 0)
    if (( behind == 0 )); then
        check_item "リモートと同期済み" "OK"
    else
        check_item "リモートと同期済み" "WARN" "(${behind}コミット遅れ)"
    fi

    echo ""
    printf "  結果: ${C_GREEN}%d OK${C_RESET} / ${C_YELLOW}%d WARN${C_RESET} / ${C_RED}%d FAIL${C_RESET}\n" \
        "$passed" "$warned" "$failed"

    if (( failed > 0 )); then
        echo ""
        log_error "リリース前に問題を解決してください"
        return 1
    elif (( warned > 0 )); then
        echo ""
        log_warning "警告事項を確認してください"
    else
        echo ""
        log_success "リリース準備完了！"
    fi
    echo ""
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -t|--type)    [[ $# -lt 2 ]] && error_exit "-t には値が必要です"; bump_type="$2"; shift 2 ;;
            -p|--pre-release) [[ $# -lt 2 ]] && error_exit "-p には値が必要です"; pre_release="$2"; shift 2 ;;
            -m|--message) [[ $# -lt 2 ]] && error_exit "-m には値が必要です"; changelog_entry="$2"; shift 2 ;;
            --push)    push_after=true; shift ;;
            --dry-run) dry_run=true; shift ;;
            current|list|check) mode="$1"; shift ;;
            bump)
                mode="bump"
                [[ $# -ge 2 && ! "$2" =~ ^- ]] && { bump_type="$2"; shift; }
                shift
                ;;
            diff)
                mode="diff"
                [[ $# -ge 2 && ! "$2" =~ ^- ]] && { release_tag="$2"; shift; }
                shift
                ;;
            changelog) mode="changelog"; shift ;;
            tag)
                mode="tag"
                [[ $# -ge 2 && ! "$2" =~ ^- ]] && { release_tag="$2"; shift; }
                shift
                ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  shift ;;
        esac
    done
}

main() {
    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        error_exit "Gitリポジトリ内で実行してください"
    fi

    parse_arguments "$@"

    case "$mode" in
        current)   do_current ;;
        bump)      do_bump ;;
        list)      do_list ;;
        diff)      do_diff "$release_tag" ;;
        check)     do_check ;;
        changelog) update_changelog "$(get_current_version)" "$changelog_entry" ;;
        *)         error_exit "不明なコマンド: $mode" ;;
    esac
}

main "$@"
