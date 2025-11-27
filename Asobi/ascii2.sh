#!/bin/bash

# ============================================================================
# 顔文字ルーレット＆ゲーム - Enhanced Kaomoji Roulette & Games
# Version: 2.0.0
# Description: 複数のゲームモードを持つインタラクティブな顔文字エンターテインメント
# ============================================================================

# エラー処理の設定
set -euo pipefail
trap cleanup EXIT
trap 'error_handler $LINENO' ERR

# グローバル設定
readonly VERSION="2.0.0"
readonly SCRIPT_NAME="$(basename "$0")"
readonly CONFIG_DIR="$HOME/.config/kaomoji_roulette"
readonly HIGH_SCORE_FILE="$CONFIG_DIR/highscores"
readonly HISTORY_FILE="$CONFIG_DIR/history"

# ANSIカラーコードの定義
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly BLINK='\033[5m'
readonly NC='\033[0m'

# 顔文字の配列（カテゴリ別）
declare -A KAOMOJI_CATEGORIES

KAOMOJI_CATEGORIES["happy"]="( ´ ▽ ` )ﾉ|(｡◕‿◕｡)|ヽ(^o^)丿|(◕‿◕✿)|٩(◕‿◕｡)۶|＼(^o^)／|(≧◡≦)|(◠‿◠)|(✯◡✯)|(≧∇≦)/"
KAOMOJI_CATEGORIES["love"]="(｡♥‿♥｡)|(✿ ♥‿♥)|ヽ(♡‿♡)ノ|(´♡‿♡`)|♥(ˆ⌣ˆԅ)|(灬º‿º灬)♡|♡(ӦｖӦ｡)|❤(◕‿◕)❤"
KAOMOJI_CATEGORIES["cool"]="(｀・ω・´)|ヽ(＾Д＾)ﾉ|(•̀ᴗ•́)و|(๑•̀ㅂ•́)و✧|(ง •̀_•́)ง|(⌐■_■)|(▀̿Ĺ̯▀̿ ̿)"
KAOMOJI_CATEGORIES["cute"]="(・∀・)|(｡･ω･｡)|(〃￣ω￣〃)|(*´∀｀*)|(´｡• ω •｡`)|(●'◡'●)|(◕ᴗ◕✿)|ʕ•ᴥ•ʔ|(＾• ω •＾)"
KAOMOJI_CATEGORIES["sad"]="(´･ω･`)|(╥﹏╥)|(｡•́︿•̀｡)|(っ˘̩╭╮˘̩)っ|(╯︵╰,)|(⌯˃̶᷄ ﹏ ˂̶᷄⌯)"
KAOMOJI_CATEGORIES["surprised"]="(°o°)|(⊙_⊙)|(●__●)|Σ(°△°|||)|(◉Д◉)|w(°ｏ°)w"

# 全顔文字を統合した配列
declare -a ALL_KAOMOJI

# ============================================================================
# 初期化関数
# ============================================================================

init_system() {
    # 設定ディレクトリの作成
    [[ ! -d "$CONFIG_DIR" ]] && mkdir -p "$CONFIG_DIR"
    [[ ! -f "$HIGH_SCORE_FILE" ]] && touch "$HIGH_SCORE_FILE"
    [[ ! -f "$HISTORY_FILE" ]] && touch "$HISTORY_FILE"
    
    # 全顔文字を配列に格納
    for category in "${!KAOMOJI_CATEGORIES[@]}"; do
        IFS='|' read -ra emojis <<< "${KAOMOJI_CATEGORIES[$category]}"
        ALL_KAOMOJI+=("${emojis[@]}")
    done
}

# エラーハンドラ
error_handler() {
    local line_no=$1
    echo -e "\n${RED}エラーが発生しました (行: $line_no)${NC}"
    cleanup
    exit 1
}

# クリーンアップ処理
cleanup() {
    # カーソルを表示
    tput cnorm 2>/dev/null || true
    # 画面をクリア
    echo -e "${NC}"
}

