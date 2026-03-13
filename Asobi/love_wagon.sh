#!/bin/bash
set -euo pipefail

#
# あいのり LOVE WAGON シミュレーター
# 作成日: 2026-03-12
# バージョン: 1.0
#
# 世界を旅するラブワゴンを舞台にした恋愛ドラマシミュレーター
# キャラクターたちの恋愛模様をリアルタイムでお届けします
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

# ===== 設定（定数） =====
readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"
readonly EVENT_INTERVAL=70   # イベント発生間隔（フレーム数）
readonly POPUP_DURATION=40   # ポップアップ表示フレーム数

# ===== キャラクター設定 =====
# 名前
declare -a CHAR_NAMES=("タカシ" "ユウタ" "ケンジ" "サクラ" "ミホ" "アオイ")
# 性別: M=男性, F=女性
declare -a CHAR_GENDERS=("M" "M" "M" "F" "F" "F")
# 恋愛状況: 0=様子見 1=片思い 2=アプローチ中 3=両思い 4=フラれた
declare -a CHAR_STATUS=(0 0 0 0 0 0)
# 片思いの相手インデックス (-1=なし)
declare -a CHAR_TARGET=(-1 -1 -1 -1 -1 -1)
# 旅の参加フラグ: 1=参加中, 0=帰国済み
declare -a CHAR_ACTIVE=(1 1 1 1 1 1)

# ===== 旅の状態 =====
declare -i day=1
declare -i total_distance=0
declare -i anim_frame=0
declare -i road_offset=0

# 訪問地リスト
declare -a LOCATIONS=(
    "タイ・バンコク"
    "ベトナム・ホイアン"
    "カンボジア・アンコールワット"
    "インド・ジャイプール"
    "トルコ・カッパドキア"
    "ギリシャ・サントリーニ"
    "イタリア・フィレンツェ"
    "フランス・パリ"
    "スペイン・バルセロナ"
    "ポルトガル・リスボン"
)
declare -i loc_idx=0
declare current_location="${LOCATIONS[0]}"

# イベントログ（最新5件）
declare -a event_log=(
    "第1話スタート！ラブワゴン旅立ち♥"
    "みんなでバンコクの夜市へ"
    "恋の予感が漂いはじめた..."
    "運命の出会いは近い！"
)

# ポップアップ
declare popup_msg=""
declare -i popup_timer=0

# ===== ターミナル制御 =====

cleanup() {
    show_cursor
    printf '\033[?1049l'
    stty echo   2>/dev/null || true
    stty icanon 2>/dev/null || true
}
trap cleanup EXIT INT TERM

init_terminal() {
    printf '\033[?1049h'
    hide_cursor
    stty -echo   2>/dev/null || true
    stty -icanon min 0 time 0 2>/dev/null || true
    update_terminal_size
}

# ===== ヘルパー =====

add_event() {
    local msg="$1"
    event_log+=("$msg")
    popup_msg="$msg"
    popup_timer=$POPUP_DURATION
}

get_status_label() {
    case $1 in
        0) echo "様子見..." ;;
        1) echo "♡片思い♡" ;;
        2) echo "♥アタック" ;;
        3) echo "★両思い★" ;;
        4) echo "×フラれた" ;;
        *) echo "         " ;;
    esac
}

get_status_color() {
    case $1 in
        0) echo -ne "${C_DIM}" ;;
        1) echo -ne "${C_BRIGHT_MAGENTA}" ;;
        2) echo -ne "${C_BRIGHT_RED}" ;;
        3) echo -ne "${C_BRIGHT_YELLOW}" ;;
        4) echo -ne "${C_CYAN}" ;;
        *) echo -ne "${C_DIM}" ;;
    esac
}

# ===== ランダムイベント処理 =====

