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

    local i
    for (( i=1; i<=TOTAL_SHOTS; i++ )); do
        printf "  %2d本目 → Enter でシュート！ " "$i"
        read -r _

        if shoot; then
            current_score=$(( current_score + 1 ))
            printf "  ${C_GREEN}${C_BOLD}🎯 IN!   (${current_score}/${i})${C_RESET}\n"
        else
            printf "  ${C_RED}✗ MISS  (${current_score}/${i})${C_RESET}\n"
        fi
        sleep 0.2
    done

    # グローバルスコアを更新
    printf -v "$score_var" '%d' "$current_score"

    echo -e "\n  ${color}${C_BOLD}結果: ${current_score} / ${TOTAL_SHOTS} 本${C_RESET}"
    sleep 0.5
}

# ===== ゲームメインループ =====

run_game() {
    echo -e "\n${C_BOLD}${C_YELLOW}  ─── ゲーム開始 ─── 難易度: ${DIFFICULTY_LABEL} / ${TOTAL_SHOTS}本勝負 ───${C_RESET}"

    # プレイヤー1のターン
    player_turn "$P1_NAME" "$C_CYAN"    "P1_SCORE"

    echo -e "\n${C_DIM}  ──────────── 交代 ────────────${C_RESET}"
    printf "  Enter で %s のターン開始 " "$P2_NAME"
    read -r _

    # プレイヤー2のターン
    player_turn "$P2_NAME" "$C_MAGENTA" "P2_SCORE"
}
