#!/bin/bash
set -euo pipefail

# 問題統計と分析スクリプト
# 問題の回答履歴を記録し、分析結果を表示します

# 共通ライブラリの読み込み
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

# 履歴ファイルの作成
HISTORY_DIR="quiz_history"
mkdir -p "$HISTORY_DIR"
HISTORY_FILE="$HISTORY_DIR/quiz_history_$(date +%Y%m%d_%H%M%S).csv"

# 履歴ヘッダーの作成
echo "問題ID,カテゴリ,正誤,解答時間,ユーザー解答,正解" > "$HISTORY_FILE"

# 問題ディレクトリの確認
if [ ! -d "generated_quiz" ]; then
    echo -e "${C_RED}問題ファイルが見つかりません。先に問題生成スクリプトを実行してください。${C_RESET}"
    exit 1
fi

# 統計データを格納する連想配列
declare -A category_total
declare -A category_correct
declare -A difficulty_total
declare -A difficulty_correct
declare -A question_attempts
declare -A question_correct

# カテゴリリスト
CATEGORIES=("文法" "語彙" "読解" "論理" "数学" "文化")

# 問題を表示し解答を受け付ける関数（時間計測付き）
display_and_answer() {
    local question_file=$1
    
    # 問題情報の取得
    local id=$(grep "問題ID:" "$question_file" | cut -d' ' -f2)
    local category=$(grep "カテゴリ:" "$question_file" | cut -d' ' -f2)
    local question=$(sed -n '/問題:/,/選択肢:/p' "$question_file" | sed '1d;$d')
    local options=$(sed -n '/選択肢:/,/正解:/p' "$question_file" | sed '1d;$d')
    local answer=$(grep "正解:" "$question_file" | cut -d' ' -f2)
    local explanation=$(sed -n '/解説:/,$p' "$question_file" | sed '1d')
    
    # 難易度の設定（この例では仮のロジックです）
    local difficulty="普通"
    if [[ "$category" == "論理" ]] || [[ "$category" == "数学" ]]; then
        difficulty="難しい"
    elif [[ "$category" == "文法" ]] || [[ "$category" == "語彙" ]]; then
        difficulty="易しい"
    fi
    
    # 問題の表示
    echo -e "\n${C_YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
    echo -e "${C_BLUE}問題ID: ${id}${C_RESET} (${category}) [難易度: ${difficulty}]"
    echo -e "${C_YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}\n"
    echo -e "$question\n"
    echo -e "$options\n"
    
    # 時間計測開始
    local start_time=$(date +%s)
    
    # 解答の受付
    echo -n "あなたの解答（A/B/C/D/E）: "
    read user_answer
    
    # 時間計測終了
    local end_time=$(date +%s)
    local elapsed_time=$((end_time - start_time))
    
    # 解答を大文字に変換
    user_answer=$(echo "$user_answer" | tr '[:lower:]' '[:upper:]')
    
    # 解答の判定
    local is_correct=0
    if [ "$user_answer" == "$answer" ]; then
        echo -e "\n${C_GREEN}正解です！${C_RESET} ✓"
        is_correct=1
    else
        echo -e "\n${C_RED}不正解です。${C_RESET} ✗"
        echo -e "正解は ${C_GREEN}${answer}${C_RESET} です。"
    fi
    
    # 統計データの更新
    category_total["$category"]=$((${category_total["$category"]} + 1))
    difficulty_total["$difficulty"]=$((${difficulty_total["$difficulty"]} + 1))
    question_attempts["$id"]=$((${question_attempts["$id"]} + 1))
    
    if [ $is_correct -eq 1 ]; then
        category_correct["$category"]=$((${category_correct["$category"]} + 1))
        difficulty_correct["$difficulty"]=$((${difficulty_correct["$difficulty"]} + 1))
        question_correct["$id"]=$((${question_correct["$id"]} + 1))
    fi
    
    # 履歴への記録
    echo "$id,$category,$is_correct,$elapsed_time,$user_answer,$answer" >> "$HISTORY_FILE"
    
    # 解説の表示
    echo -e "\n${C_BLUE}【解説】${C_RESET}"
    echo -e "$explanation\n"
    echo -e "解答時間: ${C_YELLOW}${elapsed_time}秒${C_RESET}\n"
    
    # 続行の確認
    echo -n "次の問題に進みますか？（Y/n）: "
    read continue_answer
    
    if [ "${continue_answer,,}" == "n" ]; then
        return 1
    else
        return 0
    fi
}

