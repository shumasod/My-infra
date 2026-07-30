#!/bin/bash
set -euo pipefail

#
# AWS Lambda管理ヘルパー
# 作成日: 2026-07-30
# バージョン: 1.0
#
# AWS Lambda関数の一覧・デプロイ・ログ確認を行います
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"
readonly REGION="${AWS_REGION:-ap-northeast-1}"

declare command_name="list"
declare function_name=""
declare log_lines=50
declare zip_file=""
declare handler=""
declare runtime="python3.11"
declare memory=128
declare timeout=30
declare dry_run=false
declare output_format="table"

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME <コマンド> [オプション]

AWS Lambda関数の管理ツールです。

コマンド:
  list                   関数一覧を表示
  info <関数名>          関数の詳細情報
  invoke <関数名>        関数を呼び出し
  logs <関数名>          ログを表示
  deploy <関数名>        ZIPでデプロイ
  env <関数名>           環境変数を管理
  alias <関数名>         エイリアス一覧
  metrics <関数名>       実行メトリクス

オプション:
  -h, --help             このヘルプを表示
  -v, --version          バージョン情報を表示
  -r, --region <リージョン>  AWSリージョン [デフォルト: ap-northeast-1]
  -n, --lines <行数>     ログ表示行数 [デフォルト: 50]
  -z, --zip <ファイル>   デプロイするZIPファイル
  --handler <ハンドラー> Lambdaハンドラー (例: index.handler)
  --runtime <ランタイム> ランタイム (例: python3.11)
  --memory <MB>          メモリサイズ [デフォルト: 128]
  --timeout <秒>         タイムアウト [デフォルト: 30]
  --format <形式>        出力形式 (table|json) [デフォルト: table]
  --dry-run              実際には実行しない

環境変数:
  AWS_REGION             デフォルトリージョン

例:
  $PROG_NAME list
  $PROG_NAME info my-function
  $PROG_NAME logs my-function -n 100
  $PROG_NAME deploy my-function -z function.zip
  $PROG_NAME invoke my-function
EOF
}

check_aws() {
    if ! command -v aws &>/dev/null; then
        error_exit "AWS CLI がインストールされていません"
    fi
    if ! aws sts get-caller-identity --region "$REGION" &>/dev/null; then
        error_exit "AWS認証情報が設定されていません"
    fi
}

cmd_list() {
    log_info "Lambda関数一覧を取得中... (リージョン: $REGION)"
    echo ""

    local functions
    functions=$(aws lambda list-functions \
        --region "$REGION" \
        --query 'Functions[*].[FunctionName,Runtime,MemorySize,Timeout,LastModified]' \
        --output json 2>/dev/null)

    if [[ "$output_format" == "json" ]]; then
        echo "$functions"
        return
    fi

    printf "${C_BOLD}%-35s %-15s %8s %8s %-20s${C_RESET}\n" \
        "関数名" "ランタイム" "メモリ(MB)" "タイムアウト" "最終更新"
    printf "%s\n" "$(printf '%.0s─' {1..90})"

    echo "$functions" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for f in sorted(data, key=lambda x: x[0]):
    name, runtime, mem, timeout, modified = f
    modified = modified[:10] if modified else 'N/A'
    print(f'  {name:<33} {runtime or \"N/A\":<15} {mem:>8} {timeout:>8}s {modified:<20}')
" 2>/dev/null || echo "  (データ取得失敗)"

    local count
    count=$(echo "$functions" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "?")
    echo ""
    printf "  合計: ${C_GREEN}%s${C_RESET} 関数\n\n" "$count"
}

