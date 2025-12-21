#!/bin/bash

# ============================================
#  🎤 M-1グランプリ採点システム 🎤
# ============================================

set -euo pipefail

# 色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# 審査員リスト（カスタマイズ可能）
JUDGES=("松本人志" "中川家・礼二" "オール巨人" "立川志らく" "サンドウィッチマン富澤" "ナイツ塙" "博多大吉")

# 結果保存用配列
declare -A RESULTS

# バナー表示
show_banner() {
    echo -e "${MAGENTA}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║     ███╗   ███╗     ██╗     ██████╗ ██████╗ ██████╗       ║
║     ████╗ ████║    ███║    ██╔════╝ ██╔══██╗██╔══██╗      ║
║     ██╔████╔██║ ████████╗  ██║  ███╗██████╔╝██████╔╝      ║
║     ██║╚██╔╝██║    ╚══██║  ██║   ██║██╔═══╝ ██╔═══╝       ║
║     ██║ ╚═╝ ██║       ██║  ╚██████╔╝██║     ██║           ║
║     ╚═╝     ╚═╝       ╚═╝   ╚═════╝ ╚═╝     ╚═╝           ║
║                                                           ║
║              🎤 採点システム 🎤                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# セパレータ
separator() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# 点数入力（バリデーション付き）
get_score() {
    local judge_name="$1"
    local combo_name="$2"
    local score

    while true; do
        echo -ne "${YELLOW}  ${judge_name}${NC} の点数 (80-100): "
        read -r score

        if [[ "$score" =~ ^[0-9]+$ ]] && [ "$score" -ge 80 ] && [ "$score" -le 100 ]; then
            echo "$score"
            return
        else
            echo -e "${RED}  ⚠️  80〜100の数値を入力してください${NC}"
        fi
    done
}

# コンビの採点
score_combo() {
    local combo_name="$1"
    local total=0
    local scores=()

    echo ""
    separator
    echo -e "${BOLD}${GREEN}🎭 エントリーNo.${entry_no}: ${combo_name}${NC}"
    separator
    echo ""
    echo -e "${BLUE}【審査員の採点】${NC}"
    echo ""

    # 各審査員からの採点
    for judge in "${JUDGES[@]}"; do
        score=$(get_score "$judge" "$combo_name")
        scores+=("$score")
        total=$((total + score))
    done

    # 結果表示（ドラマチックに）
    echo ""
    echo -e "${YELLOW}🥁 ドラムロール...${NC}"
    sleep 1
    echo ""
    echo -e "${BOLD}${MAGENTA}┌─────────────────────────────────────┐${NC}"
    echo -e "${BOLD}${MAGENTA}│  ${combo_name} の合計点数           ${NC}"
    echo -e "${BOLD}${MAGENTA}│                                     │${NC}"
    
    # 審査員ごとの点数表示
    for i in "${!JUDGES[@]}"; do
        printf "${MAGENTA}│  ${NC}%-15s: ${CYAN}%3d点${NC}${MAGENTA}            │${NC}\n" "${JUDGES[$i]}" "${scores[$i]}"
    done
    
    echo -e "${BOLD}${MAGENTA}│─────────────────────────────────────│${NC}"
    echo -e "${BOLD}${MAGENTA}│  ${RED}★ 合計: ${total}点 ★${NC}${MAGENTA}                    │${NC}"
    echo -e "${BOLD}${MAGENTA}└─────────────────────────────────────┘${NC}"

    # 結果を保存
    RESULTS["$combo_name"]=$total
}

# 最終結果表示
show_final_results() {
    echo ""
    separator
    echo -e "${BOLD}${RED}🏆 最終結果発表 🏆${NC}"
    separator
    echo ""

    # 点数順にソート
    local sorted_combos=()
    for combo in "${!RESULTS[@]}"; do
        sorted_combos+=("${RESULTS[$combo]}:$combo")
    done

    IFS=$'\n' sorted=($(sort -t: -k1 -nr <<<"${sorted_combos[*]}")); unset IFS

    # 順位表示
    local rank=1
    local medal=("🥇" "🥈" "🥉")
    
    echo -e "${BOLD}${YELLOW}┌─────────────────────────────────────────┐${NC}"
    echo -e "${BOLD}${YELLOW}│           順位表                        │${NC}"
    echo -e "${BOLD}${YELLOW}├─────────────────────────────────────────┤${NC}"

    for item in "${sorted[@]}"; do
        score="${item%%:*}"
        combo="${item#*:}"
        
        if [ $rank -le 3 ]; then
            icon="${medal[$((rank-1))]}"
        else
            icon="  "
        fi
        
        printf "${YELLOW}│${NC} %s ${BOLD}%d位${NC}: %-15s ${CYAN}%d点${NC}${YELLOW}     │${NC}\n" "$icon" "$rank" "$combo" "$score"
        ((rank++))
    done

    echo -e "${BOLD}${YELLOW}└─────────────────────────────────────────┘${NC}"

    # 優勝者発表
    winner_item="${sorted[0]}"
    winner="${winner_item#*:}"
    winner_score="${winner_item%%:*}"

    echo ""
    echo -e "${BOLD}${RED}🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉${NC}"
    echo ""
    echo -e "${BOLD}${MAGENTA}      👑 M-1グランプリ優勝は... 👑${NC}"
    echo ""
    sleep 2
    echo -e "${BOLD}${GREEN}      ✨ ${winner} ✨${NC}"
    echo -e "${BOLD}${CYAN}         ${winner_score}点${NC}"
    echo ""
    echo -e "${BOLD}${RED}🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉${NC}"
    echo ""
}

# ランダムスコア生成モード（デモ用）
demo_mode() {
    local combos=("$@")
    
    for combo in "${combos[@]}"; do
        local total=0
        echo ""
        separator
        echo -e "${BOLD}${GREEN}🎭 ${combo}${NC}"
        separator
        echo ""
        
        for judge in "${JUDGES[@]}"; do
            # 80-100のランダムスコア
            score=$((RANDOM % 21 + 80))
            total=$((total + score))
            printf "  ${YELLOW}%-15s${NC}: ${CYAN}%d点${NC}\n" "$judge" "$score"
            sleep 0.3
        done
        
        echo ""
        echo -e "  ${BOLD}${RED}★ 合計: ${total}点${NC}"
        RESULTS["$combo"]=$total
    done
}

# メイン処理
main() {
    show_banner
    
    echo -e "${CYAN}モードを選択してください:${NC}"
    echo "  1) 手動採点モード"
    echo "  2) デモモード（ランダム採点）"
    echo ""
    echo -ne "${YELLOW}選択 (1/2): ${NC}"
    read -r mode

    case "$mode" in
        1)
            # 手動採点モード
            echo ""
            echo -ne "${CYAN}エントリー数を入力してください: ${NC}"
            read -r entry_count

            if ! [[ "$entry_count" =~ ^[0-9]+$ ]] || [ "$entry_count" -lt 1 ]; then
                echo -e "${RED}無効な入力です${NC}"
                exit 1
            fi

            entry_no=1
            while [ $entry_no -le "$entry_count" ]; do
                echo ""
                echo -ne "${CYAN}コンビ名 (No.${entry_no}): ${NC}"
                read -r combo_name
                
                if [ -n "$combo_name" ]; then
                    score_combo "$combo_name"
                    ((entry_no++))
                fi
            done
            ;;
        2)
            # デモモード
            echo ""
            echo -e "${GREEN}デモモードで実行します...${NC}"
            sleep 1
            
            demo_combos=("令和ロマン" "ヤーレンズ" "さや香" "真空ジェシカ" "オズワルド" "ダンビラムーチョ" "カベポスター" "マユリカ" "くらげ" "モグライダー")
            
            demo_mode "${demo_combos[@]}"
            ;;
        *)
            echo -e "${RED}無効な選択です${NC}"
            exit 1
            ;;
    esac

    # 最終結果表示
    show_final_results
    
    echo -e "${CYAN}ご視聴ありがとうございました！${NC}"
    echo ""
}

# 実行
main
