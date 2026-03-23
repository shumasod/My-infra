#!/bin/bash
set -euo pipefail

#
# 東京ラブストーリー - カンチ！カンチ！カンチ！
# 作成日: 2026-03-23
# バージョン: 1.0
#
# 赤名リカが永尾完治（カンチ）を呼び続けるドラマ風シェルスクリプト
#

# 共通ライブラリの読み込み
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

# ===== 設定（定数） =====
readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

# ドラマ専用カラー
readonly C_RIKA='\033[1;95m'       # リカ（明るいマゼンタ）
readonly C_KANCHI='\033[1;34m'     # カンチ（青）
readonly C_NARR='\033[0;37m'       # ナレーション（グレー）
readonly C_SCENE='\033[1;33m'      # シーン（黄色）
readonly C_HEART='\033[1;31m'      # ハート（赤）
readonly C_TITLE='\033[1;96m'      # タイトル（シアン）
readonly C_PINK='\033[38;5;213m'   # ピンク（256色）
readonly C_SKY='\033[38;5;117m'    # 空色（256色）

# ===== ヘルパー関数 =====

# タイプライター効果
typewriter() {
    local text="$1"
    local delay="${2:-0.05}"
    local color="${3:-$C_RESET}"
    echo -ne "$color"
    while IFS= read -rn1 char; do
        echo -ne "$char"
        sleep "$delay"
    done <<< "$text"
    echo -e "$C_RESET"
}

# タイプライター効果（改行なし）
typewriter_inline() {
    local text="$1"
    local delay="${2:-0.05}"
    local color="${3:-$C_RESET}"
    echo -ne "$color"
    while IFS= read -rn1 char; do
        echo -ne "$char"
        sleep "$delay"
    done <<< "$text"
    echo -ne "$C_RESET"
}

# ドラマチック休止
pause() {
    sleep "${1:-1}"
}

# シーン区切り
scene_break() {
    echo ""
    echo -e "${C_SCENE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
    echo ""
    pause 0.8
}

# ナレーション
narrate() {
    echo -ne "$C_NARR"
    typewriter "  ＊ $1 ＊" 0.04
    echo ""
    pause 0.5
}

# リカのセリフ
rika_says() {
    echo -ne "${C_RIKA}リカ：${C_RESET}"
    typewriter "$1" 0.06 "$C_RIKA"
    pause 0.3
}

# リカの叫び（カンチ！）
rika_kanchi() {
    local count="${1:-1}"
    local intensity="${2:-normal}"

    echo -ne "${C_RIKA}リカ：${C_RESET}"

    case "$intensity" in
        soft)
            typewriter "カンチ…" 0.1 "$C_PINK"
            ;;
        normal)
            for ((i=0; i<count; i++)); do
                echo -ne "${C_RIKA}"
                if ((i < count - 1)); then
                    typewriter_inline "カンチ！" 0.07
                    echo -ne "　"
                    pause 0.3
                else
                    typewriter "カンチ！" 0.07 "$C_RIKA"
                fi
            done
            ;;
        loud)
            echo -ne "${C_HEART}"
            for ((i=0; i<count; i++)); do
                typewriter_inline "カンチ！！" 0.05
                pause 0.2
            done
            echo -e "$C_RESET"
            ;;
        desperate)
            echo ""
            for ((i=0; i<count; i++)); do
                echo -ne "\r  ${C_RIKA}★  カ ン チ ！！！  ★${C_RESET}  "
                pause 0.15
                echo -ne "\r  ${C_HEART}♥  カ ン チ ！！！  ♥${C_RESET}  "
                pause 0.15
            done
            echo ""
            ;;
    esac
}

# カンチのセリフ
kanchi_says() {
    echo -ne "${C_KANCHI}カンチ：${C_RESET}"
    typewriter "$1" 0.06 "$C_KANCHI"
    pause 0.3
}

# ハートアニメーション
heart_animation() {
    local count="${1:-5}"
    echo ""
    for ((i=0; i<count; i++)); do
        echo -ne "\r  ${C_HEART}♥  ♥  ♥  ♥  ♥${C_RESET}  "
        pause 0.3
        echo -ne "\r  ${C_PINK}♡  ♡  ♡  ♡  ♡${C_RESET}  "
        pause 0.3
    done
    echo ""
}

# ===== タイトル画面 =====

show_title() {
    clear
    echo ""
    echo ""
    pause 0.5

    echo -e "${C_TITLE}"
    cat <<'EOF'
  ╔══════════════════════════════════════════════════════════╗
  ║                                                          ║
  ║    東  京  ラ  ブ  ス  ト  ー  リ  ー                    ║
  ║                                                          ║
  ║              〜 カンチ！カンチ！カンチ！ 〜               ║
  ║                                                          ║
  ╚══════════════════════════════════════════════════════════╝
EOF
    echo -e "${C_RESET}"
    echo ""

    typewriter "          1991年、東京。あの夏の物語が、今蘇る。" 0.05 "$C_NARR"
    echo ""
    pause 1.5
    echo -e "          ${C_RIKA}赤名リカ${C_RESET}  と  ${C_KANCHI}永尾完治（カンチ）${C_RESET}"
    echo ""
    pause 1.0
    heart_animation 3
    pause 0.5
}