cmd_info() {
    [[ -z "$function_name" ]] && error_exit "関数名を指定してください"

    log_info "関数情報を取得中: $function_name"
    echo ""

    local info
    info=$(aws lambda get-function \
        --region "$REGION" \
        --function-name "$function_name" \
        --output json 2>/dev/null) || error_exit "関数が見つかりません: $function_name"

    if [[ "$output_format" == "json" ]]; then
        echo "$info"
        return
    fi

    echo "$info" | python3 -c "
import json, sys
data = json.load(sys.stdin)
conf = data['Configuration']
code = data.get('Code', {})

print(f'  関数名       : {conf[\"FunctionName\"]}')
print(f'  ARN          : {conf[\"FunctionArn\"]}')
print(f'  ランタイム   : {conf.get(\"Runtime\", \"N/A\")}')
print(f'  ハンドラー   : {conf.get(\"Handler\", \"N/A\")}')
print(f'  メモリ       : {conf[\"MemorySize\"]} MB')
print(f'  タイムアウト : {conf[\"Timeout\"]}秒')
print(f'  状態         : {conf.get(\"State\", \"N/A\")}')
print(f'  説明         : {conf.get(\"Description\", \"(なし)\")}')
print(f'  最終更新     : {conf[\"LastModified\"]}')
print(f'  コードサイズ : {conf[\"CodeSize\"]:,} bytes')
if 'VpcConfig' in conf and conf['VpcConfig'].get('VpcId'):
    print(f'  VPC          : {conf[\"VpcConfig\"][\"VpcId\"]}')
" 2>/dev/null

    echo ""
    # 環境変数の表示
    local env_count
    env_count=$(echo "$info" | python3 -c "
import json, sys
data = json.load(sys.stdin)
env = data['Configuration'].get('Environment', {}).get('Variables', {})
print(len(env))
" 2>/dev/null || echo 0)

    printf "  環境変数数   : %s\n\n" "$env_count"
}

cmd_invoke() {
    [[ -z "$function_name" ]] && error_exit "関数名を指定してください"

    log_info "関数を呼び出し中: $function_name"

    if $dry_run; then
        printf "${C_DIM}[DRY-RUN] aws lambda invoke %s を実行します${C_RESET}\n" "$function_name"
        return
    fi

    local response_file
    response_file=$(mktemp)
    trap "rm -f '$response_file'" EXIT

    local status_code
    status_code=$(aws lambda invoke \
        --region "$REGION" \
        --function-name "$function_name" \
        --payload '{}' \
        --output json \
        "$response_file" \
        --query 'StatusCode' \
        --output text 2>/dev/null)

    echo ""
    printf "  ステータス: "
    if [[ "${status_code:-0}" -eq 200 ]]; then
        printf "${C_GREEN}%s (成功)${C_RESET}\n" "$status_code"
    else
        printf "${C_RED}%s${C_RESET}\n" "$status_code"
    fi

    echo ""
    printf "  レスポンス:\n"
    if command -v python3 &>/dev/null; then
        python3 -m json.tool "$response_file" 2>/dev/null | head -30 | sed 's/^/    /'
    else
        cat "$response_file" | head -10 | sed 's/^/    /'
    fi
    echo ""
}

cmd_logs() {
    [[ -z "$function_name" ]] && error_exit "関数名を指定してください"

    log_info "ログを取得中: $function_name"

    local log_group="/aws/lambda/$function_name"

    # 最新のログストリームを取得
    local latest_stream
    latest_stream=$(aws logs describe-log-streams \
        --region "$REGION" \
        --log-group-name "$log_group" \
        --order-by LastEventTime \
        --descending \
        --max-items 1 \
        --query 'logStreams[0].logStreamName' \
        --output text 2>/dev/null) || {
        log_error "ロググループが見つかりません: $log_group"
        return 1
    }

    if [[ "$latest_stream" == "None" || -z "$latest_stream" ]]; then
        log_info "ログがありません"
        return
    fi

    echo ""
    printf "${C_BOLD}ログストリーム: ${C_DIM}%s${C_RESET}\n\n" "$latest_stream"

    aws logs get-log-events \
        --region "$REGION" \
        --log-group-name "$log_group" \
        --log-stream-name "$latest_stream" \
        --limit "$log_lines" \
        --query 'events[*].[timestamp,message]' \
        --output json 2>/dev/null | python3 -c "
import json, sys, datetime
data = json.load(sys.stdin)
for ts, msg in data:
    dt = datetime.datetime.fromtimestamp(ts/1000).strftime('%Y-%m-%d %H:%M:%S')
    msg = msg.rstrip()
    if 'ERROR' in msg:
        print(f'\033[1;31m[{dt}] {msg}\033[0m')
    elif 'WARN' in msg:
        print(f'\033[1;33m[{dt}] {msg}\033[0m')
    elif 'START' in msg or 'END' in msg or 'REPORT' in msg:
        print(f'\033[2m[{dt}] {msg}\033[0m')
    else:
        print(f'[{dt}] {msg}')
" 2>/dev/null
    echo ""
}

cmd_deploy() {
    [[ -z "$function_name" ]] && error_exit "関数名を指定してください"
    [[ -z "$zip_file" ]]      && error_exit "--zip でZIPファイルを指定してください"
    [[ ! -f "$zip_file" ]]    && error_exit "ZIPファイルが見つかりません: $zip_file"

    log_info "デプロイ中: $function_name <- $zip_file"

    if $dry_run; then
        printf "${C_DIM}[DRY-RUN] %s を %s にデプロイします${C_RESET}\n" "$zip_file" "$function_name"
        return
    fi

    local update_args=(
        --region "$REGION"
        --function-name "$function_name"
        --zip-file "fileb://$zip_file"
    )

    aws lambda update-function-code "${update_args[@]}" \
        --query '[FunctionName,CodeSize,LastModified]' \
        --output table 2>/dev/null

    log_success "デプロイ完了: $function_name"

    # 設定更新
    if [[ -n "$handler" || -n "$runtime" ]]; then
        local config_args=(
            --region "$REGION"
            --function-name "$function_name"
        )
        [[ -n "$handler" ]] && config_args+=(--handler "$handler")
        [[ -n "$runtime" ]] && config_args+=(--runtime "$runtime")

        aws lambda update-function-configuration "${config_args[@]}" &>/dev/null
        log_success "設定を更新しました"
    fi
}

cmd_env() {
    [[ -z "$function_name" ]] && error_exit "関数名を指定してください"

    local env_vars
    env_vars=$(aws lambda get-function-configuration \
        --region "$REGION" \
        --function-name "$function_name" \
        --query 'Environment.Variables' \
        --output json 2>/dev/null)

    echo ""
    printf "${C_BOLD}環境変数: %s${C_RESET}\n\n" "$function_name"

    echo "$env_vars" | python3 -c "
import json, sys
data = json.load(sys.stdin)
if not data:
    print('  (環境変数なし)')
else:
    for k, v in sorted(data.items()):
        mask = '****' if any(s in k.upper() for s in ['KEY','SECRET','TOKEN','PASS']) else v
        print(f'  {k} = {mask}')
" 2>/dev/null
    echo ""
}

cmd_metrics() {
    [[ -z "$function_name" ]] && error_exit "関数名を指定してください"

    log_info "メトリクスを取得中: $function_name"
    echo ""

    local end_time
    end_time=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    local start_time
    start_time=$(date -u -d "24 hours ago" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || \
                 date -u -v-24H +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "")

    [[ -z "$start_time" ]] && { log_warning "日時計算に失敗しました"; return; }

    local dims="Name=FunctionName,Value=$function_name"

    for metric in Invocations Errors Duration Throttles; do
        local val
        val=$(aws cloudwatch get-metric-statistics \
            --region "$REGION" \
            --namespace AWS/Lambda \
            --metric-name "$metric" \
            --dimensions "$dims" \
            --start-time "$start_time" \
            --end-time "$end_time" \
            --period 86400 \
            --statistics Sum Average \
            --query 'Datapoints[0].[Sum,Average]' \
            --output text 2>/dev/null | head -1)

        printf "  %-15s : %s\n" "$metric" "${val:-N/A}"
    done
    echo ""
}

parse_arguments() {
    [[ $# -eq 0 ]] && return 0

    case "$1" in
        list|info|invoke|logs|deploy|env|alias|metrics)
            command_name="$1"; shift ;;
    esac

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -r|--region)  [[ $# -lt 2 ]] && error_exit "--region には値が必要です"; REGION="$2"; shift 2 ;;
            -n|--lines)   [[ $# -lt 2 ]] && error_exit "--lines には値が必要です"; log_lines="$2"; shift 2 ;;
            -z|--zip)     [[ $# -lt 2 ]] && error_exit "--zip には値が必要です"; zip_file="$2"; shift 2 ;;
            --handler)    [[ $# -lt 2 ]] && error_exit "--handler には値が必要です"; handler="$2"; shift 2 ;;
            --runtime)    [[ $# -lt 2 ]] && error_exit "--runtime には値が必要です"; runtime="$2"; shift 2 ;;
            --memory)     [[ $# -lt 2 ]] && error_exit "--memory には値が必要です"; memory="$2"; shift 2 ;;
            --timeout)    [[ $# -lt 2 ]] && error_exit "--timeout には値が必要です"; timeout="$2"; shift 2 ;;
            --format)     [[ $# -lt 2 ]] && error_exit "--format には値が必要です"; output_format="$2"; shift 2 ;;
            --dry-run)    dry_run=true; shift ;;
            -*)  error_exit "不明なオプション: $1" ;;
            *)   function_name="$1"; shift ;;
        esac
    done
}

main() {
    parse_arguments "$@"
    check_aws
    case "$command_name" in
        list)    cmd_list ;;
        info)    cmd_info ;;
        invoke)  cmd_invoke ;;
        logs)    cmd_logs ;;
        deploy)  cmd_deploy ;;
        env)     cmd_env ;;
        metrics) cmd_metrics ;;
        *) error_exit "不明なコマンド: $command_name" ;;
    esac
}

main "$@"
