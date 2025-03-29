#!/bin/bash

# オセロゲーム (リバーシ) シェルスクリプト版
# 8x8ボードで遊ぶテキストベースのオセロゲーム

# 色の定義
BLACK="\033[30;47m"  # 黒石（白背景に黒文字）
WHITE="\033[37;40m"  # 白石（黒背景に白文字）
RESET="\033[0m"      # リセット
GREEN="\033[32m"     # 緑色（ボードの線）

# プレイヤー表示用
PLAYER_BLACK="●"
PLAYER_WHITE="○"

# 初期設定
BOARD_SIZE=8
EMPTY="."
BLACK_PIECE="B"
WHITE_PIECE="W"
CURRENT_PLAYER=$BLACK_PIECE

# ボードの初期化
initialize_board() {
    # 8x8の空のボードを作成
    BOARD=()
    for (( i=0; i<$BOARD_SIZE; i++ )); do
        ROW=()
        for (( j=0; j<$BOARD_SIZE; j++ )); do
            ROW+=($EMPTY)
        done
        BOARD+=("${ROW[@]}")
    done
    
    # 初期配置（中央に4つの石を置く）
    local mid1=$((BOARD_SIZE/2-1))
    local mid2=$((BOARD_SIZE/2))
    BOARD[$mid1][$mid1]=$WHITE_PIECE
    BOARD[$mid1][$mid2]=$BLACK_PIECE
    BOARD[$mid2][$mid1]=$BLACK_PIECE
    BOARD[$mid2][$mid2]=$WHITE_PIECE
}

# ボードの表示
display_board() {
    clear
    echo "  オセロゲーム (リバーシ)"
    echo "  プレイヤー: ${BLACK}${PLAYER_BLACK}${RESET} vs ${WHITE}${PLAYER_WHITE}${RESET}"
    echo
    
    # 列の番号を表示（1-8）
    echo -n "  "
    for (( j=0; j<$BOARD_SIZE; j++ )); do
        echo -n "${GREEN}$((j+1)) ${RESET}"
    done
    echo
    
    # ボードとその内容を表示
    for (( i=0; i<$BOARD_SIZE; i++ )); do
        # 行の番号を表示（A-H）
        echo -n "${GREEN}$( printf "\\$(printf '%03o' $((i+65))) " )${RESET}"
        
        for (( j=0; j<$BOARD_SIZE; j++ )); do
            case ${BOARD[$i][$j]} in
                $BLACK_PIECE)
                    echo -n "${BLACK}${PLAYER_BLACK}${RESET} "
                    ;;
                $WHITE_PIECE)
                    echo -n "${WHITE}${PLAYER_WHITE}${RESET} "
                    ;;
                $EMPTY)
                    echo -n "${GREEN}.${RESET} "
                    ;;
            esac
        done
        echo
    done
    
    # スコアを表示
    count_pieces
    echo
    echo "スコア: ${BLACK}${PLAYER_BLACK}${RESET}: $BLACK_COUNT vs ${WHITE}${PLAYER_WHITE}${RESET}: $WHITE_COUNT"
    
    # 現在のプレイヤーを表示
    if [[ $CURRENT_PLAYER == $BLACK_PIECE ]]; then
        echo "現在のプレイヤー: ${BLACK}${PLAYER_BLACK}${RESET}"
    else
        echo "現在のプレイヤー: ${WHITE}${PLAYER_WHITE}${RESET}"
    fi
}

# 駒の数を数える
count_pieces() {
    BLACK_COUNT=0
    WHITE_COUNT=0
    
    for (( i=0; i<$BOARD_SIZE; i++ )); do
        for (( j=0; j<$BOARD_SIZE; j++ )); do
            if [[ ${BOARD[$i][$j]} == $BLACK_PIECE ]]; then
                ((BLACK_COUNT++))
            elif [[ ${BOARD[$i][$j]} == $WHITE_PIECE ]]; then
                ((WHITE_COUNT++))
            fi
        done
    done
}

# 有効な手かどうかチェック
is_valid_move() {
    local row=$1
    local col=$2
    local player=$3
    
    # 相手の駒
    if [[ $player == $BLACK_PIECE ]]; then
        local opponent=$WHITE_PIECE
    else
        local opponent=$BLACK_PIECE
    fi
    
    # 既に駒がある場所には置けない
    if [[ ${BOARD[$row][$col]} != $EMPTY ]]; then
        return 1
    fi
    
    # 8方向（上、右上、右、右下、下、左下、左、左上）
    local directions=(
        "-1 0"  "-1 1"  "0 1"  "1 1" 
        "1 0"   "1 -1"  "0 -1" "-1 -1"
    )
    
    local valid=0
    
    # 各方向をチェック
    for direction in "${directions[@]}"; do
        read dr dc <<< "$direction"
        
        local r=$((row + dr))
        local c=$((col + dc))
        
        # 相手の駒が続く限りループ
        local found_opponent=0
        while [[ $r -ge 0 && $r -lt $BOARD_SIZE && $c -ge 0 && $c -lt $BOARD_SIZE && ${BOARD[$r][$c]} == $opponent ]]; do
            found_opponent=1
            r=$((r + dr))
            c=$((c + dc))
        done
        
        # 相手の駒の後に自分の駒があれば有効な手
        if [[ $found_opponent -eq 1 && $r -ge 0 && $r -lt $BOARD_SIZE && $c -ge 0 && $c -lt $BOARD_SIZE && ${BOARD[$r][$c]} == $player ]]; then
            valid=1
            break
        fi
    done
    
    return $((1 - valid))
}

