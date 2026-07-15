#!/bin/bash
set -euo pipefail

#
# SQLクイズゲーム
# 作成日: 2026-07-14
# バージョン: 1.0
#
# SQLの知識を問うインタラクティブなクイズゲーム
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare -i QUESTION_COUNT=10
declare DIFFICULTY="normal"

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [オプション]

SQL知識クイズゲームを起動します。

オプション:
  -h, --help        このヘルプを表示
  -v, --version     バージョン情報を表示
  -n, --count N     出題数（デフォルト: 10）
  -d, --diff LEVEL  難易度 easy/normal/hard（デフォルト: normal）

例:
  $PROG_NAME
  $PROG_NAME -n 5 -d easy
  $PROG_NAME -d hard
EOF
}

declare -a Q_TEXT=()
declare -a Q_ANS=()
declare -a Q_CHOICES=()
declare -a Q_EXPLAIN=()
declare -a Q_LEVEL=()

load_questions() {
    local idx=0

    Q_TEXT[$idx]="SELECT文でテーブルの全カラムを取得するには？"
    Q_ANS[$idx]="SELECT * FROM table_name;"
    Q_CHOICES[$idx]="SELECT * FROM table_name;|SELECT ALL FROM table_name;|GET * FROM table_name;|FETCH * FROM table_name;"
    Q_EXPLAIN[$idx]="SELECT * は全カラムを取得します。* はワイルドカードです。"
    Q_LEVEL[$idx]="easy"
    (( idx++ ))

    Q_TEXT[$idx]="WHERE句で「ageが20以上かつ30以下」を表すには？"
    Q_ANS[$idx]="WHERE age BETWEEN 20 AND 30"
    Q_CHOICES[$idx]="WHERE age BETWEEN 20 AND 30|WHERE age >= 20 OR age <= 30|WHERE age IN (20, 30)|WHERE age FROM 20 TO 30"
    Q_EXPLAIN[$idx]="BETWEEN A AND B は A以上B以下を意味します。WHERE age >= 20 AND age <= 30 と同等です。"
    Q_LEVEL[$idx]="easy"
    (( idx++ ))

    Q_TEXT[$idx]="テーブルの行数を取得するSQL関数は？"
    Q_ANS[$idx]="COUNT(*)"
    Q_CHOICES[$idx]="COUNT(*)|NUM_ROWS()|ROW_COUNT()|TOTAL(*)"
    Q_EXPLAIN[$idx]="COUNT(*) は NULLを含む全行数を返します。COUNT(column) はNULLを除いた件数を返します。"
    Q_LEVEL[$idx]="easy"
    (( idx++ ))

    Q_TEXT[$idx]="GROUP BYで集計した結果を絞り込むには？"
    Q_ANS[$idx]="HAVING"
    Q_CHOICES[$idx]="HAVING|WHERE|FILTER|RESTRICT"
    Q_EXPLAIN[$idx]="WHERE は集計前、HAVING は集計後の絞り込みです。例: GROUP BY dept HAVING COUNT(*) > 5"
    Q_LEVEL[$idx]="normal"
    (( idx++ ))

    Q_TEXT[$idx]="2つのテーブルを結合して両方に存在する行のみ返すJOINは？"
    Q_ANS[$idx]="INNER JOIN"
    Q_CHOICES[$idx]="INNER JOIN|LEFT JOIN|FULL JOIN|CROSS JOIN"
    Q_EXPLAIN[$idx]="INNER JOIN は両テーブルにマッチする行のみ返します。LEFT JOIN は左テーブル全行を返します。"
    Q_LEVEL[$idx]="normal"
    (( idx++ ))

    Q_TEXT[$idx]="NULL値かどうかを判定する正しい記述は？"
    Q_ANS[$idx]="IS NULL"
    Q_CHOICES[$idx]="IS NULL|= NULL|== NULL|EQUALS NULL"
    Q_EXPLAIN[$idx]="NULLは特別な値で = では比較できません。IS NULL または IS NOT NULL を使います。"
    Q_LEVEL[$idx]="normal"
    (( idx++ ))

    Q_TEXT[$idx]="サブクエリの結果が1件以上存在するかチェックする演算子は？"
    Q_ANS[$idx]="EXISTS"
    Q_CHOICES[$idx]="EXISTS|IN|ANY|SOME"
    Q_EXPLAIN[$idx]="EXISTS はサブクエリが1行でも返せばTRUE。相関サブクエリで高速な存在チェックに使います。"
    Q_LEVEL[$idx]="normal"
    (( idx++ ))

    Q_TEXT[$idx]="ウィンドウ関数でパーティション内の順位を返す関数は？"
    Q_ANS[$idx]="RANK()"
    Q_CHOICES[$idx]="RANK()|POSITION()|ORDER()|SEQUENCE()"
    Q_EXPLAIN[$idx]="RANK() は同順位の場合に番号をスキップします。ROW_NUMBER() は常に連番、DENSE_RANK() はスキップしません。"
    Q_LEVEL[$idx]="hard"
    (( idx++ ))

    Q_TEXT[$idx]="CTEを定義するキーワードは？"
    Q_ANS[$idx]="WITH"
    Q_CHOICES[$idx]="WITH|DEFINE|DECLARE|CREATE TEMP"
    Q_EXPLAIN[$idx]="WITH句はCTE（Common Table Expression）を定義します。例: WITH cte AS (SELECT ...) SELECT * FROM cte"
    Q_LEVEL[$idx]="hard"
    (( idx++ ))

    Q_TEXT[$idx]="トランザクションをロールバックするSQL文は？"
    Q_ANS[$idx]="ROLLBACK"
    Q_CHOICES[$idx]="ROLLBACK|UNDO|REVERT|CANCEL"
    Q_EXPLAIN[$idx]="ROLLBACK でトランザクションを取り消し、COMMIT で確定します。"
    Q_LEVEL[$idx]="easy"
    (( idx++ ))

    Q_TEXT[$idx]="文字列の長さを返す関数（MySQL）は？"
    Q_ANS[$idx]="LENGTH()"
    Q_CHOICES[$idx]="LENGTH()|SIZE()|LEN()|STRLEN()"
    Q_EXPLAIN[$idx]="MySQL/PostgreSQLではLENGTH()、SQL ServerではLEN()を使います。日本語はCHAR_LENGTH()推奨。"
    Q_LEVEL[$idx]="normal"
    (( idx++ ))

    Q_TEXT[$idx]="重複を除いた値一覧を取得するには？"
    Q_ANS[$idx]="SELECT DISTINCT"
    Q_CHOICES[$idx]="SELECT DISTINCT|SELECT UNIQUE|SELECT NODUPE|SELECT SINGLE"
    Q_EXPLAIN[$idx]="DISTINCT は重複行を除外します。GROUP BY でも同様の結果を得られます。"
    Q_LEVEL[$idx]="easy"
    (( idx++ ))

    Q_TEXT[$idx]="テーブルを削除してDDLをロールバック不可にするSQL文は？"
    Q_ANS[$idx]="DROP TABLE"
    Q_CHOICES[$idx]="DROP TABLE|DELETE TABLE|REMOVE TABLE|DESTROY TABLE"
    Q_EXPLAIN[$idx]="DROP TABLE はテーブル構造ごと削除します。DELETE は行のみ削除、TRUNCATE は行を高速削除します。"
    Q_LEVEL[$idx]="normal"
    (( idx++ ))

    Q_TEXT[$idx]="日付を指定フォーマットで文字列に変換する関数（MySQL）は？"
    Q_ANS[$idx]="DATE_FORMAT()"
    Q_CHOICES[$idx]="DATE_FORMAT()|FORMAT_DATE()|TO_DATE()|STR_DATE()"
    Q_EXPLAIN[$idx]="MySQL: DATE_FORMAT(date, '%Y-%m-%d'), PostgreSQL: TO_CHAR(date, 'YYYY-MM-DD')"
    Q_LEVEL[$idx]="hard"
    (( idx++ ))

    Q_TEXT[$idx]="インデックスの主な目的は？"
    Q_ANS[$idx]="検索速度の向上"
    Q_CHOICES[$idx]="検索速度の向上|データ圧縮|テーブル結合の自動化|重複データの防止"
    Q_EXPLAIN[$idx]="インデックスはB-Tree等の構造でWHERE句・JOIN・ORDER BYを高速化します。書き込み速度は低下します。"
    Q_LEVEL[$idx]="normal"
    (( idx++ ))
}

