#!/bin/bash
set -euo pipefail

#
# 暗号化脆弱性チェックツール
# 作成日: 2026-11-05
# バージョン: 1.0
#
# 脆弱性対応: 弱い暗号化アルゴリズムの検出と修正
# CWE-326: Inadequate Encryption Strength
# CWE-327: Use of a Broken or Risky Cryptographic Algorithm
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"
declare command_name="scan"

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション]

弱い暗号化アルゴリズムの使用を検出します。

コマンド:
  scan <パス>    暗号化脆弱性スキャン (デフォルト)
  tls <ホスト>   TLS設定チェック
  hash-test      ハッシュアルゴリズム比較
  fix-guide      修正ガイドラインの表示

オプション:
  -h, --help     このヘルプを表示
  -v, --version  バージョン情報を表示

脆弱性概要:
  CWE-326: 不十分な暗号化強度
  CWE-327: 危険な暗号化アルゴリズムの使用
  危険: MD5, SHA1, DES, RC4, RSA-1024
  安全: SHA-256以上, AES-256, RSA-2048以上
EOF
}

cmd_scan() {
    local path="${1:-.}"
    log_info "暗号化脆弱性スキャン: $path"
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
    # 危険なハッシュ
    (r'\bmd5\b', "MD5使用 (衝突脆弱性あり、パスワードハッシュ不可)", "CRITICAL"),
    (r'hashlib\.md5\b', "Python MD5使用", "CRITICAL"),
    (r'\bsha1\b', "SHA-1使用 (衝突攻撃可能)", "HIGH"),
    (r'hashlib\.sha1\b', "Python SHA-1使用", "HIGH"),
    # 危険な暗号化
    (r'\bdes\b', "DES暗号化使用 (56bit、解読可能)", "CRITICAL"),
    (r'\brc4\b', "RC4ストリーム暗号使用 (脆弱)", "CRITICAL"),
    (r'\b3des\b', "3DES使用 (非推奨)", "HIGH"),
    (r'aes.*128', "AES-128使用 (AES-256を推奨)", "MEDIUM"),
    # 弱い鍵長
    (r'rsa.*1024', "RSA-1024 (2048bit以上を推奨)", "HIGH"),
    (r'openssl.*1024', "openssl 1024bit鍵 (2048bit以上を推奨)", "HIGH"),
    # 危険なSSL/TLS
    (r'ssl[v]?2|sslv2', "SSLv2使用 (廃止済み)", "CRITICAL"),
    (r'ssl[v]?3|sslv3', "SSLv3使用 (POODLE脆弱性)", "CRITICAL"),
    (r'tls1\.0|tlsv1\.0', "TLS 1.0使用 (非推奨)", "HIGH"),
    (r'tls1\.1|tlsv1\.1', "TLS 1.1使用 (非推奨)", "HIGH"),
    # ランダム性
    (r'random\.random\(\)', "Python random.random() (暗号用途に不適切)", "MEDIUM"),
    (r'\bmath\.random\b', "Math.random() (暗号用途に不適切)", "MEDIUM"),
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
    print(f"    {CYAN}→ 安全な暗号化アルゴリズムに移行してください{RESET}")
PYEOF
)
        if [[ -n "$result" ]]; then
            (( issues++ ))
            printf "${C_BOLD}%s${C_RESET}\n" "$file"
            echo "$result"
            echo ""
        fi
    done < <(find "$path" \( -name "*.sh" -o -name "*.py" -o -name "*.conf" \) -type f 2>/dev/null | sort)

    printf "スキャン完了: %d ファイル中 %d 件に暗号化脆弱性\n" "$total" "$issues"
    [[ "$issues" -gt 0 ]] && log_error "強力な暗号化アルゴリズムに移行してください" || log_success "脆弱性なし"
    echo ""
}

