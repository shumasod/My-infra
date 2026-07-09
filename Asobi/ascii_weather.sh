#!/bin/bash
set -euo pipefail

#
# ASCII アート天気予報風ディスプレイ
# 作成日: 2026-07-04
# バージョン: 1.0
#
# ランダムまたは指定した天気をASCIIアートで美しく表示します
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

readonly -a WEATHER_TYPES=("sunny" "cloudy" "rainy" "snowy" "stormy" "partly_cloudy")

declare -A WEATHER_ART
WEATHER_ART["sunny"]='
    \   |   /
     .---.
  --( ☀️  )--
     `---`
    /   |   \
'
WEATHER_ART["cloudy"]='
       .--.
    .-(    ).
   (___.__)__)
   (___.__)__)
'
WEATHER_ART["rainy"]='
       .--.
    .-(    ).
   (___.__)__)
  ‚ʻ‚ʻ‚ʻ‚ʻ‚ʻ
  ‚ʻ‚ʻ‚ʻ‚ʻ‚ʻ
'
WEATHER_ART["snowy"]='
       .--.
    .-(    ).
   (___.__)__)
  * * * * * *
   * * * * *
'
WEATHER_ART["stormy"]='
  _.-._.-._
 (_  ☁️   _)
  `-._.-`
  ⚡‚ʻ⚡‚ʻ‚ʻ
  ‚ʻ‚ʻ‚ʻ‚ʻ⚡
'
WEATHER_ART["partly_cloudy"]='
    \  .--.
   .-( ☀️  ).
  (___.__)__)
'

declare -A WEATHER_LABEL
WEATHER_LABEL["sunny"]="快晴"
WEATHER_LABEL["cloudy"]="くもり"
WEATHER_LABEL["rainy"]="雨"
WEATHER_LABEL["snowy"]="雪"
WEATHER_LABEL["stormy"]="嵐"
WEATHER_LABEL["partly_cloudy"]="晴れのちくもり"

declare -A WEATHER_COLOR
WEATHER_COLOR["sunny"]="$C_YELLOW"
WEATHER_COLOR["cloudy"]="$C_WHITE"
WEATHER_COLOR["rainy"]="$C_BLUE"
WEATHER_COLOR["snowy"]="$C_BRIGHT_CYAN"
WEATHER_COLOR["stormy"]="$C_MAGENTA"
WEATHER_COLOR["partly_cloudy"]="$C_CYAN"

declare -A WEATHER_DESC
WEATHER_DESC["sunny"]="気持ちの良い晴れ！外に出かけるには最高の日です。"
WEATHER_DESC["cloudy"]="曇り空が広がっています。雨具を念のため持参しましょう。"
WEATHER_DESC["rainy"]="一日中雨が続く見込みです。傘をお忘れなく！"
WEATHER_DESC["snowy"]="雪が降っています。足元にご注意ください。"
WEATHER_DESC["stormy"]="激しい嵐になっています。外出はなるべく控えてください。"
WEATHER_DESC["partly_cloudy"]="午前中は晴れますが、午後は曇ってくるでしょう。"

generate_temp() {
    local weather="$1"
    local base temp
    case "$weather" in
        sunny)        base=28 ;;
        cloudy)       base=20 ;;
        rainy)        base=17 ;;
        snowy)        base=-2 ;;
        stormy)       base=15 ;;
        partly_cloudy) base=23 ;;
        *)            base=20 ;;
    esac
    temp=$(( base + RANDOM % 7 - 3 ))
    echo "$temp"
}

generate_humidity() {
    local weather="$1"
    local base
    case "$weather" in
        sunny)        base=40 ;;
        cloudy)       base=65 ;;
        rainy)        base=90 ;;
        snowy)        base=80 ;;
        stormy)       base=95 ;;
        partly_cloudy) base=55 ;;
        *)            base=60 ;;
    esac
    echo $(( base + RANDOM % 10 - 5 ))
}