# 統計表示関数
display_statistics() {
    echo -e "\n${C_YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
    echo -e "${C_BLUE}問題統計${C_RESET}"
    echo -e "${C_YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}\n"
    
    # カテゴリ別統計
    echo -e "${C_BLUE}【カテゴリ別正答率】${C_RESET}"
    for category in "${CATEGORIES[@]}"; do
        local total=${category_total["$category"]}
        if [ -z "$total" ] || [ "$total" -eq 0 ]; then
            continue
        fi
        
        local correct=${category_correct["$category"]}
        if [ -z "$correct" ]; then
            correct=0
        fi
        
        local percentage=0
        if [ "$total" -gt 0 ]; then
            percentage=$((correct * 100 / total))
        fi
        
        # カラーコードの設定
        local color=$C_RED
        if [ "$percentage" -ge 80 ]; then
            color=$C_GREEN
        elif [ "$percentage" -ge 60 ]; then
            color=$C_YELLOW
        fi
        
        echo -e "${category}: ${color}${percentage}%${C_RESET} (${correct}/${total})"
    done
    
    echo -e "\n${C_BLUE}【難易度別正答率】${C_RESET}"
    for difficulty in "易しい" "普通" "難しい"; do
        local total=${difficulty_total["$difficulty"]}
        if [ -z "$total" ] || [ "$total" -eq 0 ]; then
            continue
        fi
        
        local correct=${difficulty_correct["$difficulty"]}
        if [ -z "$correct" ]; then
            correct=0
        fi
        
        local percentage=0
        if [ "$total" -gt 0 ]; then
            percentage=$((correct * 100 / total))
        fi
        
        # カラーコードの設定
        local color=$C_RED
        if [ "$percentage" -ge 80 ]; then
            color=$C_GREEN
        elif [ "$percentage" -ge 60 ]; then
            color=$C_YELLOW
        fi
        
        echo -e "${difficulty}: ${color}${percentage}%${C_RESET} (${correct}/${total})"
    done
    
    # 問題別統計（正答率の低い順）
    echo -e "\n${C_BLUE}【最も間違えやすい問題】${C_RESET}"
    declare -A question_percentage
    
    for id in "${!question_attempts[@]}"; do
        local attempts=${question_attempts["$id"]}
        local correct=${question_correct["$id"]}
        if [ -z "$correct" ]; then
            correct=0
        fi
        
        local percentage=0
        if [ "$attempts" -gt 0 ]; then
            percentage=$((correct * 100 / attempts))
        fi
        
        question_percentage["$id"]=$percentage
    done
    
    # 正答率の低い順にソート（最大5問）
    i=0
    for id in $(for qid in "${!question_percentage[@]}"; do echo "$qid ${question_percentage[$qid]}"; done | sort -k2n | head -5 | awk '{print $1}'); do
        i=$((i + 1))
        
        # 問題ファイルの検索
        question_file=$(find generated_quiz -type f -name "*${id}*.txt")
        
        if [ -z "$question_file" ]; then
            continue
        fi
        
        # カテゴリの取得
        local category=$(grep "カテゴリ:" "$question_file" | cut -d' ' -f2)
        local attempts=${question_attempts["$id"]}
        local correct=${question_correct["$id"]}
        local percentage=${question_percentage["$id"]}
        
        # カラーコードの設定
        local color=$C_RED
        if [ "$percentage" -ge 80 ]; then
            color=$C_GREEN
        elif [ "$percentage" -ge 60 ]; then
            color=$C_YELLOW
        fi
        
        echo -e "${i}. 問題ID: ${id} (${category}): ${color}${percentage}%${C_RESET} (${correct}/${attempts})"
    done
    
    echo -e "\n履歴ファイル: ${C_BLUE}${HISTORY_FILE}${C_RESET}"
}

