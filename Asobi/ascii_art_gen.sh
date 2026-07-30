#!/bin/bash
set -euo pipefail

#
# ASCIIアートジェネレーター
# 作成日: 2026-07-30
# バージョン: 1.0
#
# テキストやパターンからASCIIアートを生成します
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare mode="banner"
declare input_text=""
declare art_color="$C_CYAN"
declare frame_style="double"
declare pattern_type="stars"
declare width=60
declare height=20

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [モード] [オプション]

ASCIIアートを生成します。

モード:
  banner <テキスト>      バナーテキストを生成
  frame <テキスト>       フレーム付きメッセージ
  pattern                パターンアートを生成
  progress <数> <最大>   プログレスバー表示
  calendar               今月のカレンダー

オプション:
  -h, --help             このヘルプを表示
  -v, --version          バージョン情報を表示
  -c, --color <色>       色 (red|green|yellow|blue|cyan|magenta) [デフォルト: cyan]
  -f, --frame <スタイル> フレームスタイル (single|double|rounded|ascii)
  -p, --pattern <種類>   パターン (stars|wave|diamond|checkers|spiral)
  -w, --width <数>       幅 [デフォルト: 60]
  --height <数>          高さ [デフォルト: 20]

例:
  $PROG_NAME banner "Hello"
  $PROG_NAME frame "重要なメッセージ" -f double -c red
  $PROG_NAME pattern -p wave -w 50
  $PROG_NAME calendar
EOF
}

set_color() {
    case "${1:-cyan}" in
        red)     art_color="$C_RED" ;;
        green)   art_color="$C_GREEN" ;;
        yellow)  art_color="$C_YELLOW" ;;
        blue)    art_color="$C_BLUE" ;;
        cyan)    art_color="$C_CYAN" ;;
        magenta) art_color="$C_MAGENTA" ;;
        *)       art_color="$C_CYAN" ;;
    esac
}

# 大きな文字フォント (5x7 ASCII)
big_char() {
    local c="$1"
    case "$c" in
        A) echo " █████ |█   █ |█████ |█   █ |█   █ " ;;
        B) echo "████  |█   █ |████  |█   █ |████  " ;;
        C) echo " ████ |█     |█     |█     | ████ " ;;
        D) echo "████  |█   █ |█   █ |█   █ |████  " ;;
        E) echo "█████ |█     |████  |█     |█████ " ;;
        F) echo "█████ |█     |████  |█     |█     " ;;
        G) echo " ████ |█     |█  ██ |█   █ | ████ " ;;
        H) echo "█   █ |█   █ |█████ |█   █ |█   █ " ;;
        I) echo "█████ |  █   |  █   |  █   |█████ " ;;
        J) echo " ████ |   █  |   █  |█  █  | ██   " ;;
        K) echo "█   █ |█  █  |███   |█  █  |█   █ " ;;
        L) echo "█     |█     |█     |█     |█████ " ;;
        M) echo "█   █ |██ ██ |█ █ █ |█   █ |█   █ " ;;
        N) echo "█   █ |██  █ |█ █ █ |█  ██ |█   █ " ;;
        O) echo " ███  |█   █ |█   █ |█   █ | ███  " ;;
        P) echo "████  |█   █ |████  |█     |█     " ;;
        Q) echo " ███  |█   █ |█ █ █ |█  ██ | ████ " ;;
        R) echo "████  |█   █ |████  |█  █  |█   █ " ;;
        S) echo " ████ |█     | ███  |    █ |████  " ;;
        T) echo "█████ |  █   |  █   |  █   |  █   " ;;
        U) echo "█   █ |█   █ |█   █ |█   █ | ███  " ;;
        V) echo "█   █ |█   █ |█   █ | █ █  |  █   " ;;
        W) echo "█   █ |█   █ |█ █ █ |██ ██ |█   █ " ;;
        X) echo "█   █ | █ █  |  █   | █ █  |█   █ " ;;
        Y) echo "█   █ | █ █  |  █   |  █   |  █   " ;;
        Z) echo "█████ |   █  |  █   | █    |█████ " ;;
        0) echo " ███  |█  ██ |█ █ █ |██  █ | ███  " ;;
        1) echo "  █   | ██   |  █   |  █   |█████ " ;;
        2) echo " ███  |█   █ |   █  |  █   |█████ " ;;
        3) echo "████  |    █ | ███  |    █ |████  " ;;
        4) echo "█   █ |█   █ |█████ |    █ |    █ " ;;
        5) echo "█████ |█     |████  |    █ |████  " ;;
        6) echo " ███  |█     |████  |█   █ | ███  " ;;
        7) echo "█████ |    █ |   █  |  █   |  █   " ;;
        8) echo " ███  |█   █ | ███  |█   █ | ███  " ;;
        9) echo " ███  |█   █ | ████ |    █ | ███  " ;;
        ' ') echo "      |      |      |      |      " ;;
        '!') echo "  █   |  █   |  █   |      |  █   " ;;
        '?') echo " ███  |    █ |  ██  |      |  █   " ;;
        *) echo "  ?   |  ?   |  ?   |  ?   |  ?   " ;;
    esac
}