trigger_event() {
    # アクティブなキャラクターを収集
    local -a active=()
    local i
    for ((i = 0; i < 6; i++)); do
        ((CHAR_ACTIVE[$i] == 1)) && active+=($i)
    done
    local n=${#active[@]}
    ((n < 2)) && return 0

    local p1=${active[$((RANDOM % n))]}
    local p2=${active[$((RANDOM % n))]}
    # p1 != p2 になるまで選びなおす（最大10回）
    local retry=0
    while ((p2 == p1 && retry < 10)); do
        p2=${active[$((RANDOM % n))]}
        retry=$((retry + 1))
    done
    ((p2 == p1)) && return 0

    local rand=$((RANDOM % 12))
    case $rand in
        0)  # 片思い発生
            if ((CHAR_STATUS[$p1] == 0)); then
                CHAR_STATUS[$p1]=1
                CHAR_TARGET[$p1]=$p2
                add_event "${CHAR_NAMES[$p1]}が${CHAR_NAMES[$p2]}に一目惚れ！♡"
            fi
            ;;
        1)  # アプローチ開始
            if ((CHAR_STATUS[$p1] == 1)); then
                local tgt=${CHAR_TARGET[$p1]}
                if ((tgt >= 0 && CHAR_ACTIVE[$tgt] == 1)); then
                    CHAR_STATUS[$p1]=2
                    add_event "${CHAR_NAMES[$p1]}が${CHAR_NAMES[$tgt]}へのアプローチ開始！"
                fi
            fi
            ;;
        2)  # 両思い成立
            if ((CHAR_STATUS[$p1] == 2)); then
                local tgt=${CHAR_TARGET[$p1]}
                if ((tgt >= 0 && CHAR_STATUS[$tgt] >= 1)); then
                    CHAR_STATUS[$p1]=3
                    CHAR_STATUS[$tgt]=3
                    add_event "★★ ${CHAR_NAMES[$p1]}と${CHAR_NAMES[$tgt]}が両思い成立！★★"
                fi
            fi
            ;;
        3)  # 告白→フラれる
            if ((CHAR_STATUS[$p1] == 2)); then
                local tgt=${CHAR_TARGET[$p1]}
                CHAR_STATUS[$p1]=4
                add_event "${CHAR_NAMES[$p1]}が告白...${CHAR_NAMES[$tgt]}にフラれた(泣)"
            fi
            ;;
        4)  # 両思いペアが帰国
            if ((CHAR_STATUS[$p1] == 3)); then
                local tgt=${CHAR_TARGET[$p1]}
                CHAR_ACTIVE[$p1]=0
                if ((tgt >= 0 && CHAR_ACTIVE[$tgt] == 1)); then
                    CHAR_ACTIVE[$tgt]=0
                fi
                add_event "${CHAR_NAMES[$p1]}たちが幸せを胸に帰国しました..."
            fi
            ;;
        5)  # フラれた人が帰国
            if ((CHAR_STATUS[$p1] == 4)); then
                CHAR_ACTIVE[$p1]=0
                add_event "${CHAR_NAMES[$p1]}が傷心のまま帰国..."
            fi
            ;;
        6)  # 新メンバー加入
            local joined=0
            for ((i = 0; i < 6; i++)); do
                if ((CHAR_ACTIVE[$i] == 0 && joined == 0)); then
                    CHAR_ACTIVE[$i]=1
                    CHAR_STATUS[$i]=0
                    CHAR_TARGET[$i]=-1
                    local -a new_names=("ハルト" "リク" "ソウタ" "ナナ" "ユイ" "リサ" "レン" "モモ")
                    CHAR_NAMES[$i]="${new_names[$((RANDOM % ${#new_names[@]}))]}"
                    add_event "新メンバー「${CHAR_NAMES[$i]}」がラブワゴンに合流！"
                    joined=1
                fi
            done
            ;;
        7)  # 場所移動
            loc_idx=$(( (loc_idx + 1) % ${#LOCATIONS[@]} ))
            current_location="${LOCATIONS[$loc_idx]}"
            add_event "ラブワゴン、${current_location}へ出発！"
            ;;
        8)  # キャンドルディナー
            add_event "${CHAR_NAMES[$p1]}が${CHAR_NAMES[$p2]}をキャンドルディナーに誘った♥"
            ;;
        9)  # 夕日鑑賞
            add_event "${CHAR_NAMES[$p1]}と${CHAR_NAMES[$p2]}が夕日を見ながら語り合う"
            ;;
        10) # ドライブ中の会話
            add_event "${CHAR_NAMES[$p1]}「ここの景色、最高だね」${CHAR_NAMES[$p2]}「うん...」"
            ;;
        11) # ラブワゴン名言
            local -a quotes=(
                "好きって言えなくても、隣にいるだけで幸せ"
                "この旅で、本物の恋を見つけたい"
                "明日も走るよ、ラブワゴン"
                "恋は国境を越える"
            )
            add_event "${quotes[$((RANDOM % ${#quotes[@]}))]}"
            ;;
    esac
    return 0
}

