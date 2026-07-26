#!/bin/bash
set -euo pipefail

#
# スロットマシンゲーム
# バージョン: 1.0
#
# ターミナルで遊べるスロットマシンゲーム
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare -i initial_coins=100
declare -i bet_amount=10

# スロットシンボル (絵文字)
declare -a SYMBOLS=("🍒" "🍋" "🍊" "🍇" "⭐" "💎" "🎰" "🃏")
declare -a SYMBOL_NAMES=("チェリー" "レモン" "オレンジ" "グレープ" "スター" "ダイヤ" "セブン" "ジョーカー")

# 配当倍率 (3つ揃い)
declare -A PAYOUTS=(
    [🍒]=3
    [🍋]=4
    [🍊]=5
    [🍇]=8
    [⭐]=10
    [💎]=20
    [🎰]=50
    [🃏]=100
)

# 出現確率重み (合計100)
declare -a WEIGHTS=(25 20 18 15 10 7 4 1)

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション]

スロットマシンゲーム

オプション:
  -h, --help          このヘルプを表示
  -v, --version       バージョン情報を表示
  -c, --coins NUM     初期コイン数 [デフォルト: 100]
  -b, --bet NUM       1回のベット額 [デフォルト: 10]

配当表:
  🍒 チェリー x3   🍋 レモン   x4   🍊 オレンジ x5
  🍇 グレープ x8   ⭐ スター   x10  💎 ダイヤ   x20
  🎰 セブン   x50  🃏 ジョーカー x100

EOF
}

weighted_random() {
    local total=0
    for w in "${WEIGHTS[@]}"; do
        (( total += w )) || true
    done

    local r=$(( RANDOM % total ))
    local cumulative=0
    local i=0
    for w in "${WEIGHTS[@]}"; do
        (( cumulative += w )) || true
        if (( r < cumulative )); then
            echo "$i"
            return
        fi
        (( i++ )) || true
    done
    echo "0"
}

spin_reel() {
    local idx
    idx=$(weighted_random)
    echo "${SYMBOLS[$idx]}"
}

calculate_payout() {
    local s1="$1" s2="$2" s3="$3"
    local bet="$4"

    if [[ "$s1" == "$s2" && "$s2" == "$s3" ]]; then
        local mult="${PAYOUTS[$s1]:-1}"
        echo $(( bet * mult ))
    elif [[ "$s1" == "$s2" || "$s2" == "$s3" || "$s1" == "$s3" ]]; then
        echo $(( bet * 2 ))
    else
        echo "0"
    fi
}

animate_reels() {
    local final1="$1" final2="$2" final3="$3"
    local -i frames=10

    for (( f=0; f<frames; f++ )); do
        local r1 r2 r3
        r1="${SYMBOLS[$(( RANDOM % ${#SYMBOLS[@]} ))]}"
        r2="${SYMBOLS[$(( RANDOM % ${#SYMBOLS[@]} ))]}"
        r3="${SYMBOLS[$(( RANDOM % ${#SYMBOLS[@]} ))]}"

        if (( f >= frames - 3 )); then
            r1="$final1"
        fi
        if (( f >= frames - 2 )); then
            r2="$final2"
        fi
        if (( f >= frames - 1 )); then
            r3="$final3"
        fi

        printf "\r  [ %s | %s | %s ]  " "$r1" "$r2" "$r3"
        sleep 0.08
    done
    echo ""
}

show_paytable() {
    echo ""
    printf "  ${C_BOLD}配当表${C_RESET}\n"
    printf "  %s\n" "$(printf '%.0s-' {1..35})"
    local i=0
    for sym in "${SYMBOLS[@]}"; do
        local name="${SYMBOL_NAMES[$i]}"
        local mult="${PAYOUTS[$sym]}"
        printf "  %s %-10s  ベット x ${C_YELLOW}%d${C_RESET}\n" "$sym" "$name" "$mult"
        (( i++ )) || true
    done
    printf "  %s\n" "$(printf '%.0s-' {1..35})"
    printf "  2つ揃い              ベット x ${C_CYAN}2${C_RESET}\n"
    echo ""
}

