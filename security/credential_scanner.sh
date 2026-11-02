#!/bin/bash
set -euo pipefail

#
# 認証情報漏洩スキャナー
# 作成日: 2026-11-02
# バージョン: 1.0
#
# 脆弱性対応: 認証情報・シークレットのハードコード検出
# CVE該当: CWE-312 (Cleartext Storage), CWE-798 (Hard-coded Credentials)
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare command_name="scan"
declare target_path="."
declare exclude_pattern=""
declare show_context=0

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション]

コード内の認証情報漏洩を検出します。

コマンド:
  scan <パス>          認証情報スキャン (デフォルト)
  git-history          Gitコミット履歴のスキャン
  entropy <ファイル>   高エントロピー文字列の検出
  report <パス>        詳細レポート生成

オプション:
  -h, --help           このヘルプを表示
  -v, --version        バージョン情報を表示
  -e, --exclude <パターン> 除外パターン
  -c, --context        マッチ周辺コンテキスト表示

脆弱性概要:
  CWE-312: 平文での認証情報保存
  CWE-798: ハードコードされた認証情報
  CWE-321: ハードコードされた暗号鍵
EOF
}

scan_credentials() {
    local file="$1"
    python3 - "$file" <<'PYEOF'
import sys, re, math, base64

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

# 認証情報パターン
cred_patterns = [
    # パスワード
    (r'(?i)password\s*[=:]\s*["\']?[^\s"\'$#{}()]{8,}', "パスワード文字列", "CRITICAL"),
    (r'(?i)passwd\s*[=:]\s*["\']?[^\s"\'$#{}()]{4,}',   "passwdフィールド", "CRITICAL"),
    (r'(?i)pass\s*[=:]\s*["\']?[a-zA-Z0-9!@#$%^&*]{8,}', "pass変数",        "HIGH"),

    # APIキー・トークン
    (r'(?i)api[_-]?key\s*[=:]\s*["\']?[a-zA-Z0-9/_\-]{16,}', "APIキー",     "CRITICAL"),
    (r'(?i)api[_-]?secret\s*[=:]\s*["\']?[a-zA-Z0-9/_\-]{16,}', "APIシークレット", "CRITICAL"),
    (r'(?i)access[_-]?token\s*[=:]\s*["\']?[a-zA-Z0-9._\-]{16,}', "アクセストークン", "CRITICAL"),
    (r'(?i)secret[_-]?key\s*[=:]\s*["\']?[a-zA-Z0-9/_\-]{16,}', "シークレットキー", "CRITICAL"),
    (r'(?i)auth[_-]?token\s*[=:]\s*["\']?[a-zA-Z0-9._\-]{16,}', "認証トークン", "HIGH"),

    # AWS
    (r'AKIA[0-9A-Z]{16}', "AWS アクセスキーID", "CRITICAL"),
    (r'(?i)aws[_-]secret\s*[=:]\s*["\']?[a-zA-Z0-9/+]{40}', "AWS シークレット", "CRITICAL"),

    # 秘密鍵
    (r'-----BEGIN (?:RSA |EC |DSA )?PRIVATE KEY', "秘密鍵", "CRITICAL"),
    (r'-----BEGIN CERTIFICATE', "証明書", "MEDIUM"),

    # データベース接続文字列
    (r'(?i)(?:mysql|postgres|mongodb)://[^:]+:[^@]+@', "DBパスワード含むURL", "CRITICAL"),
    (r'(?i)(?:db|database)[_-]?password\s*[=:]\s*["\']?[^\s"\'$]{4,}', "DB パスワード", "HIGH"),

    # その他のシークレット
    (r'(?i)private[_-]?key\s*[=:]\s*["\']?[a-zA-Z0-9/_\-+]{20,}', "プライベートキー", "HIGH"),
    (r'(?i)client[_-]?secret\s*[=:]\s*["\']?[a-zA-Z0-9/_\-]{16,}', "クライアントシークレット", "HIGH"),
    (r'(?i)webhook[_-]?(?:url|secret)\s*[=:]\s*https?://', "Webhook URL", "MEDIUM"),
    (r'ghp_[a-zA-Z0-9]{36}', "GitHub Personal Access Token", "CRITICAL"),
    (r'sk-[a-zA-Z0-9]{48}', "OpenAI API Key", "CRITICAL"),
]

# 除外パターン（FP削減）
exclude = [
    r'#.*',           # コメント
    r'example',       # サンプル
    r'placeholder',   # プレースホルダー
    r'\$\{',          # 変数参照
    r'\$\(',          # コマンド置換
    r'<your',         # テンプレート
    r'xxx+',          # マスク
    r'\*+',           # マスク
    r'your[_-]',      # テンプレート
    r'changeme',      # デフォルト
]

findings = []
for i, line in enumerate(lines, 1):
    s = line.rstrip()
    if s.lstrip().startswith('#'):
        continue
    # 除外チェック
    if any(re.search(ex, s, re.IGNORECASE) for ex in exclude):
        continue

    for pat, desc, sev in cred_patterns:
        m = re.search(pat, s)
        if m:
            matched = m.group(0)
            # マスキング
            if len(matched) > 20:
                display = matched[:8] + '*' * (len(matched) - 12) + matched[-4:]
            else:
                display = matched[:4] + '*' * max(0, len(matched)-4)
            findings.append((i, s.strip(), desc, sev, display))
            break

for lineno, line, desc, sev, masked in findings:
    color = "\033[1;35m" if sev == "CRITICAL" else ("\033[1;31m" if sev == "HIGH" else "\033[1;33m")
    print(f"  {color}[{sev}]{RESET} 行{lineno:4d}: {desc}")
    print(f"    検出値: {masked}")
PYEOF
}

