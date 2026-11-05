#!/bin/bash
set -euo pipefail

#
# XXE (XML外部エンティティ)インジェクション防止ツール
# 作成日: 2026-11-05
# バージョン: 1.0
#
# 脆弱性対応: XML外部エンティティ参照による情報漏洩防止
# CVE該当: CWE-611 (XML External Entity), CWE-776 (Billion Laughs)
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare command_name="scan"
declare target_path="."

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [コマンド] [オプション] [パス]

XXEインジェクション脆弱性を検出します。

コマンド:
  scan     XMLファイルのXXEパターンスキャン (デフォルト)
  validate XMLパーサー設定の検証
  audit    XML処理コードの監査
  report   XXEリスクレポート

オプション:
  -h, --help       このヘルプを表示
  -v, --version    バージョン情報を表示

脆弱性概要:
  CWE-611: XML外部エンティティ参照の不正使用
  CWE-776: 再帰的エンティティ展開 (Billion Laughs攻撃)
EOF
}

cmd_scan() {
    log_info "XXEインジェクションパターンのスキャン: $target_path"
    echo ""

    local issues=0

    # DOCTYPE宣言の検出
    local doctype_files
    doctype_files=$(grep -rl "<!DOCTYPE" "$target_path" --include="*.xml" --include="*.svg" --include="*.xsl" --include="*.xslt" 2>/dev/null || true)

    if [[ -n "$doctype_files" ]]; then
        printf "  ${C_YELLOW}[警告] DOCTYPE宣言を含むファイル:${C_RESET}\n"
        while IFS= read -r f; do
            printf "    %s\n" "$f"
            # SYSTEM/PUBLIC エンティティ確認
            if grep -q "<!ENTITY" "$f" 2>/dev/null; then
                printf "      ${C_RED}→ カスタムエンティティ定義あり (XXEリスク)${C_RESET}\n"
                (( issues++ ))
            fi
            if grep -qE "SYSTEM\s+['\"]" "$f" 2>/dev/null; then
                printf "      ${C_RED}→ SYSTEM識別子検出 (外部ファイル参照リスク)${C_RESET}\n"
                (( issues++ ))
            fi
            if grep -qE "PUBLIC\s+['\"]" "$f" 2>/dev/null; then
                printf "      ${C_YELLOW}→ PUBLIC識別子検出${C_RESET}\n"
            fi
        done <<< "$doctype_files"
        echo ""
    fi

    # Billion Laughs パターン
    local billion_files
    billion_files=$(grep -rl "ENTITY.*ENTITY\|lol\|xxe\|&x[0-9]" "$target_path" --include="*.xml" 2>/dev/null || true)
    if [[ -n "$billion_files" ]]; then
        printf "  ${C_RED}[危険] Billion Laughs疑いファイル:${C_RESET}\n"
        while IFS= read -r f; do
            printf "    %s\n" "$f"
            (( issues++ ))
        done <<< "$billion_files"
        echo ""
    fi

    # コードでのXML解析設定確認
    printf "  ${C_CYAN}XMLパーサー設定確認:${C_RESET}\n"
    local parser_issues=0

    # Python xml.etree (安全) vs lxml
    if grep -rl "lxml\|etree.parse\|parseString" "$target_path" --include="*.py" 2>/dev/null | head -5 | while IFS= read -r f; do
        if ! grep -q "resolve_entities=False\|no_network=True\|load_dtd=False" "$f" 2>/dev/null; then
            printf "    ${C_YELLOW}%s: XXE対策設定未確認${C_RESET}\n" "$f"
            (( parser_issues++ ))
        fi
    done; then
        :
    fi

    # Java SAXParser
    if grep -rl "SAXParser\|DocumentBuilder\|XMLReader" "$target_path" --include="*.java" 2>/dev/null | head -5 | while IFS= read -r f; do
        if ! grep -q "setFeature\|FEATURE_SECURE_PROCESSING\|disallow-doctype-decl" "$f" 2>/dev/null; then
            printf "    ${C_YELLOW}%s: setFeature未設定 (XXEリスク)${C_RESET}\n" "$f"
            (( parser_issues++ ))
        fi
    done; then
        :
    fi

    echo ""
    printf "  ${C_CYAN}修正方法:${C_RESET}\n"
    printf "    Python: xml.etree.ElementTree は外部エンティティを読まない (推奨)\n"
    printf "    lxml: etree.XMLParser(resolve_entities=False, no_network=True)\n"
    printf "    Java: factory.setFeature(\"http://apache.org/xml/features/disallow-doctype-decl\", true)\n"
    echo ""

    if (( issues > 0 )); then
        log_error "XXEリスク: $issues 件の問題を検出"
    else
        log_success "XXEパターンは検出されませんでした"
    fi
}

cmd_validate() {
    log_info "XMLパーサー設定の検証"
    echo ""

    # libxml2 設定確認
    if command -v xmllint &>/dev/null; then
        printf "  xmllint: ${C_GREEN}利用可能${C_RESET}\n"
        # nonet オプション確認方法表示
        printf "    安全な使用: xmllint --nonet --noent file.xml\n"
    else
        printf "  xmllint: ${C_YELLOW}未インストール${C_RESET}\n"
    fi

    # Python xml モジュール確認
    if python3 -c "import xml.etree.ElementTree; print('OK')" 2>/dev/null | grep -q OK; then
        printf "  Python xml.etree: ${C_GREEN}利用可能 (XXE安全)${C_RESET}\n"
    fi

    # expat バージョン確認
    local expat_ver
    expat_ver=$(python3 -c "import xml.parsers.expat; print(xml.parsers.expat.EXPAT_VERSION)" 2>/dev/null || echo "不明")
    printf "  Expat バージョン: %s\n" "$expat_ver"
    echo ""
}

parse_arguments() {
    [[ $# -eq 0 ]] && return 0
    case "$1" in
        scan|validate|audit|report)
            command_name="$1"; shift ;;
    esac
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  target_path="$1"; shift ;;
        esac
    done
}

main() {
    parse_arguments "$@"
    case "$command_name" in
        scan)     cmd_scan ;;
        validate) cmd_validate ;;
        audit)    cmd_scan ;;
        report)   cmd_scan; cmd_validate ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
