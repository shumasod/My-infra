#!/bin/bash
set -euo pipefail

#
# レース条件脆弱性検出・防止ツール
# 作成日: 2026-11-05
# バージョン: 1.0
#
# 脆弱性対応: レース条件によるセキュリティ問題の検出・防止
# CVE該当: CWE-362 (Race Condition), CWE-367 (TOCTOU)
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare command_name="scan"

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション]

レース条件脆弱性を検出・防止します。

コマンド:
  scan <パス>          レース条件脆弱性スキャン (デフォルト)
  check-lock <ファイル> ファイルロック状態確認
  test-atomic          アトミック書き込みテスト
  demo                 安全なパターンのデモ

オプション:
  -h, --help           このヘルプを表示
  -v, --version        バージョン情報を表示

脆弱性概要:
  CWE-362: 共有リソースへの競合アクセス
  CWE-367: TOCTOU (確認から使用までの時間的ギャップ)
  対策: アトミック操作・ファイルロックの使用
EOF
}

scan_race_patterns() {
    local file="$1"
    python3 - "$file" <<'PYEOF'
import sys, re

filepath = sys.argv[1]
try:
    with open(filepath, errors='replace') as f:
        lines = f.readlines()
except:
    sys.exit(0)

RED    = "\033[1;31m"
YELLOW = "\033[1;33m"
CYAN   = "\033[1;36m"
RESET  = "\033[0m"
BOLD   = "\033[1m"

# レース条件パターン
patterns = [
    # TOCTOU: 存在確認→使用のギャップ
    (r'\[\s*-[ef]\s+.*\]\s*&&\s*(?:cat|rm|mv|cp|chmod|chown)',
     "TOCTOU: ファイル存在確認→操作のギャップ", "HIGH"),
    (r'if\s+\[\s*-[ef]\s+.*\].*\n.*(?:cat|source|\.|rm|mv)',
     "TOCTOU: 条件チェック後のファイル操作", "HIGH"),

    # 予測可能な一時ファイル
    (r'/tmp/[a-zA-Z0-9_-]+\$\$',
     "PIDベースの一時ファイル (予測可能)", "HIGH"),
    (r'/tmp/[a-zA-Z0-9_-]+\b(?!\$|\()',
     "固定名の一時ファイル", "HIGH"),

    # mktempなしのtmpファイル
    (r'TMPFILE\s*=\s*["\']?/tmp/[^$\(]',
     "mktemp未使用の一時ファイル変数", "HIGH"),

    # ロックなしの共有ファイル操作
    (r'>>\s+(?!/dev/null)[^\s]+\s*$',
     "ロックなしのファイル追記 (競合の可能性)", "LOW"),

    # シグナルハンドラでの非安全操作
    (r'trap\s+.*(?:rm|mv|cp|echo.*>>)',
     "シグナルハンドラでの非アトミック操作", "MEDIUM"),

    # mkdir の競合
    (r'mkdir\s+(?!-p\b).*\$',
     "競合する可能性のあるmkdir", "LOW"),

    # sleep後のファイル確認
    (r'sleep\s+\d+.*\n.*(?:\[\s*-[ef])',
     "sleep後のファイル状態確認 (TOCTOU)", "MEDIUM"),
]

findings = []
for i, line in enumerate(lines, 1):
    s = line.rstrip()
    if s.lstrip().startswith('#'):
        continue
    for pat, desc, sev in patterns:
        if re.search(pat, s):
            findings.append((i, s.strip(), desc, sev))
            break

for lineno, line, desc, sev in findings:
    color = RED if sev == "HIGH" else YELLOW
    print(f"  {color}[{sev}]{RESET} 行{lineno:4d}: {desc}")
    print(f"    {BOLD}{line[:80]}{RESET}")
PYEOF
}

cmd_scan() {
    local path="${1:-.}"
    log_info "レース条件脆弱性スキャン: $path"
    echo ""

    local total=0 issues=0
    while IFS= read -r file; do
        (( total++ ))
        local result
        result=$(scan_race_patterns "$file")
        if [[ -n "$result" ]]; then
            (( issues++ ))
            printf "${C_BOLD}%s${C_RESET}\n" "$file"
            echo "$result"
            echo ""
        fi
    done < <(find "$path" -name "*.sh" -type f 2>/dev/null | sort)

    printf "スキャン完了: %d ファイル中 %d 件にレース条件脆弱性\n" "$total" "$issues"
    [[ "$issues" -gt 0 ]] && log_error "アトミック操作・ファイルロックを実装してください" || log_success "レース条件脆弱性なし"
    echo ""
}

