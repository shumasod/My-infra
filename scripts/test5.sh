#!/bin/bash

# 問題統計と分析スクリプト
# 問題の回答履歴を記録し、分析結果を表示します

# 色の設定
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 履歴ファイルの作成
HISTORY_DIR="quiz_history"
mkdir -p "$HISTORY_DIR"
HISTORY_FILE="$HISTORY_DIR/quiz_history_$(date +%Y%m%d_%H%M%S).csv"

# 履歴ヘッダーの作成
echo "問題ID,カテゴリ,正誤,解答時間,ユーザー解答,正解" > "$HISTORY_FILE"

# 問題ディレクトリの確認
if [ ! -d "generated_quiz" ]; then
    echo -e "${RED}問題ファイルが見つかりません。先に問題生成スクリプトを実行してください。${NC}"
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
    echo -e "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}問題ID: ${id}${NC} (${category}) [難易度: ${difficulty}]"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
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
        echo -e "\n${GREEN}正解です！${NC} ✓"
        is_correct=1
    else
        echo -e "\n${RED}不正解です。${NC} ✗"
        echo -e "正解は ${GREEN}${answer}${NC} です。"
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
    echo -e "\n${BLUE}【解説】${NC}"
    echo -e "$explanation\n"
    echo -e "解答時間: ${YELLOW}${elapsed_time}秒${NC}\n"
    
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
    echo -e "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}問題統計${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    
    # カテゴリ別統計
    echo -e "${BLUE}【カテゴリ別正答率】${NC}"
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
        local color=$RED
        if [ "$percentage" -ge 80 ]; then
            color=$GREEN
        elif [ "$percentage" -ge 60 ]; then
            color=$YELLOW
        fi
        
        echo -e "${category}: ${color}${percentage}%${NC} (${correct}/${total})"
    done
    
    echo -e "\n${BLUE}【難易度別正答率】${NC}"
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
        local color=$RED
        if [ "$percentage" -ge 80 ]; then
            color=$GREEN
        elif [ "$percentage" -ge 60 ]; then
            color=$YELLOW
        fi
        
        echo -e "${difficulty}: ${color}${percentage}%${NC} (${correct}/${total})"
    done
    
    # 問題別統計（正答率の低い順）
    echo -e "\n${BLUE}【最も間違えやすい問題】${NC}"
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
        local color=$RED
        if [ "$percentage" -ge 80 ]; then
            color=$GREEN
        elif [ "$percentage" -ge 60 ]; then
            color=$YELLOW
        fi
        
        echo -e "${i}. 問題ID: ${id} (${category}): ${color}${percentage}%${NC} (${correct}/${attempts})"
    done
    
    echo -e "\n履歴ファイル: ${BLUE}${HISTORY_FILE}${NC}"
}

# ランダム問題出題関数
random_quiz() {
    local num_questions=$1
    
    # 全ての問題ファイルを取得
    local question_files=($(find generated_quiz -type f -name "*.txt" | sort))
    
    # 問題がない場合
    if [ ${#question_files[@]} -eq 0 ]; then
        echo -e "${RED}問題ファイルが見つかりません。${NC}"
        return 1
    fi
    
    # 問題数の調整
    if [ -z "$num_questions" ] || [ "$num_questions" -gt "${#question_files[@]}" ]; then
        num_questions=${#question_files[@]}
        echo -e "${YELLOW}全ての問題（${num_questions}問）を出題します。${NC}"
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
        echo -e "${RED}カテゴリ「${category}」のディレクトリが見つかりません。${NC}"
        return 1
    fi
    
    # カテゴリの問題ファイルを取得
    local question_files=($(find "$category_path" -type f -name "*.txt" | sort))
    
    # 問題がない場合
    if [ ${#question_files[@]} -eq 0 ]; then
        echo -e "${RED}カテゴリ「${category}」には問題がありません。${NC}"
        return 1
    fi
    
    # 問題数の調整
    if [ -z "$num_questions" ] || [ "$num_questions" -gt "${#question_files[@]}" ]; then
        num_questions=${#question_files[@]}
        echo -e "${YELLOW}カテゴリ「${category}」の全ての問題（${num_questions}問）を出題します。${NC}"
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
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}日本語問題演習システム - 統計分析版${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    
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
                echo -e "${RED}無効なカテゴリ選択です。${NC}"
            fi
            ;;
        3)
            echo -e "\n${BLUE}演習を終了します。お疲れ様でした！${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}無効な選択です。${NC}"
            ;;
    esac
}

# スクリプト実行
main