# ===== 描画関数 =====

# ハートが空に浮かぶ
draw_sky() {
    local f=$1
    local -a hearts=("♥" "♡" "♥" "♡" "♥")
    local i
    for ((i = 0; i < 5; i++)); do
        local col=$(( (f * 3 + i * 19) % (TERM_COLS - 2) + 1 ))
        local row=$(( 4 + (f / 2 + i * 2) % 3 ))
        local hidx=$(( (f + i) % ${#hearts[@]} ))
        printf '\033[%d;%dH' "$row" "$col"
        echo -ne "${C_BRIGHT_MAGENTA}${hearts[$hidx]}${C_RESET}"
    done
}

# ヘッダー
draw_header() {
    local episode=$((1 + anim_frame / 80))
    printf '\033[1;1H\033[K'
    echo -ne "${C_BRIGHT_MAGENTA}${C_BOLD}"
    printf '╔'; printf '%*s' $((TERM_COLS - 2)) '' | tr ' ' '═'; printf '╗'
    echo -ne "${C_RESET}"

    printf '\033[2;1H\033[K'
    echo -ne "${C_BRIGHT_MAGENTA}${C_BOLD}║${C_RESET}"
    local info
    printf -v info "  ♥ あいのり  第%d話  📍 %-22s  走行 %dkm  ♥" \
        "$episode" "$current_location" "$total_distance"
    echo -ne "${C_WHITE}${C_BOLD}"
    printf '%-*s' $((TERM_COLS - 2)) "$info"
    echo -ne "${C_RESET}"
    echo -ne "${C_BRIGHT_MAGENTA}${C_BOLD}║${C_RESET}"

    printf '\033[3;1H\033[K'
    echo -ne "${C_BRIGHT_MAGENTA}${C_BOLD}"
    printf '╚'; printf '%*s' $((TERM_COLS - 2)) '' | tr ' ' '═'; printf '╝'
    echo -ne "${C_RESET}"
}

# ラブワゴン本体
# 引数: $1=描画開始行  $2=揺れ(0 or 1)
draw_wagon() {
    local start_row=$1
    local rock=$2
    local wagon_width=52
    local left=$(( (TERM_COLS - wagon_width) / 2 ))
    local r=$((start_row + rock))

    # 上部フレーム
    printf '\033[%d;%dH' "$r" "$left"
    echo -ne "${C_YELLOW}${C_BOLD}"
    printf '╔'; printf '%*s' $((wagon_width - 2)) '' | tr ' ' '═'; printf '╗'
    echo -ne "${C_RESET}"

    # タイトル行
    r=$((r + 1))
    printf '\033[%d;%dH' "$r" "$left"
    echo -ne "${C_YELLOW}${C_BOLD}║${C_RESET}"
    echo -ne "${C_BRIGHT_MAGENTA}${C_BOLD}"
    printf '  ♥♥  あいのり  L O V E  W A G O N  ♥♥      '
    echo -ne "${C_RESET}"
    echo -ne "${C_YELLOW}${C_BOLD}║${C_RESET}"

    # 窓の仕切り
    r=$((r + 1))
    printf '\033[%d;%dH' "$r" "$left"
    echo -ne "${C_YELLOW}${C_BOLD}"
    printf '╠'; printf '%*s' 8 '' | tr ' ' '═'
    printf '╦'; printf '%*s' 8 '' | tr ' ' '═'
    printf '╦'; printf '%*s' 8 '' | tr ' ' '═'
    printf '╦'; printf '%*s' 8 '' | tr ' ' '═'
    printf '╦'; printf '%*s' 8 '' | tr ' ' '═'
    printf '╦'; printf '%*s' 8 '' | tr ' ' '═'
    printf '╣'
    echo -ne "${C_RESET}"

    # アクティブキャラを収集
    local -a active_idx=()
    local i
    for ((i = 0; i < 6; i++)); do
        ((CHAR_ACTIVE[$i] == 1)) && active_idx+=($i)
    done

    # 名前行
    r=$((r + 1))
    printf '\033[%d;%dH' "$r" "$left"
    echo -ne "${C_YELLOW}${C_BOLD}║${C_RESET}"
    for ((i = 0; i < 6; i++)); do
        if ((i < ${#active_idx[@]})); then
            local cidx=${active_idx[$i]}
            local col
            col=$(get_status_color "${CHAR_STATUS[$cidx]}")
            echo -ne "${col}"
            printf ' %-6s ' "${CHAR_NAMES[$cidx]}"
            echo -ne "${C_RESET}"
        else
            printf '         '
        fi
        echo -ne "${C_YELLOW}${C_BOLD}║${C_RESET}"
    done

    # ステータス行
    r=$((r + 1))
    printf '\033[%d;%dH' "$r" "$left"
    echo -ne "${C_YELLOW}${C_BOLD}║${C_RESET}"
    for ((i = 0; i < 6; i++)); do
        if ((i < ${#active_idx[@]})); then
            local cidx=${active_idx[$i]}
            local col
            col=$(get_status_color "${CHAR_STATUS[$cidx]}")
            local lbl
            lbl=$(get_status_label "${CHAR_STATUS[$cidx]}")
            echo -ne "${col}"
            printf ' %-7s ' "$lbl"
            echo -ne "${C_RESET}"
        else
            printf '         '
        fi
        echo -ne "${C_YELLOW}${C_BOLD}║${C_RESET}"
    done

    # 窓下フレーム
    r=$((r + 1))
    printf '\033[%d;%dH' "$r" "$left"
    echo -ne "${C_YELLOW}${C_BOLD}"
    printf '╠'; printf '%*s' 8 '' | tr ' ' '═'
    printf '╩'; printf '%*s' 8 '' | tr ' ' '═'
    printf '╩'; printf '%*s' 8 '' | tr ' ' '═'
    printf '╩'; printf '%*s' 8 '' | tr ' ' '═'
    printf '╩'; printf '%*s' 8 '' | tr ' ' '═'
    printf '╩'; printf '%*s' 8 '' | tr ' ' '═'
    printf '╣'
    echo -ne "${C_RESET}"

    # 車体下部（赤ライン）
    r=$((r + 1))
    printf '\033[%d;%dH' "$r" "$left"
    echo -ne "${C_YELLOW}${C_BOLD}║${C_RESET}"
    echo -ne "${C_RED}${C_BOLD}"
    printf '%*s' $((wagon_width - 2)) '' | tr ' ' '▓'
    echo -ne "${C_RESET}"
    echo -ne "${C_YELLOW}${C_BOLD}║${C_RESET}"

    # 底部フレーム（タイヤ込み）
    r=$((r + 1))
    printf '\033[%d;%dH' "$r" "$left"
    echo -ne "${C_YELLOW}${C_BOLD}"
    printf '╚════'; echo -ne "${C_RESET}"
    echo -ne "${C_DIM}●●${C_RESET}"
    echo -ne "${C_YELLOW}${C_BOLD}"
    printf '%*s' $((wagon_width - 16)) '' | tr ' ' '═'
    echo -ne "${C_RESET}"
    echo -ne "${C_DIM}●●${C_RESET}"
    echo -ne "${C_YELLOW}${C_BOLD}══╝${C_RESET}"
}

# スクロール道路
draw_road() {
    local road_row=$1
    local offset=$2
    local cols=$TERM_COLS

    # 地平線
    printf '\033[%d;1H\033[K' "$road_row"
    echo -ne "${C_GREEN}${C_DIM}"
    printf '%*s' "$cols" '' | tr ' ' '~'
    echo -ne "${C_RESET}"

    # 道路（2行）
    local r
    for ((r = road_row + 1; r <= road_row + 2; r++)); do
        printf '\033[%d;1H\033[K' "$r"
        local c
        for ((c = 1; c <= cols; c++)); do
            local pos=$(( (c + offset) % 10 ))
            if ((pos < 2)); then
                echo -ne "${C_WHITE}─${C_RESET}"
            elif ((pos == 5)); then
                echo -ne "${C_YELLOW}|${C_RESET}"
            else
                echo -ne "${C_DIM} ${C_RESET}"
            fi
        done
    done
}

# イベントポップアップ
draw_popup() {
    local msg="$1"
    local msg_len=${#msg}
    local box_width=$((msg_len + 6))
    local left=$(( (TERM_COLS - box_width) / 2 ))
    local row=$(( TERM_ROWS / 2 - 1 ))

    printf '\033[%d;%dH' "$row" "$left"
    echo -ne "${C_BRIGHT_YELLOW}${C_BOLD}"
    printf '╔'; printf '%*s' $((box_width - 2)) '' | tr ' ' '═'; printf '╗'
    echo -ne "${C_RESET}"

    printf '\033[%d;%dH' $((row + 1)) "$left"
    echo -ne "${C_BRIGHT_YELLOW}${C_BOLD}║  ${C_RESET}"
    echo -ne "${C_WHITE}${C_BOLD}"
    printf '%-*s' "$msg_len" "$msg"
    echo -ne "${C_RESET}"
    echo -ne "${C_BRIGHT_YELLOW}${C_BOLD}  ║${C_RESET}"

    printf '\033[%d;%dH' $((row + 2)) "$left"
    echo -ne "${C_BRIGHT_YELLOW}${C_BOLD}"
    printf '╚'; printf '%*s' $((box_width - 2)) '' | tr ' ' '═'; printf '╝'
    echo -ne "${C_RESET}"
}

# イベントログパネル
draw_event_log() {
    local log_row=$((TERM_ROWS - 6))

    printf '\033[%d;1H\033[K' "$log_row"
    echo -ne "${C_MAGENTA}${C_BOLD}"
    printf '── 恋愛ドラマ最新情報 '
    printf '%*s' $((TERM_COLS - 22)) '' | tr ' ' '─'
    echo -ne "${C_RESET}"

    local total=${#event_log[@]}
    local start=$((total - 4))
    ((start < 0)) && start=0
    local i
    for ((i = 0; i < 4; i++)); do
        printf '\033[%d;1H\033[K' $((log_row + 1 + i))
        local idx=$((start + i))
        if ((idx < total)); then
            echo -ne "${C_DIM}  ▶ ${C_RESET}"
            echo -ne "${C_WHITE}${event_log[$idx]}${C_RESET}"
        fi
    done

    printf '\033[%d;1H\033[K' $((TERM_ROWS - 1))
    echo -ne "${C_DIM}"
    printf '%*s' "$TERM_COLS" '' | tr ' ' '─'
    echo -ne "${C_RESET}"

    printf '\033[%d;1H\033[K' "$TERM_ROWS"
    echo -ne "${C_DIM}  [Space] イベント発生  [Q] 終了  ─  あいのり LOVE WAGON v${VERSION}${C_RESET}"
}

# ===== タイトル画面 =====

show_title() {
    clear_screen
    update_terminal_size
    local mr=$((TERM_ROWS / 2))

    print_center "♥ ♡ ♥ ♡ ♥ ♡ ♥ ♡ ♥ ♡ ♥ ♡ ♥ ♡ ♥ ♡ ♥ ♡ ♥" $((mr - 7)) "${C_BRIGHT_MAGENTA}"
    print_center ""                                                $((mr - 6)) ""
    print_center "あ  い  の  り"                                  $((mr - 5)) "${C_BRIGHT_YELLOW}${C_BOLD}"
    print_center "LOVE  WAGON  SIMULATOR"                          $((mr - 4)) "${C_BRIGHT_YELLOW}${C_BOLD}"
    print_center ""                                                $((mr - 3)) ""
    print_center "恋して、旅して、ときめいて。"                    $((mr - 2)) "${C_WHITE}${C_BOLD}"
    print_center "世界を走るラブワゴンで繰り広げられる恋愛ドラマ" $((mr - 1)) "${C_DIM}"
    print_center ""                                                $((mr))     ""
    print_center "♥ ♡ ♥ ♡ ♥ ♡ ♥ ♡ ♥ ♡ ♥ ♡ ♥ ♡ ♥ ♡ ♥ ♡ ♥" $((mr + 1)) "${C_BRIGHT_MAGENTA}"
    print_center ""                                                $((mr + 3)) ""
    print_center "[ Space / Enter でスタート ]"                    $((mr + 4)) "${C_BRIGHT_CYAN}${C_BOLD}"
    print_center "[ Q で終了 ]"                                    $((mr + 5)) "${C_DIM}"

    show_cursor
    local key=""
    while true; do
        IFS= read -rsn1 key
        case "$key" in
            ' '|''|$'\n') break ;;
            'q'|'Q') exit 0 ;;
        esac
    done
    hide_cursor
}

# ===== メインアニメーションループ =====

run_love_wagon() {
    local -i event_tick=0
    local -i wagon_row=7      # ワゴン描画開始行
    local -i road_row=17      # 道路開始行

    while true; do
        anim_frame=$((anim_frame + 1))
        road_offset=$((road_offset + 1))
        day=$((1 + anim_frame / 80))
        total_distance=$((anim_frame * 2))

        # キー入力
        local key=""
        IFS= read -rsn1 -t 0.01 key 2>/dev/null || true
        case "$key" in
            'q'|'Q') break ;;
            ' ') trigger_event || true ;;
        esac

        # 自動イベント
        event_tick=$((event_tick + 1))
        if ((event_tick >= EVENT_INTERVAL)); then
            event_tick=0
            trigger_event || true
        fi

        # ポップアップカウントダウン
        ((popup_timer > 0)) && popup_timer=$((popup_timer - 1))

        # ── 描画開始 ──
        printf '\033[H'

        # ヘッダー
        draw_header

        # 空（ハート）
        local r
        for ((r = 4; r <= 6; r++)); do
            printf '\033[%d;1H\033[K' "$r"
        done
        draw_sky "$anim_frame"

        # ワゴン（揺れあり）
        local rock=$(( anim_frame % 6 == 0 ? 1 : 0 ))
        draw_wagon "$wagon_row" "$rock"

        # 道路（スクロール）
        draw_road "$road_row" "$road_offset"

        # ポップアップ
        if ((popup_timer > 0 && ${#popup_msg} > 0)); then
            draw_popup "$popup_msg"
        fi

        # イベントログ
        draw_event_log

        sleep 0.1
    done
}

# ===== メイン処理 =====

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME

あいのり LOVE WAGON シミュレーターを起動します。

操作:
  Space     ランダムイベントを即座に発生させる
  Q         終了

バージョン: $VERSION
EOF
}

main() {
    case "${1:-}" in
        -h|--help)    show_usage; exit 0 ;;
        -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
    esac

    init_terminal
    show_title
    run_love_wagon
}

main "$@"
