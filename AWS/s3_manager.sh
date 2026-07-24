#!/bin/bash
set -euo pipefail

#
# S3バケット管理ツール
# バージョン: 1.0
#
# AWS S3バケットのファイル操作・同期・容量確認ツール
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"
readonly DEFAULT_REGION="${AWS_DEFAULT_REGION:-ap-northeast-1}"

declare action=""
declare region="$DEFAULT_REGION"
declare bucket=""
declare prefix=""
declare local_path="."
declare dry_run=false
declare -i max_keys=100

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME <アクション> [オプション]

AWS S3バケット管理ツール

アクション:
  list      バケット一覧またはオブジェクト一覧
  upload    ファイルをアップロード
  download  ファイルをダウンロード
  sync      ディレクトリ同期
  delete    オブジェクト削除
  size      バケット容量確認
  url       署名付きURL生成

オプション:
  -h, --help            このヘルプを表示
  -v, --version         バージョン情報を表示
  -r, --region REGION   AWSリージョン [デフォルト: $DEFAULT_REGION]
  -b, --bucket NAME     バケット名
  -p, --prefix PATH     S3プレフィックス
  -l, --local PATH      ローカルパス [デフォルト: .]
  -n, --max-keys NUM    最大取得件数 [デフォルト: 100]
  --dry-run             実際には実行しない

例:
  $PROG_NAME list
  $PROG_NAME list -b mybucket -p logs/
  $PROG_NAME upload -b mybucket -l ./data -p backup/
  $PROG_NAME sync -b mybucket -p app/ -l ./local
  $PROG_NAME size -b mybucket
  $PROG_NAME url -b mybucket -p path/to/file.txt

EOF
}

check_aws() {
    if ! command -v aws &>/dev/null; then
        error_exit "AWS CLI が見つかりません"
    fi
    if ! aws sts get-caller-identity &>/dev/null; then
        error_exit "AWS認証情報が設定されていません"
    fi
}

format_size() {
    local bytes="$1"
    if   (( bytes >= 1073741824 )); then printf "%.1f GB" "$(echo "scale=1; $bytes/1073741824" | bc)"
    elif (( bytes >= 1048576    )); then printf "%.1f MB" "$(echo "scale=1; $bytes/1048576"    | bc)"
    elif (( bytes >= 1024       )); then printf "%.1f KB" "$(echo "scale=1; $bytes/1024"       | bc)"
    else                                 printf "%d B"   "$bytes"
    fi
}

do_list() {
    if [[ -z "$bucket" ]]; then
        log_info "S3バケット一覧 (リージョン: $region)"
        echo ""
        printf "  %-40s %s\n" "バケット名" "作成日"
        printf "  %s\n" "$(printf '%.0s-' {1..60})"
        aws s3api list-buckets \
            --query 'Buckets[].[Name,CreationDate]' \
            --output text 2>/dev/null | \
        while IFS=$'\t' read -r name created; do
            printf "  %-40s %s\n" "$name" "${created:0:10}"
        done
    else
        log_info "オブジェクト一覧: s3://${bucket}/${prefix}"
        echo ""
        printf "  %-55s %-12s %s\n" "キー" "サイズ" "最終更新"
        printf "  %s\n" "$(printf '%.0s-' {1..85})"

        local list_args=(--bucket "$bucket" --max-keys "$max_keys")
        [[ -n "$prefix" ]] && list_args+=(--prefix "$prefix")

        aws s3api list-objects-v2 \
            --region "$region" \
            "${list_args[@]}" \
            --query 'Contents[].[Key,Size,LastModified]' \
            --output text 2>/dev/null | \
        while IFS=$'\t' read -r key size modified; do
            local size_fmt
            size_fmt=$(format_size "$size")
            printf "  %-55s %-12s %s\n" \
                "${key:0:53}" "$size_fmt" "${modified:0:19}"
        done
    fi
    echo ""
}

do_upload() {
    [[ -z "$bucket" ]] && error_exit "--bucket でバケット名を指定してください"
    [[ ! -e "$local_path" ]] && error_exit "ローカルパスが存在しません: $local_path"

    local s3_target="s3://${bucket}/${prefix}"
    log_info "アップロード: $local_path → $s3_target"

    local cp_args=(--region "$region")
    [[ "$dry_run" == true ]] && cp_args+=(--dryrun)

    if [[ -d "$local_path" ]]; then
        aws s3 cp "$local_path" "$s3_target" --recursive "${cp_args[@]}"
    else
        aws s3 cp "$local_path" "$s3_target" "${cp_args[@]}"
    fi
    log_success "アップロード完了"
}