show_forecast() {
    local weather="$1"
    local color="${WEATHER_COLOR[$weather]}"
    local label="${WEATHER_LABEL[$weather]}"
    local art="${WEATHER_ART[$weather]}"
    local desc="${WEATHER_DESC[$weather]}"
    local temp
    temp=$(generate_temp "$weather")
    local humidity
    humidity=$(generate_humidity "$weather")
    local today
    today=$(date '+%Y年%m月%d日 %H:%M')

    clear_screen
    echo ""
    print_center "今日のお天気" 0 "${C_BOLD}${C_CYAN}"
    print_center "$today" 0 "$C_DIM"
    echo ""
    print_center "─────────────────────────────" 0 "$C_DIM"
    echo ""

    while IFS= read -r art_line; do
        print_center "$art_line" 0 "$color"
    done <<< "$art"

    echo ""
    print_center "${C_BOLD}${color}${label}${C_RESET}" 0 ""
    echo ""
    print_center "─────────────────────────────" 0 "$C_DIM"
    echo ""

    local temp_color="$C_GREEN"
    [ "$temp" -ge 30 ] && temp_color="$C_RED"
    [ "$temp" -le 5 ]  && temp_color="$C_BLUE"

    printf "  ${C_BOLD}気温:${C_RESET}    ${temp_color}%d°C${C_RESET}\n" "$temp"
    printf "  ${C_BOLD}湿度:${C_RESET}    ${C_CYAN}%d%%${C_RESET}\n" "$humidity"
    echo ""
    printf "  ${C_DIM}%s${C_RESET}\n" "$desc"
    echo ""
    print_center "─────────────────────────────" 0 "$C_DIM"
    echo ""
}

show_all_forecast() {
    clear_screen
    echo ""
    print_center "週間天気予報（ランダム）" 0 "${C_BOLD}${C_CYAN}"
    print_center "$(date '+%Y年%m月%d日') 〜 7日間" 0 "$C_DIM"
    echo ""
    printf "  ${C_BOLD}%-6s  %-10s  %6s  %5s${C_RESET}\n" "曜日" "天気" "気温" "湿度"
    printf "  ${C_DIM}%s${C_RESET}\n" "──────────────────────────────"

    local -a WEEKDAYS=("日" "月" "火" "水" "木" "金" "土")
    local dow
    dow=$(date +%w)
    local i
    for (( i = 0; i < 7; i++ )); do
        local wday="${WEEKDAYS[$(( (dow + i) % 7 ))]}"
        local wtype="${WEATHER_TYPES[$(( RANDOM % ${#WEATHER_TYPES[@]} ))]}"
        local temp
        temp=$(generate_temp "$wtype")
        local humidity
        humidity=$(generate_humidity "$wtype")
        local color="${WEATHER_COLOR[$wtype]}"
        local label="${WEATHER_LABEL[$wtype]}"

        local temp_color="$C_GREEN"
        [ "$temp" -ge 30 ] && temp_color="$C_RED"
        [ "$temp" -le 5 ]  && temp_color="$C_BLUE"

        printf "  ${C_BOLD}%s曜${C_RESET}   ${color}%-10s${C_RESET}  ${temp_color}%3d°C${C_RESET}  ${C_CYAN}%3d%%${C_RESET}\n" \
            "$wday" "$label" "$temp" "$humidity"
    done
    echo ""
}

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション] [天気タイプ]

ASCII アートで今日の天気を表示します。

引数:
  天気タイプ  sunny/cloudy/rainy/snowy/stormy/partly_cloudy
             （省略時はランダム）

オプション:
  -h, --help    このヘルプを表示
  -v, --version バージョン情報を表示
  -w, --week    週間天気予報を表示
EOF
}

main() {
    local weather_type=""
    local show_week=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -w|--week)    show_week=true; shift ;;
            sunny|cloudy|rainy|snowy|stormy|partly_cloudy)
                weather_type="$1"; shift ;;
            *) error_exit "不明なオプション: $1" ;;
        esac
    done

    if "$show_week"; then
        show_all_forecast
        return
    fi

    if [ -z "$weather_type" ]; then
        weather_type="${WEATHER_TYPES[$(( RANDOM % ${#WEATHER_TYPES[@]} ))]}"
    fi

    show_forecast "$weather_type"
}

main "$@"