# ===== シーン1: 出会い =====

scene_1() {
    scene_break
    echo -e "${C_SCENE}  【第1話】 出会い — 東京の街で${C_RESET}"
    scene_break

    narrate "東京・新宿。人混みの中で、リカは運命の人に出会う。"

    pause 0.5
    kanchi_says "あの…すみません、この辺に喫茶店はありますか？"
    pause 0.5
    rika_says "えっ？ あ、あるよ！あそこの角を曲がって！"
    pause 0.8
    narrate "リカはカンチを見た瞬間、何かを感じた。"
    pause 0.5
    rika_says "ねえ、お名前は？"
    pause 0.5
    kanchi_says "永尾…永尾完治といいます。"
    pause 0.5
    rika_says "カンチ！ カンチって呼んでいい？"
    pause 0.8

    echo ""
    rika_kanchi 1 "soft"
    pause 0.5
    narrate "その日から、リカの「カンチ！」は始まった。"
}

# ===== シーン2: 追いかけるリカ =====

scene_2() {
    scene_break
    echo -e "${C_SCENE}  【第2話】 追いかけて — 渋谷の交差点${C_RESET}"
    scene_break

    narrate "渋谷のスクランブル交差点。人の波の中でリカはカンチを見つけた。"
    pause 0.8

    rika_kanchi 2 "normal"
    pause 0.5
    kanchi_says "え？リカ？なんでここに？"
    pause 0.5
    rika_says "探してたんだよ！ずっと！"
    pause 0.8

    narrate "リカは人混みをかき分けて走った。"
    pause 0.5
    rika_kanchi 3 "normal"
    pause 0.5
    kanchi_says "待って、リカ！危ない！"
    pause 0.8
    narrate "でもリカは止まらない。カンチに届けたい気持ちで、胸がいっぱいだった。"
    pause 0.5
    rika_kanchi 1 "loud"
}

# ===== シーン3: 電話越しに =====

scene_3() {
    scene_break
    echo -e "${C_SCENE}  【第3話】 夜の電話 — 別れと再会${C_RESET}"
    scene_break

    narrate "深夜2時。リカは電話をかけた。"
    pause 0.8

    echo -e "${C_NARR}  ☎  プルルル… プルルル…${C_RESET}"
    pause 1.0
    kanchi_says "もしもし…"
    pause 0.5
    rika_kanchi 1 "soft"
    pause 0.3
    rika_says "ねえ…今、何してるの？"
    pause 0.5
    kanchi_says "寝てた…。リカ、こんな時間に何？"
    pause 0.5
    rika_says "会いたくなっちゃった。ダメ？"
    pause 0.8
    narrate "沈黙が続いた。カンチには、他に好きな人がいた。"
    pause 1.0
    rika_says "ねえ…"
    pause 0.5
    rika_kanchi 1 "soft"
    pause 0.5
    rika_says "私のこと、好きじゃないの？"
    pause 1.0
    kanchi_says "リカ…それは…"
    pause 0.8
    rika_kanchi 2 "normal"
    pause 0.3
    rika_says "正直に言って！"
    pause 1.0
    narrate "カンチは答えられなかった。"
}

# ===== シーン4: 駅のホームで =====

scene_4() {
    scene_break
    echo -e "${C_SCENE}  【第4話】 さよなら — 駅のホーム${C_RESET}"
    scene_break

    narrate "夕暮れの東京駅。リカはカンチの背中を見つけた。"
    pause 0.8

    rika_says "カンチ、待って！"
    pause 0.5
    kanchi_says "リカ…来てたのか。"
    pause 0.5
    rika_says "行かないで。ねえ、行かないでよ。"
    pause 0.8
    narrate "電車の到着を告げるアナウンスが流れた。"
    pause 0.5

    echo -e "${C_NARR}  📢 まもなく、○番線に電車が参ります…${C_RESET}"
    pause 1.0

    rika_kanchi 1 "normal"
    pause 0.3
    rika_says "私といてくれなきゃやだ！"
    pause 0.8
    kanchi_says "リカ…俺には…さくらが…"
    pause 0.5
    rika_kanchi 3 "loud"
    pause 0.5
    narrate "涙をこらえながら、リカは笑った。あの、眩しい笑顔で。"
    pause 0.8
    rika_says "カンチって、ほんとバカ。"
    pause 0.5
    rika_says "でも…好きだよ。"
    pause 1.0
    heart_animation 4
}

# ===== シーン5: 最後の叫び =====

