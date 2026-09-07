#!/bin/bash
set -euo pipefail

#
# JSON差分比較ツール
# 作成日: 2026-07-27
# バージョン: 1.0
#
# 2つのJSONファイルを比較し、差分を見やすく表示します
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare file1=""
declare file2=""
declare output_format="pretty"
declare show_only_diff=false
declare ignore_order=false

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション] <ファイル1> <ファイル2>

2つのJSONファイルを比較し、差分を表示します。

引数:
  <ファイル1>            比較元JSONファイル
  <ファイル2>            比較先JSONファイル

オプション:
  -h, --help            このヘルプを表示
  -v, --version         バージョン情報を表示
  -f, --format <形式>   出力形式 (pretty|json|minimal) [デフォルト: pretty]
  -d, --diff-only       差分のみ表示
  -i, --ignore-order    配列の順序を無視

例:
  $PROG_NAME config_v1.json config_v2.json
  $PROG_NAME -d -f minimal old.json new.json
EOF
}

check_deps() {
    if ! command -v python3 &>/dev/null; then
        error_exit "python3 が必要です"
    fi
}

validate_json() {
    local file="$1"
    if ! python3 -c "import json,sys; json.load(open('$file'))" 2>/dev/null; then
        error_exit "無効なJSONファイル: $file"
    fi
}

flatten_json() {
    local file="$1"
    local prefix="${2:-}"
    python3 - "$file" "$prefix" <<'PYEOF'
import json
import sys

def flatten(obj, prefix="", result=None):
    if result is None:
        result = {}
    if isinstance(obj, dict):
        for k, v in obj.items():
            key = f"{prefix}.{k}" if prefix else k
            flatten(v, key, result)
    elif isinstance(obj, list):
        for i, v in enumerate(obj):
            key = f"{prefix}[{i}]"
            flatten(v, key, result)
    else:
        result[prefix] = obj
    return result

with open(sys.argv[1]) as f:
    data = json.load(f)

flat = flatten(data)
for k, v in sorted(flat.items()):
    print(f"{k}={json.dumps(v, ensure_ascii=False)}")
PYEOF
}

