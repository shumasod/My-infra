#!/bin/bash
set -euo pipefail

#
# 環境変数セキュリティ監査ツール
# 作成日: 2026-11-05
# バージョン: 1.0
#
# 脆弱性対応: 環境変数への機密情報露出の検出
# CVE該当: CWE-526 (Cleartext Storage of Sensitive Information in an Environment Variable), CWE-312
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare command_name="audit"

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション]

環境変数のセキュリティを監査します。

コマンド:
  audit          現在の環境変数の監査 (デフォルト)
  scan <パス>    スクリプト内の環境変数使用検査
  dotenv <ファイル>  .envファイルのセキュリティ確認
  export-safe    安全な環境変数エクスポート一覧
  check-process  実行中プロセスの環境変数確認

オプション:
  -h, --help     このヘルプを表示
  -v, --version  バージョン情報を表示

脆弱性概要:
  CWE-526: 環境変数への平文機密情報保存
  CWE-312: 機密情報の平文保存
  対策: シークレット管理システムの使用
EOF
}

# 機密情報として扱うキーのパターン
readonly SENSITIVE_KEYS="PASSWORD|PASSWD|SECRET|TOKEN|API_KEY|APIKEY|PRIVATE_KEY|ACCESS_KEY|AUTH_KEY|CREDENTIAL|CERTIFICATE|PRIVATE|SIGNING_KEY|ENCRYPTION_KEY|MASTER_KEY"

