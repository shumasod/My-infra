m #!/bin/bash
set -euo pipefail

# ============================================
#  🎤 M-1グランプリ2025 採点システム 🎤
#     ～ 第21代王者決定戦 ～
# ============================================

# 共通ライブラリの読み込み
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

# ========== 2025年版データ ==========

# 審査員（2025年・9人制）
JUDGES=(
    "礼二(中川家)"
    "山内(かまいたち)"
    "塙(ナイツ)"
    "博多大吉"
    "哲夫(笑い飯)"
    "柴田(アンタッチャブル)"
    "駒場(ミルクボーイ)"
    "後藤(フット)"
    "海原ともこ"
)

# 決勝進出者（2025年・10組）
FINALISTS_2025=(
    "たくろう"
    "ヤーレンズ"
    "真空ジェシカ"
    "ヨネダ2000"
    "ママタルト"
    "エバース"
    "ドンデコルテ"
    "めぞん"
    "豪快キャプテン"
    "カナメストーン"
)

# 敗者復活戦出場者（2025年・21組）
HAISHA_2025=(
    "ミカボ"
    "センチネル"
    "おおぞらモード"
    "ネコニスズ"
    "TCクラクション"
    "生姜猫"
    "ひつじねいり"
    "豆鉄砲"
    "大王"
    "黒帯"
    "カナメストーン"
    "20世紀"
    "例えば炎"
    "今夜も星が綺麗"
    "イチゴ"
    "スタミナパン"
    "ドーナツ・ピーナツ"
    "ゼロカラン"
    "カベポスター"
    "フランツ"
    "ミキ"
)

# コメントテンプレート
COMMENTS_HIGH=("完璧やった！" "爆発力すごい！" "完成度高い！" "4分間笑いっぱなし" "優勝あるで！" "めちゃくちゃ面白い！")
COMMENTS_MID=("もうひと押し欲しかった" "後半よかった" "安定してた" "惜しいところあった" "つかみがもう少し")
COMMENTS_LOW=("ちょっと空回りしたな" "緊張してた？" "本来の力出てない" "噛み合ってなかった" "もったいない")

# 歴代チャンピオン
CHAMPION_NAMES=("2024令和ロマン" "2023令和ロマン" "2022ウエストランド" "2021錦鯉" "2020マヂラブ" "2019ミルクボーイ" "2018霜降り明星")
CHAMPION_SCORES=(665 656 649 655 649 681 662)

OUTPUT_DIR="./m1_2025_results"

# ========== ユーティリティ ==========

show_banner() {
    echo -e "${C_MAGENTA}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║     ███╗   ███╗     ██╗     ██████╗  ██████╗  ██████╗ ███████╗║
║     ████╗ ████║    ███║    ██╔════╝ ██╔═══██╗██╔════╝ ██╔════╝║
║     ██╔████╔██║ ████████╗  ██║█████╗██║   ██║██║█████╗███████╗║
║     ██║╚██╔╝██║    ╚══██║  ██║╚════╝██║   ██║██║╚════╝╚════██║║
║     ██║ ╚═╝ ██║       ██║  ╚██████╗ ╚██████╔╝╚██████╗ ███████║║
║     ╚═╝     ╚═╝       ╚═╝   ╚═════╝  ╚═════╝  ╚═════╝ ╚══════╝║
║                                                               ║
║        🎤 M-1グランプリ2025 採点システム 🎤                   ║
║            ～ 史上最多11,521組の頂点へ ～                     ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${C_RESET}"
}

separator() { echo -e "${C_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"; }
double_sep() { echo -e "${C_YELLOW}═══════════════════════════════════════════════════════${C_RESET}"; }

