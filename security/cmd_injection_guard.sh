#!/bin/bash
set -euo pipefail

#
# コマンドインジェクション対策ツール
# 作成日: 2026-11-02
# バージョン: 1.0
#
# 脆弱性対応: コマンドインジェクション検出・防止
# CVE該当: CWE-78 (OS Command Injection), CWE-88 (Argument Injection)
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare command_name="scan"
declare target_path="."
declare severity_filter="all"

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション]

コマンドインジェクション脆弱性を検出・防止します。

コマンド:
  scan <パス>          スクリプトのコマンドインジェクション検出 (デフォルト)
  validate <入力>      ユーザー入力のサニタイズ検証
  report <パス>        詳細レポート生成
  fix-suggest <ファイル> 修正提案の表示

オプション:
  -h, --help           このヘルプを表示
  -v, --version        バージョン情報を表示
  -s, --severity <レベル> 検出レベル: high|medium|low|all [デフォルト: all]

脆弱性概要:
  CWE-78: eval/exec での未サニタイズ変数展開
  CWE-88: コマンド引数へのインジェクション
  CWE-116: エスケープ処理不足
EOF
}

detect_injection_patterns() {
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

# パターン: (正規表現, 説明, 重大度, 修正案)
patterns = [
    (r'\beval\s+["\']?\$', "eval に未サニタイズ変数を渡している", "CRITICAL",
     'eval を避け、関数や case 文に置き換えてください'),

    (r'\beval\s+`', "eval にコマンド置換を渡している", "CRITICAL",
     'eval `cmd` を $(cmd) に置き換え、結果を検証してください'),

    (r'`\$[A-Za-z_][A-Za-z0-9_]*`', "バックティックに変数を直接渡している", "HIGH",
     '"$var" を使用してダブルクォートで囲んでください'),

    (r'sh\s+-c\s+["\']?\$', "sh -c に未サニタイズ変数", "HIGH",
     '引数を個別に渡すか、printf %q でエスケープしてください'),

    (r'bash\s+-c\s+["\']?\$', "bash -c に未サニタイズ変数", "HIGH",
     '引数を個別に渡すか、printf %q でエスケープしてください'),

    (r'(?:mysql|psql|sqlite3)\s+.*-e\s+["\'].*\$(?![(])', "SQLコマンドへの変数直接埋め込み", "HIGH",
     'プレースホルダーを使用するか、変数を適切にエスケープしてください'),

    (r'(?:curl|wget)\s+.*\$(?![({\{])', "curl/wget URLへの変数直接展開", "MEDIUM",
     'URLをダブルクォートで囲み、変数を検証してください'),

    (r'(?:find|xargs)\s+.*-exec\s+.*\$', "find/xargsのexecに変数", "MEDIUM",
     '変数をシングルクォートで保護するか別の方法を使用してください'),

    (r'(?:rm|mv|cp|chmod)\s+-rf?\s+["\']?\$(?!HOME|PWD|0)', "危険なコマンドに変数を直接渡している", "MEDIUM",
     '変数の値を事前に検証し、想定外のパスを除外してください'),

    (r'IFS=.*read.*\|.*\$', "IFS操作後のパイプラインで変数使用", "LOW",
     'IFS をスコープ内でのみ変更してください'),
]

findings = []
for i, line in enumerate(lines, 1):
    stripped = line.rstrip()
    # コメント行スキップ
    if stripped.lstrip().startswith('#'):
        continue
    for pat, desc, sev, fix in patterns:
        if re.search(pat, stripped):
            findings.append((i, stripped.strip(), desc, sev, fix))

if findings:
    for lineno, line, desc, sev, fix in findings:
        if sev == "CRITICAL":
            color = "\033[1;35m"
        elif sev == "HIGH":
            color = RED
        else:
            color = YELLOW
        print(f"  {color}[{sev}]{RESET} 行{lineno:4d}: {desc}")
        print(f"    コード: {BOLD}{line[:75]}{RESET}")
        print(f"    修正案: {CYAN}{fix}{RESET}")
        print()
PYEOF
}