cmd_banner() {
    local text="${input_text^^}"
    local rows=5
    local -a lines=("" "" "" "" "")

    for (( i=0; i<${#text}; i++ )); do
        local ch="${text:$i:1}"
        local char_art
        char_art=$(big_char "$ch")
        local row=0
        while IFS='|' read -r -a parts; do
            for part in "${parts[@]}"; do
                lines[$row]+="${part} "
                (( row++ )) || true
                row=$(( row > 4 ? 0 : row ))
            done
            break
        done <<< "$(echo "$char_art" | tr '|' '\n' | awk '{printf "%s|", $0}' | sed 's/|$//')"

        IFS='|' read -ra row_parts <<< "$char_art"
        for (( r=0; r<rows; r++ )); do
            lines[$r]+="${row_parts[$r]:-      } "
        done
    done

    echo ""
    printf "${art_color}${C_BOLD}"
    for line in "${lines[@]}"; do
        echo "  $line"
    done
    printf "${C_RESET}\n"
}

cmd_frame() {
    local text="$input_text"
    local text_len=${#text}
    local inner_w=$(( text_len + 4 ))

    local tl tr bl br h v
    case "$frame_style" in
        double)  tl="╔"; tr="╗"; bl="╚"; br="╝"; h="═"; v="║" ;;
        rounded) tl="╭"; tr="╮"; bl="╰"; br="╯"; h="─"; v="│" ;;
        ascii)   tl="+"; tr="+"; bl="+"; br="+"; h="-"; v="|" ;;
        single|*) tl="┌"; tr="┐"; bl="└"; br="┘"; h="─"; v="│" ;;
    esac

    local hline
    hline=$(printf "%${inner_w}s" | tr ' ' "$h")

    echo ""
    printf "${art_color}"
    printf "  %s%s%s\n" "$tl" "$hline" "$tr"
    printf "  %s  %s  %s\n" "$v" "$text" "$v"
    printf "  %s%s%s\n" "$bl" "$hline" "$br"
    printf "${C_RESET}\n"
}