get_comment() {
    local s=$1 idx
    if [ "$s" -ge 95 ]; then
        idx=$((RANDOM % ${#COMMENTS_HIGH[@]})); echo "${COMMENTS_HIGH[$idx]}"
    elif [ "$s" -ge 88 ]; then
        idx=$((RANDOM % ${#COMMENTS_MID[@]})); echo "${COMMENTS_MID[$idx]}"
    else
        idx=$((RANDOM % ${#COMMENTS_LOW[@]})); echo "${COMMENTS_LOW[$idx]}"
    fi
}

# ========== 採点処理 ==========

score_combo() {
    local combo="$1" mode="${2:-auto}" total=0
    
    echo ""
    separator
    echo -e "${C_BOLD}${C_GREEN}🎭 ${combo}${C_RESET}"
    separator
    echo -e "${C_BLUE}【9人の審査員による採点】${C_RESET}"
    
    for judge in "${JUDGES[@]}"; do
        local score
        if [ "$mode" = "auto" ]; then
            score=$((RANDOM % 21 + 80))
        else
            while true; do
                echo -ne "  ${C_YELLOW}${judge}${C_RESET} (80-100): "
                read -r score
                [[ "$score" =~ ^[0-9]+$ ]] && [ "$score" -ge 80 ] && [ "$score" -le 100 ] && break
            done
        fi
        total=$((total + score))
        local comment; comment=$(get_comment "$score")
        printf "  %-18s: ${C_CYAN}%3d点${C_RESET} ${C_DIM}「%s」${C_RESET}\n" "$judge" "$score" "$comment"
    done
    
    echo ""
    echo -e "${C_MAGENTA}┌────────────────────────────────────┐${C_RESET}"
    echo -e "${C_MAGENTA}│ ${combo}${C_RESET}"
    echo -e "${C_MAGENTA}│ ${C_RED}★★★ 合計: ${total}点 ★★★${C_RESET}"
    echo -e "${C_MAGENTA}└────────────────────────────────────┘${C_RESET}"
    
    # 歴代比較
    for i in "${!CHAMPION_SCORES[@]}"; do
        if [ "$total" -gt "${CHAMPION_SCORES[$i]}" ]; then
            echo -e "  ${C_GREEN}→ ${CHAMPION_NAMES[$i]}(${CHAMPION_SCORES[$i]}点)超え！${C_RESET}"
            break
        fi
    done
    
    LAST_SCORE=$total
}

# ========== 結果表示 ==========

show_results() {
    local -n names=$1
    local -n scores=$2
    
    echo ""
    double_sep
    echo -e "${C_BOLD}${C_RED}🏆 M-1グランプリ2025 最終結果 🏆${C_RESET}"
    double_sep
    
    # ソート
    local sorted=()
    for i in "${!names[@]}"; do
        sorted+=("${scores[$i]}:${names[$i]}")
    done
    IFS=$'\n' sorted=($(sort -t: -k1 -nr <<<"${sorted[*]}")); unset IFS
    
    local medals=("🥇" "🥈" "🥉")
    echo -e "${C_YELLOW}┌──────────────────────────────────────────┐${C_RESET}"
    echo -e "${C_YELLOW}│        第21代王者決定！順位表            │${C_RESET}"
    echo -e "${C_YELLOW}├──────────────────────────────────────────┤${C_RESET}"
    
    local rank=1
    for item in "${sorted[@]}"; do
        local sc="${item%%:*}"
        local nm="${item#*:}"
        local icon="  "
        [ $rank -le 3 ] && icon="${medals[$((rank-1))]}"
        printf "${C_YELLOW}│${C_RESET} %s %2d位: %-14s ${C_CYAN}%d点${C_RESET} ${C_YELLOW}│${C_RESET}\n" "$icon" "$rank" "$nm" "$sc"
        ((rank++))
    done
    echo -e "${C_YELLOW}└──────────────────────────────────────────┘${C_RESET}"
    
    # 優勝者
    local winner="${sorted[0]#*:}"
    local wscore="${sorted[0]%%:*}"
    echo ""
    echo -e "${C_RED}🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉${C_RESET}"
    echo ""
    echo -e "${C_MAGENTA}   👑 第21代 M-1チャンピオン 👑${C_RESET}"
    echo ""
    echo -e "${C_BOLD}${C_GREEN}      ✨ ${winner} ✨${C_RESET}"
    echo -e "${C_CYAN}          ${wscore}点${C_RESET}"
    echo ""
    echo -e "${C_RED}🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉${C_RESET}"
    
    # 歴代比較
    echo ""
    echo -e "${C_YELLOW}【歴代チャンピオン比較】${C_RESET}"
    echo "  今回: ${winner} ${wscore}点"
    for i in "${!CHAMPION_NAMES[@]}"; do
        echo "  ${CHAMPION_NAMES[$i]}: ${CHAMPION_SCORES[$i]}点"
    done
}

# ========== 統計分析 ==========

show_stats() {
    local -n names=$1
    local -n scores=$2
    
    echo ""
    echo -e "${C_CYAN}📊 統計分析${C_RESET}"
    
    local max=0 min=900 sum=0
    for s in "${scores[@]}"; do
        ((sum += s))
        [ "$s" -gt "$max" ] && max=$s
        [ "$s" -lt "$min" ] && min=$s
    done
    local avg=$((sum / ${#scores[@]}))
    
    echo "  出場: ${#names[@]}組"
    echo "  最高: ${max}点 / 最低: ${min}点 / 平均: ${avg}点"
    echo "  審査員: 9人制（満点: 900点）"
}

# ========== エクスポート ==========

export_all() {
    local -n names=$1
    local -n scores=$2
    
    mkdir -p "$OUTPUT_DIR"
    
    # CSV
    echo "順位,コンビ,点数" > "${OUTPUT_DIR}/m1_2025_results.csv"
    local sorted=()
    for i in "${!names[@]}"; do sorted+=("${scores[$i]}:${names[$i]}"); done
    IFS=$'\n' sorted=($(sort -t: -k1 -nr <<<"${sorted[*]}")); unset IFS
    local r=1
    for item in "${sorted[@]}"; do
        echo "${r},${item#*:},${item%%:*}" >> "${OUTPUT_DIR}/m1_2025_results.csv"
        ((r++))
    done
    
    # HTML
    cat > "${OUTPUT_DIR}/m1_2025_results.html" << 'HTMLHEAD'
<!DOCTYPE html><html lang="ja"><head><meta charset="UTF-8">
<title>M-1グランプリ2025 結果</title>
<style>
body{font-family:'Hiragino Sans',sans-serif;background:linear-gradient(135deg,#0d0d1a,#1a1a3e);color:#fff;padding:20px;min-height:100vh}
h1{text-align:center;font-size:2em;background:linear-gradient(90deg,#ff6b6b,#ffd93d,#6bcb77);-webkit-background-clip:text;-webkit-text-fill-color:transparent}
.subtitle{text-align:center;color:#888;margin-bottom:30px}
.winner{text-align:center;padding:30px;margin:20px 0;background:linear-gradient(135deg,#ffd700,#ff6b6b);border-radius:20px;color:#1a1a2e}
.winner h2{margin:0;font-size:1.2em}.winner .name{font-size:2em;margin:10px 0}
.ranking{background:rgba(255,255,255,0.05);border-radius:15px;padding:20px}
.item{display:flex;justify-content:space-between;padding:12px 15px;margin:8px 0;background:rgba(255,255,255,0.08);border-radius:8px}
.gold{background:linear-gradient(90deg,rgba(255,215,0,0.3),transparent);border-left:4px solid gold}
.silver{background:linear-gradient(90deg,rgba(192,192,192,0.3),transparent);border-left:4px solid silver}
.bronze{background:linear-gradient(90deg,rgba(205,127,50,0.3),transparent);border-left:4px solid #cd7f32}
.score{color:#6bcb77;font-weight:bold;font-size:1.1em}
.judges{margin-top:30px;padding:15px;background:rgba(255,255,255,0.05);border-radius:10px}
.judges h3{color:#ffd93d}
</style></head><body>
<h1>🎤 M-1グランプリ2025 🎤</h1>
<p class="subtitle">史上最多11,521組の頂点</p>
HTMLHEAD
    
    # 優勝者
    local winner="${sorted[0]#*:}"
    local wscore="${sorted[0]%%:*}"
    echo "<div class='winner'><h2>👑 第21代王者 👑</h2><div class='name'>${winner}</div><div>${wscore}点</div></div>" >> "${OUTPUT_DIR}/m1_2025_results.html"
    
    echo "<div class='ranking'><h3>📋 最終順位</h3>" >> "${OUTPUT_DIR}/m1_2025_results.html"
    
    r=1
    for item in "${sorted[@]}"; do
        local cls="" medal=""
        [ $r -eq 1 ] && cls="gold" && medal="🥇 "
        [ $r -eq 2 ] && cls="silver" && medal="🥈 "
        [ $r -eq 3 ] && cls="bronze" && medal="🥉 "
        echo "<div class='item $cls'><span>${medal}${r}位 ${item#*:}</span><span class='score'>${item%%:*}点</span></div>" >> "${OUTPUT_DIR}/m1_2025_results.html"
        ((r++))
    done
    
    # 審査員情報
    cat >> "${OUTPUT_DIR}/m1_2025_results.html" << 'JUDGES'
</div>
<div class="judges">
<h3>👨‍⚖️ 審査員（9人制）</h3>
<p>礼二(中川家) / 山内健司(かまいたち) / 塙宣之(ナイツ) / 博多大吉 / 哲夫(笑い飯) / 柴田英嗣(アンタッチャブル) / 駒場孝(ミルクボーイ) / 後藤輝基(フットボールアワー) / 海原ともこ</p>
</div>
</body></html>
JUDGES
    
    echo -e "${C_GREEN}✓ 出力完了: ${OUTPUT_DIR}/${C_RESET}"
}

# ========== 1stラウンド ==========

run_first_round() {
    local mode=$1
    local -n combos=$2
    local -n first_scores=$3
    
    echo ""
    double_sep
    echo -e "${C_BOLD}${C_RED}🎯 ファーストラウンド${C_RESET}"
    echo -e "${C_DIM}   笑神籤（えみくじ）で出番決定！${C_RESET}"
    double_sep
    
    first_scores=()
    
    # シャッフル（笑神籤風）
    local shuffled=()
    for combo in "${combos[@]}"; do shuffled+=("$combo"); done
    for ((i=${#shuffled[@]}-1; i>0; i--)); do
        j=$((RANDOM % (i+1)))
        tmp="${shuffled[$i]}"
        shuffled[$i]="${shuffled[$j]}"
        shuffled[$j]="$tmp"
    done
    
    local order=1
    for combo in "${shuffled[@]}"; do
        echo ""
        echo -e "${C_YELLOW}【${order}番手】${C_RESET}"
        score_combo "$combo" "$mode"
        first_scores+=("$LAST_SCORE")
        ((order++))
    done
    
    # 結果表示
    echo ""
    echo -e "${C_YELLOW}【ファーストラウンド結果】${C_RESET}"
    local sorted=()
    for i in "${!shuffled[@]}"; do sorted+=("${first_scores[$i]}:$i:${shuffled[$i]}"); done
    IFS=$'\n' sorted=($(sort -t: -k1 -nr <<<"${sorted[*]}")); unset IFS
    
    FINALIST_IDX=()
    FINALIST_NAMES_FINAL=()
    local r=1
    for item in "${sorted[@]}"; do
        IFS=':' read -r sc idx nm <<< "$item"
        if [ $r -le 3 ]; then
            echo -e "  ${C_GREEN}${r}位: ${nm} (${sc}点) → 最終決戦へ！${C_RESET}"
            FINALIST_IDX+=("$idx")
            FINALIST_NAMES_FINAL+=("$nm")
        else
            echo -e "  ${C_DIM}${r}位: ${nm} (${sc}点)${C_RESET}"
        fi
        ((r++))
    done
    
    # グローバルに保存
    SHUFFLED_COMBOS=("${shuffled[@]}")
}

# ========== 最終決戦 ==========

run_final_battle() {
    local mode=$1
    
    echo ""
    double_sep
    echo -e "${C_BOLD}${C_RED}🔥 最終決戦 🔥${C_RESET}"
    echo -e "${C_DIM}   上位3組による頂上決戦！${C_RESET}"
    double_sep
    
    FINAL_NAMES=()
    FINAL_SCORES=()
    
    for name in "${FINALIST_NAMES_FINAL[@]}"; do
        score_combo "$name" "$mode"
        FINAL_NAMES+=("$name")
        FINAL_SCORES+=("$LAST_SCORE")
    done
}

# ========== 敗者復活戦 ==========

run_haisha_fukkatsu() {
    echo ""
    double_sep
    echo -e "${C_BOLD}${C_MAGENTA}🔥 敗者復活戦 🔥${C_RESET}"
    echo -e "${C_DIM}   21組が最後の1枠を争う！${C_RESET}"
    double_sep
    
    echo ""
    echo -e "${C_CYAN}【敗者復活戦 出場者】${C_RESET}"
    local col=0
    for combo in "${HAISHA_2025[@]}"; do
        printf "  %-14s" "$combo"
        ((col++))
        [ $((col % 3)) -eq 0 ] && echo ""
    done
    echo ""
    
    echo ""
    echo -e "${C_YELLOW}🗳️  会場投票集計中...${C_RESET}"
    sleep 2
    
    # ランダムで勝者決定
    local winner_idx=$((RANDOM % ${#HAISHA_2025[@]}))
    local winner="${HAISHA_2025[$winner_idx]}"
    
    echo ""
    echo -e "${C_GREEN}🎉 敗者復活: ${C_BOLD}${winner}${C_RESET}${C_GREEN} が決勝進出！${C_RESET}"
    
    HAISHA_WINNER="$winner"
}

# ========== メイン ==========

main() {
    show_banner
    
    while true; do
        echo ""
        echo -e "${C_CYAN}【モード選択】${C_RESET}"
        echo "  1) 🎯 本番形式（1st→最終決戦）"
        echo "  2) 🔥 敗者復活戦付き完全版"
        echo "  3) 🎲 クイックデモ（全10組一斉採点）"
        echo "  4) ✏️  手動採点モード"
        echo "  5) 📋 2025出場者一覧を表示"
        echo "  0) 終了"
        echo -ne "${C_YELLOW}選択: ${C_RESET}"
        read -r choice
        
        case "$choice" in
            1)
                COMBOS=("${FINALISTS_2025[@]}")
                FIRST_SCORES=()
                run_first_round "auto" COMBOS FIRST_SCORES
                run_final_battle "auto"
                show_results FINAL_NAMES FINAL_SCORES
                show_stats FINAL_NAMES FINAL_SCORES
                export_all FINAL_NAMES FINAL_SCORES
                ;;
            2)
                run_haisha_fukkatsu
                COMBOS=("${FINALISTS_2025[@]}")
                # 敗者復活組を追加（既存なら入れ替え）
                local found=false
                for i in "${!COMBOS[@]}"; do
                    [ "${COMBOS[$i]}" = "$HAISHA_WINNER" ] && found=true
                done
                [ "$found" = false ] && COMBOS+=("$HAISHA_WINNER")
                
                FIRST_SCORES=()
                run_first_round "auto" COMBOS FIRST_SCORES
                run_final_battle "auto"
                show_results FINAL_NAMES FINAL_SCORES
                show_stats FINAL_NAMES FINAL_SCORES
                export_all FINAL_NAMES FINAL_SCORES
                ;;
            3)
                RESULT_NAMES=()
                RESULT_SCORES=()
                echo ""
                double_sep
                echo -e "${C_BOLD}${C_GREEN}🎲 クイックデモ - 全10組一斉採点${C_RESET}"
                double_sep
                
                for combo in "${FINALISTS_2025[@]}"; do
                    score_combo "$combo" "auto"
                    RESULT_NAMES+=("$combo")
                    RESULT_SCORES+=("$LAST_SCORE")
                done
                show_results RESULT_NAMES RESULT_SCORES
                show_stats RESULT_NAMES RESULT_SCORES
                export_all RESULT_NAMES RESULT_SCORES
                ;;
            4)
                RESULT_NAMES=()
                RESULT_SCORES=()
                echo ""
                echo -e "${C_CYAN}手動採点する組数 (1-10): ${C_RESET}"
                read -r count
                [ -z "$count" ] && count=3
                
                for ((i=0; i<count && i<${#FINALISTS_2025[@]}; i++)); do
                    score_combo "${FINALISTS_2025[$i]}" "manual"
                    RESULT_NAMES+=("${FINALISTS_2025[$i]}")
                    RESULT_SCORES+=("$LAST_SCORE")
                done
                show_results RESULT_NAMES RESULT_SCORES
                ;;
            5)
                echo ""
                double_sep
                echo -e "${C_BOLD}${C_CYAN}📋 M-1グランプリ2025 出場者一覧${C_RESET}"
                double_sep
                echo ""
                echo -e "${C_YELLOW}【決勝進出者 10組】${C_RESET}"
                for i in "${!FINALISTS_2025[@]}"; do
                    printf "  %2d. %s\n" $((i+1)) "${FINALISTS_2025[$i]}"
                done
                echo ""
                echo -e "${C_YELLOW}【審査員 9名】${C_RESET}"
                for judge in "${JUDGES[@]}"; do
                    echo "  ・$judge"
                done
                echo ""
                echo -e "${C_YELLOW}【敗者復活戦 21組】${C_RESET}"
                local col=0
                for combo in "${HAISHA_2025[@]}"; do
                    printf "  %-14s" "$combo"
                    ((col++))
                    [ $((col % 3)) -eq 0 ] && echo ""
                done
                echo ""
                ;;
            0)
                echo -e "${C_CYAN}ご視聴ありがとうございました！${C_RESET}"
                exit 0
                ;;
        esac
        
        echo ""
        echo -ne "${C_YELLOW}続ける？(y/n): ${C_RESET}"
        read -r cont
        [ "$cont" != "y" ] && exit 0
    done
}

main