compare_json() {
    local f1="$1"
    local f2="$2"
    local format="$3"
    local diff_only="$4"

    log_info "JSONファイルを比較中..."
    echo ""

    python3 - "$f1" "$f2" "$format" "$diff_only" <<'PYEOF'
import json
import sys

RED    = '\033[1;31m'
GREEN  = '\033[1;32m'
YELLOW = '\033[1;33m'
CYAN   = '\033[1;36m'
BOLD   = '\033[1m'
DIM    = '\033[2m'
RESET  = '\033[0m'

def flatten(obj, prefix=""):
    result = {}
    if isinstance(obj, dict):
        for k, v in obj.items():
            key = f"{prefix}.{k}" if prefix else k
            result.update(flatten(v, key))
    elif isinstance(obj, list):
        for i, v in enumerate(obj):
            result.update(flatten(v, f"{prefix}[{i}]"))
    else:
        result[prefix] = obj
    return result

with open(sys.argv[1]) as f:
    data1 = json.load(f)
with open(sys.argv[2]) as f:
    data2 = json.load(f)

fmt       = sys.argv[3]
diff_only = sys.argv[4] == "true"

flat1 = flatten(data1)
flat2 = flatten(data2)

all_keys = sorted(set(flat1) | set(flat2))

added   = []
removed = []
changed = []
same    = []

for k in all_keys:
    if k not in flat1:
        added.append(k)
    elif k not in flat2:
        removed.append(k)
    elif flat1[k] != flat2[k]:
        changed.append(k)
    else:
        same.append(k)

total   = len(all_keys)
n_diff  = len(added) + len(removed) + len(changed)

print(f"{BOLD}=== JSON差分レポート ==={RESET}")
print(f"{DIM}ファイル1: {sys.argv[1]}{RESET}")
print(f"{DIM}ファイル2: {sys.argv[2]}{RESET}")
print()
print(f"  総キー数  : {total}")
print(f"  {GREEN}追加{RESET}      : {len(added)}")
print(f"  {RED}削除{RESET}      : {len(removed)}")
print(f"  {YELLOW}変更{RESET}      : {len(changed)}")
print(f"  変更なし  : {len(same)}")
print()

if n_diff == 0:
    print(f"{GREEN}差分はありません。ファイルは同一です。{RESET}")
    sys.exit(0)

if fmt == "pretty":
    if added:
        print(f"{GREEN}{BOLD}【追加されたキー】{RESET}")
        for k in added:
            val = json.dumps(flat2[k], ensure_ascii=False)
            print(f"  {GREEN}+ {k}{RESET}: {val}")
        print()

    if removed:
        print(f"{RED}{BOLD}【削除されたキー】{RESET}")
        for k in removed:
            val = json.dumps(flat1[k], ensure_ascii=False)
            print(f"  {RED}- {k}{RESET}: {val}")
        print()

    if changed:
        print(f"{YELLOW}{BOLD}【変更されたキー】{RESET}")
        for k in changed:
            v1 = json.dumps(flat1[k], ensure_ascii=False)
            v2 = json.dumps(flat2[k], ensure_ascii=False)
            print(f"  {YELLOW}~ {k}{RESET}")
            print(f"      {RED}< {v1}{RESET}")
            print(f"      {GREEN}> {v2}{RESET}")
        print()

    if not diff_only and same:
        print(f"{DIM}{BOLD}【変更なし】{RESET}")
        for k in same:
            val = json.dumps(flat1[k], ensure_ascii=False)
            print(f"{DIM}  = {k}: {val}{RESET}")

elif fmt == "minimal":
    for k in added:
        print(f"+ {k}: {json.dumps(flat2[k], ensure_ascii=False)}")
    for k in removed:
        print(f"- {k}: {json.dumps(flat1[k], ensure_ascii=False)}")
    for k in changed:
        print(f"~ {k}: {json.dumps(flat1[k], ensure_ascii=False)} -> {json.dumps(flat2[k], ensure_ascii=False)}")

elif fmt == "json":
    result = {
        "summary": {"total": total, "added": len(added), "removed": len(removed), "changed": len(changed), "same": len(same)},
        "added":   {k: flat2[k] for k in added},
        "removed": {k: flat1[k] for k in removed},
        "changed": {k: {"from": flat1[k], "to": flat2[k]} for k in changed},
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))
PYEOF
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_usage
                exit 0
                ;;
            -v|--version)
                echo "$PROG_NAME version $VERSION"
                exit 0
                ;;
            -f|--format)
                [[ $# -lt 2 ]] && error_exit "--format には値が必要です"
                output_format="$2"
                case "$output_format" in
                    pretty|json|minimal) ;;
                    *) error_exit "不明な形式: $output_format" ;;
                esac
                shift 2
                ;;
            -d|--diff-only)
                show_only_diff=true
                shift
                ;;
            -i|--ignore-order)
                ignore_order=true
                shift
                ;;
            -*)
                error_exit "不明なオプション: $1"
                ;;
            *)
                if [[ -z "$file1" ]]; then
                    file1="$1"
                elif [[ -z "$file2" ]]; then
                    file2="$1"
                else
                    error_exit "引数が多すぎます"
                fi
                shift
                ;;
        esac
    done

    [[ -z "$file1" ]] && error_exit "ファイル1を指定してください"
    [[ -z "$file2" ]] && error_exit "ファイル2を指定してください"
    [[ ! -f "$file1" ]] && error_exit "ファイルが見つかりません: $file1"
    [[ ! -f "$file2" ]] && error_exit "ファイルが見つかりません: $file2"
}

main() {
    parse_arguments "$@"
    check_deps
    validate_json "$file1"
    validate_json "$file2"
    compare_json "$file1" "$file2" "$output_format" "$show_only_diff"
}

main "$@"