do_download() {
    [[ -z "$bucket" ]] && error_exit "--bucket でバケット名を指定してください"
    [[ -z "$prefix" ]] && error_exit "--prefix でS3パスを指定してください"

    local s3_source="s3://${bucket}/${prefix}"
    log_info "ダウンロード: $s3_source → $local_path"
    mkdir -p "$local_path"

    local cp_args=(--region "$region")
    [[ "$dry_run" == true ]] && cp_args+=(--dryrun)

    aws s3 cp "$s3_source" "$local_path" --recursive "${cp_args[@]}" || \
    aws s3 cp "$s3_source" "$local_path" "${cp_args[@]}"
    log_success "ダウンロード完了"
}

do_sync() {
    [[ -z "$bucket" ]] && error_exit "--bucket でバケット名を指定してください"

    local s3_path="s3://${bucket}/${prefix}"
    log_info "同期: $local_path ↔ $s3_path"

    local sync_args=(--region "$region")
    [[ "$dry_run" == true ]] && sync_args+=(--dryrun)

    aws s3 sync "$local_path" "$s3_path" "${sync_args[@]}"
    log_success "同期完了"
}

do_delete() {
    [[ -z "$bucket" ]] && error_exit "--bucket でバケット名を指定してください"
    [[ -z "$prefix" ]] && error_exit "--prefix で削除対象を指定してください"

    local s3_target="s3://${bucket}/${prefix}"
    log_warning "削除: $s3_target"
    printf "削除しますか? [yes/NO]: "
    local ans; read -r ans
    [[ "$ans" != "yes" ]] && { log_info "キャンセルしました"; return; }

    aws s3 rm "$s3_target" --recursive --region "$region"
    log_success "削除完了"
}

do_size() {
    [[ -z "$bucket" ]] && error_exit "--bucket でバケット名を指定してください"

    log_info "バケット容量: s3://${bucket}/${prefix}"
    echo ""

    local result
    result=$(aws s3api list-objects-v2 \
        --bucket "$bucket" \
        --region "$region" \
        ${prefix:+--prefix "$prefix"} \
        --query '[length(Contents), sum(Contents[].Size)]' \
        --output text 2>/dev/null || echo "0	0")

    local count size_bytes
    count=$(echo "$result" | awk '{print $1}')
    size_bytes=$(echo "$result" | awk '{print $2}')
    local size_fmt
    size_fmt=$(format_size "${size_bytes:-0}")

    printf "  オブジェクト数: %s\n" "${count:-0}"
    printf "  合計サイズ:     %s\n\n" "$size_fmt"
}

do_url() {
    [[ -z "$bucket" ]] && error_exit "--bucket でバケット名を指定してください"
    [[ -z "$prefix" ]] && error_exit "--prefix でオブジェクトキーを指定してください"

    log_info "署名付きURL生成: s3://${bucket}/${prefix}"
    local url
    url=$(aws s3 presign "s3://${bucket}/${prefix}" \
        --region "$region" \
        --expires-in 3600 2>/dev/null)
    echo ""
    echo "  有効期限: 1時間"
    echo "  URL:"
    echo "  $url"
    echo ""
}

parse_arguments() {
    [[ $# -eq 0 ]] && { show_usage; exit 0; }
    action="$1"; shift

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -r|--region)  [[ $# -lt 2 ]] && error_exit "--region には値が必要です"; region="$2"; shift 2 ;;
            -b|--bucket)  [[ $# -lt 2 ]] && error_exit "--bucket には値が必要です"; bucket="$2"; shift 2 ;;
            -p|--prefix)  [[ $# -lt 2 ]] && error_exit "--prefix には値が必要です"; prefix="$2"; shift 2 ;;
            -l|--local)   [[ $# -lt 2 ]] && error_exit "--local には値が必要です"; local_path="$2"; shift 2 ;;
            -n|--max-keys) [[ $# -lt 2 ]] && error_exit "--max-keys には数値が必要です"; max_keys="$2"; shift 2 ;;
            --dry-run)    dry_run=true; shift ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  error_exit "不明な引数: $1" ;;
        esac
    done
}

main() {
    parse_arguments "$@"
    check_aws

    case "$action" in
        list)     do_list ;;
        upload)   do_upload ;;
        download) do_download ;;
        sync)     do_sync ;;
        delete)   do_delete ;;
        size)     do_size ;;
        url)      do_url ;;
        *)        error_exit "不明なアクション: $action。--help を参照してください" ;;
    esac
}

main "$@"