cmd_audit() {
    log_info "現在の環境変数セキュリティ監査"
    echo ""

    printf "${C_BOLD}【機密情報を含む可能性のある環境変数】${C_RESET}\n\n"

    local found=0
    while IFS='=' read -r key value; do
        if echo "$key" | grep -qiE "$SENSITIVE_KEYS"; then
            (( found++ ))
            local masked_value
            if [[ ${#value} -gt 8 ]]; then
                masked_value="${value:0:4}$(printf '*%.0s' $(seq 1 $((${#value} - 8))))${value: -4}"
            else
                masked_value="$(printf '*%.0s' $(seq 1 ${#value}))"
            fi
            printf "  ${C_RED}[機密]${C_RESET} %-30s = %s\n" "$key" "$masked_value"
        fi
    done < <(env 2>/dev/null | sort)

    echo ""
    if [[ "$found" -gt 0 ]]; then
        log_warning "$found 件の機密環境変数を検出"
        printf "\n  ${C_CYAN}推奨対策:${C_RESET}\n"
        printf "  • HashiCorp Vault, AWS Secrets Manager などのシークレット管理を使用\n"
        printf "  • 環境変数を/proc/[pid]/environ から読み取れないよう制限\n"
        printf "  • コンテナ環境ではシークレットマウントを使用\n"
    else
        log_success "機密環境変数は検出されませんでした"
    fi
    echo ""

    printf "${C_BOLD}【環境変数統計】${C_RESET}\n\n"
    local total_vars
    total_vars=$(env 2>/dev/null | wc -l)
    printf "  総環境変数数: %s\n" "$total_vars"
    printf "  機密可能性:   %s\n\n" "$found"
}

cmd_scan() {
    local path="${1:-.}"
    log_info "スクリプト内の環境変数使用検査: $path"
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
RESET  = "\033[0m"
BOLD   = "\033[1m"

patterns = [
    (r'export\s+(?:PASSWORD|SECRET|TOKEN|API_KEY|PRIVATE_KEY)\s*=\s*\S+',
     "機密情報をexportでセット", "CRITICAL"),
    (r'(?:PASSWORD|SECRET|TOKEN|API_KEY)\s*=\s*["\']?[a-zA-Z0-9!@#$%^&*]{8,}["\']?',
     "機密情報のハードコード", "CRITICAL"),
    (r'printenv\s+(?:PASSWORD|SECRET|TOKEN)',
     "機密環境変数のprintenv", "HIGH"),
    (r'echo\s+.*\$(?:PASSWORD|SECRET|TOKEN|API_KEY)',
     "機密環境変数のechoによる出力", "HIGH"),
    (r'env\s+.*(?:PASSWORD|SECRET|TOKEN)=',
     "envコマンドでの機密情報渡し", "HIGH"),
    (r'\$\{?(?:PASSWORD|PASSWD|SECRET|TOKEN)[^}]*\}?',
     "機密環境変数の参照", "MEDIUM"),
]

findings = []
for i, line in enumerate(lines, 1):
    s = line.rstrip()
    if s.lstrip().startswith('#'):
        continue
    for pat, desc, sev in patterns:
        if re.search(pat, s, re.IGNORECASE):
            # マスキング処理
            masked = re.sub(r'(=\s*)[^\s"\']+', r'\1***', s)
            findings.append((i, masked.strip(), desc, sev))
            break

for lineno, line, desc, sev in findings:
    color = "\033[1;35m" if sev == "CRITICAL" else (RED if sev == "HIGH" else YELLOW)
    print(f"  {color}[{sev}]{RESET} 行{lineno:4d}: {desc}")
    print(f"    {BOLD}{line[:80]}{RESET}")
PYEOF
)
        if [[ -n "$result" ]]; then
            (( issues++ ))
            printf "${C_BOLD}%s${C_RESET}\n" "$file"
            echo "$result"
            echo ""
        fi
    done < <(find "$path" -name "*.sh" -type f 2>/dev/null | sort)

    printf "スキャン完了: %d ファイル中 %d 件に問題を検出\n" "$total" "$issues"
    echo ""
}

cmd_dotenv() {
    local envfile="${1:-.env}"
    log_info ".envファイルのセキュリティ確認: $envfile"
    echo ""

    if [[ ! -f "$envfile" ]]; then
        # .envファイルを探す
        local found_files
        found_files=$(find . -name ".env*" -type f 2>/dev/null | grep -v ".git" | head -10)
        if [[ -z "$found_files" ]]; then
            log_info ".envファイルが見つかりません"
            return
        fi
        while IFS= read -r f; do
            cmd_dotenv "$f"
        done <<< "$found_files"
        return
    fi

    # パーミッション確認
    local perms
    perms=$(stat -c "%a" "$envfile" 2>/dev/null || echo "???")
    printf "  ファイル: %s\n" "$envfile"
    printf "  パーミッション: "
    if [[ "$perms" == "600" || "$perms" == "400" ]]; then
        printf "${C_GREEN}%s (適切)${C_RESET}\n" "$perms"
    elif [[ "${perms: -1}" != "0" ]]; then
        printf "${C_RED}%s (他ユーザーがアクセス可能)${C_RESET}\n" "$perms"
    else
        printf "${C_YELLOW}%s (確認推奨)${C_RESET}\n" "$perms"
    fi

    # .gitignoreに含まれているか確認
    if [[ -f ".gitignore" ]]; then
        if grep -q "\.env" ".gitignore" 2>/dev/null; then
            printf "  .gitignore: ${C_GREEN}除外済み${C_RESET}\n"
        else
            printf "  .gitignore: ${C_RED}未除外 (Gitにコミットされる危険)${C_RESET}\n"
        fi
    fi

    # 内容の機密確認 (値をマスク)
    echo ""
    printf "  ${C_BOLD}機密変数:${C_RESET}\n"
    local secret_count=0
    while IFS='=' read -r key value; do
        [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
        if echo "$key" | grep -qiE "$SENSITIVE_KEYS"; then
            (( secret_count++ ))
            printf "  ${C_YELLOW}• %s = ***MASKED***${C_RESET}\n" "$key"
        fi
    done < "$envfile"

    [[ "$secret_count" -eq 0 ]] && printf "  ${C_DIM}(なし)${C_RESET}\n"
    echo ""
}

cmd_export_safe() {
    log_info "安全な環境変数一覧 (機密除外)"
    echo ""

    while IFS='=' read -r key value; do
        if ! echo "$key" | grep -qiE "$SENSITIVE_KEYS"; then
            printf "  %-30s = %s\n" "$key" "${value:0:50}"
        fi
    done < <(env 2>/dev/null | sort)
    echo ""
}

cmd_check_process() {
    log_info "実行中プロセスの環境変数確認"
    echo ""

    if [[ $EUID -ne 0 ]]; then
        log_warning "root権限がないため、自プロセスのみ確認可能"
    fi

    # 自プロセスの環境変数
    local my_pid=$$
    if [[ -f "/proc/$my_pid/environ" ]]; then
        printf "  PID %s の機密環境変数:\n" "$my_pid"
        tr '\0' '\n' < "/proc/$my_pid/environ" 2>/dev/null | \
        grep -iE "$SENSITIVE_KEYS" | \
        sed 's/=.*/=***MASKED***/' | \
        while IFS= read -r line; do
            printf "  ${C_YELLOW}• %s${C_RESET}\n" "$line"
        done
    fi
    echo ""
}

parse_arguments() {
    [[ $# -eq 0 ]] && return 0
    case "$1" in
        audit|scan|dotenv|export-safe|check-process)
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
        audit)         cmd_audit ;;
        scan)          cmd_scan          "${POSITIONAL[0]:-.}" ;;
        dotenv)        cmd_dotenv        "${POSITIONAL[0]:-.env}" ;;
        export-safe)   cmd_export_safe ;;
        check-process) cmd_check_process ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
