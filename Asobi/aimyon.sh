#!/bin/bash
set -euo pipefail

#
# あいみょん 楽曲ランダム表示
# 作成日: 2026-07-04
# バージョン: 2.0
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="2.0"

# Format: "タイトル:歌詞:シングル名:リリース年:備考"
declare -A SONGS=(
    ["marigold"]="マリーゴールド:風の強さがちょっと心を揺さぶりすぎて まじめに見つめた君が恋しい:Marigold:2018:ブレイクのきっかけとなったシングル"
    ["kimi_rock"]="君はロックを聴かない:少し寂しそうな君に こんな歌を聞かそう 手を叩く合図:君はロックを聴かない:2017:メジャーデビューシングル"
    ["hadaka"]="裸の心:一体このままいつまで 一人でいるつもりだろう だんだん自分を憎んだり:裸の心:2019:オリコン週間1位"
    ["harunohi"]="春の日:北千住駅のplatform 銀色の改札 思い出ばなしと 思い出深し:春の日:2018:春をテーマにした楽曲"
    ["ai"]="愛を伝えたいだとか:健康的な朝だな こんな時に君の「愛してる」が聞きたいや 揺れるカーテン:愛を伝えたいだとか:2019:ラブソング"
)

print_separator_colored() {
    echo -e "\n${C_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}\n"
}

display_song() {
    local song_data="$1"
    local title lyrics single year note
    IFS=':' read -r title lyrics single year note <<< "$song_data"

    print_separator_colored
    echo -e "${C_BOLD}${C_BLUE}♪ ${title}${C_RESET}"
    echo ""
    echo -e "${C_BOLD}歌詞:${C_RESET}"
    echo -e "${C_MAGENTA}${lyrics}${C_RESET}"
    echo ""
    echo -e "${C_BOLD}シングル:${C_RESET}"
    echo -e "${C_CYAN}${single} (${year})${C_RESET}"
    echo ""
    echo -e "${C_BOLD}備考:${C_RESET} ${note}"
    print_separator_colored
}

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション]

あいみょんの楽曲をランダムに表示します。

オプション:
  -h, --help     このヘルプを表示
  -v, --version  バージョン情報を表示
  -a, --all      全曲を表示
EOF
}

main() {
    local show_all=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -a|--all)     show_all=true; shift ;;
            *) error_exit "不明なオプション: $1" ;;
        esac
    done

    echo -e "${C_BOLD}${C_BLUE}Welcome to Aimyon Song Selector!${C_RESET}\n"

    local song_keys=("${!SONGS[@]}")

    if "$show_all"; then
        for key in "${song_keys[@]}"; do
            display_song "${SONGS[$key]}"
        done
    else
        local random_index=$(( RANDOM % ${#song_keys[@]} ))
        local random_key="${song_keys[$random_index]}"
        display_song "${SONGS[$random_key]}"
        echo -e "${C_DIM}もう一度実行すると別の曲が表示されます！${C_RESET}\n"
    fi
}

main "$@"