cmd_scan() {
    local path="${1:-$target_path}"
    log_info "認証情報漏洩スキャン: $path"
    echo ""

    local total=0 issues=0 critical=0

    while IFS= read -r file; do
        [[ -n "$exclude_pattern" && "$file" == *"$exclude_pattern"* ]] && continue
        (( total++ ))
        local result
        result=$(scan_credentials "$file")
        if [[ -n "$result" ]]; then
            (( issues++ ))
            local crit_count
            crit_count=$(echo "$result" | grep -c "CRITICAL" || true)
            (( critical += crit_count ))
            printf "${C_BOLD}%s${C_RESET}\n" "$file"
            echo "$result"
            echo ""
        fi
    done < <(find "$path" \( -name "*.sh" -o -name "*.env" -o -name "*.conf" -o -name "*.yaml" -o -name "*.yml" -o -name "*.json" -o -name "*.py" \) -type f 2>/dev/null | sort)

    echo "---"
    printf "スキャン完了: %d ファイル、%d 件の認証情報漏洩を検出 (CRITICAL: %d 件)\n" \
        "$total" "$issues" "$critical"
    if [[ "$critical" -gt 0 ]]; then
        log_error "CRITICAL な認証情報漏洩が $critical 件あります。即座に対応してください"
    elif [[ "$issues" -gt 0 ]]; then
        log_warning "認証情報漏洩の可能性があります"
    else
        log_success "認証情報漏洩なし"
    fi
    echo ""
}

cmd_git_history() {
    log_info "Gitコミット履歴の認証情報スキャン"
    echo ""

    if ! git rev-parse --git-dir &>/dev/null 2>&1; then
        error_exit "Gitリポジトリではありません"
    fi

    local commits
    commits=$(git log --oneline | wc -l)
    printf "  スキャン対象コミット数: %s\n\n" "$commits"

    git log --diff-filter=A --name-only --format="%H %s" | head -100 | \
    while IFS= read -r line; do
        if echo "$line" | grep -qE "^[0-9a-f]{40}"; then
            local hash msg
            hash=$(echo "$line" | cut -d' ' -f1)
            msg=$(echo "$line" | cut -d' ' -f2-)
            local diff_result
            diff_result=$(git show "$hash" 2>/dev/null | grep "^+" | grep -iE "(password|secret|key|token|credential)" | grep -v "^+++" || true)
            if [[ -n "$diff_result" ]]; then
                printf "  ${C_RED}[検出] %s${C_RESET}: %s\n" "${hash:0:8}" "$msg"
            fi
        fi
    done
    echo ""
}

cmd_entropy() {
    local file="${1:-}"
    [[ -z "$file" ]] && error_exit "ファイルを指定してください"

    log_info "高エントロピー文字列検出: $file"
    echo ""

    python3 - "$file" <<'PYEOF'
import sys, re, math

filepath = sys.argv[1]
try:
    with open(filepath, errors='replace') as f:
        content = f.read()
except:
    sys.exit(0)

def entropy(s):
    if not s: return 0
    prob = [s.count(c)/len(s) for c in set(s)]
    return -sum(p * math.log2(p) for p in prob)

RED    = "\033[1;31m"
YELLOW = "\033[1;33m"
RESET  = "\033[0m"

# 潜在的なシークレット(長い英数字文字列)
pat = re.compile(r'["\']([a-zA-Z0-9/+_\-]{20,})["\']')
found = False
for m in pat.finditer(content):
    s = m.group(1)
    e = entropy(s)
    if e > 4.5:  # 高エントロピー閾値
        lineno = content[:m.start()].count('\n') + 1
        color = RED if e > 5.5 else YELLOW
        print(f"  {color}[エントロピー:{e:.2f}]{RESET} 行{lineno}: {s[:20]}...")
        found = True

if not found:
    print(f"  高エントロピー文字列は検出されませんでした")
PYEOF
    echo ""
}

parse_arguments() {
    [[ $# -eq 0 ]] && return 0
    case "$1" in
        scan|git-history|entropy|report)
            command_name="$1"; shift ;;
    esac

    local positional=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -e|--exclude) [[ $# -lt 2 ]] && error_exit "--exclude には値が必要です"; exclude_pattern="$2"; shift 2 ;;
            -c|--context) show_context=1; shift ;;
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
        scan)        cmd_scan        "${POSITIONAL[0]:-$target_path}" ;;
        git-history) cmd_git_history ;;
        entropy)     cmd_entropy     "${POSITIONAL[0]:-}" ;;
        report)      cmd_scan        "${POSITIONAL[0]:-$target_path}" ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
