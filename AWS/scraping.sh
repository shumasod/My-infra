#!/bin/bash

# 高精度ウェブスクレイピングスクリプト (改善版)

# Usage: ./scraper.sh [options] <URL>

set -euo pipefail

# 設定変数

readonly SCRIPT_NAME=$(basename “$0”)
OUTPUT_DIR=”./scraped_data”
COOKIE_JAR=”./cookies.txt”
readonly DEFAULT_USER_AGENT=“Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36”
DELAY=1
MAX_RETRIES=3
TIMEOUT=30
VERBOSE=false
FOLLOW_REDIRECTS=true
EXTRACT_LINKS=false
EXTRACT_IMAGES=false
EXTRACT_TEXT=false
OUTPUT_FORMAT=“html”
USER_AGENT=”$DEFAULT_USER_AGENT”

# 色設定

readonly RED=’\033[0;31m’
readonly GREEN=’\033[0;32m’
readonly YELLOW=’\033[1;33m’
readonly BLUE=’\033[0;34m’
readonly NC=’\033[0m’

# 一時ファイル管理

declare -a TEMP_FILES=()

# クリーンアップ関数

cleanup() {
local exit_code=$?
if [ ${#TEMP_FILES[@]} -gt 0 ]; then
log_info “一時ファイルをクリーンアップ中…”
local temp_file
for temp_file in “${TEMP_FILES[@]}”; do
rm -f “$temp_file” 2>/dev/null || true
done
fi
exit $exit_code
}

trap cleanup EXIT INT TERM

# ログ関数

log_info() {
echo -e “${BLUE}[INFO]${NC} $1” >&2
}

log_success() {
echo -e “${GREEN}[SUCCESS]${NC} $1” >&2
}

log_warning() {
echo -e “${YELLOW}[WARNING]${NC} $1” >&2
}

log_error() {
echo -e “${RED}[ERROR]${NC} $1” >&2
}

# ヘルプ表示

show_help() {
cat << ‘EOF’
高精度ウェブスクレイピングツール

使用方法:
./scraper.sh [オプション] <URL>

オプション:
-h, –help              このヘルプを表示
-o, –output DIR        出力ディレクトリ (デフォルト: ./scraped_data)
-d, –delay SECONDS     リクエスト間の遅延 (デフォルト: 1秒)
-r, –retries NUM       最大リトライ回数 (デフォルト: 3)
-t, –timeout SECONDS   タイムアウト時間 (デフォルト: 30秒)
-u, –user-agent STRING カスタムUser-Agent
-c, –cookies FILE      クッキーファイルのパス
-v, –verbose           詳細出力を有効にする
–no-redirects          リダイレクトを無効にする
–extract-links         リンクを抽出する
–extract-images        画像URLを抽出する
–extract-text          テキストを抽出する
–format FORMAT         出力形式 (html|json) デフォルト: html

例:
./scraper.sh https://example.com
./scraper.sh -v -d 2 -o ./results https://example.com
./scraper.sh –extract-links –extract-text https://example.com
EOF
}

# 依存関係チェック

check_dependencies() {
local missing_deps=()
local cmd

```
for cmd in curl jq; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        missing_deps+=("$cmd")
    fi
done

if [ ${#missing_deps[@]} -ne 0 ]; then
    log_error "以下の依存関係が不足しています: ${missing_deps[*]}"
    log_info "インストール方法:"
    echo "  Ubuntu/Debian: sudo apt-get install curl jq"
    echo "  CentOS/RHEL: sudo yum install curl jq"
    echo "  macOS: brew install curl jq"
    exit 1
fi
```

}

# URLの検証

validate_url() {
local url=”$1”
if [[ ! “$url” =~ ^https?:// ]]; then
log_error “無効なURL形式: $url”
return 1
fi
}

# 数値検証関数

validate_number() {
local value=”$1”
local name=”$2”
local min=”${3:-0}”
local max=”${4:-999999}”

```
if ! [[ "$value" =~ ^[0-9]+$ ]]; then
    log_error "$name は正の整数である必要があります: $value"
    return 1
fi

if [ "$value" -lt "$min" ] || [ "$value" -gt "$max" ]; then
    log_error "$name は $min から $max の範囲で指定してください: $value"
    return 1
fi
```

}

# 出力ディレクトリのセットアップ

setup_output_dir() {
if [ ! -d “$OUTPUT_DIR” ]; then
if [ ! -w “$(dirname “$OUTPUT_DIR”)” ]; then
log_error “親ディレクトリに書き込み権限がありません: $(dirname “$OUTPUT_DIR”)”
return 1
fi

```
    log_info "出力ディレクトリを作成します: $OUTPUT_DIR"
    if mkdir -p "$OUTPUT_DIR"; then
        log_success "出力ディレクトリを作成しました"
    else
        log_error "ディレクトリの作成に失敗しました"
        return 1
    fi
elif [ ! -w "$OUTPUT_DIR" ]; then
    log_error "出力ディレクトリに書き込み権限がありません: $OUTPUT_DIR"
    return 1
fi

return 0
```

}

# ファイル名生成

generate_filename() {
local url=”$1”
local extension=”$2”
local timestamp
timestamp=$(date +”%Y%m%d_%H%M%S”)
local domain
domain=$(echo “$url” | sed -E ‘s|^https?://([^/?]+).*|\1|’)
local safe_domain
safe_domain=$(echo “$domain” | tr ‘.’ ‘*’ | tr -cd ’[:alnum:]*-’)
echo “${safe_domain}_${timestamp}.${extension}”
}

# HTTPリクエスト実行

make_request() {
local url=”$1”
local output_file=”$2”
local attempt=1

```
while [ $attempt -le $MAX_RETRIES ]; do
    log_info "リクエスト試行 $attempt/$MAX_RETRIES: $url"
    
    local curl_opts=(
        "--silent"
        "--show-error"
        "--fail-with-body"
        "--connect-timeout" "$TIMEOUT"
        "--max-time" $((TIMEOUT * 2))
        "--user-agent" "$USER_AGENT"
        "--cookie-jar" "$COOKIE_JAR"
        "--cookie" "$COOKIE_JAR"
        "-w" "\\n%{http_code}|%{url_effective}|%{time_total}|%{size_download}"
    )
    
    # リダイレクト設定
    if [ "$FOLLOW_REDIRECTS" = true ]; then
        curl_opts+=("--location")
    fi
    
    local response
    local http_code effective_url time_total size_download
    
    # リクエスト実行
    if response=$(curl "${curl_opts[@]}" "$url" 2>/dev/null); then
        # 最後の行（メタデータ）を抽出
        local metadata
        metadata=$(echo "$response" | tail -n 1)
        IFS='|' read -r http_code effective_url time_total size_download <<< "$metadata"
        
        # HTMLコンテンツを保存（最後の行を除外）
        echo "$response" | sed '$d' > "$output_file"
        
        if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
            log_success "ダウンロード完了 (HTTP $http_code, ${size_download} bytes, ${time_total}s)"
            [ "$VERBOSE" = true ] && log_info "実効URL: $effective_url"
            return 0
        elif [ "$http_code" -ge 400 ] && [ "$http_code" -lt 500 ]; then
            log_error "クライアントエラー (HTTP $http_code)"
            return 1
        else
            log_warning "HTTPエラー: $http_code"
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

log_error "最大リトライ回数に達しました"
return 1
```

}

# リンク抽出（絶対URL/相対URL対応）

extract_links() {
local html_file=”$1”
local output_file=”$2”
local base_url=”$3”

```
log_info "リンクを抽出中..."

local temp_file
temp_file=$(mktemp)
TEMP_FILES+=("$temp_file")

# href属性からリンクを抽出
if grep -oP 'href="\K[^"]+' "$html_file" 2>/dev/null > "$temp_file"; then
    # 絶対URLのみフィルタ（相対URLは別途処理可能）
    grep -E '^https?://' "$temp_file" | sort -u > "$output_file" || true
    
    local link_count
    link_count=$(wc -l < "$output_file")
    log_success "リンク ${link_count} 個を抽出しました: $output_file"
else
    log_warning "リンクが見つかりませんでした"
    touch "$output_file"
fi
```

}

# 画像URL抽出

extract_images() {
local html_file=”$1”
local output_file=”$2”

```
log_info "画像URLを抽出中..."

local temp_file
temp_file=$(mktemp)
TEMP_FILES+=("$temp_file")

# src属性から画像URLを抽出
if grep -oP 'src="\K[^"]+' "$html_file" 2>/dev/null > "$temp_file"; then
    grep -iE '\.(jpg|jpeg|png|gif|svg|webp)(\?[^"]*)?$' "$temp_file" | sort -u > "$output_file" || true
    
    local image_count
    image_count=$(wc -l < "$output_file")
    log_success "画像URL ${image_count} 個を抽出しました: $output_file"
else
    log_warning "画像URLが見つかりませんでした"
    touch "$output_file"
fi
```

}

# テキスト抽出

extract_text() {
local html_file=”$1”
local output_file=”$2”

```
log_info "テキストを抽出中..."

# HTMLタグを除去
if sed 's/<[^>]*>//g' "$html_file" | \
    sed 's/&nbsp;/ /g; s/&lt;/</g; s/&gt;/>/g; s/&amp;/\&/g' | \
    sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | \
    grep -v '^$' > "$output_file"; then
    log_success "テキストを抽出しました: $output_file"
else
    log_warning "テキスト抽出でエラーが発生しました"
    return 1
fi
```

}

# JSON形式で出力

create_json_output() {
local url=”$1”
local html_file=”$2”
local output_file=”$3”

```
log_info "JSON形式で出力中..."

local title description timestamp
title=$(grep -oP '<title>\K[^<]+' "$html_file" 2>/dev/null | head -1 || echo "")
description=$(grep -oP '<meta\s+name="description"\s+content="\K[^"]+' "$html_file" 2>/dev/null | head -1 || echo "")
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null)

if jq -n \
    --arg url "$url" \
    --arg title "$title" \
    --arg description "$description" \
    --arg timestamp "$timestamp" \
    --arg html_file "$(basename "$html_file")" \
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
```

}

# メイン処理

main() {
local url=””

```
# 引数解析
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -o|--output)
            OUTPUT_DIR="${2:?出力ディレクトリが指定されていません}"
            shift 2
            ;;
        -d|--delay)
            validate_number "${2:?遅延時間が指定されていません}" "遅延時間" 0 || exit 1
            DELAY="$2"
            shift 2
            ;;
        -r|--retries)
            validate_number "${2:?リトライ回数が指定されていません}" "リトライ回数" 1 10 || exit 1
            MAX_RETRIES="$2"
            shift 2
            ;;
        -t|--timeout)
            validate_number "${2:?タイムアウト時間が指定されていません}" "タイムアウト時間" 1 3600 || exit 1
            TIMEOUT="$2"
            shift 2
            ;;
        -u|--user-agent)
            USER_AGENT="${2:?User-Agentが指定されていません}"
            shift 2
            ;;
        -c|--cookies)
            COOKIE_JAR="${2:?クッキーファイルパスが指定されていません}"
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
        --extract-text)
            EXTRACT_TEXT=true
            shift
            ;;
        --format)
            case "${2:?出力形式が指定されていません}" in
                html|json)
                    OUTPUT_FORMAT="$2"
                    ;;
                *)
                    log_error "無効な出力形式: $2 (使用可能: html, json)"
                    exit 1
                    ;;
            esac
            shift 2
            ;;
        -*)
            log_error "未知のオプション: $1"
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

# 検証
[ -z "$url" ] && { log_error "URLが指定されていません"; exit 1; }

check_dependencies
validate_url "$url" || exit 1
setup_output_dir || exit 1

# ファイル生成
local base_filename
base_filename=$(generate_filename "$url" "html")
local html_file="$OUTPUT_DIR/$base_filename"

log_info "スクレイピング開始: $url"

# メインリクエスト
if make_request "$url" "$html_file"; then
    [ "$DELAY" -gt 0 ] && sleep "$DELAY"
    
    # JSON出力
    if [ "$OUTPUT_FORMAT" = "json" ]; then
        local json_file="${html_file%.html}.json"
        create_json_output "$url" "$html_file" "$json_file"
    fi
    
    # リンク抽出
    if [ "$EXTRACT_LINKS" = true ]; then
        local links_file="${html_file%.html}_links.txt"
        extract_links "$html_file" "$links_file" "$url"
    fi
    
    # 画像抽出
    if [ "$EXTRACT_IMAGES" = true ]; then
        local images_file="${html_file%.html}_images.txt"
        extract_images "$html_file" "$images_file"
    fi
    
    # テキスト抽出
    if [ "$EXTRACT_TEXT" = true ]; then
        local text_file="${html_file%.html}.txt"
        extract_text "$html_file" "$text_file"
    fi
    
    log_success "スクレイピング完了"
else
    log_error "スクレイピングに失敗しました"
    exit 1
fi
```

}

main “$@”