cmd_pattern() {
    echo ""
    printf "${art_color}"

    case "$pattern_type" in
        stars)
            for (( y=0; y<height; y++ )); do
                printf "  "
                for (( x=0; x<width; x++ )); do
                    local val=$(( (x + y) % 4 ))
                    case $val in
                        0) printf "★" ;;
                        1) printf "☆" ;;
                        2) printf "✦" ;;
                        3) printf "· " ;;
                    esac
                done
                echo ""
            done
            ;;
        wave)
            for (( y=0; y<height; y++ )); do
                printf "  "
                for (( x=0; x<width; x++ )); do
                    local val=$(( (x + y * 2) % 8 ))
                    case $val in
                        0|7) printf "▁" ;;
                        1|6) printf "▃" ;;
                        2|5) printf "▅" ;;
                        3|4) printf "▇" ;;
                    esac
                done
                echo ""
            done
            ;;
        diamond)
            local cx=$(( width / 2 ))
            local cy=$(( height / 2 ))
            local r=$(( height < width ? height / 2 : width / 4 ))
            for (( y=0; y<height; y++ )); do
                printf "  "
                for (( x=0; x<width; x++ )); do
                    local dx=$(( x - cx ))
                    local dy=$(( (y - cy) * 2 ))
                    local dist=$(( dx < 0 ? -dx : dx ))
                    local disty=$(( dy < 0 ? -dy : dy ))
                    if (( dist + disty <= r * 2 )); then
                        if (( dist + disty == r * 2 )); then
                            printf "◆"
                        else
                            printf "◇"
                        fi
                    else
                        printf " "
                    fi
                done
                echo ""
            done
            ;;
        checkers)
            for (( y=0; y<height; y++ )); do
                printf "  "
                for (( x=0; x<width; x++ )); do
                    if (( (x + y) % 2 == 0 )); then
                        printf "██"
                    else
                        printf "  "
                    fi
                done
                echo ""
            done
            ;;
        spiral)
            local -a grid
            for (( y=0; y<height; y++ )); do
                grid[$y]=$(printf "%${width}s" | tr ' ' ' ')
            done
            local cx=$(( width / 2 ))
            local cy=$(( height / 2 ))
            local x=$cx y=$cy
            local dx=1 dy=0
            local steps=1 step_count=0 turn_count=0 total_steps=$(( width * height ))
            local chars=("·" "○" "●" "◎")
            local char_idx=0

            for (( i=0; i<total_steps; i++ )); do
                if (( y >= 0 && y < height && x >= 0 && x < width )); then
                    local ch="${chars[$char_idx]}"
                    local line="${grid[$y]}"
                    grid[$y]="${line:0:$x}${ch}${line:$(( x + 1 ))}"
                fi
                (( x += dx ))
                (( y += dy )) || true
                (( step_count++ ))
                if (( step_count == steps )); then
                    step_count=0
                    local tmp=$dx
                    dx=$(( -dy ))
                    dy=$tmp
                    (( turn_count++ ))
                    (( turn_count % 2 == 0 )) && (( steps++ )) || true
                    char_idx=$(( (char_idx + 1) % ${#chars[@]} ))
                fi
            done

            for (( y=0; y<height; y++ )); do
                printf "  %s\n" "${grid[$y]}"
            done
            ;;
    esac

    printf "${C_RESET}\n"
}

cmd_progress() {
    local current="${ARGS[0]:-50}"
    local maximum="${ARGS[1]:-100}"
    local pct=$(( current * 100 / (maximum > 0 ? maximum : 1) ))

    echo ""
    printf "${C_BOLD}進捗状況: %d / %d (%d%%)${C_RESET}\n\n" "$current" "$maximum" "$pct"

    for style in "block" "shade" "arrow" "dots"; do
        local bar=""
        local filled=$(( pct * 30 / 100 ))
        local empty=$(( 30 - filled ))

        case "$style" in
            block)
                bar="${C_GREEN}$(printf '%0.s█' $(seq 1 $filled 2>/dev/null))${C_RESET}$(printf '%0.s░' $(seq 1 $empty 2>/dev/null))"
                ;;
            shade)
                bar="${C_CYAN}$(printf '%0.s▓' $(seq 1 $filled 2>/dev/null))${C_RESET}$(printf '%0.s░' $(seq 1 $empty 2>/dev/null))"
                ;;
            arrow)
                bar="${C_YELLOW}$(printf '%0.s─' $(seq 1 $(( filled > 0 ? filled - 1 : 0 )) 2>/dev/null))>${C_RESET}$(printf '%0.s─' $(seq 1 $empty 2>/dev/null))"
                ;;
            dots)
                bar="${C_MAGENTA}$(printf '%0.s●' $(seq 1 $filled 2>/dev/null))${C_RESET}$(printf '%0.s○' $(seq 1 $empty 2>/dev/null))"
                ;;
        esac

        printf "  %-8s [%b] %d%%\n" "$style" "$bar" "$pct"
    done
    echo ""
}