scene_5() {
    scene_break
    echo -e "${C_SCENE}  【最終話】 カンチ！カンチ！カンチ！${C_RESET}"
    scene_break

    narrate "別れの日。リカは全力で、カンチに叫んだ。"
    pause 1.0

    echo ""
    rika_kanchi 5 "desperate"
    pause 0.5

    narrate "カンチは振り返らなかった。"
    pause 1.0

    rika_says "カンチ！！ セックスしよ！！"
    pause 0.5

    narrate "…あの有名なセリフが、東京の風に溶けていった。"
    pause 1.5

    kanchi_says "（振り返れなかった…）"
    pause 0.8
    narrate "それでもリカは叫び続けた。"
    pause 0.5

    echo ""
    for i in 1 2 3; do
        echo -ne "  ${C_RIKA}"
        typewriter_inline "カ" 0.15
        typewriter_inline "ン" 0.15
        typewriter_inline "チ！！！" 0.1
        echo -e "${C_RESET}"
        pause 0.4
    done
    echo ""

    narrate "その声は、きっとカンチの心に届いていた。"
    pause 1.0
}

# ===== エピローグ =====

epilogue() {
    scene_break
    echo -e "${C_SCENE}  【エピローグ】${C_RESET}"
    scene_break

    narrate "あれから何年が経っただろう。"
    pause 0.8
    narrate "東京の街は変わっても、あの夏の記憶は変わらない。"
    pause 1.0

    echo ""
    echo -e "  ${C_HEART}♥♥♥♥♥♥♥♥♥♥♥♥♥♥♥♥♥♥♥♥♥♥♥♥♥♥♥♥♥♥${C_RESET}"
    echo ""
    typewriter "    「カンチ」と呼ぶ声が、東京に響き渡る。" 0.06 "$C_PINK"
    typewriter "    それは愛の叫びだった。" 0.06 "$C_PINK"
    echo ""
    echo -e "  ${C_HEART}♥♥♥♥♥♥♥♥♥♥♥♥♥♥♥♥♥♥♥♥♥♥♥♥♥♥♥♥♥♥${C_RESET}"
    echo ""
    pause 1.0

    echo -e "  ${C_TITLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
    echo -e "  ${C_TITLE}  東 京 ラ ブ ス ト ー リ ー  〜 完 〜${C_RESET}"
    echo -e "  ${C_TITLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
    echo ""
    echo -e "  ${C_NARR}原作：柴門ふみ  （シェル版：My-infra Entertainment）${C_RESET}"
    echo ""
}

# ===== ボーナスモード: カンチ連呼 =====

kanchi_loop() {
    clear
    echo ""
    echo -e "${C_SCENE}  ★ カンチ連呼モード ★${C_RESET}"
    echo ""
    narrate "リカが止まらない！！"
    echo ""

    local kanchi_list=(
        "カンチ！"
        "カンチ！！"
        "カンチ！！！"
        "ねえカンチ！"
        "カンチってば！"
        "カンチ〜！"
        "カンチぃ！"
        "カ・ン・チ！"
        "カンチ！待って！"
        "カンチ！好きだよ！"
        "カンチ！バカ！"
        "カンチ！セックスしよ！"
        "カンチ！！！！！！"
    )

    for line in "${kanchi_list[@]}"; do
        echo -ne "  ${C_RIKA}リカ：${C_RESET}"
        typewriter "$line" 0.08 "$C_RIKA"
        pause "$(echo "scale=2; $RANDOM / 32767 * 0.5 + 0.2" | bc)"
    done

    echo ""
    echo -e "  ${C_HEART}― リカの「カンチ！」は永遠に続く ―${C_RESET}"
    echo ""
}

# ===== 使用方法 =====

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション]

東京ラブストーリー形式でカンチを呼び続けるシェルスクリプト

オプション:
  -h, --help       このヘルプを表示
  -v, --version    バージョン情報を表示
  --loop           カンチ連呼モード（ボーナス）
  --scene <番号>   指定したシーンのみ実行 (1-5)

例:
  $PROG_NAME             # フル再生
  $PROG_NAME --loop      # カンチ連呼モード
  $PROG_NAME --scene 4   # シーン4のみ

EOF
}

# ===== 引数解析 =====

# グローバル変数として設定
declare g_mode="full"
declare g_scene_num=""

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_usage
                exit 0
                ;;
            -v|--version)
                echo "$PROG_NAME version $VERSION"
                exit 0
                ;;
            --loop)
                g_mode="loop"
                shift
                ;;
            --scene)
                [[ $# -lt 2 ]] && { echo "エラー: --scene には番号が必要です (1-5)" >&2; exit 1; }
                g_scene_num="$2"
                g_mode="scene"
                shift 2
                ;;
            *)
                echo "不明なオプション: $1" >&2
                show_usage
                exit 1
                ;;
        esac
    done
}

# ===== メイン処理 =====

main() {
    parse_arguments "$@"
    local mode="$g_mode"
    local scene_num="$g_scene_num"

    case "$mode" in
        loop)
            kanchi_loop
            ;;
        scene)
            show_title
            case "$scene_num" in
                1) scene_1 ;;
                2) scene_2 ;;
                3) scene_3 ;;
                4) scene_4 ;;
                5) scene_5 ;;
                *) echo "シーン番号は 1〜5 で指定してください" >&2; exit 1 ;;
            esac
            echo ""
            ;;
        full)
            show_title
            scene_1
            scene_2
            scene_3
            scene_4
            scene_5
            epilogue
            ;;
    esac
}

# スクリプト実行
main "$@"