# ============================================================================
# ユーティリティ関数
# ============================================================================

# プログレスバーの表示
show_progress_bar() {
    local current=$1
    local total=$2
    local width=30
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    
    printf "\r["
    printf "%${filled}s" | tr ' ' '='
    printf "%$((width - filled))s" | tr ' ' '-'
    printf "] %3d%%" "$percentage"
}

# アニメーション付きテキスト表示
animated_text() {
    local text="$1"
    local delay="${2:-0.03}"
    
    for (( i=0; i<${#text}; i++ )); do
        echo -n "${text:$i:1}"
        sleep "$delay"
    done
    echo
}

# クリップボードにコピー
copy_to_clipboard() {
    local text="$1"
    local copied=false
    
    if command -v pbcopy > /dev/null 2>&1; then
        echo -n "$text" | pbcopy
        copied=true
    elif command -v xclip > /dev/null 2>&1; then
        echo -n "$text" | xclip -selection clipboard
        copied=true
    elif command -v wl-copy > /dev/null 2>&1; then
        echo -n "$text" | wl-copy
        copied=true
    elif command -v clip.exe > /dev/null 2>&1; then
        echo -n "$text" | clip.exe
        copied=true
    fi
    
    if [[ "$copied" == true ]]; then
        echo -e "${GREEN}✓ クリップボードにコピーしました！${NC}"
        return 0
    else
        return 1
    fi
}

# スコア保存
save_score() {
    local game="$1"
    local score="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "$timestamp|$game|$score" >> "$HIGH_SCORE_FILE"
}

# ============================================================================
# ゲーム: クラシックルーレット
# ============================================================================

classic_roulette() {
    local speed_ms=50
    local slowdown_factor=15
    local total_steps=30
    local current_step=0
    local index=0
    
    # カーソル非表示
    tput civis
    
    echo -e "\n${CYAN}━━━ ルーレット開始！ ━━━${NC}\n"
    sleep 0.5
    
    # メインアニメーション
    while [ $current_step -lt $total_steps ]; do
        # カーソル位置を保存して上書き表示
        printf "\r${YELLOW}回転中: ${GREEN}%-30s${NC}" "${ALL_KAOMOJI[$index]}"
        
        # インデックス更新
        index=$(( (index + 1) % ${#ALL_KAOMOJI[@]} ))
        current_step=$((current_step + 1))
        
        # 速度を徐々に遅くする
        if [ $current_step -gt $((total_steps * 2 / 3)) ]; then
            speed_ms=$((speed_ms + slowdown_factor))
            slowdown_factor=$((slowdown_factor + 5))
        fi
        
        # スリープ（ミリ秒をsleepコマンド用に変換）
        sleep "$(echo "scale=3; $speed_ms / 1000" | bc 2>/dev/null || echo "0.05")"
    done
    
    # 最終選択
    local final_index=$((RANDOM % ${#ALL_KAOMOJI[@]}))
    local winner="${ALL_KAOMOJI[$final_index]}"
    
    # 結果表示
    echo -e "\n\n${CYAN}╔════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}     ${BLINK}${YELLOW}★ 当選！★${NC}      ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}${winner}${NC}  ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════╝${NC}"
    
    # クリップボードにコピー
    copy_to_clipboard "$winner"
    
    # 履歴に保存
    echo "$(date '+%Y-%m-%d %H:%M:%S')|roulette|$winner" >> "$HISTORY_FILE"
    
    # カーソル表示
    tput cnorm
}

# ============================================================================
# ゲーム: 顔文字スロット
# ============================================================================

kaomoji_slot() {
    local credits=10
    local bet=1
    
    tput civis
    
    while [ $credits -gt 0 ]; do
        clear
        echo -e "${CYAN}╔════════════════════════════════╗${NC}"
        echo -e "${CYAN}║    ${YELLOW}顔文字スロットマシン${NC}     ${CYAN}║${NC}"
        echo -e "${CYAN}╠════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC} クレジット: ${GREEN}$credits${NC}  ベット: ${YELLOW}$bet${NC}  ${CYAN}║${NC}"
        echo -e "${CYAN}╚════════════════════════════════╝${NC}"
        echo
        
        echo -e "${WHITE}[ENTER] スピン | [q] 終了${NC}"
        read -n 1 -r key
        
        if [[ "$key" == "q" ]]; then
            break
        fi
        
        # ベット消費
        credits=$((credits - bet))
        
        # スロット回転アニメーション
        local slot1 slot2 slot3
        for i in {1..15}; do
            slot1="${ALL_KAOMOJI[$((RANDOM % ${#ALL_KAOMOJI[@]}))]}"
            slot2="${ALL_KAOMOJI[$((RANDOM % ${#ALL_KAOMOJI[@]}))]}"
            slot3="${ALL_KAOMOJI[$((RANDOM % ${#ALL_KAOMOJI[@]}))]}"
            
            printf "\r  %s | %s | %s  " "$slot1" "$slot2" "$slot3"
            sleep 0.1
        done
        
        # 最終結果
        slot1="${ALL_KAOMOJI[$((RANDOM % ${#ALL_KAOMOJI[@]}))]}"
        slot2="${ALL_KAOMOJI[$((RANDOM % ${#ALL_KAOMOJI[@]}))]}"
        slot3="${ALL_KAOMOJI[$((RANDOM % ${#ALL_KAOMOJI[@]}))]}"
        
        printf "\r  %s | %s | %s  \n\n" "$slot1" "$slot2" "$slot3"
        
        # 当たり判定
        if [[ "$slot1" == "$slot2" ]] && [[ "$slot2" == "$slot3" ]]; then
            local win=20
            credits=$((credits + win))
            echo -e "${BLINK}${GREEN}★★★ ジャックポット！！！ +$win クレジット ★★★${NC}"
            save_score "slot" "$win"
        elif [[ "$slot1" == "$slot2" ]] || [[ "$slot2" == "$slot3" ]] || [[ "$slot1" == "$slot3" ]]; then
            local win=3
            credits=$((credits + win))
            echo -e "${YELLOW}★ ペア成立！ +$win クレジット ★${NC}"
            save_score "slot" "$win"
        else
            echo -e "${RED}残念... もう一度挑戦！${NC}"
        fi
        
        sleep 2
    done
    
    echo -e "\n${CYAN}最終スコア: $credits クレジット${NC}"
    tput cnorm
}

# ============================================================================
# ゲーム: 顔文字神経衰弱
# ============================================================================

memory_game() {
    local size=4  # 4x4グリッド
    local total=$((size * size))
    local -a board hidden
    local moves=0
    local matches=0
    local first_pick=-1
    local second_pick=-1
    
    # ボード初期化（ペアを作成）
    local -a temp_emojis
    for i in $(seq 0 $((total / 2 - 1))); do
        local emoji="${ALL_KAOMOJI[$((RANDOM % ${#ALL_KAOMOJI[@]}))]}"
        temp_emojis+=("$emoji" "$emoji")
    done
    
    # シャッフル
    board=($(printf '%s\n' "${temp_emojis[@]}" | shuf))
    
    # 隠し状態の初期化
    for i in $(seq 0 $((total - 1))); do
        hidden[$i]=1
    done
    
    tput civis
    
    while [ $matches -lt $((total / 2)) ]; do
        clear
        echo -e "${CYAN}╔════════════════════════════════╗${NC}"
        echo -e "${CYAN}║     ${YELLOW}顔文字神経衰弱${NC}        ${CYAN}║${NC}"
        echo -e "${CYAN}╠════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC} 移動: ${GREEN}$moves${NC}  マッチ: ${YELLOW}$matches/$((total/2))${NC}  ${CYAN}║${NC}"
        echo -e "${CYAN}╚════════════════════════════════╝${NC}\n"
        
        # ボード表示
        for row in $(seq 0 $((size - 1))); do
            for col in $(seq 0 $((size - 1))); do
                local idx=$((row * size + col))
                printf "%2d:" $((idx + 1))
                
                if [ ${hidden[$idx]} -eq 0 ] || [ $idx -eq $first_pick ] || [ $idx -eq $second_pick ]; then
                    printf "%-15s" "${board[$idx]}"
                else
                    printf "%-15s" "[？？？]"
                fi
            done
            echo
        done
        
        echo -e "\n${WHITE}番号を入力 (1-$total) または 'q' で終了:${NC}"
        read -r choice
        
        if [[ "$choice" == "q" ]]; then
            break
        fi
        
        # 入力検証
        if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt $total ]; then
            continue
        fi
        
        local idx=$((choice - 1))
        
        # すでに開いているカードは選択不可
        if [ ${hidden[$idx]} -eq 0 ]; then
            continue
        fi
        
        if [ $first_pick -eq -1 ]; then
            first_pick=$idx
        else
            second_pick=$idx
            moves=$((moves + 1))
            
            # マッチ判定
            if [[ "${board[$first_pick]}" == "${board[$second_pick]}" ]]; then
                hidden[$first_pick]=0
                hidden[$second_pick]=0
                matches=$((matches + 1))
                
                # 再表示して成功を見せる
                clear
                echo -e "${GREEN}★ マッチ成功！ ★${NC}"
                sleep 1
            else
                # 一時的に両方表示
                clear
                echo -e "${RED}✗ 不一致... ✗${NC}"
                sleep 1.5
            fi
            
            first_pick=-1
            second_pick=-1
        fi
    done
    
    if [ $matches -eq $((total / 2)) ]; then
        echo -e "\n${BLINK}${GREEN}★★★ クリア！おめでとう！ ★★★${NC}"
        echo -e "${CYAN}総移動数: $moves${NC}"
        save_score "memory" "$moves"
    fi
    
    tput cnorm
    sleep 3
}

# ============================================================================
# ゲーム: 顔文字占い
# ============================================================================

fortune_telling() {
    local -a fortunes=(
        "大吉|素晴らしい一日になるでしょう！"
        "吉|良いことが起こりそうです"
        "中吉|平穏な一日を過ごせます"
        "小吉|小さな幸せが見つかります"
        "末吉|努力が報われる日"
        "凶|注意深く行動しましょう"
    )
    
    local -a lucky_items=(
        "青いペン" "白い花" "丸いもの" "甘いお菓子"
        "古い本" "新しい靴" "緑の葉っぱ" "キラキラしたもの"
    )
    
    echo -e "\n${PURPLE}占いの準備中...${NC}"
    animated_text "あなたの運勢を占います..." 0.05
    sleep 1
    
    # ランダムに顔文字と運勢を選択
    local kaomoji="${ALL_KAOMOJI[$((RANDOM % ${#ALL_KAOMOJI[@]}))]}"
    local fortune="${fortunes[$((RANDOM % ${#fortunes[@]}))]}"
    local lucky_item="${lucky_items[$((RANDOM % ${#lucky_items[@]}))]}"
    
    IFS='|' read -r result message <<< "$fortune"
    
    # 結果表示
    clear
    echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║       ${PURPLE}★ 今日の運勢 ★${NC}        ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  守護顔文字: ${GREEN}$kaomoji${NC}"
    echo -e "${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  運勢: ${YELLOW}【$result】${NC}"
    echo -e "${CYAN}║${NC}  $message"
    echo -e "${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ラッキーアイテム: ${BLUE}$lucky_item${NC}"
    echo -e "${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"
    
    copy_to_clipboard "$kaomoji"
    echo "$(date '+%Y-%m-%d %H:%M:%S')|fortune|$result|$kaomoji" >> "$HISTORY_FILE"
}

# ============================================================================
# メニューシステム
# ============================================================================

show_main_menu() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}   ${YELLOW}顔文字ゲームセンター v$VERSION${NC}   ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC}                                      ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}1)${NC} 🎰 クラシックルーレット        ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}2)${NC} 🎲 顔文字スロット              ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}3)${NC} 🃏 神経衰弱ゲーム              ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}4)${NC} 🔮 今日の運勢占い              ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}5)${NC} 📊 ハイスコア表示              ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}6)${NC} 📜 履歴表示                    ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}7)${NC} ❓ ヘルプ                      ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}8)${NC} ❌ 終了                        ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}                                      ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"
}