play_game() {
    local -i coins="$initial_coins"
    local -i bet="$bet_amount"
    local -i total_spins=0
    local -i total_wins=0
    local -i total_jackpots=0
    local -i max_coins="$coins"

    local cleanup_called=false
    cleanup_slot() {
        $cleanup_called && return
        cleanup_called=true
        show_cursor
        echo ""
        echo ""
        log_info "ゲーム終了"
        printf "  最終コイン: ${C_BOLD}%d${C_RESET}\n" "$coins"
        printf "  総スピン:   ${C_BOLD}%d${C_RESET}\n" "$total_spins"
        printf "  勝利回数:   ${C_BOLD}%d${C_RESET}\n" "$total_wins"
        printf "  最大所持:   ${C_BOLD}%d${C_RESET}\n" "$max_coins"
        if (( total_spins > 0 )); then
            local win_rate=$(( total_wins * 100 / total_spins ))
            printf "  勝率:       ${C_BOLD}%d%%${C_RESET}\n" "$win_rate"
        fi
        echo ""
    }
    trap cleanup_slot EXIT INT TERM

    hide_cursor
    clear_screen

    while true; do
        clear_screen

        # ヘッダー
        print_center "🎰  スロットマシン  🎰" 1 "$C_YELLOW"
        draw_separator 2

        move_cursor 3 2
        printf "  コイン: ${C_YELLOW}${C_BOLD}%d${C_RESET}  |  ベット: ${C_CYAN}%d${C_RESET}  |  スピン: %d  |  勝利: %d" \
            "$coins" "$bet" "$total_spins" "$total_wins"

        move_cursor 5 2
        echo "  ╔═══════════════════════╗"
        move_cursor 6 2
        echo "  ║  [ ? | ? | ? ]        ║"
        move_cursor 7 2
        echo "  ╚═══════════════════════╝"

        show_paytable

        move_cursor 20 2
        printf "${C_DIM}[Enter]=スピン  [+]=ベット増  [-]=ベット減  [q]=終了${C_RESET}"

        move_cursor 21 2
        printf "> "

        if (( coins < bet )); then
            move_cursor 22 2
            printf "${C_RED}コインが不足しています！${C_RESET}\n"
            sleep 2
            break
        fi

        local key=""
        IFS= read -r -s -n1 key || true

        case "${key:-}" in
            q|Q) break ;;
            "+") (( bet < coins )) && (( bet += 10 )) || true; continue ;;
            "-") (( bet > 10 )) && (( bet -= 10 )) || true; continue ;;
            "") ;;  # Enter
            *) continue ;;
        esac

        (( coins -= bet )) || true
        (( total_spins++ )) || true

        local r1 r2 r3
        r1=$(spin_reel)
        r2=$(spin_reel)
        r3=$(spin_reel)

        # アニメーション
        move_cursor 6 2
        printf "  ║  "
        animate_reels "$r1" "$r2" "$r3"

        move_cursor 6 2
        printf "  ║  [ %s | %s | %s ]        \n" "$r1" "$r2" "$r3"

        local payout
        payout=$(calculate_payout "$r1" "$r2" "$r3" "$bet")

        move_cursor 9 2
        if (( payout > 0 )); then
            (( coins += payout )) || true
            (( total_wins++ )) || true
            (( payout >= bet * 20 )) && (( total_jackpots++ )) || true
            (( coins > max_coins )) && max_coins=$coins || true

            if (( payout >= bet * 20 )); then
                printf "${C_YELLOW}${C_BOLD}🎊 JACKPOT!! +%d コイン 🎊${C_RESET}" "$payout"
            elif (( payout >= bet * 5 )); then
                printf "${C_GREEN}${C_BOLD}✨ BIG WIN! +%d コイン ✨${C_RESET}" "$payout"
            else
                printf "${C_GREEN}WIN! +%d コイン${C_RESET}" "$payout"
            fi
        else
            printf "${C_RED}ハズレ... -%d コイン${C_RESET}" "$bet"
        fi

        sleep 1
    done
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -c|--coins)   [[ $# -lt 2 ]] && error_exit "-c には値が必要です"; initial_coins="$2"; shift 2 ;;
            -b|--bet)     [[ $# -lt 2 ]] && error_exit "-b には値が必要です"; bet_amount="$2"; shift 2 ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  shift ;;
        esac
    done
}

main() {
    parse_arguments "$@"
    play_game
}

main "$@"