cmd_check_lock() {
    local target_file="${1:-}"
    [[ -z "$target_file" ]] && error_exit "ファイルを指定してください"

    log_info "ファイルロック状態確認: $target_file"
    echo ""

    # flock確認
    if command -v flock &>/dev/null; then
        if flock -n "$target_file" true 2>/dev/null; then
            log_success "ファイルはロックされていません"
        else
            log_warning "ファイルはロック中です"
        fi
    fi

    # lsof確認
    if command -v lsof &>/dev/null; then
        local holders
        holders=$(lsof "$target_file" 2>/dev/null | tail -n +2 || true)
        if [[ -n "$holders" ]]; then
            printf "${C_YELLOW}【ファイル使用中のプロセス】${C_RESET}\n"
            echo "$holders" | while IFS= read -r line; do
                printf "  %s\n" "$line"
            done
        else
            printf "  ${C_GREEN}使用中のプロセスなし${C_RESET}\n"
        fi
    fi
    echo ""
}

cmd_test_atomic() {
    log_info "アトミック書き込みテスト"
    echo ""

    local test_dir
    test_dir=$(mktemp -d)
    trap "rm -rf '$test_dir'" EXIT

    local target_file="$test_dir/target.txt"
    local original_content="オリジナルコンテンツ"
    echo "$original_content" > "$target_file"

    printf "${C_BOLD}【非アトミック書き込み (危険)】${C_RESET}\n"
    printf "  コード: echo 'new content' > %s\n" "$target_file"
    printf "  問題: 書き込み中に他プロセスが読み取ると不完全なデータを得る\n\n"

    printf "${C_BOLD}【アトミック書き込み (安全)】${C_RESET}\n"
    printf "  コード: tmpfile=\$(mktemp); echo 'new' > \"\$tmpfile\"; mv \"\$tmpfile\" target\n"

    # アトミック書き込みデモ
    local tmpfile
    tmpfile=$(mktemp "$test_dir/tmp.XXXXXXXX")
    echo "新しいコンテンツ" > "$tmpfile"
    mv "$tmpfile" "$target_file"
    printf "  結果: "
    if [[ "$(cat "$target_file")" == "新しいコンテンツ" ]]; then
        printf "${C_GREEN}アトミック書き込み成功${C_RESET}\n"
    else
        printf "${C_RED}失敗${C_RESET}\n"
    fi
    echo ""

    printf "${C_BOLD}【flock によるファイルロック (安全)】${C_RESET}\n"
    local lockfile="$test_dir/test.lock"
    printf "  コード: ( flock -x 9; echo 'locked write' >> file ) 9>\"%s\"\n" "$lockfile"
    ( flock -x 9; echo "ロック済み書き込み" >> "$target_file" ) 9>"$lockfile"
    printf "  結果: ${C_GREEN}ロック取得・書き込み・解放 完了${C_RESET}\n"
    echo ""
}

cmd_demo() {
    log_info "安全なレース条件防止パターン"
    echo ""

    cat <<'SAFE_PATTERNS'
  【危険なパターン】
  ───────────────────────────────────────────
  # TOCTOU 脆弱性
  if [ -f "$config_file" ]; then
      source "$config_file"   # ← 確認後にファイルが変わる可能性
  fi

  # 予測可能な一時ファイル
  TMPFILE="/tmp/myapp_$$"   # ← PIDは予測可能
  echo "data" > "$TMPFILE"

  # ロックなしの並行書き込み
  echo "log entry" >> /var/log/myapp.log  # ← 競合の可能性

  【安全なパターン】
  ───────────────────────────────────────────
  # アトミックなファイル操作
  tmpfile=$(mktemp)
  trap 'rm -f "$tmpfile"' EXIT
  generate_config > "$tmpfile"
  mv "$tmpfile" "$config_file"   # ← アトミックな置換

  # セキュアな一時ファイル
  TMPFILE=$(mktemp --suffix=.tmp)   # ← ランダムな名前
  TMPDIR=$(mktemp -d)               # ← ランダムなディレクトリ

  # flock によるロック付き書き込み
  LOGFILE="/var/log/myapp.log"
  LOCKFILE="${LOGFILE}.lock"
  (
      flock -x 200
      echo "$(date): log entry" >> "$LOGFILE"
  ) 200>"$LOCKFILE"

  # with_file_lock (lib/common.sh)
  with_file_lock /var/run/myapp.lock \
      bash -c 'echo "safe write" >> /var/log/myapp.log'

SAFE_PATTERNS
    echo ""
}

parse_arguments() {
    [[ $# -eq 0 ]] && return 0
    case "$1" in
        scan|check-lock|test-atomic|demo)
            command_name="$1"; shift ;;
    esac
    local positional=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  positional+=("$1"); shift ;;
        esac
    done
    POSITIONAL=("${positional[@]+"${positional[@]}"}")
}

declare -a POSITIONAL=()

main() {
    parse_arguments "$@"
    case "$command_name" in
        scan)         cmd_scan       "${POSITIONAL[0]:-.}" ;;
        check-lock)   cmd_check_lock "${POSITIONAL[0]:-}" ;;
        test-atomic)  cmd_test_atomic ;;
        demo)         cmd_demo ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
