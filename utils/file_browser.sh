#!/bin/bash
set -euo pipefail

#
# TUIファイルブラウザー
# 作成日: 2026-07-31
# バージョン: 1.0
#
# ターミナル上でファイルをナビゲートできるTUIファイルブラウザーです
#

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.0"

declare start_dir="${1:-.}"
declare current_dir
current_dir=$(realpath "$start_dir")
declare -a entries=()
declare -i cursor=0
declare -i scroll=0
declare show_hidden=false
declare sort_mode="name"
declare preview_mode=false
declare status_msg=""

cleanup() {
    show_cursor
    printf '\033[?1049l'
    stty echo 2>/dev/null || true
    stty icanon 2>/dev/null || true
}
trap cleanup EXIT INT TERM

load_entries() {
    entries=()
    local opts=()
    $show_hidden && opts+=("-a")

    # 親ディレクトリ
    if [[ "$current_dir" != "/" ]]; then
        entries+=("..")
    fi

    # ディレクトリ
    while IFS= read -r d; do
        entries+=("$d/")
    done < <(ls -1 "${opts[@]}" --group-directories-first "$current_dir" 2>/dev/null | \
             awk 'BEGIN{} {if(system("test -d \"'"$current_dir"'/\" $0")){ } }' || \
             find "$current_dir" -maxdepth 1 -mindepth 1 -type d -name "${show_hidden:+*}" \
             ! \( -name ".*" \) 2>/dev/null | sort | xargs -I{} basename {})

    # より確実な方法で再ロード
    entries=()
    [[ "$current_dir" != "/" ]] && entries+=("..")

    while IFS= read -r item; do
        local full="$current_dir/$item"
        if [[ -d "$full" ]]; then
            entries+=("$item/")
        else
            entries+=("$item")
        fi
    done < <(
        if $show_hidden; then
            ls -1A "$current_dir" 2>/dev/null | sort
        else
            ls -1 "$current_dir" 2>/dev/null | sort
        fi
    )

    # ソート
    case "$sort_mode" in
        size)
            local -a dirs=() files=()
            [[ "${entries[0]:-}" == ".." ]] && { dirs=(".."); entries=("${entries[@]:1}"); } || true
            for e in "${entries[@]}"; do
                [[ "$e" == */ ]] && dirs+=("$e") || files+=("$e")
            done
            local -a sorted_files=()
            for f in "${files[@]}"; do
                local sz
                sz=$(stat -c%s "$current_dir/$f" 2>/dev/null || echo 0)
                sorted_files+=("$sz $f")
            done
            entries=()
            [[ ${#dirs[@]} -gt 0 ]] && entries+=("${dirs[@]}")
            while IFS=' ' read -r _ name; do
                entries+=("$name")
            done < <(printf '%s\n' "${sorted_files[@]}" | sort -rn)
            ;;
    esac

    local total=${#entries[@]}
    [[ $cursor -ge $total ]] && cursor=$(( total > 0 ? total - 1 : 0 ))
}

format_size() {
    local bytes=$1
    if (( bytes >= 1073741824 )); then
        printf "%.1f GB" "$(echo "scale=1; $bytes/1073741824" | bc 2>/dev/null || echo '?')"
    elif (( bytes >= 1048576 )); then
        printf "%.1f MB" "$(echo "scale=1; $bytes/1048576" | bc 2>/dev/null || echo '?')"
    elif (( bytes >= 1024 )); then
        printf "%.1f KB" "$(echo "scale=1; $bytes/1024" | bc 2>/dev/null || echo '?')"
    else
        printf "%d B" "$bytes"
    fi
}

draw_ui() {
    clear_screen
    update_terminal_size

    local content_rows=$(( TERM_ROWS - 6 ))
    local list_width=$(( preview_mode ? TERM_COLS / 2 : TERM_COLS - 4 ))

    # ヘッダー
    move_cursor 1 1
    printf "${C_BG_BLUE}${C_WHITE}${C_BOLD}"
    printf " %-$((TERM_COLS-1))s" " TUIファイルブラウザー v${VERSION}"
    printf "${C_RESET}"

    # パス表示
    move_cursor 2 2
    local path_display="$current_dir"
    [[ ${#path_display} -gt $(( TERM_COLS - 10 )) ]] && \
        path_display="...${path_display: -(( TERM_COLS - 13 ))}"
    printf "${C_BOLD}パス: ${C_CYAN}%s${C_RESET}" "$path_display"

    # 区切り線
    draw_separator 3

    # ファイルリスト
    local total=${#entries[@]}
    [[ $total -eq 0 ]] && {
        move_cursor 5 4
        printf "${C_DIM}(空のディレクトリ)${C_RESET}"
    }

    local visible_rows=$content_rows
    [[ $scroll -gt 0 ]] && (( scroll = scroll > cursor ? cursor : scroll ))
    [[ $cursor -ge $(( scroll + visible_rows )) ]] && scroll=$(( cursor - visible_rows + 1 ))

    for (( i=0; i<visible_rows && i+scroll<total; i++ )); do
        local idx=$(( i + scroll ))
        local entry="${entries[$idx]}"
        local full_path="$current_dir/$entry"
        [[ "$entry" == ".." ]] && full_path="$(dirname "$current_dir")"

        local row=$(( i + 4 ))
        move_cursor $row 2

        local is_dir=false
        [[ "$entry" == */ || "$entry" == ".." ]] && is_dir=true

        local size_str=""
        local perm_str=""
        if [[ "$entry" != ".." ]]; then
            size_str=$(stat -c%s "$full_path" 2>/dev/null | xargs -I{} sh -c 'echo {}' || echo "?")
            [[ -n "$size_str" && "$size_str" != "?" ]] && size_str=$(format_size "$size_str")
            perm_str=$(stat -c "%A" "$full_path" 2>/dev/null || echo "----------")
        fi

        local name_color="$C_RESET"
        $is_dir && name_color="$C_BOLD$C_BLUE"
        [[ -x "$full_path" && ! -d "$full_path" ]] && name_color="$C_GREEN"
        [[ -L "$full_path" ]] && name_color="$C_CYAN"

        local prefix=" "
        [[ $idx -eq $cursor ]] && prefix="${C_BG_GRAY}${C_WHITE}▶${C_RESET}"

        local entry_display="${entry%/}"
        $is_dir && entry_display="${entry_display}/"

        if [[ $idx -eq $cursor ]]; then
            printf "${C_BG_GRAY}${C_WHITE}▶ %-$((list_width-15))s %10s${C_RESET}" \
                "${entry_display:0:$((list_width-15))}" "${size_str:-}"
        else
            printf "  ${name_color}%-$((list_width-15))s${C_RESET} ${C_DIM}%10s${C_RESET}" \
                "${entry_display:0:$((list_width-15))}" "${size_str:-}"
        fi
    done

    # プレビュー
    if $preview_mode && [[ $cursor -lt $total ]]; then
        local selected="${entries[$cursor]}"
        local selected_path="$current_dir/$selected"
        [[ "$selected" == ".." ]] && selected_path="$(dirname "$current_dir")"

        local preview_col=$(( list_width + 4 ))
        local preview_width=$(( TERM_COLS - preview_col - 2 ))

        move_cursor 4 $preview_col
        printf "${C_BOLD}【プレビュー】${C_RESET}"

        if [[ -f "$selected_path" ]]; then
            local row=5
            while IFS= read -r line && [[ $row -lt $(( TERM_ROWS - 3 )) ]]; do
                move_cursor $row $preview_col
                printf "%s" "${line:0:$preview_width}"
                (( row++ ))
            done < <(head -$(( TERM_ROWS - 5 )) "$selected_path" 2>/dev/null)
        elif [[ -d "$selected_path" ]]; then
            local row=5
            while IFS= read -r item && [[ $row -lt $(( TERM_ROWS - 3 )) ]]; do
                move_cursor $row $preview_col
                [[ -d "$selected_path/$item" ]] && \
                    printf "${C_BLUE}%s/${C_RESET}" "${item:0:$preview_width}" || \
                    printf "%s" "${item:0:$preview_width}"
                (( row++ ))
            done < <(ls -1 "$selected_path" 2>/dev/null | head $(( TERM_ROWS - 5 )))
        fi
    fi

    # フッター
    draw_separator $(( TERM_ROWS - 2 ))
    move_cursor $(( TERM_ROWS - 1 )) 2
    printf "${C_DIM}↑↓:移動 Enter:開く Backspace:戻る h:隠しファイル p:プレビュー q:終了 | %d/%d${C_RESET}" \
        "$(( cursor + 1 ))" "$total"

    if [[ -n "$status_msg" ]]; then
        move_cursor $(( TERM_ROWS )) 2
        printf "${C_YELLOW}%s${C_RESET}" "$status_msg"
    fi
}

navigate_into() {
    local entry="${entries[$cursor]:-}"
    [[ -z "$entry" ]] && return

    if [[ "$entry" == ".." ]]; then
        current_dir=$(dirname "$current_dir")
        cursor=0; scroll=0
        load_entries
    elif [[ "$entry" == */ ]]; then
        local dir="${entry%/}"
        local new_dir="$current_dir/$dir"
        if [[ -d "$new_dir" && -r "$new_dir" ]]; then
            current_dir="$new_dir"
            cursor=0; scroll=0
            load_entries
        else
            status_msg="アクセス権限がありません: $dir"
        fi
    else
        local file="$current_dir/$entry"
        if [[ -r "$file" ]]; then
            show_cursor
            printf '\033[?1049l'
            if command -v less &>/dev/null; then
                less "$file"
            else
                cat "$file" | head -100
                read -rsn1
            fi
            printf '\033[?1049h'
            hide_cursor
        else
            status_msg="読み取りできません: $entry"
        fi
    fi
}

main() {
    printf '\033[?1049h'
    hide_cursor
    stty -echo 2>/dev/null || true
    stty -icanon 2>/dev/null || true

    load_entries
    draw_ui

    while true; do
        status_msg=""
        local key
        key=$(dd bs=6 count=1 2>/dev/null | cat)

        case "$key" in
            $'\x1b[A'|k|K)  # 上
                (( cursor > 0 )) && (( cursor-- ))
                ;;
            $'\x1b[B'|j|J)  # 下
                (( cursor < ${#entries[@]} - 1 )) && (( cursor++ ))
                ;;
            $'\x1b[5~')  # PageUp
                cursor=$(( cursor > 10 ? cursor - 10 : 0 ))
                ;;
            $'\x1b[6~')  # PageDown
                local max=$(( ${#entries[@]} - 1 ))
                cursor=$(( cursor + 10 < max ? cursor + 10 : max ))
                ;;
            $'\x1b[H'|g)  # Home
                cursor=0
                ;;
            $'\x1b[F'|G)  # End
                cursor=$(( ${#entries[@]} - 1 ))
                ;;
            $'\r'|$'\n'|l|L)  # Enter
                navigate_into
                ;;
            $'\x7f'|h|H)  # Backspace/h
                if [[ "$key" == $'\x7f' ]]; then
                    current_dir=$(dirname "$current_dir")
                    cursor=0; scroll=0
                    load_entries
                else
                    show_hidden=!$show_hidden
                    load_entries
                fi
                ;;
            p|P)
                preview_mode=!$preview_mode
                ;;
            r|R)
                load_entries
                ;;
            q|Q|$'\x1b')
                break
                ;;
        esac

        draw_ui
    done
}

main