cmd_calendar() {
    local year month
    year=$(date +%Y)
    month=$(date +%m)
    local month_name
    month_name=$(date +"%Y年%m月")

    local days_in_month
    days_in_month=$(cal "$month" "$year" | tail -1 | awk '{print $NF}')
    if [[ -z "$days_in_month" ]]; then
        days_in_month=$(cal "$month" "$year" | grep -v "^$" | tail -1 | awk '{print $NF}')
    fi

    local first_dow
    first_dow=$(date -d "${year}-${month}-01" +%u 2>/dev/null || date -j -f "%Y-%m-%d" "${year}-${month}-01" +%u 2>/dev/null || echo 1)
    first_dow=$(( first_dow % 7 ))

    local today
    today=$(date +%d | sed 's/^0//')

    echo ""
    printf "${art_color}${C_BOLD}"
    cmd_frame <<< "" 2>/dev/null || true
    printf "  ╔═══════════════════════════╗\n"
    printf "  ║  %s  ║\n" "$month_name"
    printf "  ╠═══════════════════════════╣\n"
    printf "  ║  日  月  火  水  木  金  土  ║\n"
    printf "  ╠═══════════════════════════╣\n"
    printf "${C_RESET}"

    local day=1
    printf "  ${art_color}║${C_RESET}  "

    for (( i=0; i<first_dow; i++ )); do
        printf "    "
    done

    local col=$first_dow
    while [[ $day -le ${days_in_month:-31} ]]; do
        if [[ $day -eq $today ]]; then
            printf "${C_BOLD}${C_GREEN}%2d${C_RESET}  " "$day"
        elif [[ $col -eq 0 ]]; then
            printf "${C_RED}%2d${C_RESET}  " "$day"
        elif [[ $col -eq 6 ]]; then
            printf "${C_CYAN}%2d${C_RESET}  " "$day"
        else
            printf "%2d  " "$day"
        fi
        (( day++ ))
        (( col++ ))
        if [[ $col -eq 7 ]]; then
            printf "${art_color}║${C_RESET}\n  ${art_color}║${C_RESET}  "
            col=0
        fi
    done

    while [[ $col -gt 0 && $col -lt 7 ]]; do
        printf "    "
        (( col++ ))
    done
    printf "${art_color}║${C_RESET}\n"
    printf "  ${art_color}╚═══════════════════════════╝${C_RESET}\n\n"
}

declare -a ARGS=()

parse_arguments() {
    [[ $# -eq 0 ]] && return 0

    case "$1" in
        banner|frame|pattern|progress|calendar)
            mode="$1"; shift ;;
    esac

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -c|--color)
                [[ $# -lt 2 ]] && error_exit "--color には値が必要です"
                set_color "$2"; shift 2 ;;
            -f|--frame)
                [[ $# -lt 2 ]] && error_exit "--frame には値が必要です"
                frame_style="$2"; shift 2 ;;
            -p|--pattern)
                [[ $# -lt 2 ]] && error_exit "--pattern には値が必要です"
                pattern_type="$2"; shift 2 ;;
            -w|--width)
                [[ $# -lt 2 ]] && error_exit "--width には値が必要です"
                width="$2"; shift 2 ;;
            --height)
                [[ $# -lt 2 ]] && error_exit "--height には値が必要です"
                height="$2"; shift 2 ;;
            -*)  error_exit "不明なオプション: $1" ;;
            *)
                if [[ -z "$input_text" ]]; then
                    input_text="$1"
                else
                    ARGS+=("$1")
                fi
                shift ;;
        esac
    done
}

main() {
    parse_arguments "$@"
    case "$mode" in
        banner)   cmd_banner ;;
        frame)    cmd_frame ;;
        pattern)  cmd_pattern ;;
        progress) cmd_progress ;;
        calendar) cmd_calendar ;;
        *)        error_exit "不明なモード: $mode" ;;
    esac
}

main "$@"
