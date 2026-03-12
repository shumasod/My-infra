#!/bin/bash
set -euo pipefail

#
# logging打ち落としシューティングゲーム
# 作成日: 2026-03-12
# バージョン: 1.0
#
# 落ちてくるログメッセージを撃ち落とすターミナルシューティングゲーム
# ←→キー（またはA/Dキー）で移動、スペースキーで射撃
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

# ===== 設定（定数） =====
readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"
readonly MAX_LIVES=3
readonly MAX_BULLETS=5
readonly SPAWN_INTERVAL_BASE=35  # ログ出現間隔（フレーム数）
readonly FRAME_SLEEP="0.05"      # フレーム間隔（秒）≒20fps

# ログタイプ定義
readonly -a LOG_NAMES=("DEBUG" "INFO " "WARN " "ERROR" "CRIT!")
readonly -a LOG_SCORES=(10 20 40 70 100)
readonly -a LOG_SPEEDS=(4 3 3 2 1)  # Nフレームに1回落下（小さいほど速い）

# ログカラー（lib/common.sh の C_* 定数を使用）
declare -a LOG_COLORS=(
    "${C_DIM}"                   # DEBUG - 薄灰色
    "${C_CYAN}"                  # INFO  - シアン
    "${C_YELLOW}"                # WARN  - 黄色
    "${C_RED}"                   # ERROR - 赤
    "${C_BRIGHT_MAGENTA}"        # CRIT! - マゼンタ
)

# ===== グローバル変数 =====
declare -i ROWS=24 COLS=80
declare -i GAME_TOP=3 PLAYER_ROW=22 GAME_BOTTOM=21
declare -i score=0 lives=0 frame=0 game_running=1
declare -i player_col=40

# ログオブジェクト（並列配列）
declare -a log_cols=() log_rows=() log_types=() log_born=()
declare -i log_count=0

# 弾オブジェクト（並列配列）
declare -a bul_cols=() bul_rows=()
declare -i bul_count=0

# 爆発エフェクト（並列配列）
declare -a boom_cols=() boom_rows=() boom_born=()
declare -i boom_count=0

# ===== ターミナル制御 =====

cleanup() {
    show_cursor
    printf '\033[?1049l'           # メイン画面に戻る
    stty echo   2>/dev/null || true
    stty icanon 2>/dev/null || true
}
trap cleanup EXIT INT TERM

init_game_terminal() {
    printf '\033[?1049h'           # 代替スクリーンバッファへ切り替え
    hide_cursor
    stty -echo   2>/dev/null || true
    stty -icanon min 0 time 0 2>/dev/null || true
    update_terminal_size
    ROWS=${TERM_ROWS}
    COLS=${TERM_COLS}
    GAME_TOP=3
    PLAYER_ROW=$((ROWS - 2))
    GAME_BOTTOM=$((ROWS - 3))
}

# ===== 入力処理 =====

process_input() {
    local key=""
    IFS= read -rsn1 -t 0.01 key 2>/dev/null || return 0

    # エスケープシーケンス（矢印キー）
    if [[ "$key" == $'\x1b' ]]; then
        local seq=""
        IFS= read -rsn2 -t 0.05 seq 2>/dev/null || true
        case "$seq" in
            '[D') ((player_col > 3))        && player_col=$((player_col - 2)) ;;  # ←
            '[C') ((player_col < COLS - 3)) && player_col=$((player_col + 2)) ;;  # →
        esac
        return 0
    fi

    case "$key" in
        ' ')          # スペース: 射撃
            if ((bul_count < MAX_BULLETS)); then
                bul_cols+=("$player_col")
                bul_rows+=("$((PLAYER_ROW - 1))")
                bul_count=$((bul_count + 1))
            fi
            ;;
        'a'|'A')      # ←移動
            ((player_col > 3))        && player_col=$((player_col - 2))
            ;;
        'd'|'D')      # →移動
            ((player_col < COLS - 3)) && player_col=$((player_col + 2))
            ;;
        'q'|'Q')      # 終了
            game_running=0
            ;;
    esac
}

# ===== ゲームロジック =====

