#!/bin/bash
set -euo pipefail

#
# DNS確認ツール
# バージョン: 1.0
#
# DNSレコードの確認・解析・比較を行うツール
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare mode="lookup"
declare -a target_domains=()
declare record_type="ALL"
declare -a dns_servers=("8.8.8.8" "1.1.1.1" "8.8.4.4")
declare output_format="table"
declare check_propagation=false
declare -i timeout_sec=5

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション] ドメイン [ドメイン...]

DNS確認ツール

コマンド (デフォルト: lookup):
  lookup            DNSレコードを参照
  propagation       DNSプロパゲーション確認 (複数サーバーで確認)
  reverse           逆引きDNS確認
  mx                メールサーバー確認
  spf               SPFレコード確認
  compare           複数ドメインのDNS比較
  monitor           DNSレコードの変化を監視

オプション:
  -h, --help              このヘルプを表示
  -v, --version           バージョン情報を表示
  -m, --mode MODE         動作モード
  -t, --type TYPE         レコードタイプ (A|AAAA|MX|TXT|NS|CNAME|SOA|ALL) [デフォルト: ALL]
  -s, --server DNS        DNSサーバー (複数可、カンマ区切り)
  -f, --format FMT        出力形式 (table|csv|json)
  --timeout SEC           タイムアウト秒数 [デフォルト: 5]

例:
  $PROG_NAME example.com
  $PROG_NAME -t A example.com
  $PROG_NAME -t MX -f csv example.com
  $PROG_NAME -m propagation example.com
  $PROG_NAME -m mx example.com
  $PROG_NAME -m spf example.com
  $PROG_NAME -m reverse 8.8.8.8

EOF
}

dig_query() {
    local domain="$1"
    local type="$2"
    local server="${3:-}"

    local dig_opts=(+short +time="$timeout_sec" +tries=1)
    [[ -n "$server" ]] && dig_opts+=("@${server}")

    dig "${dig_opts[@]}" "$domain" "$type" 2>/dev/null || echo ""
}

do_lookup() {
    for domain in "${target_domains[@]}"; do
        log_info "DNS参照: $domain"
        echo ""

        local types=()
        if [[ "$record_type" == "ALL" ]]; then
            types=(A AAAA MX NS TXT CNAME SOA)
        else
            types=("$record_type")
        fi

        for type in "${types[@]}"; do
            local result
            result=$(dig_query "$domain" "$type")

            if [[ -z "$result" ]]; then
                [[ "$record_type" == "ALL" ]] && continue
                printf "  %-8s ${C_DIM}(なし)${C_RESET}\n" "${type}:"
                continue
            fi

            printf "  ${C_BOLD}%-8s${C_RESET}\n" "${type}:"
            while IFS= read -r line; do
                [[ -z "$line" ]] && continue
                local color="$C_RESET"
                case "$type" in
                    A|AAAA) color="$C_CYAN" ;;
                    MX)     color="$C_YELLOW" ;;
                    NS)     color="$C_GREEN" ;;
                    TXT)    color="$C_DIM" ;;
                esac
                printf "    ${color}%s${C_RESET}\n" "$line"
            done <<< "$result"
        done
        echo ""
    done
}

do_propagation() {
    local domain="${target_domains[0]:-}"
    [[ -z "$domain" ]] && error_exit "ドメインを指定してください"

    local type="${record_type:-A}"
    [[ "$type" == "ALL" ]] && type="A"

    log_info "DNSプロパゲーション確認: $domain ($type)"
    echo ""

    local -a all_servers=(
        "8.8.8.8:Google"
        "1.1.1.1:Cloudflare"
        "8.8.4.4:Google2"
        "208.67.222.222:OpenDNS"
        "9.9.9.9:Quad9"
        "64.6.64.6:Verisign"
    )

    printf "  ${C_BOLD}%-18s %-20s %-40s${C_RESET}\n" "DNSサーバー" "プロバイダー" "結果"
    printf "  %s\n" "$(printf '%.0s-' {1..80})"

    local -a results=()
    for server_info in "${all_servers[@]}"; do
        local server="${server_info%%:*}"
        local provider="${server_info#*:}"

        local result
        result=$(dig_query "$domain" "$type" "$server" | head -1)
        results+=("$result")

        if [[ -z "$result" ]]; then
            printf "  %-18s %-20s ${C_RED}%-40s${C_RESET}\n" "$server" "$provider" "タイムアウト"
        else
            printf "  %-18s %-20s ${C_GREEN}%-40s${C_RESET}\n" "$server" "$provider" "$result"
        fi
    done

    echo ""

    # 一致確認
    local first="${results[0]:-}"
    local all_match=true
    for r in "${results[@]}"; do
        [[ "$r" != "$first" ]] && all_match=false && break
    done

    if $all_match; then
        log_success "全DNSサーバーで一致しています"
    else
        log_warning "DNSサーバーによって異なる結果が返っています (プロパゲーション中)"
    fi
    echo ""
}

do_reverse() {
    for ip in "${target_domains[@]}"; do
        log_info "逆引きDNS: $ip"
        echo ""

        local result
        result=$(dig +short -x "$ip" 2>/dev/null || echo "")

        if [[ -z "$result" ]]; then
            printf "  ${C_RED}逆引きレコードなし${C_RESET}\n"
        else
            printf "  ${C_GREEN}%s${C_RESET}\n" "$result"
        fi
        echo ""
    done
}

