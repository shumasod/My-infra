#!/bin/bash
set -euo pipefail

#
# エラー情報漏洩チェックツール
# 作成日: 2026-11-05
# バージョン: 1.0
#
# 脆弱性対応: エラーメッセージによる情報漏洩の検出と防止
# CWE-209: Generation of Error Message Containing Sensitive Information
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"
declare command_name="scan"

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション]

エラー情報漏洩の脆弱性を検出します。

コマンド:
  scan <パス>    エラー情報漏洩スキャン (デフォルト)
  report         レポート生成
  fix-guide      修正ガイドラインの表示

オプション:
  -h, --help     このヘルプを表示
  -v, --version  バージョン情報を表示

脆弱性概要:
  CWE-209: エラーメッセージによる機密情報漏洩
  CWE-536: Servlet Runtime Error Message Containing Sensitive Information
EOF
}

cmd_scan() {
    local path="${1:-.}"
    log_info "エラー情報漏洩スキャン: $path"
    echo ""

    local total=0 issues=0
    while IFS= read -r file; do
        (( total++ ))
        local result
        result=$(python3 - "$file" <<'PYEOF'
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
    (r'echo.*\$\{?MYSQL_PASSWORD\}?', "パスワードをエラー出力に含めている", "CRITICAL"),
    (r'echo.*\$\{?DB_PASS(?:WORD)?\}?', "DBパスワードをエラー出力に含めている", "CRITICAL"),
    (r'echo.*\$\{?API_(?:KEY|SECRET|TOKEN)\}?', "APIキーをエラー出力に含めている", "HIGH"),
    (r'echo.*\$\{?AWS_SECRET', "AWSシークレットをエラー出力に含めている", "HIGH"),
    (r'traceback\.print_exc\(\)', "Pythonスタックトレースを直接出力 (内部情報漏洩)", "MEDIUM"),
    (r'print\(.*exception.*\)', "例外オブジェクトを直接出力", "MEDIUM"),
    (r'echo.*\$\?.*error', "終了コードを含むエラーメッセージ", "LOW"),
    (r'echo.*\$\(.*\).*fail', "コマンド出力をそのままエラーメッセージに使用", "MEDIUM"),
]

findings = []
for i, line in enumerate(lines, 1):
    s = line.rstrip()
    if s.lstrip().startswith('#'):
        continue
    for pat, desc, sev in patterns:
        if re.search(pat, s, re.IGNORECASE):
            findings.append((i, s.strip(), desc, sev))
            break

for lineno, line, desc, sev in findings:
    color = RED if sev in ("CRITICAL","HIGH") else YELLOW
    print(f"  {color}[{sev}]{RESET} 行{lineno:4d}: {desc}")
    print(f"    {BOLD}{line[:80]}{RESET}")
    print(f"    {CYAN}→ 汎用エラーメッセージを使用し、詳細はログに記録してください{RESET}")
PYEOF
)
        if [[ -n "$result" ]]; then
            (( issues++ ))
            printf "${C_BOLD}%s${C_RESET}\n" "$file"
            echo "$result"
            echo ""
        fi
    done < <(find "$path" \( -name "*.sh" -o -name "*.py" \) -type f 2>/dev/null | sort)

    printf "スキャン完了: %d ファイル中 %d 件に情報漏洩リスク\n" "$total" "$issues"
    [[ "$issues" -gt 0 ]] && log_error "エラーメッセージから機密情報を除去してください" || log_success "脆弱性なし"
    echo ""
}

cmd_fix_guide() {
    log_info "エラー情報漏洩修正ガイドライン"
    echo ""
    cat <<'GUIDE'
  【エラー情報漏洩の修正】

  危険: 機密情報をエラーメッセージに含める
    echo "DB接続エラー: host=$DB_HOST user=$DB_USER pass=$DB_PASS" >&2

  安全: 汎用メッセージ + ログへの詳細記録
    logger -t myapp "DB接続エラー: host=$DB_HOST user=$DB_USER"  # パスワード除外
    echo "データベース接続に失敗しました。管理者にお問い合わせください。" >&2

  危険: Pythonスタックトレースをそのまま表示
    except Exception as e:
        print(f"エラー: {e}")

  安全: 汎用メッセージ + ログ記録
    except Exception as e:
        logging.error(f"処理エラー: {e}", exc_info=True)
        print("処理中にエラーが発生しました。")

GUIDE
    echo ""
}

cmd_report() {
    log_info "エラー情報漏洩レポート"
    echo ""
    cmd_scan "."
}

parse_arguments() {
    [[ $# -eq 0 ]] && return 0
    case "$1" in
        scan|report|fix-guide)
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
        scan)      cmd_scan    "${POSITIONAL[0]:-.}" ;;
        report)    cmd_report ;;
        fix-guide) cmd_fix_guide ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
