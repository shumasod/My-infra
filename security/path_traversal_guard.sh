#!/bin/bash
set -euo pipefail

#
# パストラバーサル対策ツール
# 作成日: 2026-11-02
# バージョン: 1.0
#
# 脆弱性対応: パストラバーサル攻撃の検出・防止
# CVE該当: CWE-22 (Path Traversal), CWE-23 (Relative Path Traversal)
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare command_name="scan"
declare base_dir=""

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション]

パストラバーサル脆弱性を検出・防止します。

コマンド:
  scan <パス>          スクリプトのパストラバーサル検出 (デフォルト)
  validate <パス>      パスの安全性検証
  normalize <パス>     パスの正規化と検証
  audit <ベースDir>    ディレクトリ外アクセス監査

オプション:
  -h, --help           このヘルプを表示
  -v, --version        バージョン情報を表示
  -b, --base <パス>    ベースディレクトリ (validate コマンド用)

脆弱性概要:
  CWE-22: ../による親ディレクトリへのアクセス
  CWE-23: 相対パスによる意図しないファイルアクセス
  CWE-36: 絶対パストラバーサル
EOF
}

scan_file_for_traversal() {
    local file="$1"
    python3 - "$file" <<'PYEOF'
import sys, re

filepath = sys.argv[1]
try:
    with open(filepath) as f:
        lines = f.readlines()
except:
    sys.exit(0)

RED    = "\033[1;31m"
YELLOW = "\033[1;33m"
CYAN   = "\033[1;36m"
RESET  = "\033[0m"
BOLD   = "\033[1m"

patterns = [
    (r'\.\./\.\.',                        "二重パストラバーサル (../../)", "CRITICAL"),
    (r'\$[A-Za-z_]\w*\s*/\.\.',           "変数+パストラバーサル",         "HIGH"),
    (r'cat\s+.*\$.*(?:file|path|name|dir)', "ユーザー入力ファイルのcat",   "HIGH"),
    (r'(?:source|\.)\s+\$',               "変数でのsource読み込み",        "HIGH"),
    (r'(?:include|require)\s+.*\$',       "変数でのインクルード",           "HIGH"),
    (r'readlink\s+.*\$(?!PWD)',            "readlinkへの変数パス",          "MEDIUM"),
    (r'(?:rm|mv|cp)\s+.*\$.*(?:file|path|name)', "危険なファイル操作+変数", "MEDIUM"),
    (r'find\s+\$[A-Za-z]',               "findのパスに変数使用",           "MEDIUM"),
    (r'\.\./',                             "相対パストラバーサル (../)",     "LOW"),
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
    color = "\033[1;35m" if sev == "CRITICAL" else (RED if sev == "HIGH" else YELLOW)
    print(f"  {color}[{sev}]{RESET} 行{lineno:4d}: {desc}")
    print(f"    {BOLD}{line[:80]}{RESET}")
PYEOF
}

cmd_scan() {
    local path="${1:-.}"
    log_info "パストラバーサル脆弱性スキャン: $path"
    echo ""

    local total=0 issues=0
    while IFS= read -r file; do
        (( total++ ))
        local result
        result=$(scan_file_for_traversal "$file")
        if [[ -n "$result" ]]; then
            (( issues++ ))
            printf "${C_BOLD}${C_YELLOW}%s${C_RESET}\n" "$file"
            echo "$result"
            echo ""
        fi
    done < <(find "$path" -name "*.sh" -type f 2>/dev/null | sort)

    printf "スキャン完了: %d ファイル中 %d ファイルに問題を検出\n" "$total" "$issues"
    echo ""
}

cmd_validate() {
    local input_path="${1:-}"
    [[ -z "$input_path" ]] && error_exit "検証するパスを指定してください"

    log_info "パス安全性検証: $input_path"
    echo ""

    python3 - "$input_path" "${base_dir:-/}" <<'PYEOF'
import sys, os, re

input_path = sys.argv[1]
base = sys.argv[2]

GREEN  = "\033[1;32m"
RED    = "\033[1;31m"
YELLOW = "\033[1;33m"
RESET  = "\033[0m"

issues = []

# ../チェック
if '..' in input_path.split(os.sep):
    issues.append(("CRITICAL", "パストラバーサルシーケンス (..) を含む"))

# Nullバイト
if '\x00' in input_path:
    issues.append(("CRITICAL", "Nullバイトを含む"))

# URLエンコード
if re.search(r'%2[Ee]', input_path):
    issues.append(("HIGH", "URLエンコードされた . (%2e) を含む"))

# 正規化後のチェック
try:
    real = os.path.realpath(input_path)
    norm = os.path.normpath(input_path)
    if real != norm and base != '/':
        if not real.startswith(base):
            issues.append(("HIGH", f"正規化後にベースディレクトリ外: {real}"))
except:
    issues.append(("MEDIUM", "パスの正規化に失敗"))

print(f"  入力パス:     {input_path}")
try:
    print(f"  正規化パス:   {os.path.normpath(input_path)}")
    print(f"  絶対パス:     {os.path.realpath(input_path)}")
except:
    pass
print()

if issues:
    print(f"  {RED}[危険] 以下の問題が検出されました:{RESET}")
    for sev, msg in issues:
        color = "\033[1;35m" if sev == "CRITICAL" else RED
        print(f"    {color}[{sev}]{RESET} {msg}")
else:
    print(f"  {GREEN}[安全] パストラバーサルは検出されませんでした{RESET}")
PYEOF
    echo ""
}

cmd_normalize() {
    local input_path="${1:-}"
    [[ -z "$input_path" ]] && error_exit "正規化するパスを指定してください"

    log_info "パス正規化: $input_path"
    echo ""

    local normalized
    normalized=$(realpath -m "$input_path" 2>/dev/null || python3 -c "import os,sys; print(os.path.normpath(sys.argv[1]))" "$input_path")

    printf "  入力:    %s\n" "$input_path"
    printf "  正規化:  %s\n" "$normalized"

    if [[ -n "$base_dir" ]]; then
        if [[ "$normalized" == "$base_dir"* ]]; then
            log_success "ベースディレクトリ内: $base_dir"
        else
            log_error "ベースディレクトリ外に解決されます: $base_dir"
        fi
    fi
    echo ""
}

cmd_audit() {
    local audit_base="${1:-$(pwd)}"
    log_info "ディレクトリ外アクセス監査: $audit_base"
    echo ""

    local outside_links=0
    while IFS= read -r link; do
        local target
        target=$(readlink -f "$link" 2>/dev/null || readlink "$link" 2>/dev/null || echo "")
        if [[ -n "$target" && "$target" != "$audit_base"* ]]; then
            printf "  ${C_RED}[外部リンク]${C_RESET} %s -> %s\n" "$link" "$target"
            (( outside_links++ ))
        fi
    done < <(find "$audit_base" -type l 2>/dev/null)

    if [[ "$outside_links" -eq 0 ]]; then
        log_success "ディレクトリ外への参照なし"
    else
        log_warning "$outside_links 件の外部参照を検出"
    fi
    echo ""
}

parse_arguments() {
    [[ $# -eq 0 ]] && return 0
    case "$1" in
        scan|validate|normalize|audit)
            command_name="$1"; shift ;;
    esac

    local positional=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -b|--base)    [[ $# -lt 2 ]] && error_exit "--base には値が必要です"; base_dir="$2"; shift 2 ;;
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
        scan)      cmd_scan      "${POSITIONAL[0]:-.}" ;;
        validate)  cmd_validate  "${POSITIONAL[0]:-}" ;;
        normalize) cmd_normalize "${POSITIONAL[0]:-}" ;;
        audit)     cmd_audit     "${POSITIONAL[0]:-$(pwd)}" ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
