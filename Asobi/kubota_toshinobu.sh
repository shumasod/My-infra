#!/bin/bash
set -euo pipefail

#
# 久保田利伸 歌詞ランダム表示スクリプト
# 作成日: 2026-03-29
# バージョン: 1.0
#
# 久保田利伸の名曲の歌詞フレーズをランダムに表示します
#
# 使用方法:
#   ./kubota_toshinobu.sh          # ランダムに1フレーズ表示
#   ./kubota_toshinobu.sh -i       # インタラクティブモード（Enterで次へ）
#   ./kubota_toshinobu.sh -a       # 全フレーズ一覧表示
#   ./kubota_toshinobu.sh -h       # ヘルプ表示
#

# 共通ライブラリの読み込み
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

# ===== 曲データ定義 =====
# フォーマット: "曲名:リリース年:歌詞フレーズ"

readonly -a SONGS=(
    "LA・LA・LA LOVE SONG:1996:La la la la la la la love song♪ 今すぐ君に会いたくて 心がはやる"
    "LA・LA・LA LOVE SONG:1996:二人は出逢うべくして出逢ったんだよ きっとそうさ 君に恋した理由はわかんないけれど"
    "Missing:1994:Missing you... いつでも気軽に笑えたのは そばにいたからだろ"
    "Missing:1994:君がいなくなってはじめて気がついた こんなにも大切だって"
    "そばにいたい:1991:そばにいたい ただ そばにいたい それだけでいい 君のそばにいたい"
    "そばにいたい:1991:どんな言葉より どんな涙より 君のそばにいることが 俺の答えだから"
    "太陽のKiss:1992:忘れないで 太陽のKiss あの夏の輝きを 二人だけのsecret"
    "太陽のKiss:1992:砂浜に描いた夢は 波に消えても 心に刻まれた あの日のままで"
    "You were mine:1993:You were mine 君は僕のものだった あの頃は信じてた 永遠に続くって"
    "You were mine:1993:時が流れて変わっていくものと 変わらないものがある 君への想いは変わらない"
    "Shake It Paradise:1991:Shake it paradise 踊れ 夜が明けるまで 止まるな止まるな"
    "Shake It Paradise:1991:この胸の高鳴りは誰にも止められない さあ行こうぜ paradise"
    "永遠に愛してる:1995:永遠に愛してる この言葉に嘘はない 君と歩む未来を信じてる"
    "永遠に愛してる:1995:出逢えてよかった 君がいるから 明日も頑張れる 永遠に愛してる"
    "Still In Love:1997:Still in love まだ愛してる 時が経っても 色褪せない想い"
    "Still In Love:1997:離れていても 君の声が聞こえる気がして 振り返れば いつでもそこに"
    "愛してない:1989:愛してない なんて言えない 本当は誰より 君を想ってる"
    "愛してない:1989:強がって見せても 心の奥じゃ ずっと君のそばにいたかった"
    "FUNKASTIC:1998:Funk it up もっと上へ どこまでも飛んでいけ 限界なんてない"
    "FUNKASTIC:1998:魂に火をつけろ このビートに身を任せて 全力で生きろ"
    "流星のサドル:2010:流れ星に願いをかけた あの夜を覚えてる 君の笑顔が輝いていた"
    "流星のサドル:2010:どんな夜も どんな朝も 二人一緒なら 怖くない"
)

# ===== ヘルパー関数 =====

show_usage() {
    cat <<EOF
使用方法: ${PROG_NAME} [オプション]

久保田利伸の名曲歌詞フレーズをランダムに表示します。

オプション:
  -i, --interactive   インタラクティブモード（Enterで次のフレーズへ）
  -a, --all           全フレーズを一覧表示
  -h, --help          このヘルプを表示
  -v, --version       バージョン情報を表示

例:
  ${PROG_NAME}          # ランダムに1フレーズ表示
  ${PROG_NAME} -i       # 繰り返し表示モード
  ${PROG_NAME} -a       # 全${#SONGS[@]}フレーズを一覧表示
EOF
}

# セパレーターを描画
draw_sep() {
    echo -e "${C_CYAN}♪ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ ♪${C_RESET}"
}

# 1フレーズ表示
show_phrase() {
    local entry="$1"
    local title year lyrics
    IFS=':' read -r title year lyrics <<< "$entry"

    echo ""
    draw_sep
    echo -e "  ${C_BOLD}${C_MAGENTA}久保田利伸${C_RESET}"
    draw_sep
    echo ""
    echo -e "  ${C_YELLOW}♬ 「${title}」${C_RESET}  ${C_DIM}(${year})${C_RESET}"
    echo ""
    echo -e "  ${C_BRIGHT_CYAN}${lyrics}${C_RESET}"
    echo ""
    draw_sep
    echo ""
}

# ランダムに1エントリ返す
random_song() {
    local idx=$(( RANDOM % ${#SONGS[@]} ))
    echo "${SONGS[$idx]}"
}

# ===== モード別処理 =====

mode_single() {
    show_phrase "$(random_song)"
}

mode_interactive() {
    local count=0
    # シャッフル済みインデックス配列を作成
    local -a indices=()
    for i in "${!SONGS[@]}"; do indices+=("$i"); done
    # Fisher-Yates シャッフル
    for (( i=${#indices[@]}-1; i>0; i-- )); do
        j=$(( RANDOM % (i+1) ))
        tmp="${indices[$i]}"; indices[$i]="${indices[$j]}"; indices[$j]="$tmp"
    done

    echo -e "${C_DIM}  Enter で次のフレーズ / q で終了${C_RESET}"

    for idx in "${indices[@]}"; do
        show_phrase "${SONGS[$idx]}"
        (( count++ ))
        echo -e "  ${C_DIM}[${count}/${#SONGS[@]}] Enter で次へ / q で終了${C_RESET}"
        IFS= read -r input || break
        [[ "$input" == "q" || "$input" == "Q" ]] && break
    done

    echo -e "\n  ${C_GREEN}全フレーズを表示しました。ありがとうございました！${C_RESET}\n"
}

mode_all() {
    echo ""
    echo -e "${C_BOLD}${C_MAGENTA}  久保田利伸 歌詞フレーズ一覧 (全${#SONGS[@]}フレーズ)${C_RESET}"
    echo ""
    local prev_title=""
    for entry in "${SONGS[@]}"; do
        local title year lyrics
        IFS=':' read -r title year lyrics <<< "$entry"
        if [[ "$title" != "$prev_title" ]]; then
            echo -e "${C_CYAN}  ┌─ ${C_YELLOW}${C_BOLD}「${title}」${C_RESET} ${C_DIM}(${year})${C_RESET}"
            prev_title="$title"
        fi
        echo -e "${C_CYAN}  │${C_RESET}  ${lyrics}"
    done
    echo -e "${C_CYAN}  └────${C_RESET}"
    echo ""
}

# ===== 引数解析 =====

main() {
    local mode="single"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -i|--interactive) mode="interactive" ;;
            -a|--all)         mode="all" ;;
            -h|--help)        show_usage; exit 0 ;;
            -v|--version)     echo "${PROG_NAME} v${VERSION}"; exit 0 ;;
            *) log_error "不明なオプション: $1"; show_usage; exit 1 ;;
        esac
        shift
    done

    case "$mode" in
        single)      mode_single ;;
        interactive) mode_interactive ;;
        all)         mode_all ;;
    esac
}

main "$@"
