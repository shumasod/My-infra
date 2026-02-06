#!/bin/bash
set -euo pipefail

#
# シェルスクリプトカラオケ
# 作成日: 2024
# バージョン: 1.1
#
# 概要:
#   ターミナルベースのカラオケアプリケーション
#   歌詞をカラオケ風に色分けして表示します
#
# 使用例:
#   ./karaoke.sh                # インタラクティブメニュー
#   ./karaoke.sh list           # 曲一覧
#   ./karaoke.sh play "きらきら星"
#   ./karaoke.sh demo           # デモ再生
#

# ===== 共通ライブラリ読み込み =====
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

# ===== 設定（定数） =====
readonly PROG_NAME=$(basename "$0")
readonly VERSION="1.1"
readonly SONGS_DIR="${SCRIPT_DIR}/songs"

# カラオケ専用色定義
readonly C_SUNG='\033[1;33m'        # 歌った部分（黄色）
readonly C_CURRENT='\033[1;37;44m'  # 現在の部分（白地に青背景）
readonly C_UPCOMING='\033[1;37m'    # これから歌う部分（白）
readonly C_TITLE_BAR='\033[1;36m'   # タイトル（シアン）

# ===== グローバル変数 =====
declare current_song=""
declare -a lyrics=()
declare -a timings=()
declare -i total_score=0
declare -i max_score=0

# ===== ヘルパー関数 =====

#
# 使用方法を表示
#
show_usage() {
    cat <<EOF
${C_CYAN}シェルスクリプトカラオケ${C_RESET} v${VERSION}

使用方法: $PROG_NAME [オプション] [コマンド]

コマンド:
  play <曲名>     指定した曲を再生
  list            曲一覧を表示
  add             新しい曲を追加
  demo            デモモード

オプション:
  -h, --help      このヘルプを表示
  -v, --version   バージョン情報を表示

例:
  $PROG_NAME                # インタラクティブモード
  $PROG_NAME list           # 曲一覧
  $PROG_NAME play "きらきら星"
  $PROG_NAME demo           # デモ再生
EOF
}

# 共通ライブラリから提供される関数:
# - update_terminal_size, clear_screen, move_cursor
# - hide_cursor, show_cursor, print_center

# ===== カラオケ表示関数 =====