get_questions_by_level() {
    local level="$1"
    local count="$2"
    local result_indices=()
    local all_indices=()

    for i in "${!Q_LEVEL[@]}"; do
        case "$level" in
            easy)   [[ "${Q_LEVEL[$i]}" == "easy" ]] && all_indices+=("$i") ;;
            normal) [[ "${Q_LEVEL[$i]}" != "hard" ]] && all_indices+=("$i") ;;
            hard)   all_indices+=("$i") ;;
        esac
    done

    local n=${#all_indices[@]}
    for (( i=n-1; i>0; i-- )); do
        local j=$(( RANDOM % (i+1) ))
        local tmp="${all_indices[$i]}"
        all_indices[$i]="${all_indices[$j]}"
        all_indices[$j]="$tmp"
    done

    local take=$(( count < n ? count : n ))
    for (( i=0; i<take; i++ )); do
        result_indices+=("${all_indices[$i]}")
    done
    echo "${result_indices[@]}"
}

play_question() {
    local idx="$1"
    local qnum="$2"
    local total="$3"

    IFS='|' read -ra choices <<< "${Q_CHOICES[$idx]}"

    local n=${#choices[@]}
    for (( i=n-1; i>0; i-- )); do
        local j=$(( RANDOM % (i+1) ))
        local tmp="${choices[$i]}"
        choices[$i]="${choices[$j]}"
        choices[$j]="$tmp"
    done

    local correct_pos=0
    for i in "${!choices[@]}"; do
        if [[ "${choices[$i]}" == "${Q_ANS[$idx]}" ]]; then
            correct_pos=$i
            break
        fi
    done

    echo ""
    local level_color
    case "${Q_LEVEL[$idx]}" in
        easy)   level_color="$C_GREEN" ;;
        normal) level_color="$C_YELLOW" ;;
        hard)   level_color="$C_RED" ;;
    esac

    printf "  ${C_BOLD}Q%d/%d${C_RESET} ${level_color}[%s]${C_RESET}\n" "$qnum" "$total" "${Q_LEVEL[$idx]}"
    echo ""
    echo -e "  ${C_BOLD}${Q_TEXT[$idx]}${C_RESET}"
    echo ""

    local labels=("A" "B" "C" "D")
    for i in "${!choices[@]}"; do
        echo -e "  ${C_CYAN}${labels[$i]}.${C_RESET} ${choices[$i]}"
    done
    echo ""

    local answer
    while true; do
        echo -n "  答え [A/B/C/D]: "
        read -r answer
        answer="${answer^^}"
        if [[ "$answer" =~ ^[ABCD]$ ]]; then
            break
        fi
        log_warning "A, B, C, D のいずれかを入力してください"
    done

    local ans_idx
    case "$answer" in
        A) ans_idx=0 ;;
        B) ans_idx=1 ;;
        C) ans_idx=2 ;;
        D) ans_idx=3 ;;
    esac

    if (( ans_idx == correct_pos )); then
        echo -e "\n  ${C_GREEN}${C_BOLD}✓ 正解！${C_RESET}"
        echo -e "  ${C_DIM}${Q_EXPLAIN[$idx]}${C_RESET}"
        echo "1"
    else
        echo -e "\n  ${C_RED}${C_BOLD}✗ 不正解${C_RESET} 正解: ${labels[$correct_pos]}. ${Q_ANS[$idx]}"
        echo -e "  ${C_DIM}${Q_EXPLAIN[$idx]}${C_RESET}"
        echo "0"
    fi
}

