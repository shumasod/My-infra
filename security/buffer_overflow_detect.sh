#!/bin/bash
set -euo pipefail

#
# バッファオーバーフロー脆弱性検出ツール
# 作成日: 2026-11-05
# バージョン: 1.0
#
# 脆弱性対応: バッファオーバーフロー脆弱性パターンの検出
# CVE該当: CWE-120 (Buffer Copy Without Checking Size), CWE-121 (Stack-based Buffer Overflow)
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare command_name="scan"

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション]

バッファオーバーフロー脆弱性パターンを検出します。

コマンド:
  scan <パス>          脆弱性スキャン (デフォルト)
  check-binary <ファイル> バイナリのセキュリティ機能確認
  analyze <ファイル>   詳細なコード解析
  report <パス>        レポート生成

オプション:
  -h, --help           このヘルプを表示
  -v, --version        バージョン情報を表示

脆弱性概要:
  CWE-120: サイズチェックなしのバッファコピー
  CWE-121: スタックベースのバッファオーバーフロー
  対策: 入力長の検証・安全な文字列操作関数の使用
EOF
}

scan_overflow_patterns() {
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

# バッファオーバーフロー関連パターン (シェルスクリプト観点)
patterns = [
    # 無制限のread
    (r'\bread\b(?!\s+-[a-z]*n[0-9])\s+(?!-)',
     "入力長制限なしのread (read -N/-n を推奨)", "HIGH"),

    # 大きなループ・無制限の文字列蓄積
    (r'while\s+.*read.*;\s*do\s*\n.*\+=',
     "ループ内の無制限文字列蓄積", "MEDIUM"),

    # 配列への無制限追加
    (r'(?:arr|array|list|stack|buf)\s*\+=\s*\(',
     "配列への無制限追加 (サイズチェックなし)", "LOW"),

    # ファイル全体読み込み
    (r'(?:content|data|buf|buffer)\s*=\s*\$\(cat\s+',
     "ファイル全体のコマンド置換 (大ファイルでメモリ問題)", "MEDIUM"),

    # 再帰関数
    (r'^\s*\w+\(\)\s*\{.*\n(?:.*\n)*?.*\b\1\b',
     "再帰関数 (スタックオーバーフローの可能性)", "LOW"),

    # 無制限のhead/tail/wc
    (r'wc\s+-c\s+.*\$\{.*\}',
     "サイズチェックなしの変数コンテンツ計算", "LOW"),

    # 入力値をそのまま配列インデックスに
    (r'\$\{[a-zA-Z_]\w*\[["\']?\$(?:1|2|3|@|\*|[A-Za-z_]\w*)',
     "未検証のユーザー入力を配列インデックスに使用", "HIGH"),

    # eval での文字列評価
    (r'\beval\b.*\$(?:1|2|3|@|\*)',
     "eval での引数展開 (大入力でのメモリ問題)", "HIGH"),

    # printf のフォーマット文字列
    (r'printf\s+\$(?:1|2|3|@|\*|[A-Za-z_]\w*)',
     "フォーマット文字列にユーザー入力 (CWE-134)", "CRITICAL"),
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
    log_info "バッファオーバーフロー脆弱性スキャン: $path"
    echo ""

    local total=0 issues=0
    while IFS= read -r file; do
        (( total++ ))
        local result
        result=$(scan_overflow_patterns "$file")
        if [[ -n "$result" ]]; then
            (( issues++ ))
            printf "${C_BOLD}%s${C_RESET}\n" "$file"
            echo "$result"
            echo ""
        fi
    done < <(find "$path" -name "*.sh" -type f 2>/dev/null | sort)

    printf "スキャン完了: %d ファイル中 %d 件に問題\n" "$total" "$issues"
    [[ "$issues" -gt 0 ]] && log_error "入力長の検証を実装してください" || log_success "問題なし"
    echo ""
}

cmd_check_binary() {
    local binary="${1:-}"
    [[ -z "$binary" ]] && error_exit "バイナリファイルを指定してください"
    [[ ! -f "$binary" ]] && error_exit "ファイルが見つかりません: $binary"

    log_info "バイナリセキュリティ機能確認: $binary"
    echo ""

    # checksec的な確認
    python3 - "$binary" <<'PYEOF'
import sys, subprocess, os

binary = sys.argv[1]

GREEN  = "\033[1;32m"
RED    = "\033[1;31m"
YELLOW = "\033[1;33m"
RESET  = "\033[0m"

def check(label, cond, good_msg="有効", bad_msg="無効"):
    color = GREEN if cond else RED
    status = good_msg if cond else bad_msg
    print(f"  {label:<30} {color}[{status}]{RESET}")

# ELFバイナリ確認
try:
    with open(binary, 'rb') as f:
        magic = f.read(4)
    is_elf = magic == b'\x7fELF'
except:
    is_elf = False

if not is_elf:
    print(f"  ELFバイナリではありません")
    sys.exit(0)

# readelf/objdump で確認
try:
    # RELRO
    result = subprocess.run(['readelf', '-l', binary], capture_output=True, text=True)
    has_relro = 'GNU_RELRO' in result.stdout
    check("RELRO", has_relro)

    # Stack Canary
    result = subprocess.run(['readelf', '-s', binary], capture_output=True, text=True)
    has_canary = '__stack_chk_fail' in result.stdout
    check("Stack Canary", has_canary)

    # NX bit
    result = subprocess.run(['readelf', '-l', binary], capture_output=True, text=True)
    has_nx = 'GNU_STACK' in result.stdout and 'RWE' not in result.stdout
    check("NX bit (DEP)", has_nx)

    # PIE
    result = subprocess.run(['readelf', '-h', binary], capture_output=True, text=True)
    has_pie = 'DYN (Shared object file)' in result.stdout or 'DYN (Position-Independent Executable)' in result.stdout
    check("PIE (ASLR対応)", has_pie)

    # Fortify
    result = subprocess.run(['readelf', '-s', binary], capture_output=True, text=True)
    has_fortify = '__memcpy_chk' in result.stdout or '__strcpy_chk' in result.stdout
    check("Fortify Source", has_fortify)

except FileNotFoundError:
    print("  readelf が見つかりません (binutils をインストールしてください)")
except Exception as e:
    print(f"  確認失敗: {e}")
PYEOF
    echo ""
}

cmd_analyze() {
    local file="${1:-}"
    [[ -z "$file" ]] && error_exit "ファイルを指定してください"

    log_info "詳細コード解析: $file"
    echo ""

    # read コマンドの入力長チェック
    printf "${C_BOLD}【read コマンドの入力長制限確認】${C_RESET}\n\n"
    local read_count unlimited_read
    read_count=$(grep -c "\bread\b" "$file" 2>/dev/null || echo 0)
    unlimited_read=$(grep -n "\bread\b" "$file" 2>/dev/null | grep -v "\-[a-z]*n[0-9]\|-N[0-9]" | head -5 || true)

    printf "  readコマンド使用数: %s\n" "$read_count"
    if [[ -n "$unlimited_read" ]]; then
        printf "  ${C_YELLOW}入力長未制限の read:\n${C_RESET}"
        echo "$unlimited_read" | while IFS= read -r line; do
            printf "    %s\n" "$line"
        done
        printf "\n  ${C_CYAN}修正例: read -r -N 1024 input${C_RESET}\n"
    else
        printf "  ${C_GREEN}全readに長さ制限あり${C_RESET}\n"
    fi
    echo ""

    # printf フォーマット文字列確認
    printf "${C_BOLD}【printf フォーマット文字列確認】${C_RESET}\n\n"
    local unsafe_printf
    unsafe_printf=$(grep -n 'printf\s\+\$' "$file" 2>/dev/null | head -5 || true)
    if [[ -n "$unsafe_printf" ]]; then
        printf "  ${C_RED}[危険] フォーマット文字列にユーザー入力:\n${C_RESET}"
        echo "$unsafe_printf" | while IFS= read -r line; do
            printf "  %s\n" "$line"
        done
        printf "  ${C_CYAN}修正例: printf '%%s' \"\$var\" (フォーマット固定)${C_RESET}\n"
    else
        printf "  ${C_GREEN}安全なprintfパターン${C_RESET}\n"
    fi
    echo ""
}

parse_arguments() {
    [[ $# -eq 0 ]] && return 0
    case "$1" in
        scan|check-binary|analyze|report)
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
        scan)         cmd_scan          "${POSITIONAL[0]:-.}" ;;
        check-binary) cmd_check_binary  "${POSITIONAL[0]:-}" ;;
        analyze)      cmd_analyze       "${POSITIONAL[0]:-}" ;;
        report)       cmd_scan          "${POSITIONAL[0]:-.}" ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
