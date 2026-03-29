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