show_result() {
    local correct="$1"
    local total="$2"
    local pct=$(( correct * 100 / total ))

    echo ""
    echo -e "  ${C_DIM}$(printf '%.0s─' {1..50})${C_RESET}"
    echo ""

    local rank color
    if (( pct >= 90 )); then
        rank="S"; color="$C_MAGENTA"
    elif (( pct >= 70 )); then
        rank="A"; color="$C_CYAN"
    elif (( pct >= 50 )); then
        rank="B"; color="$C_GREEN"
    elif (( pct >= 30 )); then
        rank="C"; color="$C_YELLOW"
    else
        rank="D"; color="$C_RED"
    fi

    print_center "クイズ終了" 0 "${C_BOLD}${C_CYAN}"
    echo ""
    printf "  ${C_BOLD}正解数:${C_RESET} ${C_GREEN}%d${C_RESET} / %d問  (%d%%)\n" "$correct" "$total" "$pct"
    printf "  ${C_BOLD}ランク:${C_RESET} ${color}${C_BOLD}%s${C_RESET}\n" "$rank"
    echo ""

    case "$rank" in
        S) echo -e "  ${C_MAGENTA}SQLマスター！完璧な知識です。${C_RESET}" ;;
        A) echo -e "  ${C_CYAN}素晴らしい！SQL上級者です。${C_RESET}" ;;
        B) echo -e "  ${C_GREEN}良い成績です。基礎は身についています。${C_RESET}" ;;
        C) echo -e "  ${C_YELLOW}もう少し練習が必要です。${C_RESET}" ;;
        D) echo -e "  ${C_RED}SQLの基礎から学び直しましょう。${C_RESET}" ;;
    esac
    echo ""
}

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -n|--count)
                [[ $# -lt 2 ]] && error_exit "--count には問題数が必要です"
                QUESTION_COUNT="$2"; shift 2 ;;
            -d|--diff)
                [[ $# -lt 2 ]] && error_exit "--diff には難易度が必要です"
                DIFFICULTY="$2"
                [[ "$DIFFICULTY" =~ ^(easy|normal|hard)$ ]] || error_exit "難易度は easy/normal/hard を指定"
                shift 2 ;;
            *) error_exit "不明なオプション: $1" ;;
        esac
    done

    load_questions

    echo ""
    print_center "SQL クイズゲーム" 0 "${C_BOLD}${C_CYAN}"
    print_center "難易度: ${DIFFICULTY}  出題数: ${QUESTION_COUNT}問" 0 "$C_DIM"
    echo ""

    read -ra indices <<< "$(get_questions_by_level "$DIFFICULTY" "$QUESTION_COUNT")"
    local total=${#indices[@]}
    declare -i correct=0

    for (( i=0; i<total; i++ )); do
        local result
        result=$(play_question "${indices[$i]}" "$(( i+1 ))" "$total")
        if [[ "${result##*$'\n'}" == "1" ]]; then
            (( correct++ ))
        fi
    done

    show_result "$correct" "$total"
}

main "$@"