# ランダム問題出題関数
random_quiz() {
    local num_questions=$1
    
    # 全ての問題ファイルを取得
    local question_files=($(find generated_quiz -type f -name "*.txt" | sort))
    
    # 問題がない場合
    if [ ${#question_files[@]} -eq 0 ]; then
        echo -e "${C_RED}問題ファイルが見つかりません。${C_RESET}"
        return 1
    fi
    
    # 問題数の調整
    if [ -z "$num_questions" ] || [ "$num_questions" -gt "${#question_files[@]}" ]; then
        num_questions=${#question_files[@]}
        echo -e "${C_YELLOW}全ての問題（${num_questions}問）を出題します。${C_RESET}"
    fi
    
    # 問題をランダムに選択
    selected_files=()
    
    # Fisher-Yates シャッフルアルゴリズム
    question_files_copy=()
    for ((i=0; i<${#question_files[@]}; i++)); do
        question_files_copy+=("${question_files[$i]}")
    done
    
    for ((i=${#question_files_copy[@]}-1; i>=0; i--)); do
        j=$((RANDOM % (i+1)))
        temp="${question_files_copy[$i]}"
        question_files_copy[$i]="${question_files_copy[$j]}"
        question_files_copy[$j]="$temp"
    done
    
    selected_files=("${question_files_copy[@]:0:$num_questions}")
    
    # 問題を表示
    for question_file in "${selected_files[@]}"; do
        if ! display_and_answer "$question_file"; then
            break
        fi
    done
    
    # 統計表示
    display_statistics
}

# カテゴリ別問題出題関数
category_quiz() {
    local category=$1
    local num_questions=$2
    
    # カテゴリのパスを設定
    local category_path="generated_quiz/$category"
    
    # ディレクトリの存在チェック
    if [ ! -d "$category_path" ]; then
        echo -e "${C_RED}カテゴリ「${category}」のディレクトリが見つかりません。${C_RESET}"
        return 1
    fi
    
    # カテゴリの問題ファイルを取得
    local question_files=($(find "$category_path" -type f -name "*.txt" | sort))
    
    # 問題がない場合
    if [ ${#question_files[@]} -eq 0 ]; then
        echo -e "${C_RED}カテゴリ「${category}」には問題がありません。${C_RESET}"
        return 1
    fi
    
    # 問題数の調整
    if [ -z "$num_questions" ] || [ "$num_questions" -gt "${#question_files[@]}" ]; then
        num_questions=${#question_files[@]}
        echo -e "${C_YELLOW}カテゴリ「${category}」の全ての問題（${num_questions}問）を出題します。${C_RESET}"
    fi
    
    # 問題をランダムに選択
    selected_files=()
    
    # Fisher-Yates シャッフルアルゴリズム
    question_files_copy=()
    for ((i=0; i<${#question_files[@]}; i++)); do
        question_files_copy+=("${question_files[$i]}")
    done
    
    for ((i=${#question_files_copy[@]}-1; i>=0; i--)); do
        j=$((RANDOM % (i+1)))
        temp="${question_files_copy[$i]}"
        question_files_copy[$i]="${question_files_copy[$j]}"
        question_files_copy[$j]="$temp"
    done
    
    selected_files=("${question_files_copy[@]:0:$num_questions}")
    
    # 問題を表示
    for question_file in "${selected_files[@]}"; do
        if ! display_and_answer "$question_file"; then
            break
        fi
    done
    
    # 統計表示
    display_statistics
}

# メイン実行関数
main() {
    echo -e "${C_YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
    echo -e "${C_BLUE}日本語問題演習システム - 統計分析版${C_RESET}"
    echo -e "${C_YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}\n"
    
    echo -e "モードを選択してください："
    echo "1. ランダム出題"
    echo "2. カテゴリ別出題"
    echo "3. 終了"
    
    echo -n "選択（1-3）: "
    read mode_selection
    
    case $mode_selection in
        1)
            echo -n "出題する問題数を入力してください: "
            read num_questions
            random_quiz "$num_questions"
            ;;
        2)
            echo -e "\nカテゴリを選択してください："
            for i in "${!CATEGORIES[@]}"; do
                echo "$((i+1)). ${CATEGORIES[$i]}"
            done
            
            echo -n "選択（1-${#CATEGORIES[@]}）: "
            read category_selection
            
            if [ "$category_selection" -ge 1 ] && [ "$category_selection" -le "${#CATEGORIES[@]}" ]; then
                selected_category="${CATEGORIES[$((category_selection-1))]}"
                
                echo -n "出題する問題数を入力してください: "
                read num_questions
                
                category_quiz "$selected_category" "$num_questions"
            else
                echo -e "${C_RED}無効なカテゴリ選択です。${C_RESET}"
            fi
            ;;
        3)
            echo -e "\n${C_BLUE}演習を終了します。お疲れ様でした！${C_RESET}"
            exit 0
            ;;
        *)
            echo -e "${C_RED}無効な選択です。${C_RESET}"
            ;;
    esac
}

# スクリプト実行
main
