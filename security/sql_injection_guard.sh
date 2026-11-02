#!/bin/bash
set -euo pipefail

#
# SQLインジェクション対策ツール
# 作成日: 2026-11-02
# バージョン: 1.0
#
# 脆弱性対応: SQLインジェクション攻撃の検出・防止
# CVE該当: CWE-89 (SQL Injection), CWE-564 (SQL Injection: Hibernate)
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare command_name="scan"
declare target_path="."

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション]

SQLインジェクション脆弱性を検出・防止します。

コマンド:
  scan <パス>          SQLインジェクション脆弱性スキャン (デフォルト)
  validate <入力>      SQL入力値の検証・サニタイズ
  test-db <接続情報>   DBへのインジェクションテスト
  report <パス>        詳細レポート生成

オプション:
  -h, --help           このヘルプを表示
  -v, --version        バージョン情報を表示

脆弱性概要:
  CWE-89: ユーザー入力を含む動的SQL構築
  CWE-564: ORMを経由したSQLインジェクション
  対策: プリペアドステートメント・パラメータ化クエリの使用
EOF
}

scan_sql_patterns() {
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

patterns = [
    # シェルスクリプトのSQL
    (r'(?:mysql|psql|sqlite3)\s+.*-e\s+["\'].*\$(?![({])',
     "mysql/psql -e に変数を直接展開", "CRITICAL"),

    (r'(?:mysql|psql|sqlite3)\s+.*-e\s+["\'].*["\'].*\+.*\$',
     "SQL文字列連結に変数使用", "CRITICAL"),

    (r'SQL\s*=\s*["\']SELECT.*\$(?![({])',
     "SELECT文に変数を直接埋め込み", "HIGH"),

    (r'SQL\s*=\s*["\'](?:INSERT|UPDATE|DELETE).*\$(?![({])',
     "DML文に変数を直接埋め込み", "HIGH"),

    (r'(?:mysql|psql|sqlite3)\s+.*<<<\s+.*\$',
     "ヒアストリングでSQL実行+変数", "HIGH"),

    (r'(?i)WHERE\s+\w+\s*=\s*["\']?\$(?![({])',
     "WHERE句に変数を直接使用", "HIGH"),

    (r'(?i)LIKE\s+["\']%?\$(?![({])',
     "LIKE句に変数を直接使用", "MEDIUM"),

    (r'(?i)ORDER\s+BY\s+\$(?![({])',
     "ORDER BY句に変数を直接使用", "HIGH"),

    (r'(?i)LIMIT\s+\$(?![({])',
     "LIMIT句に変数を直接使用", "MEDIUM"),

    (r'(?i)(?:CREATE|DROP|ALTER)\s+(?:TABLE|DATABASE|INDEX)\s+.*\$',
     "DDL文に変数を使用", "HIGH"),
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
    if sev in ("CRITICAL", "HIGH"):
        print(f"    {CYAN}修正案: プリペアドステートメントまたはエスケープ処理を使用してください{RESET}")
    print()
PYEOF
}

cmd_scan() {
    local path="${1:-$target_path}"
    log_info "SQLインジェクション脆弱性スキャン: $path"
    echo ""

    local total=0 issues=0

    while IFS= read -r file; do
        (( total++ ))
        local result
        result=$(scan_sql_patterns "$file")
        if [[ -n "$result" ]]; then
            (( issues++ ))
            printf "${C_BOLD}%s${C_RESET}\n" "$file"
            echo "$result"
        fi
    done < <(find "$path" \( -name "*.sh" -o -name "*.sql" -o -name "*.py" \) -type f 2>/dev/null | sort)

    echo "---"
    printf "スキャン完了: %d ファイル中 %d 件にSQLインジェクション脆弱性を検出\n" "$total" "$issues"
    if [[ "$issues" -gt 0 ]]; then
        log_error "SQLインジェクション脆弱性を修正してください"
    else
        log_success "SQLインジェクション脆弱性なし"
    fi
    echo ""
}

cmd_validate() {
    local input="${1:-}"
    [[ -z "$input" ]] && error_exit "検証する入力を指定してください"

    log_info "SQL入力値検証: $input"
    echo ""

    python3 - "$input" <<'PYEOF'
import sys, re

input_str = sys.argv[1]

GREEN  = "\033[1;32m"
RED    = "\033[1;31m"
YELLOW = "\033[1;33m"
CYAN   = "\033[1;36m"
RESET  = "\033[0m"

# SQLインジェクションパターン
sql_patterns = [
    (r"'.*(?:OR|AND|UNION|SELECT|INSERT|UPDATE|DELETE|DROP|CREATE|ALTER|EXEC|EXECUTE)",
     "SQLキーワードと引用符の組み合わせ"),
    (r"--\s*$", "SQLコメント (--)"),
    (r";\s*(?:DROP|DELETE|UPDATE|INSERT|SELECT)", "セミコロン後のSQL文"),
    (r"(?:1\s*=\s*1|1\s*'\s*=\s*'1)", "常に真の条件"),
    (r"UNION\s+(?:ALL\s+)?SELECT", "UNION SELECT"),
    (r"(?:exec|execute)\s+(?:xp_|sp_)", "ストアドプロシージャ実行"),
    (r"(?:SLEEP|BENCHMARK|WAITFOR)\s*\(", "時間ベースSQLi"),
    (r"LOAD_FILE\s*\(|INTO\s+(?:OUT|DUMP)FILE", "ファイル読み書きSQLi"),
    (r"0x[0-9a-fA-F]+", "16進数エンコード"),
    (r"CHAR\s*\(\s*\d+", "CHAR()関数によるエンコード"),
]

print(f"  入力値: '{input_str}'")
print()

issues = []
for pat, desc in sql_patterns:
    if re.search(pat, input_str, re.IGNORECASE):
        issues.append(desc)

if issues:
    print(f"  {RED}[危険] SQLインジェクションパターンを検出:{RESET}")
    for issue in issues:
        print(f"    • {issue}")
else:
    print(f"  {GREEN}[安全] SQLインジェクションパターン未検出{RESET}")

# エスケープ処理例
escaped = input_str.replace("'", "''").replace("\\", "\\\\")
print()
print(f"  {CYAN}エスケープ済み形式: '{escaped}'{RESET}")
print(f"  推奨: プリペアドステートメントを使用してください")
PYEOF
    echo ""
}

cmd_report() {
    local path="${1:-$target_path}"
    log_info "SQLインジェクション詳細レポート: $path"
    echo ""

    printf "${C_BOLD}【安全なSQL構築パターン】${C_RESET}\n\n"
    cat <<'SECURE_EXAMPLES'
  # 【危険】変数の直接埋め込み
  mysql -e "SELECT * FROM users WHERE name = '$user_input'"

  # 【安全】プリペアドステートメント (MySQL)
  mysql -e "PREPARE stmt FROM 'SELECT * FROM users WHERE name = ?';
            SET @name = '$user_input';
            EXECUTE stmt USING @name;"

  # 【安全】エスケープ処理
  escaped_input=$(echo "$user_input" | sed "s/'/''/g")
  mysql -e "SELECT * FROM users WHERE name = '${escaped_input}'"

  # 【安全】入力値検証 (英数字のみ許可)
  if [[ ! "$user_input" =~ ^[a-zA-Z0-9_]+$ ]]; then
    error_exit "無効な入力値です"
  fi

SECURE_EXAMPLES

    cmd_scan "$path"
}

parse_arguments() {
    [[ $# -eq 0 ]] && return 0
    case "$1" in
        scan|validate|test-db|report)
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
        scan)     cmd_scan     "${POSITIONAL[0]:-$target_path}" ;;
        validate) cmd_validate "${POSITIONAL[0]:-}" ;;
        test-db)  log_info "DBテスト機能は本番環境での使用に注意してください" ;;
        report)   cmd_report   "${POSITIONAL[0]:-$target_path}" ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
