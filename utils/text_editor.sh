#!/bin/bash
set -euo pipefail

#
# TUIテキストエディタ
# 作成日: 2026-08-25
# バージョン: 1.0
#
# ターミナル上で動作するシンプルなテキストエディタです
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare filename=""
declare -a lines=()
declare -i cursor_row=0
declare -i cursor_col=0
declare -i scroll_top=0
declare -i modified=0
declare status_msg=""
declare mode="normal"

show_usage() {
    cat <<EOF
使用方法: $PROG_NAME [ファイル]

TUIベースのシンプルなテキストエディタです。

引数:
  [ファイル]    編集するファイル (省略時は新規作成)

キーバインド:
  矢印キー       カーソル移動
  Ctrl+S         保存
  Ctrl+Q         終了 (変更がある場合は確認)
  Ctrl+G         指定行へジャンプ
  Ctrl+F         文字列検索
  Ctrl+K         行削除
  Ctrl+D         行複製
  Ctrl+A         行頭へ
  Ctrl+E         行末へ
  Page Up/Down   ページ移動
  Home/End       行頭/行末

例:
  $PROG_NAME
  $PROG_NAME /etc/hosts
  $PROG_NAME myfile.txt
EOF
}

load_file() {
    local f="$1"
    lines=()
    if [[ -f "$f" ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
            lines+=("$line")
        done < "$f"
        [[ ${#lines[@]} -eq 0 ]] && lines=("")
    else
        lines=("")
    fi
}

save_file() {
    local f="${1:-$filename}"
    if [[ -z "$f" ]]; then
        status_msg="保存先ファイル名を指定してください (Ctrl+S でファイル名入力)"
        return 1
    fi
    printf '%s\n' "${lines[@]}" > "$f" 2>/dev/null || {
        status_msg="保存失敗: $f"
        return 1
    }
    modified=0
    filename="$f"
    status_msg="保存完了: $f"
}

get_visible_rows() {
    echo $(( TERM_ROWS - 3 ))
}

render() {
    update_terminal_size
    local vis_rows
    vis_rows=$(get_visible_rows)
    local total_lines=${#lines[@]}

    if (( cursor_row < scroll_top )); then
        scroll_top=$cursor_row
    elif (( cursor_row >= scroll_top + vis_rows )); then
        scroll_top=$(( cursor_row - vis_rows + 1 ))
    fi

    clear_screen

    # ヘッダー行
    move_cursor 1 1
    local title="${filename:-[新規ファイル]}"
    [[ $modified -eq 1 ]] && title+=" *"
    printf "${C_BG_GRAY}${C_BOLD} %-*s ${C_RESET}" $(( TERM_COLS - 2 )) " $title"

    # コンテンツ行
    local display_row=2
    local line_num=$(( scroll_top + 1 ))
    local end_line=$(( scroll_top + vis_rows ))
    (( end_line > total_lines )) && end_line=$total_lines

    for (( i = scroll_top; i < end_line; i++ )); do
        move_cursor $display_row 1
        local is_current=0
        (( i == cursor_row )) && is_current=1

        if (( is_current )); then
            printf "${C_BG_GRAY}${C_BOLD}%4d${C_RESET}${C_BG_GRAY} ${C_RESET}" $(( i + 1 ))
        else
            printf "${C_DIM}%4d${C_RESET} " $(( i + 1 ))
        fi

        local line="${lines[$i]:-}"
        local max_len=$(( TERM_COLS - 6 ))
        if [[ ${#line} -gt $max_len ]]; then
            line="${line:0:$max_len}"
        fi

        if (( is_current )); then
            printf "${C_BOLD}%s${C_RESET}" "$line"
        else
            printf "%s" "$line"
        fi

        (( display_row++ ))
    done

    # 空行のチルダ表示
    while (( display_row <= vis_rows + 1 )); do
        move_cursor $display_row 1
        printf "${C_DIM}~${C_RESET}"
        (( display_row++ ))
    done

    # ステータスバー
    move_cursor $(( TERM_ROWS - 1 )) 1
    local pos_info="行 $(( cursor_row + 1 ))/${total_lines}  列 $(( cursor_col + 1 ))"
    local mode_str=""
    [[ "$mode" == "search" ]] && mode_str=" [検索]"
    printf "${C_BG_GRAY}${C_BOLD} %-*s %s ${C_RESET}" \
        $(( TERM_COLS - ${#pos_info} - 4 )) " ${status_msg}${mode_str}" "$pos_info"
    status_msg=""

    # カーソル位置設定
    local cur_line="${lines[$cursor_row]:-}"
    local display_col=$(( cursor_col + 6 ))
    (( display_col > TERM_COLS )) && display_col=$TERM_COLS
    move_cursor $(( cursor_row - scroll_top + 2 )) $display_col
}

insert_char() {
    local ch="$1"
    local line="${lines[$cursor_row]:-}"
    local before="${line:0:$cursor_col}"
    local after="${line:$cursor_col}"
    lines[$cursor_row]="${before}${ch}${after}"
    (( cursor_col++ ))
    modified=1
}

delete_char_before() {
    if (( cursor_col > 0 )); then
        local line="${lines[$cursor_row]:-}"
        lines[$cursor_row]="${line:0:$(( cursor_col - 1 ))}${line:$cursor_col}"
        (( cursor_col-- ))
        modified=1
    elif (( cursor_row > 0 )); then
        local prev_line="${lines[$((cursor_row - 1))]:-}"
        local curr_line="${lines[$cursor_row]:-}"
        cursor_col=${#prev_line}
        lines[$((cursor_row - 1))]="${prev_line}${curr_line}"
        local new_lines=()
        for (( i = 0; i < ${#lines[@]}; i++ )); do
            (( i == cursor_row )) && continue
            new_lines+=("${lines[$i]}")
        done
        lines=("${new_lines[@]}")
        (( cursor_row-- ))
        modified=1
    fi
}

insert_newline() {
    local line="${lines[$cursor_row]:-}"
    local before="${line:0:$cursor_col}"
    local after="${line:$cursor_col}"
    lines[$cursor_row]="$before"
    local new_lines=()
    for (( i = 0; i <= cursor_row; i++ )); do
        new_lines+=("${lines[$i]}")
    done
    new_lines+=("$after")
    for (( i = cursor_row + 1; i < ${#lines[@]}; i++ )); do
        new_lines+=("${lines[$i]}")
    done
    lines=("${new_lines[@]}")
    (( cursor_row++ ))
    cursor_col=0
    modified=1
}

delete_line() {
    if [[ ${#lines[@]} -le 1 ]]; then
        lines=("")
        cursor_col=0
    else
        local new_lines=()
        for (( i = 0; i < ${#lines[@]}; i++ )); do
            (( i == cursor_row )) && continue
            new_lines+=("${lines[$i]}")
        done
        lines=("${new_lines[@]}")
        (( cursor_row >= ${#lines[@]} )) && cursor_row=$(( ${#lines[@]} - 1 ))
        cursor_col=0
    fi
    modified=1
    status_msg="行を削除しました"
}

duplicate_line() {
    local line="${lines[$cursor_row]:-}"
    local new_lines=()
    for (( i = 0; i <= cursor_row; i++ )); do
        new_lines+=("${lines[$i]}")
    done
    new_lines+=("$line")
    for (( i = cursor_row + 1; i < ${#lines[@]}; i++ )); do
        new_lines+=("${lines[$i]}")
    done
    lines=("${new_lines[@]}")
    (( cursor_row++ ))
    modified=1
    status_msg="行を複製しました"
}

search_text() {
    local term="$1"
    local found=0
    for (( i = cursor_row; i < ${#lines[@]}; i++ )); do
        local start_col=0
        (( i == cursor_row )) && start_col=$(( cursor_col + 1 ))
        if [[ "${lines[$i]:$start_col}" == *"$term"* ]]; then
            cursor_row=$i
            local pos="${lines[$i]:$start_col}"
            local before="${pos%%$term*}"
            cursor_col=$(( start_col + ${#before} ))
            found=1
            break
        fi
    done
    if (( ! found )); then
        for (( i = 0; i < cursor_row; i++ )); do
            if [[ "${lines[$i]}" == *"$term"* ]]; then
                cursor_row=$i
                local before="${lines[$i]%%$term*}"
                cursor_col=${#before}
                found=1
                break
            fi
        done
    fi
    if (( found )); then
        status_msg="\"${term}\" 見つかりました"
    else
        status_msg="\"${term}\" は見つかりませんでした"
    fi
}

prompt_input() {
    local prompt_text="$1"
    local input=""
    move_cursor $(( TERM_ROWS - 1 )) 1
    printf "${C_BG_GRAY}${C_BOLD} %s ${C_RESET}" "$prompt_text"
    show_cursor
    local old_stty
    old_stty=$(stty -g)
    stty echo icanon
    read -r input || true
    stty "$old_stty"
    hide_cursor
    echo "$input"
}

run_editor() {
    local cleanup_done=false
    cleanup() {
        $cleanup_done && return
        cleanup_done=true
        show_cursor
        stty "$ORIGINAL_STTY" 2>/dev/null || true
        printf '\033[?1049l'
    }
    trap cleanup EXIT INT TERM

    local ORIGINAL_STTY
    ORIGINAL_STTY=$(stty -g)

    printf '\033[?1049h'
    hide_cursor
    stty -echo -icanon min 1 time 0

    while true; do
        render

        local key
        IFS= read -r -s -n1 key 2>/dev/null || key=""

        if [[ "$key" == $'\x1b' ]]; then
            local seq=""
            IFS= read -r -s -n1 -t 0.1 seq || true
            if [[ "$seq" == "[" ]]; then
                local arrow=""
                IFS= read -r -s -n1 -t 0.1 arrow || true
                case "$arrow" in
                    A) (( cursor_row > 0 )) && (( cursor_row-- )) ;;
                    B) (( cursor_row < ${#lines[@]} - 1 )) && (( cursor_row++ )) ;;
                    C) local line_len="${#lines[$cursor_row]:-0}"
                       (( cursor_col < line_len )) && (( cursor_col++ )) ;;
                    D) (( cursor_col > 0 )) && (( cursor_col-- )) ;;
                    5) IFS= read -r -s -n1 -t 0.1 || true  # Page Up
                       local vis; vis=$(get_visible_rows)
                       cursor_row=$(( cursor_row - vis < 0 ? 0 : cursor_row - vis )) ;;
                    6) IFS= read -r -s -n1 -t 0.1 || true  # Page Down
                       local vis; vis=$(get_visible_rows)
                       local max_row=$(( ${#lines[@]} - 1 ))
                       cursor_row=$(( cursor_row + vis > max_row ? max_row : cursor_row + vis )) ;;
                    H) cursor_col=0 ;;
                    F) cursor_col=${#lines[$cursor_row]:-0} ;;
                esac
                local line_len="${#lines[$cursor_row]:-0}"
                (( cursor_col > line_len )) && cursor_col=$line_len
            fi
            continue
        fi

        case "$key" in
            $'\x11')  # Ctrl+Q
                if (( modified )); then
                    stty "$ORIGINAL_STTY"
                    show_cursor
                    local ans
                    ans=$(prompt_input "変更が保存されていません。終了しますか？ (y/N): ")
                    hide_cursor
                    stty -echo -icanon min 1 time 0
                    [[ "$ans" == "y" || "$ans" == "Y" ]] && break
                else
                    break
                fi ;;
            $'\x13')  # Ctrl+S
                if [[ -z "$filename" ]]; then
                    stty "$ORIGINAL_STTY"
                    show_cursor
                    local fname
                    fname=$(prompt_input "ファイル名: ")
                    hide_cursor
                    stty -echo -icanon min 1 time 0
                    [[ -n "$fname" ]] && save_file "$fname"
                else
                    save_file
                fi ;;
            $'\x06')  # Ctrl+F
                stty "$ORIGINAL_STTY"
                show_cursor
                local term
                term=$(prompt_input "検索: ")
                hide_cursor
                stty -echo -icanon min 1 time 0
                [[ -n "$term" ]] && search_text "$term" ;;
            $'\x07')  # Ctrl+G
                stty "$ORIGINAL_STTY"
                show_cursor
                local linenum
                linenum=$(prompt_input "行番号: ")
                hide_cursor
                stty -echo -icanon min 1 time 0
                if [[ "$linenum" =~ ^[0-9]+$ ]]; then
                    cursor_row=$(( linenum - 1 < 0 ? 0 : linenum - 1 ))
                    (( cursor_row >= ${#lines[@]} )) && cursor_row=$(( ${#lines[@]} - 1 ))
                    cursor_col=0
                fi ;;
            $'\x0b')  # Ctrl+K
                delete_line ;;
            $'\x04')  # Ctrl+D
                duplicate_line ;;
            $'\x01')  # Ctrl+A
                cursor_col=0 ;;
            $'\x05')  # Ctrl+E
                cursor_col=${#lines[$cursor_row]:-0} ;;
            $'\x0d'|$'\n')  # Enter
                insert_newline ;;
            $'\x7f'|$'\x08')  # Backspace/Delete
                delete_char_before ;;
            "")  ;;
            *)
                [[ ${#key} -eq 1 ]] && insert_char "$key" ;;
        esac
    done
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)    show_usage; exit 0 ;;
            -v|--version) echo "$PROG_NAME version $VERSION"; exit 0 ;;
            -*) error_exit "不明なオプション: $1" ;;
            *)  filename="$1"; shift ;;
        esac
    done
}

main() {
    parse_arguments "$@"

    if [[ -n "$filename" ]]; then
        load_file "$filename"
    else
        lines=("")
    fi

    run_editor
}

main "$@"
