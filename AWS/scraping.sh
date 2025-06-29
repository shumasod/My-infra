#!/bin/bash

# 高精度ウェブスクレイピングスクリプト
# Usage: ./scraper.sh [options] <URL>

set -euo pipefail

# 設定変数
SCRIPT_NAME=$(basename "$0")
OUTPUT_DIR="./scraped_data"
COOKIE_JAR="./cookies.txt"
USER_AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
DELAY=1
MAX_RETRIES=3
TIMEOUT=30
VERBOSE=false
FOLLOW_REDIRECTS=true
EXTRACT_LINKS=false
EXTRACT_IMAGES=false
CUSTOM_HEADERS=""
OUTPUT_FORMAT="html"

# 色設定
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# 一時ファイル管理用変数
TEMP_FILES=()

# クリーンアップ関数
cleanup() {
    local exit_code=$?
    if [ ${#TEMP_FILES[@]} -gt 0 ]; then
        log_info "一時ファイルをクリーンアップ中..."
        for temp_file in "${TEMP_FILES[@]}"; do
            if [ -f "$temp_file" ]; then
                rm -f "$temp_file"
            fi
        done
    fi
    exit $exit_code
}

# trapの設定
trap cleanup EXIT INT TERM

# ログ関数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# 数値検証関数
validate_number() {
    local value="$1"
    local name="$2"
    local min="$3"
    local max="${4:-999999}"
    
    if ! [[ "$value" =~ ^[0-9]+$ ]]; then
        log_error "$name は正の整数である必要があります: $value"
        return 1
    fi
    
    if [ "$value" -lt "$min" ] || [ "$value" -gt "$max" ]; then
        log_error "$name は $min から $max の範囲で指定してください: $value"
        return 1
    fi
}

# ヘルプ表示
show_help() {
    cat << EOF
$SCRIPT_NAME - 高精度ウェブスクレイピングツール

使用方法:
    $SCRIPT_NAME [オプション] <URL>

オプション:
    -h, --help              このヘルプを表示
    -o, --output DIR        出力ディレクトリ (デフォルト: $OUTPUT_DIR)
    -d, --delay SECONDS     リクエスト間の遅延 (デフォルト: $DELAY秒)
    -r, --retries NUM       最大リトライ回数 (デフォルト: $MAX_RETRIES)
    -t, --timeout SECONDS   タイムアウト時間 (デフォルト: $TIMEOUT秒)
    -u, --user-agent STRING カスタムUser-Agent
    -c, --cookies FILE      クッキーファイルのパス
    -v, --verbose           詳細出力を有効にする
    --no-redirects          リダイレクトを無効にする
    --extract-links         リンクを抽出する
    --extract-images        画像URLを抽出する
    --header "Name: Value"  カスタムHTTPヘッダーを追加
    --format FORMAT         出力形式 (html|text|json) デフォルト: html

例:
    $SCRIPT_NAME https://example.com
    $SCRIPT_NAME -v -d 2 -o ./results https://example.com
    $SCRIPT_NAME --extract-links --format json https://example.com
EOF
}

# 依存関係チェック
check_dependencies() {
    local missing_deps=()
    local cmd
    
    for cmd in curl jq xmllint; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "以下の依存関係が不足しています: ${missing_deps[*]}"
        log_info "インストール方法:"
        echo "  Ubuntu/Debian: sudo apt-get install curl jq libxml2-utils"
        echo "  CentOS/RHEL: sudo yum install curl jq libxml2"
        echo "  macOS: brew install curl jq libxml2"
        exit 1
    fi
}

# URLの検証
validate_url() {
    local url="$1"
    if [[ ! "$url" =~ ^https?:// ]]; then
        log_error "無効なURL形式: $url"
        return 1
    fi
}

# ディレクトリ作成（確認プロンプト付き）
setup_output_dir() {
    if [ ! -d "$OUTPUT_DIR" ]; then
        if [ ! -w "$(dirname "$OUTPUT_DIR")" ]; then
            log_error "出力ディレクトリの親ディレクトリに書き込み権限がありません: $(dirname "$OUTPUT_DIR")"
            return 1
        fi
        
        log_info "出力ディレクトリを作成します: $OUTPUT_DIR"
        if ! mkdir -p "$OUTPUT_DIR"; then
            log_error "出力ディレクトリの作成に失敗しました: $OUTPUT_DIR"
            return 1
        fi
        log_success "出力ディレクトリを作成しました: $OUTPUT_DIR"
    elif [ ! -w "$OUTPUT_DIR" ]; then
        log_error "出力ディレクトリに書き込み権限がありません: $OUTPUT_DIR"
        return 1
    fi
}

# ファイル名の生成（URLから安全なファイル名を作成）
generate_filename() {
    local url="$1"
    local extension="$2"
    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    local domain
    domain=$(echo "$url" | sed -E 's|^https?://([^/]+).*|\1|')
    local safe_domain
    safe_domain=$(echo "$domain" | tr '.' '_' | tr -cd '[:alnum:]_-')
    echo "${safe_domain}_${timestamp}.${extension}"
}

# HTTPリクエストの実行
make_request() {
    local url="$1"
    local output_file="$2"
    local attempt=1
    
    # curl オプションを配列で構築（POSIX互換）
    local curl_opts
    curl_opts=(
        "--silent"
        "--show-error"
        "--fail"
        "--location"
        "--connect-timeout" "$TIMEOUT"
        "--max-time" $((TIMEOUT * 2))
        "--user-agent" "$USER_AGENT"
        "--cookie-jar" "$COOKIE_JAR"
        "--cookie" "$COOKIE_JAR"
        "--write-out" "%{http_code}|%{url_effective}|%{time_total}|%{size_download}"
    )
    
    # リダイレクト設定
    if [ "$FOLLOW_REDIRECTS" = false ]; then
        # --locationを除去
        local new_opts=()
        local opt
        for opt in "${curl_opts[@]}"; do
            [ "$opt" != "--location" ] && new_opts+=("$opt")
        done
        curl_opts=("${new_opts[@]}")
    fi
    
    # カスタムヘッダー追加
    if [ -n "$CUSTOM_HEADERS" ]; then
        local header
        while IFS= read -r header; do
            [ -n "$header" ] && curl_opts+=("--header" "$header")
        done <<< "$CUSTOM_HEADERS"
    fi
    
    while [ $attempt -le $MAX_RETRIES ]; do
        log_info "リクエスト試行 $attempt/$MAX_RETRIES: $url"
        
        local response
        local http_code effective_url time_total size_download
        
        if response=$(curl "${curl_opts[@]}" --output "$output_file" "$url" 2>/dev/null); then
            IFS='|' read -r http_code effective_url time_total size_download <<< "$response"
            
            if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
                log_success "ダウンロード完了 (HTTP $http_code, ${size_download}bytes, ${time_total}s)"
                if [ "$VERBOSE" = true ]; then
                    log_info "実効URL: $effective_url"
                fi
                return 0
            else
                log_warning "HTTP エラー: $http_code"
            fi
        else
            log_warning "接続エラーが発生しました"
        fi
        
        if [ $attempt -lt $MAX_RETRIES ]; then
            local wait_time=$((attempt * DELAY))
            log_info "${wait_time}秒待機してリトライします..."
            sleep "$wait_time"
        fi
        
        ((attempt++))
    done
    
    log_error "最大リトライ回数に達しました: $url"
    return 1
}

# リンク抽出
extract_links() {
    local html_file="$1"
    local output_file="$2"
    
    log_info "リンクを抽出中..."
    
    # 一時ファイル作成
    local temp_file
    temp_file=$(mktemp)
    TEMP_FILES+=("$temp_file")
    
    # href属性からリンクを抽出
    if grep -oP 'href="\K[^"]+' "$html_file" 2>/dev/null | \
        grep -E '^https?://' | \
        sort -u > "$temp_file"; then
        
        mv "$temp_file" "$output_file"
        local link_count
        link_count=$(wc -l < "$output_file")
        log_success "リンク $link_count 個を抽出しました: $output_file"
    else
        log_warning "リンクが見つかりませんでした"
        touch "$output_file"
    fi
}

# 画像URL抽出
extract_images() {
    local html_file="$1"
    local output_file="$2"
    
    log_info "画像URLを抽出中..."
    
    # 一時ファイル作成
    local temp_file
    temp_file=$(mktemp)
    TEMP_FILES+=("$temp_file")
    
    # src属性から画像URLを抽出
    if grep -oP 'src="\K[^"]+' "$html_file" 2>/dev/null | \
        grep -iE '\.(jpg|jpeg|png|gif|svg|webp)(\?.*)?$' | \
        sort -u > "$temp_file"; then
        
        mv "$temp_file" "$output_file"
        local image_count
        image_count=$(wc -l < "$output_file")
        log_success "画像URL $image_count 個を抽出しました: $output_file"
    else
        log_warning "画像URLが見つかりませんでした"
        touch "$output_file"
    fi
}

# テキスト抽出
extract_text() {
    local html_file="$1"
    local output_file="$2"
    
    log_info "テキストを抽出中..."
    
    # HTMLタグを除去してテキストのみ抽出
    if command -v xmllint >/dev/null 2>&1; then
        if xmllint --html --xpath "//text()" "$html_file" 2>/dev/null | \
            sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | \
            grep -v '^$' > "$output_file"; then
            log_success "テキストを抽出しました: $output_file"
        else
            log_warning "xmllintでのテキスト抽出に失敗しました。代替手段を使用します。"
            extract_text_fallback "$html_file" "$output_file"
        fi
    else
        extract_text_fallback "$html_file" "$output_file"
    fi
}

# テキスト抽出（代替手段）
extract_text_fallback() {
    local html_file="$1"
    local output_file="$2"
    
    # xmllintが使用できない場合の代替手段
    if sed 's/<[^>]*>//g' "$html_file" | \
        sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | \
        grep -v '^$' > "$output_file"; then
        log_success "テキストを抽出しました（代替手段使用）: $output_file"
    else
        log_error "テキスト抽出に失敗しました"
        return 1
    fi
}

# JSON形式で出力
create_json_output() {
    local url="$1"
    local html_file="$2"
    local output_file="$3"
    local timestamp
    timestamp=$(date -Iseconds 2>/dev/null || date +"%Y-%m-%dT%H:%M:%S%z")
    
    log_info "JSON形式で出力中..."
    
    local title description
    title=$(grep -oP '<title>\K[^<]+' "$html_file" 2>/dev/null | head -1 || echo "No title")
    description=$(grep -oP '<meta name="description" content="\K[^"]+' "$html_file" 2>/dev/null | head -1 || echo "")
    
    if jq -n \
        --arg url "$url" \
        --arg title "$title" \
        --arg description "$description" \
        --arg timestamp "$timestamp" \
        --arg html_file "$html_file" \
        '{
            url: $url,
            title: $title,
            description: $description,
            scraped_at: $timestamp,
            html_file: $html_file
        }' > "$output_file"; then
        log_success "JSON出力を作成しました: $output_file"
    else
        log_error "JSON出力の作成に失敗しました"
        return 1
    fi
}

# メイン処理
main() {
    local url=""
    
    # 引数解析
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -o|--output)
                if [ -z "${2:-}" ]; then
                    log_error "出力ディレクトリが指定されていません"
                    exit 1
                fi
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -d|--delay)
                if [ -z "${2:-}" ]; then
                    log_error "遅延時間が指定されていません"
                    exit 1
                fi
                validate_number "$2" "遅延時間" 0 || exit 1
                DELAY="$2"
                shift 2
                ;;
            -r|--retries)
                if [ -z "${2:-}" ]; then
                    log_error "リトライ回数が指定されていません"
                    exit 1
                fi
                validate_number "$2" "リトライ回数" 1 10 || exit 1
                MAX_RETRIES="$2"
                shift 2
                ;;
            -t|--timeout)
                if [ -z "${2:-}" ]; then
                    log_error "タイムアウト時間が指定されていません"
                    exit 1
                fi
                validate_number "$2" "タイムアウト時間" 1 3600 || exit 1
                TIMEOUT="$2"
                shift 2
                ;;
            -u|--user-agent)
                if [ -z "${2:-}" ]; then
                    log_error "User-Agentが指定されていません"
                    exit 1
                fi
                USER_AGENT="$2"
                shift 2
                ;;
            -c|--cookies)
                if [ -z "${2:-}" ]; then
                    log_error "クッキーファイルパスが指定されていません"
                    exit 1
                fi
                COOKIE_JAR="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --no-redirects)
                FOLLOW_REDIRECTS=false
                shift
                ;;
            --extract-links)
                EXTRACT_LINKS=true
                shift
                ;;
            --extract-images)
                EXTRACT_IMAGES=true
                shift
                ;;
            --header)
                if [ -z "${2:-}" ]; then
                    log_error "ヘッダーが指定されていません"
                    exit 1
                fi
                CUSTOM_HEADERS="${CUSTOM_HEADERS}${2}\n"
                shift 2
                ;;
            --format)
                if [ -z "${2:-}" ]; then
                    log_error "出力形式が指定されていません"
                    exit 1
                fi
                case "$2" in
                    html|text|json)
                        OUTPUT_FORMAT="$2"
                        ;;
                    *)
                        log_error "無効な出力形式: $2 (使用可能: html, text, json)"
                        exit 1
                        ;;
                esac
                shift 2
                ;;
            -*)
                log_error "未知のオプション: $1"
                echo "ヘルプを表示するには: $SCRIPT_NAME --help"
                exit 1
                ;;
            *)
                if [ -z "$url" ]; then
                    url="$1"
                else
                    log_error "複数のURLが指定されています"
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # URL必須チェック
    if [ -z "$url" ]; then
        log_error "URLが指定されていません"
        echo "使用方法: $SCRIPT_NAME [オプション] <URL>"
        exit 1
    fi
    
    # 依存関係と設定のチェック
    check_dependencies
    validate_url "$url" || exit 1
    setup_output_dir || exit 1
    
    # ファイル名生成
    local base_filename
    base_filename=$(generate_filename "$url" "html")
    local html_file="$OUTPUT_DIR/$base_filename"
    
    log_info "スクレイピング開始: $url"
    
    # メインリクエスト実行
    if make_request "$url" "$html_file"; then
        # 遅延
        if [ "$DELAY" -gt 0 ]; then
            sleep "$DELAY"
        fi
        
        # 出力形式に応じた処理
        case "$OUTPUT_FORMAT" in
            text)
                local text_file="${html_file%.html}.txt"
                extract_text "$html_file" "$text_file" || log_warning "テキスト抽出でエラーが発生しました"
                ;;
            json)
                local json_file="${html_file%.html}.json"
                create_json_output "$url" "$html_file" "$json_file" || log_warning "JSON出力でエラーが発生しました"
                ;;
            html)
                log_success "HTMLファイルを保存しました: $html_file"
                ;;
        esac
        
        # 追加の抽出処理
        if [ "$EXTRACT_LINKS" = true ]; then
            local links_file="${html_file%.html}_links.txt"
            extract_links "$html_file" "$links_file" || log_warning "リンク抽出でエラーが発生しました"
        fi
        
        if [ "$EXTRACT_IMAGES" = true ]; then
            local images_file="${html_file%.html}_images.txt"
            extract_images "$html_file" "$images_file" || log_warning "画像URL抽出でエラーが発生しました"
        fi
        
        log_success "スクレイピング完了"
    else
        log_error "スクレイピングに失敗しました"
        exit 1
    fi
}

# スクリプト実行
main "$@"
