#!/bin/bash
set -euo pipefail

#
# 今日の星占い
# 作成日: 2026-07-04
# バージョン: 1.0
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

readonly -a SIGNS=(
    "牡羊座:♈:3/21-4/19"
    "牡牛座:♉:4/20-5/20"
    "双子座:♊:5/21-6/21"
    "蟹座:♋:6/22-7/22"
    "獅子座:♌:7/23-8/22"
    "乙女座:♍:8/23-9/22"
    "天秤座:♎:9/23-10/23"
    "蠍座:♏:10/24-11/22"
    "射手座:♐:11/23-12/21"
    "山羊座:♑:12/22-1/19"
    "水瓶座:♒:1/20-2/18"
    "魚座:♓:2/19-3/20"
)

readonly -a LUCK_WORDS=(
    "絶好調" "好調" "まずまず" "普通" "注意が必要" "難しい日"
)

readonly -a LOVE_MSGS=(
    "素敵な出会いが期待できます！積極的に行動してみて"
    "今の関係をより深めるチャンスです"
    "思わぬところから縁が生まれるかもしれません"
    "自分の気持ちを正直に伝えることが大切な日"
    "焦らず自然体でいることが吉です"
    "相手の立場に立って考えると道が開けます"
)

readonly -a WORK_MSGS=(
    "アイデアが豊富に湧き出る日。メモを忘れずに"
    "集中力が高まっており、難しい仕事も片付きます"
    "チームワークを大切にすると成果が倍増します"
    "計画を見直すのに最適な時期です"
    "慎重に進めることで後のトラブルを防げます"
    "コミュニケーションを丁寧に取ることがカギ"
)

readonly -a MONEY_MSGS=(
    "臨時収入の予感！ただし使いすぎに注意"
    "節約意識が財運を引き寄せます"
    "長期的な視点でお金と向き合いましょう"
    "衝動買いは後悔のもと。一度考えてから"
    "投資・貯蓄を始めるなら今がチャンス"
    "小さな節約が大きな積み重ねになります"
)

readonly -a HEALTH_MSGS=(
    "エネルギーに満ち溢れています！運動を楽しんで"
    "十分な睡眠が幸運を呼び込みます"
    "水分補給をこまめに行いましょう"
    "無理せずゆっくり過ごすことが回復への近道"
    "ストレス発散に好きなことをする時間を作って"
    "規則正しい生活リズムが健康の秘訣です"
)

readonly -a LUCKY_ITEMS=(
    "ブルーのペン" "白いハンカチ" "丸いもの" "緑の植物" "音楽" "手帳"
    "水晶" "赤いもの" "香水" "青空" "コーヒー" "本"
)

readonly -a LUCKY_COLORS=(
    "スカイブルー" "ゴールド" "ローズピンク" "グリーン" "ホワイト" "パープル"
    "シルバー" "オレンジ" "ネイビー" "ベージュ" "レッド" "ラベンダー"
)

get_seed() {
    local sign_idx="$1"
    local today
    today=$(date +%Y%m%d)
    echo $(( (today + sign_idx * 31) % 100 ))
}

pseudo_rand() {
    local seed="$1"
    local max="$2"
    echo $(( (seed * 1103515245 + 12345) % max ))
}

show_stars() {
    local score="$1"
    local stars=""
    local i
    for (( i = 0; i < 5; i++ )); do
        if [ "$score" -gt $(( i * 20 )) ]; then
            stars+="★"
        else
            stars+="☆"
        fi
    done
    echo "$stars"
}