cmd_scan() {
    local path="${1:-$target_path}"
    log_info "コマンドインジェクション脆弱性スキャン: $path"
    echo ""

    local total=0 vulnerable=0 critical=0 high=0 medium=0

    while IFS= read -r file; do
        (( total++ ))
        local result
        result=$(detect_injection_patterns "$file")
        if [[ -n "$result" ]]; then
            (( vulnerable++ ))
            local crit_count high_count
            crit_count=$(echo "$result" | grep -c "CRITICAL" || true)
            high_count=$(echo "$result" | grep -c "\[HIGH\]" || true)
            (( critical += crit_count ))
            (( high += high_count ))
            printf "${C_BOLD}%s${C_RESET}\n" "$file"
            echo "$result"
            draw_separator 0 "-"
            echo ""
        fi
    done < <(find "$path" -name "*.sh" -type f 2>/dev/null | sort)

    printf "${C_BOLD}【スキャン結果サマリー】${C_RESET}\n\n"
    printf "  %-20s %s\n" "スキャンファイル数:" "$total"
    printf "  %-20s " "脆弱性検出:"
    if [[ "$vulnerable" -gt 0 ]]; then
        printf "${C_RED}%s ファイル${C_RESET}\n" "$vulnerable"
    else
        printf "${C_GREEN}0 ファイル${C_RESET}\n"
    fi
    printf "  %-20s ${C_MAGENTA}%s${C_RESET}\n" "CRITICAL:" "$critical"
    printf "  %-20s ${C_RED}%s${C_RESET}\n"     "HIGH:"     "$high"
    echo ""
}

cmd_validate() {
    local input="${1:-}"
    [[ -z "$input" ]] && error_exit "検証する入力を指定してください"

    log_info "入力値サニタイズ検証"
    echo ""

    python3 - "$input" <<'PYEOF'
import sys, re, shlex

input_str = sys.argv[1]

GREEN  = "\033[1;32m"
RED    = "\033[1;31m"
YELLOW = "\033[1;33m"
RESET  = "\033[0m"

dangerous_chars = [';', '|', '&', '`', '$', '(', ')', '{', '}', '<', '>', '!', '\n', '\r']
dangerous_patterns = [
    (r'[;|&`$]', "シェルメタキャラクター"),
    (r'\.\./', "パストラバーサル"),
    (r'[<>]', "リダイレクト記号"),
    (r'\\x[0-9a-fA-F]{2}', "16進数エスケープ"),
    (r'%[0-9a-fA-F]{2}', "URLエンコード"),
    (r'\$\(|\`', "コマンド置換"),
    (r'\b(cat|rm|chmod|chown|wget|curl|nc|bash|sh|perl|python)\b', "危険なコマンド名"),
]

print(f"  入力値: '{input_str}'")
print(f"  長さ:   {len(input_str)} 文字")
print()

issues = []
for pat, desc in dangerous_patterns:
    if re.search(pat, input_str):
        issues.append(desc)

if issues:
    print(f"  {RED}[危険] 以下の問題が検出されました:{RESET}")
    for issue in issues:
        print(f"    • {issue}")
else:
    print(f"  {GREEN}[安全] 危険なパターンは検出されませんでした{RESET}")

print()
# シェルエスケープ済みの安全な形式
try:
    safe = shlex.quote(input_str)
    print(f"  シェルセーフ形式: {safe}")
except:
    pass

# 英数字のみ許可する場合
alphanumeric = re.sub(r'[^a-zA-Z0-9_\-]', '', input_str)
print(f"  英数字のみ:       '{alphanumeric}'")
PYEOF
    echo ""
}

cmd_report() {
    local path="${1:-$target_path}"
    log_info "コマンドインジェクション詳細レポート: $path"
    echo ""

    local report_out
    report_out=$(mktemp --suffix=.txt)

    {
        echo "# コマンドインジェクション脆弱性レポート"
        echo "スキャン日時: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "対象パス: $path"
        echo ""
        while IFS= read -r file; do
            local result
            result=$(detect_injection_patterns "$file")
            if [[ -n "$result" ]]; then
                echo "## $file"
                echo "$result"
                echo ""
            fi
        done < <(find "$path" -name "*.sh" -type f 2>/dev/null | sort)
    } > "$report_out"

    log_success "レポート生成: $report_out"
    cat "$report_out"
}

parse_arguments() {
    [[ $# -eq 0 ]] && return 0
    case "$1" in
        scan|validate|report|fix-suggest)
            command_name="$1"; shift ;;
    esac

    local positional=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -s|--severity) [[ $# -lt 2 ]] && error_exit "--severity には値が必要です"; severity_filter="$2"; shift 2 ;;
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
        scan)        cmd_scan     "${POSITIONAL[0]:-$target_path}" ;;
        validate)    cmd_validate "${POSITIONAL[0]:-}" ;;
        report)      cmd_report   "${POSITIONAL[0]:-$target_path}" ;;
        fix-suggest) cmd_scan     "${POSITIONAL[0]:-$target_path}" ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
