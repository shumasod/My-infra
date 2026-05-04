#!/bin/bash
set -euo pipefail

#
# バスケットフリースロー対決
# 作成日: 2026-03-29
# バージョン: 1.0
#
# 2人のプレイヤーがフリースローの本数を競い合うゲームです
# 難易度によってシュートの成功率が変わります
#

# 共通ライブラリの読み込み
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

# ===== 難易度別成功率（%） =====
readonly RATE_EASY=75
readonly RATE_NORMAL=60
readonly RATE_HARD=40

# ===== グローバルゲーム変数 =====
declare    P1_NAME=""
declare    P2_NAME=""
declare -i P1_SCORE=0
declare -i P2_SCORE=0
declare -i TOTAL_SHOTS=10
declare -i SUCCESS_RATE=$RATE_NORMAL
declare    DIFFICULTY_LABEL="ノーマル"

# ===== ゲーム設定（プレイヤー名・難易度・本数） =====

setup_players() {
    echo -e "\n${C_BOLD}${C_YELLOW}  ─── プレイヤー設定 ───${C_RESET}\n"

    while true; do
        printf "  プレイヤー1 の名前を入力: "
        read -r P1_NAME
        [[ -n "$P1_NAME" ]] && break
        echo -e "  ${C_RED}名前を入力してください${C_RESET}"
    done

    while true; do
        printf "  プレイヤー2 の名前を入力: "
        read -r P2_NAME
        [[ -n "$P2_NAME" ]] && break
        echo -e "  ${C_RED}名前を入力してください${C_RESET}"
    done
}

setup_difficulty() {
    echo -e "\n${C_BOLD}${C_YELLOW}  ─── 難易度選択 ───${C_RESET}\n"
    echo -e "  ${C_GREEN}1) イージー    ${C_DIM}(成功率 ${RATE_EASY}%)${C_RESET}"
    echo -e "  ${C_YELLOW}2) ノーマル   ${C_DIM}(成功率 ${RATE_NORMAL}%)${C_RESET}"
    echo -e "  ${C_RED}3) ハード      ${C_DIM}(成功率 ${RATE_HARD}%)${C_RESET}"
    echo ""

    while true; do
        printf "  選択 [1-3]: "
        read -r choice
        case "$choice" in
            1) SUCCESS_RATE=$RATE_EASY;   DIFFICULTY_LABEL="イージー"; break ;;
            2) SUCCESS_RATE=$RATE_NORMAL; DIFFICULTY_LABEL="ノーマル"; break ;;
            3) SUCCESS_RATE=$RATE_HARD;   DIFFICULTY_LABEL="ハード";   break ;;
            *) echo -e "  ${C_RED}1〜3 で選んでください${C_RESET}" ;;
        esac
    done
}

setup_shots() {
    echo -e "\n${C_BOLD}${C_YELLOW}  ─── シュート本数 ───${C_RESET}\n"
    echo -e "  1)  5本"
    echo -e "  2) 10本"
    echo -e "  3) 15本"
    echo ""

    while true; do
        printf "  選択 [1-3]: "
        read -r choice
        case "$choice" in
            1) TOTAL_SHOTS=5;  break ;;
            2) TOTAL_SHOTS=10; break ;;
            3) TOTAL_SHOTS=15; break ;;
            *) echo -e "  ${C_RED}1〜3 で選んでください${C_RESET}" ;;
        esac
    done
}

# ===== シュート判定 =====
# 戻り値: 0=成功 1=失敗（set -e 対策で直接呼び出さず if で使う）

shoot() {
    local rand=$(( RANDOM % 100 + 1 ))
    [ "$rand" -le "$SUCCESS_RATE" ]
}

# ===== スコアボード表示 =====

show_scoreboard() {
    local shot_num="$1"
    echo -e "\n  ${C_DIM}── ${shot_num}本目終了 ── スコア ──────────────────${C_RESET}"
    printf "  %-20s %s%d${C_RESET} / %d本\n" \
        "${P1_NAME}" "${C_CYAN}" "$P1_SCORE" "$shot_num"
    printf "  %-20s %s%d${C_RESET} / %d本\n" \
        "${P2_NAME}" "${C_MAGENTA}" "$P2_SCORE" "$shot_num"
    echo -e "  ${C_DIM}──────────────────────────────────────${C_RESET}\n"
}

# ===== 1プレイヤーの全ターン =====

player_turn() {
    local player_name="$1"
    local color="$2"
    local score_var="$3"   # スコア変数名（P1_SCORE or P2_SCORE）
    local current_score=0

    echo -e "\n${color}${C_BOLD}  ════════════════════════════════════"
    echo -e "  🏀  ${player_name} のターン"
    echo -e "  ════════════════════════════════════${C_RESET}\n"
    sleep 0.5

    show_hoop

    local i
    for (( i=1; i<=TOTAL_SHOTS; i++ )); do
        printf "  %2d本目 → Enter でシュート！ " "$i"
        read -r _

        if shoot; then
            animate_shot "true"
            current_score=$(( current_score + 1 ))
            echo -e "  ${C_GREEN}${C_BOLD}  ✅ ${current_score}本成功 / ${i}本目${C_RESET}"
        else
            animate_shot "false"
            echo -e "  ${C_RED}  ❌ ${current_score}本成功 / ${i}本目${C_RESET}"
        fi
    done

    # グローバルスコアを更新
    printf -v "$score_var" '%d' "$current_score"

    echo -e "\n  ${color}${C_BOLD}結果: ${current_score} / ${TOTAL_SHOTS} 本${C_RESET}"
    sleep 0.5
}

# ===== ASCII アート =====