show_sign_menu() {
    clear_screen
    update_terminal_size
    echo ""
    print_center "今日の星占い" 0 "${C_BOLD}${C_MAGENTA}"
    print_center "$(date '+%Y年%m月%d日')" 0 "$C_DIM"
    echo ""
    echo -e "${C_CYAN}  星座を選択してください:${C_RESET}"
    echo ""

    local i
    for (( i = 0; i < ${#SIGNS[@]}; i++ )); do
        local entry="${SIGNS[$i]}"
        local name="${entry%%:*}"
        local rest="${entry#*:}"
        local symbol="${rest%%:*}"
        local period="${rest#*:}"
        printf "  ${C_YELLOW}%2d${C_RESET}) ${C_BOLD}%s${C_RESET} %s  ${C_DIM}%s${C_RESET}\n" \
            $(( i + 1 )) "$symbol" "$name" "$period"
    done
    echo ""
    printf "  ${C_DIM}0) 終了${C_RESET}\n"
    echo ""
}

show_fortune() {
    local sign_idx="$1"
    local entry="${SIGNS[$sign_idx]}"
    local sign_name="${entry%%:*}"
    local rest="${entry#*:}"
    local symbol="${rest%%:*}"

    local seed
    seed=$(get_seed "$sign_idx")

    local overall=$(( (seed * 73 + 17) % 100 ))
    local love=$(( (seed * 53 + 29) % 100 ))
    local work=$(( (seed * 37 + 41) % 100 ))
    local money=$(( (seed * 61 + 13) % 100 ))
    local health=$(( (seed * 79 + 7) % 100 ))

    local luck_idx=$(( overall / 17 ))
    [ "$luck_idx" -ge ${#LUCK_WORDS[@]} ] && luck_idx=$(( ${#LUCK_WORDS[@]} - 1 ))

    local love_idx=$(pseudo_rand $(( seed + 1 )) ${#LOVE_MSGS[@]})
    local work_idx=$(pseudo_rand $(( seed + 2 )) ${#WORK_MSGS[@]})
    local money_idx=$(pseudo_rand $(( seed + 3 )) ${#MONEY_MSGS[@]})
    local health_idx=$(pseudo_rand $(( seed + 4 )) ${#HEALTH_MSGS[@]})
    local item_idx=$(pseudo_rand $(( seed + 5 )) ${#LUCKY_ITEMS[@]})
    local color_idx=$(pseudo_rand $(( seed + 6 )) ${#LUCKY_COLORS[@]})

    clear_screen
    echo ""
    print_center "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" 0 "$C_MAGENTA"
    print_center "${symbol} ${sign_name} の今日の運勢 ${symbol}" 0 "${C_BOLD}${C_MAGENTA}"
    print_center "$(date '+%Y年%m月%d日')" 0 "$C_DIM"
    print_center "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" 0 "$C_MAGENTA"
    echo ""

    echo -e "  ${C_BOLD}総合運:${C_RESET}  $(show_stars "$overall")  ${C_YELLOW}${LUCK_WORDS[$luck_idx]}${C_RESET}"
    echo ""
    echo -e "  ${C_BOLD}恋愛運:${C_RESET}  $(show_stars "$love")"
    echo -e "  ${C_DIM}  ${LOVE_MSGS[$love_idx]}${C_RESET}"
    echo ""
    echo -e "  ${C_BOLD}仕事運:${C_RESET}  $(show_stars "$work")"
    echo -e "  ${C_DIM}  ${WORK_MSGS[$work_idx]}${C_RESET}"
    echo ""
    echo -e "  ${C_BOLD}金運:${C_RESET}    $(show_stars "$money")"
    echo -e "  ${C_DIM}  ${MONEY_MSGS[$money_idx]}${C_RESET}"
    echo ""
    echo -e "  ${C_BOLD}健康運:${C_RESET}  $(show_stars "$health")"
    echo -e "  ${C_DIM}  ${HEALTH_MSGS[$health_idx]}${C_RESET}"
    echo ""

    print_center "─────────────────────────────" 0 "$C_DIM"
    echo -e "  ${C_BOLD}ラッキーアイテム:${C_RESET} ${C_GREEN}${LUCKY_ITEMS[$item_idx]}${C_RESET}"
    echo -e "  ${C_BOLD}ラッキーカラー:${C_RESET}   ${C_CYAN}${LUCKY_COLORS[$color_idx]}${C_RESET}"
    echo ""
}

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション] [星座番号]

今日の星占いを表示します。

引数:
  星座番号  1-12 で星座を直接指定（省略時はメニュー表示）

オプション:
  -h, --help     このヘルプを表示
  -v, --version  バージョン情報を表示
  -a, --all      全星座の運勢を一覧表示
EOF
}

main() {
    local direct_sign=""
    local show_all=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -a|--all)     show_all=true; shift ;;
            [1-9]|1[0-2]) direct_sign="$1"; shift ;;
            *) error_exit "不明なオプション: $1" ;;
        esac
    done

    if "$show_all"; then
        clear_screen
        echo ""
        print_center "全星座の運勢 — $(date '+%Y年%m月%d日')" 0 "${C_BOLD}${C_MAGENTA}"
        echo ""
        local i
        for (( i = 0; i < ${#SIGNS[@]}; i++ )); do
            local entry="${SIGNS[$i]}"
            local name="${entry%%:*}"
            local rest="${entry#*:}"
            local symbol="${rest%%:*}"
            local seed
            seed=$(get_seed "$i")
            local overall=$(( (seed * 73 + 17) % 100 ))
            local luck_idx=$(( overall / 17 ))
            [ "$luck_idx" -ge ${#LUCK_WORDS[@]} ] && luck_idx=$(( ${#LUCK_WORDS[@]} - 1 ))
            printf "  %s %-6s  %s  ${C_YELLOW}%s${C_RESET}\n" \
                "$symbol" "$name" "$(show_stars "$overall")" "${LUCK_WORDS[$luck_idx]}"
        done
        echo ""
        return
    fi

    if [ -n "$direct_sign" ]; then
        show_fortune $(( direct_sign - 1 ))
        echo -e "${C_DIM}Enterキーで戻る...${C_RESET}"
        read -r
        return
    fi

    while true; do
        show_sign_menu
        printf "  番号を入力 > "
        local choice
        read -r choice

        case "$choice" in
            0|q|Q) break ;;
            [1-9]|1[0-2])
                show_fortune $(( choice - 1 ))
                echo -e "${C_DIM}Enterキーでメニューに戻る...${C_RESET}"
                read -r
                ;;
            *) log_warning "1〜12の番号、または0を入力してください" ; sleep 1 ;;
        esac
    done

    clear_screen
    log_success "またのご利用をお待ちしています！"
}

main "$@"
