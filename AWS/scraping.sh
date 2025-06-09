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
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
    
    for cmd in curl jq xmllint; do
        if ! command -v "$cmd" &> /dev/null; then
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
    local url=$1
    if [[ ! $url =~ ^https?:// ]]; then
        log_error "無効なURL形式: $url"
        return 1
    fi
}

# ディレクトリ作成
setup_output_dir() {
    if [ ! -d "$OUTPUT_DIR" ]; then
        mkdir -p "$OUTPUT_DIR"
        log_info "出力ディレクトリを作成しました: $OUTPUT_DIR"
    fi
}

# ファイル名の生成（URLから安全なファイル名を作成）
generate_filename() {
    local url=$1
    local extension=$2
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local domain=$(echo "$url" | sed -E 's|^https?://([^/]+).*|\1|')
    local safe_domain=$(echo "$domain" | tr '.' '_' | tr -cd '[:alnum:]_-')
    echo "${safe_domain}_${timestamp}.${extension}"
}

# HTTPリクエストの実行
make_request() {
    local url=$1
    local output_file=$2
    local attempt=1
    
    local curl_opts=(
        --silent
        --show-error
        --fail
        --location
        --connect-timeout "$TIMEOUT"
        --max-time $((TIMEOUT * 2))
        --user-agent "$USER_AGENT"
        --cookie-jar "$COOKIE_JAR"
        --cookie "$COOKIE_JAR"
        --write-out "%{http_code}|%{url_effective}|%{time_total}|%{size_download}"
    )
    
    if [ "$FOLLOW_REDIRECTS" = false ]; then
        curl_opts=(${curl_opts[@]/--location/})
    fi
    
    if [ -n "$CUSTOM_HEADERS" ]; then
        while IFS= read -r header; do
            curl_opts+=("--header" "$header")
        done <<< "$CUSTOM_HEADERS"
    fi
    
    while [ $attempt -le $MAX_RETRIES ]; do
        log_info "リクエスト試行 $attempt/$MAX_RETRIES: $url"
        
        local response
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
    local html_file=$1
    local output_file=$2
    
    log_info "リンクを抽出中..."
    
    # href属性からリンクを抽出
    grep -oP 'href="\K[^"]+' "$html_file" | \
        grep -E '^https?://' | \
        sort -u > "$output_file"
    
    local link_count=$(wc -l < "$output_file")
    log_success "リンク $link_count 個を抽出しました: $output_file"
}

# 画像URL抽出
extract_images() {
    local html_file=$1
    local output_file=$2
    
    log_info "画像URLを抽出中..."
    
    # src属性から画像URLを抽出
    grep -oP 'src="\K[^"]+' "$html_file" | \
        grep -E '\.(jpg|jpeg|png|gif|svg|webp)(\?.*)?$' | \
        sort -u > "$output_file"
    
    local image_count=$(wc -l < "$output_file")
    log_success "画像URL $image_count 個を抽出しました: $output_file"
}

# テキスト抽出
extract_text() {
    local html_file=$1
    local output_file=$2
    
    log_info "テキストを抽出中..."
    
    # HTMLタグを除去してテキストのみ抽出
    if command -v xmllint &> /dev/null; then
        xmllint --html --xpath "//text()" "$html_file" 2>/dev/null | \
            sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | \
            grep -v '^$' > "$output_file"
    else
        # xmllintが使用できない場合の代替手段
        sed 's/<[^>]*>//g' "$html_file" | \
            sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | \
            grep -v '^$' > "$output_file"
    fi
    
    log_success "テキストを抽出しました: $output_file"
}

# JSON形式で出力
create_json_output() {
    local url=$1
    local html_file=$2
    local output_file=$3
    local timestamp=$(date -Iseconds)
    
    log_info "JSON形式で出力中..."
    
    local title=$(grep -oP '<title>\K[^<]+' "$html_file" 2>/dev/null || echo "No title")
    local description=$(grep -oP '<meta name="description" content="\K[^"]+' "$html_file" 2>/dev/null || echo "")
    
    jq -n \
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
        }' > "$output_file"
    
    log_success "JSON出力を作成しました: $output_file"
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
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -d|--delay)
                DELAY="$2"
                shift 2
                ;;
            -r|--retries)
                MAX_RETRIES="$2"
                shift 2
                ;;
            -t|--timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            -u|--user-agent)
                USER_AGENT="$2"
                shift 2
                ;;
            -c|--cookies)
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
                CUSTOM_HEADERS="${CUSTOM_HEADERS}${2}\n"
                shift 2
                ;;
            --format)
                OUTPUT_FORMAT="$2"
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
    validate_url "$url"
    setup_output_dir
    
    # ファイル名生成
    local base_filename=$(generate_filename "$url" "html")
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
                extract_text "$html_file" "$text_file"
                ;;
            json)
                local json_file="${html_file%.html}.json"
                create_json_output "$url" "$html_file" "$json_file"
                ;;
            html)
                log_success "HTMLファイルを保存しました: $html_file"
                ;;
        esac
        
        # 追加の抽出処理
        if [ "$EXTRACT_LINKS" = true ]; then
            local links_file="${html_file%.html}_links.txt"
            extract_links "$html_file" "$links_file"
        fi
        
        if [ "$EXTRACT_IMAGES" = true ]; then
            local images_file="${html_file%.html}_images.txt"
            extract_images "$html_file" "$images_file"
        fi
        
        log_success "スクレイピング完了"
    else
        log_error "スクレイピングに失敗しました"
        exit 1
    fi
}

# スクリプト実行
main "$@"