show_high_scores() {
    clear
    echo -e "${CYAN}=== ハイスコア ===${NC}\n"
    
    if [[ -s "$HIGH_SCORE_FILE" ]]; then
        echo -e "${YELLOW}最近のスコア:${NC}"
        tail -10 "$HIGH_SCORE_FILE" | while IFS='|' read -r timestamp game score; do
            echo -e "${GREEN}$timestamp${NC} - $game: $score"
        done
    else
        echo -e "${YELLOW}まだスコアがありません${NC}"
    fi
    
    echo -e "\n${WHITE}Enterキーを押してメニューに戻る...${NC}"
    read -r
}

show_history() {
    clear
    echo -e "${CYAN}=== 使用履歴 ===${NC}\n"
    
    if [[ -s "$HISTORY_FILE" ]]; then
        echo -e "${YELLOW}最近の顔文字:${NC}"
        tail -10 "$HISTORY_FILE" | while IFS='|' read -r timestamp game result rest; do
            echo -e "${GREEN}$timestamp${NC} [$game]: $result"
        done
    else
        echo -e "${YELLOW}まだ履歴がありません${NC}"
    fi
    
    echo -e "\n${WHITE}Enterキーを押してメニューに戻る...${NC}"
    read -r
}

show_help() {
    clear
    cat << EOF
${CYAN}╔══════════════════════════════════════╗
║      ヘルプ - 使い方ガイド          ║
╚══════════════════════════════════════╝${NC}

${YELLOW}【ゲーム説明】${NC}

${GREEN}1. クラシックルーレット${NC}
   ランダムに顔文字を選択します。
   選ばれた顔文字は自動的にクリップボードにコピーされます。

${GREEN}2. 顔文字スロット${NC}
   スロットマシンゲーム。3つ揃えばジャックポット！
   クレジットを増やして高得点を目指しましょう。

${GREEN}3. 神経衰弱ゲーム${NC}
   同じ顔文字のペアを見つけるメモリーゲーム。
   できるだけ少ない手数でクリアを目指しましょう。

${GREEN}4. 今日の運勢占い${NC}
   今日の運勢と守護顔文字を占います。
   ラッキーアイテムも教えてくれます。

${YELLOW}【その他の機能】${NC}

• 選ばれた顔文字は自動的にクリップボードにコピー
• ゲームスコアと使用履歴の記録
• マルチプラットフォーム対応

${CYAN}開発: Kaomoji Game Center Team
バージョン: $VERSION${NC}

EOF
    echo -e "${WHITE}Enterキーを押してメニューに戻る...${NC}"
    read -r
}

# ============================================================================
# メイン処理
# ============================================================================

main() {
    # 初期化
    init_system
    
    # メインループ
    while true; do
        show_main_menu
        echo -e "\n${WHITE}選択してください (1-8): ${NC}"
        read -r choice
        
        case $choice in
            1)
                classic_roulette
                echo -e "\n${WHITE}Enterキーを押して続ける...${NC}"
                read -r
                ;;
            2)
                kaomoji_slot
                ;;
            3)
                memory_game
                ;;
            4)
                fortune_telling
                echo -e "\n${WHITE}Enterキーを押して続ける...${NC}"
                read -r
                ;;
            5)
                show_high_scores
                ;;
            6)
                show_history
                ;;
            7)
                show_help
                ;;
            8)
                echo -e "\n${YELLOW}またね！(｡･ω･)ﾉﾞ${NC}"
                animated_text "Thank you for playing!" 0.03
                exit 0
                ;;
            *)
                echo -e "\n${RED}無効な選択です${NC}"
                sleep 1
                ;;
        esac
    done
}

# スクリプトの実行
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