# バナーを表示
show_banner() {
    echo -e "${C_MAGENTA}"
    cat <<'EOF'
  _  __                 _
 | |/ /__ _ _ __ __ _  ___ | | _____
 | ' // _` | '__/ _` |/ _ \| |/ / _ \
 | . \ (_| | | | (_| | (_) |   <  __/
 |_|\_\__,_|_|  \__,_|\___/|_|\_\___|

EOF
    echo -e "${C_RESET}"
    echo -e "${C_BOLD}シェルスクリプトカラオケ${C_RESET} v${VERSION}"
    echo ""
}

# 歌詞ファイルを読み込み
load_song() {
    local song_file="$1"

    if [[ ! -f "$song_file" ]]; then
        echo -e "${C_RED}エラー: 曲ファイルが見つかりません: $song_file${C_RESET}"
        return 1
    fi

    lyrics=()
    timings=()

    local title=""
    local artist=""
    local in_lyrics=false

    while IFS= read -r line || [[ -n "$line" ]]; do
        # コメントをスキップ
        [[ "$line" =~ ^# ]] && continue
        [[ -z "$line" ]] && continue

        if [[ "$line" =~ ^title= ]]; then
            title="${line#title=}"
        elif [[ "$line" =~ ^artist= ]]; then
            artist="${line#artist=}"
        elif [[ "$line" =~ ^--- ]]; then
            in_lyrics=true
        elif $in_lyrics; then
            # フォーマット: 時間(秒)|歌詞
            if [[ "$line" =~ ^([0-9.]+)\|(.*)$ ]]; then
                timings+=("${BASH_REMATCH[1]}")
                lyrics+=("${BASH_REMATCH[2]}")
            fi
        fi
    done < "$song_file"

    current_song="$title - $artist"
}

# 曲選択画面を表示
show_song_list() {
    clear_screen
    update_terminal_size

    echo ""
    echo -e "${C_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
    echo -e "${C_CYAN}  曲一覧${C_RESET}"
    echo -e "${C_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
    echo ""

    local i=1
    local songs=()

    for song_file in "${SONGS_DIR}"/*.txt; do
        if [[ -f "$song_file" ]]; then
            local title=""
            local artist=""

            while IFS= read -r line; do
                [[ "$line" =~ ^title= ]] && title="${line#title=}"
                [[ "$line" =~ ^artist= ]] && artist="${line#artist=}"
                [[ -n "$title" && -n "$artist" ]] && break
            done < "$song_file"

            songs+=("$song_file")
            echo -e "  ${C_YELLOW}${i})${C_RESET} ${C_BOLD}${title}${C_RESET}"
            echo -e "     ${C_DIM}${artist}${C_RESET}"
            echo ""
            ((i++))
        fi
    done

    if [[ ${#songs[@]} -eq 0 ]]; then
        echo -e "  ${C_DIM}曲がありません${C_RESET}"
        echo ""
        echo "  曲を追加するには:"
        echo "    $PROG_NAME add"
        echo ""
    fi

    echo -e "${C_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"

    # 配列を返す
    printf '%s\n' "${songs[@]}"
}

# カラオケ画面のフレームを描画
draw_karaoke_frame() {
    local title="$1"

    clear_screen
    update_terminal_size

    # タイトルバー
    move_cursor 1 1
    echo -ne "${C_BG_MAGENTA}${C_WHITE}"
    printf "%-${TERM_COLS}s" "  ♪ $title"
    echo -ne "${C_RESET}"

    # 下部のコントロールバー
    move_cursor "$TERM_ROWS" 1
    echo -ne "${C_BG_CYAN}${C_WHITE}"
    printf "%-${TERM_COLS}s" "  [Space] 一時停止  [Q] 終了  [←/→] シーク"
    echo -ne "${C_RESET}"
}

# 歌詞を表示（カラオケ風）
display_lyrics() {
    local current_index=$1
    local progress=$2  # 0.0 - 1.0

    local display_start=$((current_index - 2))
    local display_end=$((current_index + 4))

    [[ $display_start -lt 0 ]] && display_start=0
    [[ $display_end -ge ${#lyrics[@]} ]] && display_end=$((${#lyrics[@]} - 1))

    local center_row=$(( TERM_ROWS / 2 ))
    local row=$((center_row - (current_index - display_start)))

    for ((i = display_start; i <= display_end; i++)); do
        if [[ $i -lt 0 || $i -ge ${#lyrics[@]} ]]; then
            ((row++))
            continue
        fi

        local lyric="${lyrics[$i]}"
        local display_lyric=""

        move_cursor "$row" 1
        printf "%-${TERM_COLS}s" ""  # 行をクリア

        if [[ $i -lt $current_index ]]; then
            # 既に歌った行
            print_center "$lyric" "$row" "${C_DIM}"
        elif [[ $i -eq $current_index ]]; then
            # 現在の行（プログレスに応じて色を変える）
            local lyric_len=${#lyric}
            local sung_len=$(echo "$lyric_len * $progress" | bc | cut -d. -f1)
            [[ -z "$sung_len" ]] && sung_len=0

            local sung_part="${lyric:0:$sung_len}"
            local remaining_part="${lyric:$sung_len}"

            local col=$(( (TERM_COLS - lyric_len) / 2 ))
            [[ $col -lt 1 ]] && col=1

            move_cursor "$row" "$col"
            echo -ne "${C_SUNG}${sung_part}${C_RESET}"
            echo -ne "${C_CURRENT}${remaining_part}${C_RESET}"
        else
            # これから歌う行
            local fade=$((i - current_index))
            if [[ $fade -eq 1 ]]; then
                print_center "$lyric" "$row" "${C_WHITE}"
            else
                print_center "$lyric" "$row" "${C_DIM}"
            fi
        fi

        ((row++))
    done
}

# プログレスバーを描画
draw_progress_bar() {
    local current=$1
    local total=$2

    local bar_width=$((TERM_COLS - 20))
    local filled=$(echo "$bar_width * $current / $total" | bc 2>/dev/null || echo 0)
    [[ -z "$filled" ]] && filled=0
    [[ $filled -gt $bar_width ]] && filled=$bar_width

    local empty=$((bar_width - filled))

    local current_min=$((current / 60))
    local current_sec=$((current % 60))
    local total_min=$((total / 60))
    local total_sec=$((total % 60))

    move_cursor $((TERM_ROWS - 1)) 1
    printf "  %02d:%02d [" "$current_min" "$current_sec"

    echo -ne "${C_CYAN}"
    for ((i = 0; i < filled; i++)); do
        echo -n "█"
    done
    echo -ne "${C_RESET}"

    echo -ne "${C_DIM}"
    for ((i = 0; i < empty; i++)); do
        echo -n "░"
    done
    echo -ne "${C_RESET}"

    printf "] %02d:%02d" "$total_min" "$total_sec"
}

# カラオケを再生
play_karaoke() {
    local song_file="$1"

    if ! load_song "$song_file"; then
        return 1
    fi

    if [[ ${#lyrics[@]} -eq 0 ]]; then
        echo -e "${C_RED}エラー: 歌詞が見つかりません${C_RESET}"
        return 1
    fi

    hide_cursor
    trap 'show_cursor; clear_screen; return' INT TERM

    draw_karaoke_frame "$current_song"

    local start_time
    start_time=$(date +%s.%N)
    local current_index=0
    local paused=false
    local pause_time=0

    # 最後のタイミングを取得（曲の長さ）
    local total_time
    total_time=$(echo "${timings[-1]} + 5" | bc)

    # メインループ
    while true; do
        # キー入力を非ブロッキングで読み取り
        if read -rsn1 -t 0.05 key 2>/dev/null; then
            case "$key" in
                q|Q)
                    break
                    ;;
                ' ')
                    if $paused; then
                        paused=false
                        start_time=$(echo "$(date +%s.%N) - $pause_time" | bc)
                    else
                        paused=true
                        pause_time=$(echo "$(date +%s.%N) - $start_time" | bc)
                    fi
                    ;;
            esac
        fi

        if $paused; then
            move_cursor $((TERM_ROWS / 2 - 5)) 1
            print_center "⏸ 一時停止中 - Spaceキーで再開" "" "${C_YELLOW}"
            continue
        fi

        # 現在の時間を計算
        local current_time
        current_time=$(echo "$(date +%s.%N) - $start_time" | bc)

        # 現在のインデックスを更新
        while [[ $current_index -lt ${#timings[@]} ]]; do
            local timing="${timings[$current_index]}"
            if (( $(echo "$current_time >= $timing" | bc -l) )); then
                ((current_index++))
            else
                break
            fi
        done

        # 表示インデックスを調整
        local display_index=$((current_index > 0 ? current_index - 1 : 0))

        # 進捗を計算
        local progress=0
        if [[ $display_index -lt $((${#timings[@]} - 1)) ]]; then
            local line_start="${timings[$display_index]}"
            local line_end="${timings[$((display_index + 1))]}"
            local line_duration
            line_duration=$(echo "$line_end - $line_start" | bc)
            local line_progress
            line_progress=$(echo "$current_time - $line_start" | bc)
            if (( $(echo "$line_duration > 0" | bc -l) )); then
                progress=$(echo "$line_progress / $line_duration" | bc -l)
                (( $(echo "$progress > 1" | bc -l) )) && progress=1
                (( $(echo "$progress < 0" | bc -l) )) && progress=0
            fi
        fi

        # 歌詞を表示
        display_lyrics "$display_index" "$progress"

        # プログレスバーを描画
        local current_int
        current_int=$(echo "$current_time" | cut -d. -f1)
        local total_int
        total_int=$(echo "$total_time" | cut -d. -f1)
        draw_progress_bar "$current_int" "$total_int"

        # 曲が終了したら
        if (( $(echo "$current_time >= $total_time" | bc -l) )); then
            break
        fi
    done

    show_cursor

    # 終了画面
    clear_screen
    echo ""
    echo -e "${C_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
    print_center "♪ お疲れ様でした！ ♪" "" "${C_YELLOW}"
    echo ""
    echo -e "${C_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
    echo ""
    print_center "$current_song" "" "${C_WHITE}"
    echo ""
    echo ""
}

# 新しい曲を追加
add_song() {
    echo -e "${C_CYAN}新しい曲を追加${C_RESET}"
    echo ""

    echo -n "曲名: "
    read -r title
    [[ -z "$title" ]] && { echo "キャンセルしました"; return; }

    echo -n "アーティスト: "
    read -r artist
    [[ -z "$artist" ]] && artist="Unknown"

    # ファイル名を生成
    local filename
    filename=$(echo "$title" | tr ' ' '_' | tr -cd '[:alnum:]_')
    local song_file="${SONGS_DIR}/${filename}.txt"

    # ファイルを作成
    cat > "$song_file" <<EOF
# 曲情報
title=${title}
artist=${artist}

# 歌詞（フォーマット: 開始秒|歌詞）
# 例: 0.0|最初の歌詞
#     2.5|次の歌詞
---
EOF

    echo ""
    echo -e "${C_GREEN}曲ファイルを作成しました: ${song_file}${C_RESET}"
    echo ""
    echo "歌詞を追加するには、ファイルを編集してください:"
    echo "  フォーマット: 開始秒|歌詞"
    echo "  例:"
    echo "    0.0|きらきら光る"
    echo "    3.0|お空の星よ"
    echo ""
}

# インタラクティブメニュー
interactive_menu() {
    while true; do
        clear_screen
        show_banner

        echo -e "${C_YELLOW}何をしますか？${C_RESET}"
        echo ""
        echo "  1) 曲を選んで歌う"
        echo "  2) 曲一覧を表示"
        echo "  3) 新しい曲を追加"
        echo "  4) デモを再生"
        echo "  5) ヘルプ"
        echo "  q) 終了"
        echo ""
        echo -n "選択 [1-5, q]: "

        read -r choice

        case "$choice" in
            1)
                clear_screen
                local songs
                mapfile -t songs < <(show_song_list)

                if [[ ${#songs[@]} -gt 0 ]]; then
                    echo ""
                    echo -n "曲番号を選択: "
                    read -r song_num

                    if [[ "$song_num" =~ ^[0-9]+$ ]] && [[ $song_num -ge 1 ]] && [[ $song_num -le ${#songs[@]} ]]; then
                        play_karaoke "${songs[$((song_num - 1))]}"
                    else
                        echo -e "${C_RED}無効な選択です${C_RESET}"
                        sleep 1
                    fi
                fi

                echo ""
                echo "Enterキーで続行..."
                read -r
                ;;
            2)
                clear_screen
                show_song_list > /dev/null
                show_song_list
                echo ""
                echo "Enterキーで続行..."
                read -r
                ;;
            3)
                clear_screen
                add_song
                echo "Enterキーで続行..."
                read -r
                ;;
            4)
                # デモ曲を再生
                if [[ -f "${SONGS_DIR}/demo_kirakira.txt" ]]; then
                    play_karaoke "${SONGS_DIR}/demo_kirakira.txt"
                else
                    echo -e "${C_RED}デモ曲がありません${C_RESET}"
                    sleep 2
                fi
                ;;
            5)
                clear_screen
                show_usage
                echo ""
                echo "Enterキーで続行..."
                read -r
                ;;
            q|Q)
                echo ""
                echo "またね！ ♪"
                exit 0
                ;;
            *)
                echo -e "${C_RED}無効な選択です${C_RESET}"
                sleep 1
                ;;
        esac
    done
}

# ===== メイン処理 =====

main() {
    # 曲ディレクトリを作成
    mkdir -p "$SONGS_DIR"

    if [[ $# -eq 0 ]]; then
        interactive_menu
        exit 0
    fi

    local command="$1"
    shift

    case "$command" in
        play)
            if [[ $# -eq 0 ]]; then
                echo -e "${C_RED}曲名を指定してください${C_RESET}"
                exit 1
            fi
            local song_name="$1"
            local song_file="${SONGS_DIR}/${song_name}.txt"

            if [[ ! -f "$song_file" ]]; then
                # 部分一致で検索
                song_file=$(find "$SONGS_DIR" -name "*${song_name}*.txt" 2>/dev/null | head -1)
            fi

            if [[ -f "$song_file" ]]; then
                play_karaoke "$song_file"
            else
                echo -e "${C_RED}曲が見つかりません: $song_name${C_RESET}"
                exit 1
            fi
            ;;
        list)
            show_song_list
            ;;
        add)
            add_song
            ;;
        demo)
            if [[ -f "${SONGS_DIR}/demo_kirakira.txt" ]]; then
                play_karaoke "${SONGS_DIR}/demo_kirakira.txt"
            else
                echo -e "${C_RED}デモ曲がありません${C_RESET}"
                exit 1
            fi
            ;;
        help|--help|-h)
            show_usage
            ;;
        version|--version|-v)
            echo "$PROG_NAME version $VERSION"
            ;;
        *)
            echo -e "${C_RED}不明なコマンド: $command${C_RESET}"
            show_usage
            exit 1
            ;;
    esac
}

# スクリプト実行
main "$@"
