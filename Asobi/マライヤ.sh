#!/bin/bash

# =============================================================================
# 🎄 All I Want for Christmas Is You - Beep Version
# =============================================================================
# マライア・キャリーの名曲をbeep音で演奏
# Usage: ./all_i_want.sh
# =============================================================================

set -euo pipefail

# カラー定義
readonly RED='\033[0;31m'
readonly BRIGHT_RED='\033[1;31m'
readonly YELLOW='\033[1;33m'
readonly GREEN='\033[0;32m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly MAGENTA='\033[0;35m'
readonly RESET='\033[0m'

# 音符の周波数（Hz）
declare -A NOTES=(
    # オクターブ 3
    ["G3"]=196  ["A3"]=220  ["B3"]=247
    # オクターブ 4
    ["C4"]=262  ["Cs4"]=277 ["D4"]=294  ["Ds4"]=311 ["E4"]=330
    ["F4"]=349  ["Fs4"]=370 ["G4"]=392  ["Gs4"]=415 ["A4"]=440
    ["As4"]=466 ["B4"]=494
    # オクターブ 5
    ["C5"]=523  ["Cs5"]=554 ["D5"]=587  ["Ds5"]=622 ["E5"]=659
    ["F5"]=698  ["Fs5"]=740 ["G5"]=784  ["Gs5"]=831 ["A5"]=880
    ["As5"]=932 ["B5"]=988
    # オクターブ 6
    ["C6"]=1047
    # 休符
    ["REST"]=0
)

# BPM設定（原曲は約150 BPM）
BPM=140
BEAT_MS=$((60000 / BPM))

# 音を鳴らす関数
play_note() {
    local note=$1
    local beats=$2
    local duration=$((BEAT_MS * beats / 4))  # 16分音符基準
    local freq="${NOTES[$note]:-0}"
    
    if [[ $freq -eq 0 ]]; then
        sleep "$(echo "scale=3; $duration/1000" | bc)"
        return
    fi
    
    if command -v beep &>/dev/null; then
        beep -f "$freq" -l "$duration" 2>/dev/null || true
    elif command -v play &>/dev/null; then
        # sox使用
        play -n synth "$(echo "scale=3; $duration/1000" | bc)" sine "$freq" 2>/dev/null || true
    elif [[ -w /dev/tty ]]; then
        echo -ne "\a"
        sleep "$(echo "scale=3; $duration/1000" | bc)"
    else
        sleep "$(echo "scale=3; $duration/1000" | bc)"
    fi
}

# 歌詞表示しながら演奏
show_lyrics() {
    local line=$1
    local color=$2
    echo -e "${color}♪ ${line}${RESET}"
}

# イントロのベル音
play_intro_bells() {
    echo -e "${YELLOW}🔔 *sleigh bells* 🔔${RESET}"
    for _ in {1..4}; do
        play_note "E5" 2
        play_note "E5" 2
        play_note "REST" 2
    done
}

# サビ: "I don't want a lot for Christmas"
play_verse1() {
    show_lyrics "I don't want a lot for Christmas..." "${CYAN}"
    
    # "I don't want a lot for Christ-mas"
    play_note "G4" 4      # I
    play_note "G4" 2      # don't
    play_note "A4" 2      # want
    play_note "G4" 2      # a
    play_note "G4" 2      # lot
    play_note "E4" 2      # for
    play_note "E4" 4      # Christ-
    play_note "D4" 4      # mas
    play_note "REST" 4
}

# "There is just one thing I need"
play_verse2() {
    show_lyrics "There is just one thing I need..." "${CYAN}"
    
    play_note "G4" 4      # There
    play_note "G4" 2      # is
    play_note "A4" 2      # just
    play_note "G4" 2      # one
    play_note "G4" 2      # thing
    play_note "E4" 2      # I
    play_note "E4" 4      # need
    play_note "REST" 8
}

# "I don't care about the presents"
play_verse3() {
    show_lyrics "I don't care about the presents..." "${CYAN}"
    
    play_note "G4" 4      # I
    play_note "G4" 2      # don't
    play_note "A4" 2      # care
    play_note "G4" 2      # a-
    play_note "G4" 2      # bout
    play_note "E4" 2      # the
    play_note "E4" 4      # pre-
    play_note "D4" 4      # sents
    play_note "REST" 4
}

# "Underneath the Christmas tree"
play_verse4() {
    show_lyrics "Underneath the Christmas tree..." "${CYAN}"
    
    play_note "G4" 4      # Un-
    play_note "G4" 2      # der-
    play_note "A4" 2      # neath
    play_note "G4" 2      # the
    play_note "G4" 2      # Christ-
    play_note "E4" 2      # mas
    play_note "E4" 4      # tree
    play_note "REST" 8
}

# サビ: "All I want for Christmas is you"
play_chorus() {
    show_lyrics "🎄 ALL I WANT FOR CHRISTMAS IS YOU! 🎄" "${BRIGHT_RED}"
    
    # "All I want for Christmas is you"
    play_note "C5" 6      # All
    play_note "REST" 2
    play_note "C5" 4      # I
    play_note "B4" 4      # want
    play_note "A4" 4      # for
    play_note "G4" 4      # Christ-
    play_note "A4" 4      # mas
    play_note "REST" 4
    play_note "B4" 6      # is
    play_note "REST" 2
    play_note "C5" 8      # you
    play_note "REST" 4
    
    # "You, baby"
    show_lyrics "You... baby~" "${MAGENTA}"
    play_note "E5" 6      # You
    play_note "D5" 6
    play_note "C5" 6      # ba-
    play_note "B4" 6      # by
    play_note "REST" 8
}

# フックの部分 "I just want you for my own"
play_hook() {
    show_lyrics "I just want you for my own..." "${GREEN}"
    
    play_note "E4" 4      # I
    play_note "Fs4" 4     # just
    play_note "G4" 4      # want
    play_note "A4" 4      # you
    play_note "G4" 4      # for
    play_note "Fs4" 4     # my
    play_note "E4" 8      # own
    play_note "REST" 4
}

# "More than you could ever know"
play_hook2() {
    show_lyrics "More than you could ever know..." "${GREEN}"
    
    play_note "E4" 4      # More
    play_note "Fs4" 4     # than
    play_note "G4" 4      # you
    play_note "A4" 4      # could
    play_note "B4" 4      # e-
    play_note "A4" 4      # ver
    play_note "G4" 8      # know
    play_note "REST" 4
}

# "Make my wish come true"
play_hook3() {
    show_lyrics "Make my wish come true..." "${YELLOW}"
    
    play_note "C5" 6      # Make
    play_note "B4" 4      # my
    play_note "A4" 4      # wish
    play_note "G4" 4      # come
    play_note "A4" 8      # true
    play_note "REST" 4
}

# 最後のサビ
play_final_chorus() {
    echo ""
    show_lyrics "🎄✨ ALL I WANT FOR CHRISTMAS... ✨🎄" "${BRIGHT_RED}"
    
    play_note "C5" 8      # All
    play_note "C5" 4      # I
    play_note "B4" 4      # want
    play_note "A4" 4      # for
    play_note "G4" 6      # Christ-
    play_note "A4" 4      # mas
    
    sleep 0.3
    show_lyrics "🎁💕 IS YOU!!! 💕🎁" "${MAGENTA}"
    
    play_note "B4" 4      # is
    play_note "C5" 12     # you!!!
    play_note "E5" 8
    play_note "C5" 16
    play_note "REST" 8
}

# アウトロ
play_outro() {
    echo ""
    echo -e "${YELLOW}🔔 *sleigh bells fade out* 🔔${RESET}"
    
    for i in {1..3}; do
        play_note "E5" 2
        play_note "E5" 2
        play_note "REST" $((2 + i))
    done
}

# ハートのアニメーション
show_hearts() {
    local hearts=("💕" "❤️" "💖" "💗" "💓" "💝")
    for heart in "${hearts[@]}"; do
        echo -ne "\r${heart}  "
        sleep 0.2
    done
    echo ""
}

# メイン表示
show_title() {
    clear
    echo ""
    echo -e "${RED}╔═══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${RED}║${RESET}                                                               ${RED}║${RESET}"
    echo -e "${RED}║${RESET}   ${YELLOW}🎄${RESET}  ${WHITE}All I Want for Christmas Is You${RESET}  ${YELLOW}🎄${RESET}              ${RED}║${RESET}"
    echo -e "${RED}║${RESET}                                                               ${RED}║${RESET}"
    echo -e "${RED}║${RESET}              ${CYAN}~ Mariah Carey ~${RESET}                              ${RED}║${RESET}"
    echo -e "${RED}║${RESET}                                                               ${RED}║${RESET}"
    echo -e "${RED}║${RESET}         ${MAGENTA}🎵 Beep Version by Claude 🎵${RESET}                     ${RED}║${RESET}"
    echo -e "${RED}║${RESET}                                                               ${RED}║${RESET}"
    echo -e "${RED}╚═══════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    echo -e "${GREEN}Press Ctrl+C to stop${RESET}"
    echo ""
    sleep 1
}

# クリーンアップ
cleanup() {
    echo ""
    echo ""
    echo -e "${YELLOW}🎄 Merry Christmas! 🎄${RESET}"
    show_hearts
    exit 0
}

trap cleanup SIGINT SIGTERM

# メイン
main() {
    show_title
    
    echo -e "${WHITE}Starting in 3...${RESET}"
    sleep 1
    echo -e "${WHITE}2...${RESET}"
    sleep 1
    echo -e "${WHITE}1...${RESET}"
    sleep 1
    echo ""
    
    # イントロ
    play_intro_bells
    echo ""
    
    # Verse
    play_verse1
    play_verse2
    play_verse3
    play_verse4
    
    echo ""
    sleep 0.5
    
    # Hook
    play_hook
    play_hook2
    play_hook3
    
    echo ""
    sleep 0.5
    
    # Chorus
    play_chorus
    
    echo ""
    sleep 0.5
    
    # Final Chorus
    play_final_chorus
    
    # Outro
    play_outro
    
    echo ""
    echo -e "${BRIGHT_RED}╔═══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BRIGHT_RED}║${RESET}                    ${YELLOW}🎄 THE END 🎄${RESET}                           ${BRIGHT_RED}║${RESET}"
    echo -e "${BRIGHT_RED}║${RESET}                                                               ${BRIGHT_RED}║${RESET}"
    echo -e "${BRIGHT_RED}║${RESET}           ${WHITE}Merry Christmas & Happy New Year!${RESET}                ${BRIGHT_RED}║${RESET}"
    echo -e "${BRIGHT_RED}╚═══════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    show_hearts
}

main