spawn_log() {
    # 出現確率（重み付き）
    local rand=$((RANDOM % 100))
    local type
    if   ((rand < 40)); then type=0   # DEBUG  40%
    elif ((rand < 70)); then type=1   # INFO   30%
    elif ((rand < 85)); then type=2   # WARN   15%
    elif ((rand < 95)); then type=3   # ERROR  10%
    else                     type=4   # CRIT!   5%
    fi

    local col=$((RANDOM % (COLS - 10) + 2))
    log_cols+=("$col")
    log_rows+=("$GAME_TOP")
    log_types+=("$type")
    log_born+=("$frame")
    log_count=$((log_count + 1))
}

update_logs() {
    local i
    local -a nc=() nr=() nt=() nb=()
    local -i new_count=0

    for ((i = 0; i < log_count; i++)); do
        local type=${log_types[$i]}
        local speed=${LOG_SPEEDS[$type]}
        local born=${log_born[$i]}

        # speedフレームに1回、1行落下
        if (((frame - born) % speed == 0)); then
            log_rows[$i]=$((${log_rows[$i]} + 1))
        fi

        if ((log_rows[$i] > GAME_BOTTOM)); then
            # 画面外に出た → 残機を減らす
            lives=$((lives - 1))
            ((lives <= 0)) && { lives=0; game_running=0; }
        else
            nc+=("${log_cols[$i]}")
            nr+=("${log_rows[$i]}")
            nt+=("${log_types[$i]}")
            nb+=("${log_born[$i]}")
            new_count=$((new_count + 1))
        fi
    done

    log_cols=("${nc[@]+"${nc[@]}"}")
    log_rows=("${nr[@]+"${nr[@]}"}")
    log_types=("${nt[@]+"${nt[@]}"}")
    log_born=("${nb[@]+"${nb[@]}"}")
    log_count=$new_count
}

update_bullets() {
    local i
    local -a nc=() nr=()
    local -i new_count=0

    for ((i = 0; i < bul_count; i++)); do
        bul_rows[$i]=$((${bul_rows[$i]} - 2))   # 弾は2行/フレームで上昇
        if ((bul_rows[$i] >= GAME_TOP)); then
            nc+=("${bul_cols[$i]}")
            nr+=("${bul_rows[$i]}")
            new_count=$((new_count + 1))
        fi
    done

    bul_cols=("${nc[@]+"${nc[@]}"}")
    bul_rows=("${nr[@]+"${nr[@]}"}")
    bul_count=$new_count
}

