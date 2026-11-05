#!/bin/bash
set -euo pipefail

#
# 安全でないデシリアライズ検出ツール
# 作成日: 2026-11-05
# バージョン: 1.0
#
# 脆弱性対応: 安全でないデシリアライズ操作の検出
# CVE該当: CWE-502 (Deserialization of Untrusted Data)
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare command_name="scan"

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション]

安全でないデシリアライズ脆弱性を検出します。

コマンド:
  scan <パス>          デシリアライズ脆弱性スキャン (デフォルト)
  check-yaml <ファイル> YAMLロードの安全性確認
  check-json <ファイル> JSONパースの安全性確認
  report               修正ガイドラインの表示

オプション:
  -h, --help           このヘルプを表示
  -v, --version        バージョン情報を表示

脆弱性概要:
  CWE-502: 信頼できないデータのデシリアライズ
  攻撃シナリオ: 細工されたシリアライズデータによるコード実行
  対策: 安全なデシリアライズ関数の使用, スキーマ検証
EOF
}

cmd_scan() {
    local path="${1:-.}"
    log_info "安全でないデシリアライズ検出: $path"
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
    # Python pickle
    (r'pickle\.(?:load|loads|Unpickler)\s*\(', "pickle.load() - 任意コード実行可能", "CRITICAL"),
    (r'cPickle\.(?:load|loads)\s*\(',          "cPickle.load() - 任意コード実行可能", "CRITICAL"),

    # YAML unsafe load
    (r'yaml\.load\s*\([^)]*\)',   "yaml.load() - コード実行可能 (safe_load使用推奨)", "CRITICAL"),
    (r'yaml\.full_load\s*\(',     "yaml.full_load() - 安全でない", "HIGH"),

    # eval での JSON/YAML 解析
    (r'eval\s*\(\s*(?:json|yaml|base64)',  "evalでデータ解析 - コード実行可能", "CRITICAL"),

    # Marshal
    (r'marshal\.(?:load|loads)\s*\(', "marshal.load() - 任意コード実行可能", "CRITICAL"),

    # シェルでのJSONパース
    (r'(?:python3?|python)\s+-c\s+["\']import\s+(?:pickle|marshal)', "スクリプトでpickle/marshal使用", "HIGH"),

    # 安全でないeval
    (r'(?:^|\s)eval\s+.*(?:\$|`)', "evalに変数/コマンド置換", "HIGH"),

    # base64デコード後のeval
    (r'base64\s+.*-d.*\|\s*(?:bash|sh|eval)', "base64デコード後にシェル実行", "CRITICAL"),
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
    color = "\033[1;35m" if sev == "CRITICAL" else ("\033[1;31m" if sev == "HIGH" else "\033[1;33m")
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
    done < <(find "$path" \( -name "*.sh" -o -name "*.py" \) -type f 2>/dev/null | sort)

    printf "スキャン完了: %d ファイル中 %d 件にデシリアライズ脆弱性\n" "$total" "$issues"
    [[ "$issues" -gt 0 ]] && log_error "デシリアライズ処理を見直してください" || log_success "脆弱性なし"
    echo ""
}

cmd_check_yaml() {
    local file="${1:-}"
    [[ -z "$file" ]] && error_exit "YAMLファイルを指定してください"

    log_info "YAML安全性確認: $file"
    echo ""

    python3 -I - "$file" <<'PYEOF'
import sys
filepath = sys.argv[1]

GREEN = "\033[1;32m"
RED   = "\033[1;31m"
RESET = "\033[0m"

try:
    import yaml
    with open(filepath) as f:
        content = f.read()

    # safe_load でテスト
    try:
        data = yaml.safe_load(content)
        print(f"  {GREEN}[OK] yaml.safe_load() で正常にロードできます{RESET}")
        print(f"  型: {type(data).__name__}")
        if isinstance(data, dict):
            print(f"  キー数: {len(data)}")
    except yaml.YAMLError as e:
        print(f"  {RED}[エラー] YAMLパースエラー: {e}{RESET}")

    # 危険なタグ確認
    dangerous_tags = ['!!python/', '!!python/object', '!!python/module', '!!binary']
    for tag in dangerous_tags:
        if tag in content:
            print(f"  {RED}[危険] 危険なYAMLタグを検出: {tag}{RESET}")

except ImportError:
    print(f"  PyYAML未インストール")
PYEOF
    echo ""
}

cmd_check_json() {
    local file="${1:-}"
    [[ -z "$file" ]] && error_exit "ファイルを指定してください"

    log_info "JSON安全性確認: $file"
    echo ""

    python3 -I - "$file" <<'PYEOF'
import sys, json

filepath = sys.argv[1]

GREEN = "\033[1;32m"
RED   = "\033[1;31m"
YELLOW = "\033[1;33m"
RESET = "\033[0m"

try:
    with open(filepath) as f:
        content = f.read()

    # 標準 json.loads テスト (安全)
    try:
        data = json.loads(content)
        print(f"  {GREEN}[OK] json.loads() で正常にパースできます (安全){RESET}")
    except json.JSONDecodeError as e:
        print(f"  {RED}[エラー] JSONパースエラー: {e}{RESET}")
        sys.exit(0)

    # 危険なeval使用の確認
    dangerous_eval = ['eval(', '__import__', 'exec(', 'os.system']
    if any(d in content for d in dangerous_eval):
        print(f"  {RED}[危険] JSON値にコード実行可能な文字列を含む可能性{RESET}")
    else:
        print(f"  {GREEN}[OK] コード実行可能な文字列は見つかりません{RESET}")

    print(f"  json.loads() を使用している限り安全です")
    print(f"  eval(json_string) は絶対に使用しないでください")
except Exception as e:
    print(f"  {RED}エラー: {e}{RESET}")
PYEOF
    echo ""
}

cmd_report() {
    log_info "安全なデシリアライズガイドライン"
    echo ""

    cat <<'GUIDE'
  【危険なデシリアライズ vs 安全な代替】

  ❌ 危険: pickle.load(user_data)
  ✅ 安全: json.loads(user_data)  # JSONのみ使用

  ❌ 危険: yaml.load(stream)
  ✅ 安全: yaml.safe_load(stream)

  ❌ 危険: eval(json_string)
  ✅ 安全: json.loads(json_string)

  ❌ 危険: base64 -d data | bash
  ✅ 安全: base64 -d data > output.sh && shellcheck output.sh

  【シェルスクリプトでの安全なJSON処理】

  # jq を使用 (推奨)
  value=$(echo "$json_data" | jq -r '.key')

  # python3 json モジュール使用
  value=$(python3 -c "import json,sys; d=json.load(sys.stdin); print(d['key'])" <<< "$json_data")

  【YAMLの安全な読み込み (Python)】

  import yaml
  # yaml.safe_load のみ使用
  data = yaml.safe_load(stream)
  # yaml.load(stream, Loader=yaml.SafeLoader) も可

GUIDE
    echo ""
}

parse_arguments() {
    [[ $# -eq 0 ]] && return 0
    case "$1" in
        scan|check-yaml|check-json|report)
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
        scan)       cmd_scan       "${POSITIONAL[0]:-.}" ;;
        check-yaml) cmd_check_yaml "${POSITIONAL[0]:-}" ;;
        check-json) cmd_check_json "${POSITIONAL[0]:-}" ;;
        report)     cmd_report ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