do_mx() {
    for domain in "${target_domains[@]}"; do
        log_info "メールサーバー確認: $domain"
        echo ""

        # MXレコード
        printf "  ${C_BOLD}MXレコード:${C_RESET}\n"
        local mx_result
        mx_result=$(dig +short MX "$domain" 2>/dev/null | sort -n || echo "")

        if [[ -z "$mx_result" ]]; then
            printf "  ${C_RED}MXレコードなし${C_RESET}\n"
        else
            while IFS= read -r line; do
                [[ -z "$line" ]] && continue
                local prio="${line%% *}"
                local host="${line#* }"
                printf "  ${C_YELLOW}優先度 %-5s${C_RESET} → %s\n" "$prio" "$host"

                # MXホストのAレコード
                local mx_ip
                mx_ip=$(dig +short A "$host" 2>/dev/null | head -1 || echo "")
                [[ -n "$mx_ip" ]] && printf "    → ${C_CYAN}%s${C_RESET}\n" "$mx_ip"
            done <<< "$mx_result"
        fi

        echo ""

        # SPF確認
        printf "  ${C_BOLD}SPFレコード:${C_RESET}\n"
        local spf
        spf=$(dig +short TXT "$domain" 2>/dev/null | grep -i "spf" | head -1 || echo "")
        if [[ -n "$spf" ]]; then
            printf "  ${C_GREEN}%s${C_RESET}\n" "$spf"
        else
            printf "  ${C_YELLOW}SPFレコードなし${C_RESET}\n"
        fi
        echo ""
    done
}

do_spf() {
    for domain in "${target_domains[@]}"; do
        log_info "SPF/DMARC/DKIM確認: $domain"
        echo ""

        # SPF
        printf "  ${C_BOLD}SPF:${C_RESET}\n"
        local spf
        spf=$(dig +short TXT "$domain" 2>/dev/null | grep -i "v=spf" | head -1 || echo "")
        if [[ -n "$spf" ]]; then
            printf "  ${C_GREEN}%s${C_RESET}\n" "$spf"
        else
            printf "  ${C_RED}SPFレコードなし${C_RESET}\n"
        fi
        echo ""

        # DMARC
        printf "  ${C_BOLD}DMARC:${C_RESET}\n"
        local dmarc
        dmarc=$(dig +short TXT "_dmarc.${domain}" 2>/dev/null | grep -i "v=DMARC" | head -1 || echo "")
        if [[ -n "$dmarc" ]]; then
            printf "  ${C_GREEN}%s${C_RESET}\n" "$dmarc"

            # ポリシー解析
            if echo "$dmarc" | grep -qi "p=reject"; then
                printf "  ポリシー: ${C_GREEN}reject (最も安全)${C_RESET}\n"
            elif echo "$dmarc" | grep -qi "p=quarantine"; then
                printf "  ポリシー: ${C_YELLOW}quarantine${C_RESET}\n"
            elif echo "$dmarc" | grep -qi "p=none"; then
                printf "  ポリシー: ${C_RED}none (監視のみ)${C_RESET}\n"
            fi
        else
            printf "  ${C_RED}DMARCレコードなし${C_RESET}\n"
        fi
        echo ""
    done
}

do_compare() {
    [[ ${#target_domains[@]} -lt 2 ]] && error_exit "比較するドメインを2つ以上指定してください"

    local type="${record_type:-A}"
    [[ "$type" == "ALL" ]] && type="A"

    log_info "DNS比較: ${target_domains[*]} ($type)"
    echo ""

    printf "  ${C_BOLD}%-35s${C_RESET}" "レコード"
    for domain in "${target_domains[@]}"; do
        printf " ${C_BOLD}%-25s${C_RESET}" "${domain:0:24}"
    done
    echo ""
    printf "  %s\n" "$(printf '%.0s-' {1..$(( 35 + 25 * ${#target_domains[@]} ))})"

    local types=()
    if [[ "$type" == "ALL" ]]; then
        types=(A AAAA MX NS TXT)
    else
        types=("$type")
    fi

    for rec_type in "${types[@]}"; do
        local -a results=()
        for domain in "${target_domains[@]}"; do
            local r
            r=$(dig_query "$domain" "$rec_type" | head -1)
            results+=("${r:-N/A}")
        done

        printf "  %-35s" "$rec_type"
        local first="${results[0]}"
        local all_match=true
        for r in "${results[@]}"; do
            [[ "$r" != "$first" ]] && all_match=false && break
        done

        for r in "${results[@]}"; do
            if $all_match; then
                printf " ${C_GREEN}%-25s${C_RESET}" "${r:0:24}"
            else
                printf " ${C_YELLOW}%-25s${C_RESET}" "${r:0:24}"
            fi
        done
        echo ""
    done
    echo ""
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -m|--mode)    [[ $# -lt 2 ]] && error_exit "-m には値が必要です"; mode="$2"; shift 2 ;;
            -t|--type)    [[ $# -lt 2 ]] && error_exit "-t には値が必要です"; record_type="${2^^}"; shift 2 ;;
            -s|--server)  [[ $# -lt 2 ]] && error_exit "-s には値が必要です"
                          IFS=',' read -ra dns_servers <<< "$2"; shift 2 ;;
            -f|--format)  [[ $# -lt 2 ]] && error_exit "-f には値が必要です"; output_format="$2"; shift 2 ;;
            --timeout)    [[ $# -lt 2 ]] && error_exit "--timeout には値が必要です"; timeout_sec="$2"; shift 2 ;;
            lookup|propagation|reverse|mx|spf|compare|monitor) mode="$1"; shift ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  target_domains+=("$1"); shift ;;
        esac
    done
}

main() {
    parse_arguments "$@"
    [[ ${#target_domains[@]} -eq 0 ]] && error_exit "ドメインを指定してください"

    case "$mode" in
        lookup)       do_lookup ;;
        propagation)  do_propagation ;;
        reverse)      do_reverse ;;
        mx)           do_mx ;;
        spf)          do_spf ;;
        compare)      do_compare ;;
        *)            error_exit "不明なモード: $mode" ;;
    esac
}

main "$@"