show_welcome() {
    clear
    echo -e "${C_BOLD}${C_YELLOW}"
    cat <<'EOF'
    ╔══════════════════════════════════════════════════════╗
    ║                                                      ║
    ║    🏀  バスケットフリースロー対決  🏀               ║
    ║                                                      ║
    ║         ___________                                  ║
    ║        |           |                                 ║
    ║     ---+-----------+---                              ║
    ║        |___________|                                 ║
    ║               |                                      ║
    ║               |                                      ║
    ║     ══════════|══════════                            ║
    ║                                                      ║
    ╚══════════════════════════════════════════════════════╝
EOF
    echo -e "${C_RESET}"
    printf "  Enter でスタート！ "
    read -r _
}

show_hoop() {
    echo -e "  ${C_YELLOW}     ___________"
    echo -e "     |           |"
    echo -e "  ---+-----------+---"
    echo -e "     |___________|"
    echo -e "           |"
    echo -e "  ══════════|══════════${C_RESET}"
}

# ボールのアニメーション（シュート前演出）
animate_shot() {
    local success="$1"
    local frames=(
        "🏀                    "
        "  🏀                  "
        "    🏀                "
        "      🏀              "
        "        🏀            "
        "          🏀          "
        "            🏀        "
        "              🏀      "
        "                🏀    "
        "                  🏀  "
    )

    printf "\n"
    for frame in "${frames[@]}"; do
        printf "\r  %s" "$frame"
        sleep 0.06
    done

    if [ "$success" = "true" ]; then
        printf "\r  ${C_GREEN}${C_BOLD}                  🎯  ⭕  IN!!!${C_RESET}\n"
    else
        printf "\r  ${C_RED}${C_BOLD}                  💨  ✗   MISS...${C_RESET}\n"
    fi
    sleep 0.3
}

# ===== 結果画面 =====

show_results() {
    clear
    echo -e "\n${C_BOLD}${C_YELLOW}"
    echo -e "  ╔══════════════════════════════════════════╗"
    echo -e "  ║         🏆  最終結果  🏆                ║"
    echo -e "  ╚══════════════════════════════════════════╝${C_RESET}\n"

    echo -e "  ${C_DIM}難易度: ${DIFFICULTY_LABEL}  /  ${TOTAL_SHOTS}本勝負${C_RESET}\n"

    local p1_pct=$(( P1_SCORE * 100 / TOTAL_SHOTS ))
    local p2_pct=$(( P2_SCORE * 100 / TOTAL_SHOTS ))

    # 成功率バー（20文字幅）
    local p1_bar_len=$(( P1_SCORE * 20 / TOTAL_SHOTS ))
    local p2_bar_len=$(( P2_SCORE * 20 / TOTAL_SHOTS ))
    local p1_bar=""
    local p2_bar=""
    for (( i=0; i<p1_bar_len; i++ ));   do p1_bar="${p1_bar}█"; done
    for (( i=p1_bar_len; i<20; i++ )); do p1_bar="${p1_bar}░"; done
    for (( i=0; i<p2_bar_len; i++ ));   do p2_bar="${p2_bar}█"; done
    for (( i=p2_bar_len; i<20; i++ )); do p2_bar="${p2_bar}░"; done

    printf "  ${C_CYAN}${C_BOLD}%-18s${C_RESET}  ${C_CYAN}%s${C_RESET}  %2d本 (%d%%)\n" \
        "$P1_NAME" "$p1_bar" "$P1_SCORE" "$p1_pct"
    printf "  ${C_MAGENTA}${C_BOLD}%-18s${C_RESET}  ${C_MAGENTA}%s${C_RESET}  %2d本 (%d%%)\n" \
        "$P2_NAME" "$p2_bar" "$P2_SCORE" "$p2_pct"
    echo ""

    # 勝敗判定
    if [ "$P1_SCORE" -gt "$P2_SCORE" ]; then
        echo -e "  ${C_GREEN}${C_BOLD}🏆 優勝: ${P1_NAME}！おめでとう！${C_RESET}"
    elif [ "$P2_SCORE" -gt "$P1_SCORE" ]; then
        echo -e "  ${C_GREEN}${C_BOLD}🏆 優勝: ${P2_NAME}！おめでとう！${C_RESET}"
    else
        echo -e "  ${C_YELLOW}${C_BOLD}🤝 引き分け！ナイスゲーム！${C_RESET}"
    fi
    echo ""
}

# もう一度プレイするか確認
ask_replay() {
    printf "  もう一度プレイしますか？ [y/N]: "
    read -r ans
    [[ "${ans,,}" == "y" ]]
}

# ===== ゲームメインループ =====

run_game() {
    echo -e "\n${C_BOLD}${C_YELLOW}  ─── ゲーム開始 ─── 難易度: ${DIFFICULTY_LABEL} / ${TOTAL_SHOTS}本勝負 ───${C_RESET}"

    # プレイヤー1のターン
    player_turn "$P1_NAME" "$C_CYAN"    "P1_SCORE"

    echo -e "\n${C_DIM}  ──────────── 交代 ────────────${C_RESET}"
    printf "  Enter で ${P2_NAME} のターン開始 "
    read -r _

    # プレイヤー2のターン
    player_turn "$P2_NAME" "$C_MAGENTA" "P2_SCORE"
}

# ===== メイン =====

main() {
    while true; do
        # スコアリセット
        P1_SCORE=0
        P2_SCORE=0

        show_welcome
        setup_players
        setup_difficulty
        setup_shots

        run_game
        show_results

        ask_replay || break
    done

    echo -e "\n  ${C_CYAN}またいつでも挑戦してください！🏀${C_RESET}\n"
}

main "$@"