check_collisions() {
    local bi li
    local -a hit_b=() hit_l=()

    for ((bi = 0; bi < bul_count; bi++)); do
        for ((li = 0; li < log_count; li++)); do
            local brow=${bul_rows[$bi]}
            local bcol=${bul_cols[$bi]}
            local lrow=${log_rows[$li]}
            local lcol=${log_cols[$li]}

            # 当たり判定: "[XXXX]" は7文字幅
            if ((brow == lrow && bcol >= lcol && bcol < lcol + 7)); then
                hit_b+=("$bi")
                hit_l+=("$li")
                local type=${log_types[$li]}
                score=$((score + LOG_SCORES[$type]))
                # 爆発エフェクトを登録
                boom_cols+=("$lcol")
                boom_rows+=("$lrow")
                boom_born+=("$frame")
                boom_count=$((boom_count + 1))
                break  # 1弾1ログ
            fi
        done
    done

    ((${#hit_b[@]} > 0)) && _remove_indexed "bul" "${hit_b[@]}"
    ((${#hit_l[@]} > 0)) && _remove_indexed "log" "${hit_l[@]}"
    return 0
}

# 指定インデックスの要素を配列から削除
_remove_indexed() {
    local target="$1"; shift
    local -A rm=()
    local idx
    for idx in "$@"; do rm[$idx]=1; done

    if [[ "$target" == "bul" ]]; then
        local -a nc=() nr=()
        local -i new_count=0
        for ((idx = 0; idx < bul_count; idx++)); do
            if [[ -z "${rm[$idx]+x}" ]]; then
                nc+=("${bul_cols[$idx]}")
                nr+=("${bul_rows[$idx]}")
                new_count=$((new_count + 1))
            fi
        done
        bul_cols=("${nc[@]+"${nc[@]}"}")
        bul_rows=("${nr[@]+"${nr[@]}"}")
        bul_count=$new_count
    else
        local -a nc=() nr=() nt=() nb=()
        local -i new_count=0
        for ((idx = 0; idx < log_count; idx++)); do
            if [[ -z "${rm[$idx]+x}" ]]; then
                nc+=("${log_cols[$idx]}")
                nr+=("${log_rows[$idx]}")
                nt+=("${log_types[$idx]}")
                nb+=("${log_born[$idx]}")
                new_count=$((new_count + 1))
            fi
        done
        log_cols=("${nc[@]+"${nc[@]}"}")
        log_rows=("${nr[@]+"${nr[@]}"}")
        log_types=("${nt[@]+"${nt[@]}"}")
        log_born=("${nb[@]+"${nb[@]}"}")
        log_count=$new_count
    fi
}

cleanup_booms() {
    local -a nc=() nr=() nb=()
    local -i new_count=0 i
    for ((i = 0; i < boom_count; i++)); do
        if (((frame - boom_born[$i]) <= 4)); then
            nc+=("${boom_cols[$i]}")
            nr+=("${boom_rows[$i]}")
            nb+=("${boom_born[$i]}")
            new_count=$((new_count + 1))
        fi
    done
    boom_cols=("${nc[@]+"${nc[@]}"}")
    boom_rows=("${nr[@]+"${nr[@]}"}")
    boom_born=("${nb[@]+"${nb[@]}"}")
    boom_count=$new_count
}

# ===== 描画 =====

draw_hearts() {
    local result="" i
    for ((i = 0; i < lives; i++));     do result+="♥"; done
    for ((i = lives; i < MAX_LIVES; i++)); do result+="♡"; done
    printf '%b%s%b' "${C_RED}" "$result" "${C_RESET}"
}

draw_frame() {
    # ホームへ移動（クリアより速い）
    printf '\033[H'

    # ── ヘッダー ──
    printf '\033[K'
    printf '%b  ★ LOGGING SHOOTER ★%b' "${C_BOLD}${C_CYAN}" "${C_RESET}"
    printf '\033[1;%dH' $((COLS - 25))
    printf '%bSCORE: %06d%b' "${C_YELLOW}${C_BOLD}" "$score" "${C_RESET}"
    printf '\033[1;%dH' $((COLS - 8))
    draw_hearts

    # セパレータ
    printf '\033[2;1H\033[K'
    printf '%*s' "$COLS" '' | tr ' ' '─'

    # ゲームエリアをクリア
    local row
    for ((row = GAME_TOP; row <= PLAYER_ROW; row++)); do
        printf '\033[%d;1H\033[K' "$row"
    done

    # 爆発エフェクト（ログより先に描画）
    local i
    for ((i = 0; i < boom_count; i++)); do
        local brow=${boom_rows[$i]}
        local bcol=${boom_cols[$i]}
        local age=$((frame - boom_born[$i]))
        if ((brow >= GAME_TOP && brow <= GAME_BOTTOM)); then
            printf '\033[%d;%dH' "$brow" "$bcol"
            if ((age <= 2)); then
                printf '%b<***>%b' "${C_BRIGHT_YELLOW}${C_BOLD}" "${C_RESET}"
            else
                printf '%b ~~ %b' "${C_YELLOW}" "${C_RESET}"
            fi
        fi
    done

    # ログを描画
    for ((i = 0; i < log_count; i++)); do
        local lrow=${log_rows[$i]}
        local lcol=${log_cols[$i]}
        local ltype=${log_types[$i]}
        if ((lrow >= GAME_TOP && lrow <= GAME_BOTTOM)); then
            printf '\033[%d;%dH%b[%s]%b' \
                "$lrow" "$lcol" \
                "${LOG_COLORS[$ltype]}" \
                "${LOG_NAMES[$ltype]}" \
                "${C_RESET}"
        fi
    done

    # 弾を描画
    for ((i = 0; i < bul_count; i++)); do
        local brow=${bul_rows[$i]}
        local bcol=${bul_cols[$i]}
        if ((brow >= GAME_TOP && brow <= GAME_BOTTOM)); then
            printf '\033[%d;%dH%b|%b' "$brow" "$bcol" "${C_BRIGHT_YELLOW}" "${C_RESET}"
        fi
    done

    # 自機を描画
    printf '\033[%d;%dH%b[^]%b' \
        "$PLAYER_ROW" "$((player_col - 1))" \
        "${C_BRIGHT_CYAN}${C_BOLD}" "${C_RESET}"

    # ── フッター ──
    printf '\033[%d;1H\033[K' $((ROWS - 1))
    printf '%*s' "$COLS" '' | tr ' ' '─'
    printf '\033[%d;1H\033[K' "$ROWS"
    printf '%b[←→/AD] 移動  [Space] 射撃  [Q] 終了%b' "${C_DIM}" "${C_RESET}"
}

# ===== ゲーム画面 =====

show_title() {
    clear_screen
    update_terminal_size
    local mr=$((TERM_ROWS / 2))
    print_center "╔═════════════════════════════════════════╗" $((mr - 7)) "${C_CYAN}"
    print_center "║                                         ║" $((mr - 6)) "${C_CYAN}"
    print_center "║    L O G G I N G   S H O O T E R       ║" $((mr - 5)) "${C_BOLD}${C_CYAN}"
    print_center "║                                         ║" $((mr - 4)) "${C_CYAN}"
    print_center "╚═════════════════════════════════════════╝" $((mr - 3)) "${C_CYAN}"
    print_center "落ちてくるログメッセージを撃ち落とせ！"     $((mr - 1)) "${C_YELLOW}${C_BOLD}"
    print_center "── スコア表 ──"                             $((mr + 1)) "${C_GREEN}"
    print_center "[DEBUG]+10  [INFO ]+20  [WARN ]+40  [ERROR]+70  [CRIT!]+100" \
        $((mr + 2)) "${C_GREEN}"
    print_center "── 操作方法 ──"                             $((mr + 4)) "${C_DIM}"
    print_center "← → / A D : 移動       Space : 射撃       Q : 終了" \
        $((mr + 5)) "${C_DIM}"
    print_center "[ Space または Enter でスタート ]"           $((mr + 7)) "${C_BRIGHT_CYAN}${C_BOLD}"
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

show_game_over() {
    # ゲームオーバー画面。リトライなら0、終了なら1を返す
    clear_screen
    update_terminal_size
    local mr=$((TERM_ROWS / 2))
    print_center "╔═══════════════════════════════════╗" $((mr - 4)) "${C_RED}"
    print_center "║                                   ║" $((mr - 3)) "${C_RED}"
    print_center "║       G A M E  O V E R           ║" $((mr - 2)) "${C_RED}${C_BOLD}"
    print_center "║                                   ║" $((mr - 1)) "${C_RED}"
    print_center "╚═══════════════════════════════════╝" $((mr))     "${C_RED}"
    print_center "最終スコア:  ${score}  点"               $((mr + 2)) "${C_YELLOW}${C_BOLD}"
    print_center "[ R / Enter ]  もう一度    [ Q ]  終了"  $((mr + 5)) "${C_DIM}"
    show_cursor
    local key=""
    while true; do
        IFS= read -rsn1 key
        case "$key" in
            'r'|'R'|''|$'\n') hide_cursor; return 0 ;;
            'q'|'Q')          return 1 ;;
        esac
    done
}

# ===== ゲームリセット =====

reset_game() {
    score=0
    lives=$MAX_LIVES
    frame=0
    game_running=1
    player_col=$((COLS / 2))

    log_cols=(); log_rows=(); log_types=(); log_born=()
    log_count=0

    bul_cols=(); bul_rows=()
    bul_count=0

    boom_cols=(); boom_rows=(); boom_born=()
    boom_count=0
}

# ===== メインゲームループ =====

run_game() {
    reset_game
    local -i spawn_interval=$SPAWN_INTERVAL_BASE

    while ((game_running)); do
        frame=$((frame + 1))

        # 入力処理
        process_input

        # ログ出現間隔（スコアが上がるほど頻繁に）
        spawn_interval=$((SPAWN_INTERVAL_BASE - score / 300))
        ((spawn_interval < 8)) && spawn_interval=8

        if ((frame % spawn_interval == 0 && log_count < 15)); then
            spawn_log
        fi

        # ゲームオブジェクトの更新
        update_logs
        update_bullets
        check_collisions
        cleanup_booms

        # 描画
        draw_frame

        # フレームレート制御
        sleep "$FRAME_SLEEP"
    done
}

# ===== メイン処理 =====

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME

logging打ち落としシューティングゲームを起動します。

操作:
  ← / A     左に移動
  → / D     右に移動
  Space     射撃
  Q         終了

スコア:
  [DEBUG]  +10点   [INFO ] +20点   [WARN ] +40点
  [ERROR]  +70点   [CRIT!] +100点

バージョン: $VERSION
EOF
}

main() {
    case "${1:-}" in
        -h|--help)    show_usage; exit 0 ;;
        -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
    esac

    init_game_terminal
    show_title

    while true; do
        run_game
        show_game_over || break
    done
}

main "$@"
