#!/bin/bash
set -euo pipefail

# 問題表示・解答スクリプト
# 生成した問題を表示し、ユーザーからの解答を受け付けます

# 共通ライブラリの読み込み
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

# 問題ディレクトリの確認
if [ ! -d "generated_quiz" ]; then
    echo -e "${C_RED}問題ファイルが見つかりません。先に問題生成スクリプトを実行してください。${C_RESET}"
    exit 1
fi

# 得点を記録する変数
SCORE=0
TOTAL=0

# カテゴリリスト
CATEGORIES=("文法" "語彙" "読解" "論理" "数学" "文化")

# 問題を表示し解答を受け付ける関数
display_and_answer() {
    local question_file=$1
    
    # 問題情報の取得
    local id=$(grep "問題ID:" "$question_file" | cut -d' ' -f2)
    local category=$(grep "カテゴリ:" "$question_file" | cut -d' ' -f2)
    local question=$(sed -n '/問題:/,/選択肢:/p' "$question_file" | sed '1d;$d')
    local options=$(sed -n '/選択肢:/,/正解:/p' "$question_file" | sed '1d;$d')
    local answer=$(grep "正解:" "$question_file" | cut -d' ' -f2)
    local explanation=$(sed -n '/解説:/,$p' "$question_file" | sed '1d')
    
    # 問題の表示
    echo -e "\n${C_YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
    echo -e "${C_BLUE}問題ID: ${id}${C_RESET} (${category})"
    echo -e "${C_YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}\n"
    echo -e "$question\n"
    echo -e "$options\n"
    
    # 解答の受付
    echo -n "あなたの解答（A/B/C/D/E）: "
    read user_answer
    
    # 解答を大文字に変換
    user_answer=$(echo "$user_answer" | tr '[:lower:]' '[:upper:]')
    
    # 解答の判定
    TOTAL=$((TOTAL + 1))
    if [ "$user_answer" == "$answer" ]; then
        echo -e "\n${C_GREEN}正解です！${C_RESET} ✓"
        SCORE=$((SCORE + 1))
    else
        echo -e "\n${C_RED}不正解です。${C_RESET} ✗"
        echo -e "正解は ${C_GREEN}${answer}${C_RESET} です。"
    fi
    
    # 解説の表示
    echo -e "\n${C_BLUE}【解説】${C_RESET}"
    echo -e "$explanation\n"
    
    # 続行の確認
    echo -n "次の問題に進みますか？（Y/n）: "
    read continue_answer
    
    if [ "${continue_answer,,}" == "n" ]; then
        return 1
    else
        return 0
    fi
}

# カテゴリ選択
select_category() {
    echo -e "\n${C_YELLOW}問題カテゴリを選択してください：${C_RESET}"
    echo "0. 全てのカテゴリ"
    for i in "${!CATEGORIES[@]}"; do
        echo "$((i+1)). ${CATEGORIES[$i]}"
    done
    
    echo -n "選択（0-6）: "
    read category_selection
    
    if [ "$category_selection" -eq 0 ]; then
        return 0
    elif [ "$category_selection" -ge 1 ] && [ "$category_selection" -le 6 ]; then
        return $category_selection
    else
        echo -e "${C_RED}無効な選択です。全てのカテゴリから出題します。${C_RESET}"
        return 0
    fi
}

# メイン実行機能
main() {
    echo -e "${C_YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
    echo -e "${C_BLUE}日本語問題演習システム${C_RESET}"
    echo -e "${C_YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}\n"
    
    # カテゴリ選択
    select_category
    local selected_category=$?
    
    # 問題ファイルの取得
    local question_files=()
    
    if [ $selected_category -eq 0 ]; then
        # 全てのカテゴリから問題を取得
        question_files=($(find generated_quiz -type f -name "*.txt" | sort))
    else
        # 選択されたカテゴリの問題を取得
        local category_name="${CATEGORIES[$((selected_category-1))]}"
        question_files=($(find "generated_quiz/$category_name" -type f -name "*.txt" | sort))
    fi
    
    # 問題がない場合
    if [ ${#question_files[@]} -eq 0 ]; then
        echo -e "${C_RED}選択されたカテゴリには問題がありません。${C_RESET}"
        exit 1
    fi
    
    # 問題数の設定
    echo -e "\n何問解きますか？（最大: ${#question_files[@]}問）"
    echo -n "問題数: "
    read num_questions
    
    if [ -z "$num_questions" ] || ! [[ "$num_questions" =~ ^[0-9]+$ ]] || [ "$num_questions" -gt "${#question_files[@]}" ]; then
        num_questions=${#question_files[@]}
        echo -e "${C_YELLOW}全ての問題（${num_questions}問）を出題します。${C_RESET}"
    fi
    
    # 問題をランダムに選択
    selected_files=()
    
    if [ "$num_questions" -eq "${#question_files[@]}" ]; then
        selected_files=("${question_files[@]}")
    else
        # Fisher-Yates シャッフルアルゴリズム
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
    fi
    
    # 問題を表示
    for question_file in "${selected_files[@]}"; do
        if ! display_and_answer "$question_file"; then
            break
        fi
    done
    
    # 結果表示
    echo -e "\n${C_YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
    echo -e "${C_BLUE}演習結果${C_RESET}"
    echo -e "${C_YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}\n"
    echo -e "正解数: ${C_GREEN}${SCORE}${C_RESET} / ${TOTAL}"
    echo -e "正答率: ${C_GREEN}$(( (SCORE * 100) / TOTAL ))%${C_RESET}\n"
    
    # スコアに基づくフィードバック
    if [ $SCORE -eq $TOTAL ]; then
        echo -e "${C_GREEN}素晴らしい！満点です！${C_RESET}"
    elif [ $SCORE -ge $(( TOTAL * 8 / 10 )) ]; then
        echo -e "${C_GREEN}よくできました！${C_RESET}"
    elif [ $SCORE -ge $(( TOTAL * 6 / 10 )) ]; then
        echo -e "${C_YELLOW}まずまずの成績です。もう少し頑張りましょう！${C_RESET}"
    else
        echo -e "${C_RED}もっと練習が必要です。頑張りましょう！${C_RESET}"
    fi
}

# スクリプト実行
main