# 盤面を更新（駒をひっくり返す）
make_move() {
    local row=$1
    local col=$2
    local player=$3
    
    # 相手の駒
    if [[ $player == $BLACK_PIECE ]]; then
        local opponent=$WHITE_PIECE
    else
        local opponent=$BLACK_PIECE
    fi
    
    # 駒を置く
    BOARD[$row][$col]=$player
    
    # 8方向（上、右上、右、右下、下、左下、左、左上）
    local directions=(
        "-1 0"  "-1 1"  "0 1"  "1 1" 
        "1 0"   "1 -1"  "0 -1" "-1 -1"
    )
    
    # 各方向をチェックして駒をひっくり返す
    for direction in "${directions[@]}"; do
        read dr dc <<< "$direction"
        
        local flip_list=()
        local r=$((row + dr))
        local c=$((col + dc))
        
        # 相手の駒が続く限りリストに追加
        while [[ $r -ge 0 && $r -lt $BOARD_SIZE && $c -ge 0 && $c -lt $BOARD_SIZE && ${BOARD[$r][$c]} == $opponent ]]; do
            flip_list+=("$r $c")
            r=$((r + dr))
            c=$((c + dc))
        done
        
        # 相手の駒の後に自分の駒があれば、リストの駒をひっくり返す
        if [[ ${#flip_list[@]} -gt 0 && $r -ge 0 && $r -lt $BOARD_SIZE && $c -ge 0 && $c -lt $BOARD_SIZE && ${BOARD[$r][$c]} == $player ]]; then
            for pos in "${flip_list[@]}"; do
                read fr fc <<< "$pos"
                BOARD[$fr][$fc]=$player
            done
        fi
    done
}

# 有効な手があるかチェック
has_valid_moves() {
    local player=$1
    
    for (( i=0; i<$BOARD_SIZE; i++ )); do
        for (( j=0; j<$BOARD_SIZE; j++ )); do
            if is_valid_move $i $j $player; then
                return 0
            fi
        done
    done
    
    return 1
}

# プレイヤーの入力を処理
get_player_move() {
    local valid=0
    local row
    local col
    
    while [[ $valid -eq 0 ]]; do
        echo -n "駒を置く位置を入力（例: B3）またはqで終了: "
        read -r input
        
        # 終了オプション
        if [[ ${input,,} == "q" ]]; then
            echo "ゲームを終了します"
            exit 0
        fi
        
        # 入力形式チェック（A-Hの文字と1-8の数字）
        if [[ ${#input} -eq 2 && ${input:0:1} =~ [A-Ha-h] && ${input:1:1} =~ [1-8] ]]; then
            # 行 (A-H -> 0-7)
            row=$(( $(printf "%d" "'${input:0:1}") - 65 ))
            # 小文字の場合の調整
            if [[ $row -gt 7 ]]; then
                row=$((row - 32))
            fi
            
            # 列 (1-8 -> 0-7)
            col=$((${input:1:1} - 1))
            
            # 有効な手かチェック
            if is_valid_move $row $col $CURRENT_PLAYER; then
                valid=1
            else
                echo "その場所には置けません。有効な場所を選んでください。"
            fi
        else
            echo "無効な入力です。A-Hの文字と1-8の数字を使用してください（例: B3）"
        fi
    done
    
    # 有効な手を実行
    make_move $row $col $CURRENT_PLAYER
}

# プレイヤーを交代
switch_player() {
    if [[ $CURRENT_PLAYER == $BLACK_PIECE ]]; then
        CURRENT_PLAYER=$WHITE_PIECE
    else
        CURRENT_PLAYER=$BLACK_PIECE
    fi
    
    # 新しいプレイヤーに有効な手がなければ、もう一度交代
    if ! has_valid_moves $CURRENT_PLAYER; then
        echo "有効な手がありません。プレイヤーをスキップします。"
        sleep 2
        
        if [[ $CURRENT_PLAYER == $BLACK_PIECE ]]; then
            CURRENT_PLAYER=$WHITE_PIECE
        else
            CURRENT_PLAYER=$BLACK_PIECE
        fi
        
        # 両プレイヤーが置けない場合はゲーム終了
        if ! has_valid_moves $CURRENT_PLAYER; then
            return 1
        fi
    fi
    
    return 0
}

# ゲーム終了時の処理
end_game() {
    display_board
    
    echo
    echo "ゲーム終了！"
    
    if [[ $BLACK_COUNT -gt $WHITE_COUNT ]]; then
        echo "${BLACK}${PLAYER_BLACK}${RESET}の勝利！"
    elif [[ $WHITE_COUNT -gt $BLACK_COUNT ]]; then
        echo "${WHITE}${PLAYER_WHITE}${RESET}の勝利！"
    else
        echo "引き分け！"
    fi
}

# メインゲームループ
main() {
    initialize_board
    
    while true; do
        display_board
        get_player_move
        
        if ! switch_player; then
            break
        fi
    done
    
    end_game
}

# ゲーム開始
main