cmd_tls() {
    local host="${1:-}"
    [[ -z "$host" ]] && error_exit "ホスト名を指定してください"

    log_info "TLS設定チェック: $host"
    echo ""

    if ! command -v openssl &>/dev/null; then
        error_exit "openssl がインストールされていません"
    fi

    # プロトコルチェック
    printf "${C_BOLD}プロトコルサポート:${C_RESET}\n"
    local protocols=("ssl2" "ssl3" "tls1" "tls1_1" "tls1_2" "tls1_3")
    local labels=("SSLv2(危険)" "SSLv3(危険)" "TLS1.0(非推奨)" "TLS1.1(非推奨)" "TLS1.2(許容)" "TLS1.3(推奨)")
    local i=0
    for proto in "${protocols[@]}"; do
        local label="${labels[$i]}"
        if echo | timeout 3 openssl s_client -connect "${host}:443" \
            "-${proto}" 2>/dev/null | grep -q "Cipher"; then
            if [[ $i -lt 4 ]]; then
                printf "  ${C_RED}[危険]${C_RESET} %s: サポートされています\n" "$label"
            else
                printf "  ${C_GREEN}[OK  ]${C_RESET} %s: サポートされています\n" "$label"
            fi
        else
            if [[ $i -lt 4 ]]; then
                printf "  ${C_GREEN}[OK  ]${C_RESET} %s: 無効\n" "$label"
            else
                printf "  ${C_YELLOW}[INFO]${C_RESET} %s: 無効\n" "$label"
            fi
        fi
        (( i++ ))
    done
    echo ""
}

cmd_hash_test() {
    log_info "ハッシュアルゴリズム比較"
    echo ""

    python3 <<'PYEOF'
import hashlib, time

data = b"test_password_12345" * 1000
algorithms = [
    ("MD5",    hashlib.md5,    "CRITICAL - 衝突脆弱性"),
    ("SHA-1",  hashlib.sha1,   "HIGH     - 衝突攻撃可能"),
    ("SHA-256",hashlib.sha256, "SAFE     - 推奨"),
    ("SHA-512",hashlib.sha512, "SAFE     - 最強"),
]

RED   = "\033[1;31m"
YELLOW = "\033[1;33m"
GREEN = "\033[1;32m"
RESET = "\033[0m"

for name, algo, risk in algorithms:
    start = time.perf_counter()
    h = algo(data).hexdigest()
    elapsed = (time.perf_counter() - start) * 1000
    color = RED if "CRITICAL" in risk else (YELLOW if "HIGH" in risk else GREEN)
    print(f"  {color}{name:8}{RESET}: {elapsed:.3f}ms  [{risk}]  {h[:16]}...")
PYEOF
    echo ""
}

cmd_fix_guide() {
    log_info "暗号化脆弱性修正ガイドライン"
    echo ""
    cat <<'GUIDE'
  【危険なアルゴリズムから安全なものへの移行】

  パスワードハッシュ:
    危険: echo -n "$password" | md5sum
    安全: python3 -c "import bcrypt; print(bcrypt.hashpw(b'$password', bcrypt.gensalt()))"
    安全: openssl passwd -6 "$password"  # SHA-512 crypt

  ファイルチェックサム:
    危険: md5sum file.tar.gz
    安全: sha256sum file.tar.gz

  データ暗号化:
    危険: openssl enc -des -in plain.txt -out cipher.txt
    安全: openssl enc -aes-256-cbc -pbkdf2 -in plain.txt -out cipher.txt

  RSA鍵生成:
    危険: openssl genrsa -out key.pem 1024
    安全: openssl genrsa -out key.pem 4096

  TLS設定 (Nginx):
    危険: ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    安全: ssl_protocols TLSv1.2 TLSv1.3;
          ssl_ciphers ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;

GUIDE
    echo ""
}

parse_arguments() {
    [[ $# -eq 0 ]] && return 0
    case "$1" in
        scan|tls|hash-test|fix-guide)
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
        scan)      cmd_scan      "${POSITIONAL[0]:-.}" ;;
        tls)       cmd_tls       "${POSITIONAL[0]:-}" ;;
        hash-test) cmd_hash_test ;;
        fix-guide) cmd_fix_guide ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
