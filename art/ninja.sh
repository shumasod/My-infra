#!/bin/bash
#=========================================================

# うずまきナルト変化スクリプト（改良版）

# 説明: このスクリプトはうずまきナルトのさまざまな形態をASCIIアートで表示します

# バージョン: 2.0

# 作成者: Claude

#=========================================================

# エラーが発生したら即終了

set -euo pipefail

#=========================================================

# 定数定義

#=========================================================
readonly SCRIPT_NAME=”$(basename “$0”)”
readonly VERSION=“2.0”
readonly MIN_DELAY=1
readonly MAX_DELAY=10

#=========================================================

# 色定義

#=========================================================
readonly COLOR_RESET=’\033[0m’
readonly COLOR_RED=’\033[31m’
readonly COLOR_GREEN=’\033[32m’
readonly COLOR_YELLOW=’\033[33m’
readonly COLOR_BLUE=’\033[34m’
readonly COLOR_MAGENTA=’\033[35m’
readonly COLOR_CYAN=’\033[36m’
readonly COLOR_WHITE=’\033[37m’
readonly COLOR_BOLD=’\033[1m’

#=========================================================

# ログ関数

#=========================================================
log_info() {
echo -e “${COLOR_CYAN}[INFO]${COLOR_RESET} $*” >&2
}

log_error() {
echo -e “${COLOR_RED}[ERROR]${COLOR_RESET} $*” >&2
}

log_success() {
echo -e “${COLOR_GREEN}[SUCCESS]${COLOR_RESET} $*” >&2
}

#=========================================================

# ヘルプ表示関数

#=========================================================
show_help() {
cat << EOF
${COLOR_BOLD}うずまきナルト変化スクリプト v${VERSION}${COLOR_RESET}

${COLOR_YELLOW}使用方法:${COLOR_RESET}
$SCRIPT_NAME [オプション]

${COLOR_YELLOW}オプション:${COLOR_RESET}
-n, –normal       通常モードのナルトを表示
-c, –chakra       チャクラモードのナルトを表示
-k, –kyuubi       九尾チャクラモードのナルトを表示
-a, –all          全てのモードを順番に表示（デフォルト）
-r, –repeat N     指定した回数だけ繰り返し表示（デフォルト: 1）
-d, –delay N      表示間隔を指定（秒数、${MIN_DELAY}-${MAX_DELAY}、デフォルト: 2）
-s, –silent       メッセージを表示しない（静かモード）
-V, –version      バージョン情報を表示
-h, –help         このヘルプを表示

${COLOR_YELLOW}例:${COLOR_RESET}
$SCRIPT_NAME                    # 全モードを1回表示
$SCRIPT_NAME -n                 # 通常モードのみ表示
$SCRIPT_NAME -a -r 3 -d 1       # 全モードを3回繰り返し、1秒間隔
$SCRIPT_NAME -k -s              # 九尾モードを静かに表示

EOF
}

#=========================================================

# バージョン表示

#=========================================================
show_version() {
echo “${SCRIPT_NAME} version ${VERSION}”
}

#=========================================================

# 端末サイズチェック

#=========================================================
check_terminal_size() {
local min_cols=80
local min_rows=25
local cols rows

```
if command -v tput >/dev/null 2>&1; then
    cols=$(tput cols 2>/dev/null || echo 80)
    rows=$(tput lines 2>/dev/null || echo 25)
    
    if [[ $cols -lt $min_cols ]] || [[ $rows -lt $min_rows ]]; then
        log_error "端末サイズが小さすぎます（最小: ${min_cols}x${min_rows}、現在: ${cols}x${rows}）"
        log_error "端末を大きくするか、フォントサイズを小さくしてください"
        return 1
    fi
fi
return 0
```

}

#=========================================================

# 画面クリア関数

#=========================================================
clear_screen() {
if [[ “${SILENT:-false}” != “true” ]]; then
clear
fi
}

#=========================================================

# 待機関数

#=========================================================
wait_with_animation() {
local delay=$1
local message=${2:-””}

```
if [[ "${SILENT:-false}" == "true" ]]; then
    sleep "$delay"
    return
fi

if [[ -n "$message" ]]; then
    echo -e "${COLOR_MAGENTA}$message${COLOR_RESET}"
fi

# アニメーション付き待機
local spinner='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
local i=0
while [[ $i -lt $delay ]]; do
    for ((j=0; j<10; j++)); do
        printf "\r${COLOR_CYAN}待機中... ${spinner:j:1}${COLOR_RESET}"
        sleep 0.1
        ((i++))
        if [[ $i -ge $delay ]]; then
            break
        fi
    done
done
printf "\r                    \r"
```

}

#=========================================================

# ナルト描画関数

#=========================================================

# ナルト（通常モード）を描画する関数

draw_naruto() {
[[ “${SILENT:-false}” != “true” ]] && echo -e “${COLOR_YELLOW}${COLOR_BOLD}通常モードのナルトを表示します…${COLOR_RESET}”
cat << “EOF”
▄▄▄▄▄▄▄▄▄▄▄
▄██████████████▄
▄███████████████████▄
████▀▀██████████▀▀████
██▀▄▄▄▄▀█████████▀▄▄▄▀██
██ ░░▒▒░░░█████░░░▒▒░░ ██
██  ▒██▒ ▓█████████▓ ▒██▒  ██
██  ░◕█◕░ ███████ ░◕█◕░  ██
██  ░░▒░░▄█████████▄░░▒░░  ██
██▄▄▓▓▒▄██████████████▄▒▓▓▄██
███████████▀▀▀▀▀███████████
████▒▒█▀ ▄▄███▄▄ ▀█▒▒████
▀██▒▒█  ▀▀███▀▀  █▒▒██▀
▀███▄▄ ░▒███▒░ ▄▄███▀
▀████▄▄███▄▄████▀
▀▀████████▀▀
▀▀▀▀▀

```
          🍜 ナルト・うずまき 🍜
```

EOF
}

# うずまきナルトのチャクラモードバージョンを描画する関数

draw_naruto_chakra_mode() {
[[ “${SILENT:-false}” != “true” ]] && echo -e “${COLOR_BLUE}${COLOR_BOLD}チャクラモードのナルトを表示します…${COLOR_RESET}”
cat << “EOF”
▄▄▄▄▄▄▄▄▄▄▄
▄██████████████▄
▄███████████████████▄
████※※██████████※※████
██▀▄▄▄▄▀█████████▀▄▄▄▀██
██ ░░⊹⊹░░░█████░░░⊹⊹░░ ██
██  ▒██▒ ▓█████████▓ ▒██▒  ██
██  ░◕█◕░ ███████ ░◕█◕░  ██
██  ░░∴░░▄█████████▄░░∴░░  ██
██▄▄⊹⊹▒▄██████████████▄▒⊹⊹▄██
███████████▀▀▀▀▀███████████
████▒▒█▀ ∴∴███∴∴ ▀█▒▒████
▀██▒▒█  ▀▀███▀▀  █▒▒██▀
▀███▄▄ ░▒███▒░ ▄▄███▀
▀████▄▄███▄▄████▀
▀▀████████▀▀
▀▀▀▀▀

```
       ⚡ チャクラモード発動！ ⚡
```

EOF
}

# 九尾チャクラモードバージョンを描画する関数

draw_naruto_kyuubi_mode() {
[[ “${SILENT:-false}” != “true” ]] && echo -e “${COLOR_RED}${COLOR_BOLD}九尾チャクラモードのナルトを表示します…${COLOR_RESET}”
cat << “EOF”
▄▄▄▄▄▄▄▄▄▄▄
▄██████████████▄
▄███████████████████▄
████❂❂██████████❂❂████
██▀▄▄▄▄▀█████████▀▄▄▄▀██
██ ░░✧✧░░░█████░░░✧✧░░ ██
██  ▒██▒ ▓█████████▓ ▒██▒  ██
██  ░❂█❂░ ███████ ░❂█❂░  ██
██  ░░✺░░▄█████████▄░░✺░░  ██
██▄▄✧✧▒▄██████████████▄▒✧✧▄██
███████████▀▀▀▀▀███████████
████▒▒█▀ ✺✺███✺✺ ▀█▒▒████
▀██▒▒█  ▀▀███▀▀  █▒▒██▀
▀███▄▄ ░▒███▒░ ▄▄███▀
▀████▄▄███▄▄████▀
▀▀████████▀▀
▀▀▀▀▀

```
      🔥 九尾チャクラモード！ 🔥
```

EOF
}

#=========================================================

# 入力値検証関数

#=========================================================
validate_delay() {
local delay=$1
if ! [[ “$delay” =~ ^[0-9]+$ ]]; then
log_error “遅延時間には正の整数を指定してください: ‘$delay’”
return 1
fi

```
if [[ $delay -lt $MIN_DELAY ]] || [[ $delay -gt $MAX_DELAY ]]; then
    log_error "遅延時間は${MIN_DELAY}から${MAX_DELAY}の間で指定してください: '$delay'"
    return 1
fi

return 0
```

}

validate_repeat() {
local repeat=$1
if ! [[ “$repeat” =~ ^[0-9]+$ ]]; then
log_error “繰り返し回数には正の整数を指定してください: ‘$repeat’”
return 1
fi

```
if [[ $repeat -lt 1 ]] || [[ $repeat -gt 100 ]]; then
    log_error "繰り返し回数は1から100の間で指定してください: '$repeat'"
    return 1
fi

return 0
```

}

#=========================================================

# モード実行関数

#=========================================================
execute_mode() {
local mode=$1
local repeat=${2:-1}
local delay=${3:-2}

```
for ((i=1; i<=repeat; i++)); do
    if [[ $repeat -gt 1 ]] && [[ "${SILENT:-false}" != "true" ]]; then
        echo -e "${COLOR_MAGENTA}${COLOR_BOLD}=== 第${i}回目の変化 ===${COLOR_RESET}"
        echo ""
    fi
    
    case "$mode" in
        "normal")
            clear_screen
            draw_naruto
            ;;
        "chakra")
            clear_screen
            draw_naruto_chakra_mode
            ;;
        "kyuubi")
            clear_screen
            draw_naruto_kyuubi_mode
            ;;
        "all")
            clear_screen
            draw_naruto
            if [[ $i -lt $repeat ]] || [[ "$mode" == "all" ]]; then
                wait_with_animation "$delay" "次の変化まで待機中..."
            fi
            
            clear_screen
            draw_naruto_chakra_mode
            if [[ $i -lt $repeat ]] || [[ "$mode" == "all" ]]; then
                wait_with_animation "$delay" "次の変化まで待機中..."
            fi
            
            clear_screen
            draw_naruto_kyuubi_mode
            ;;
    esac
    
    # 繰り返しの間に待機
    if [[ $i -lt $repeat ]]; then
        wait_with_animation "$delay" "次の繰り返しまで待機中..."
    fi
done
```

}

#=========================================================

# メイン処理

#=========================================================
main() {
# デフォルト値の設定
local mode=“all”
local delay=2
local repeat=1
local silent=false

```
# コマンドライン引数の処理
while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--normal)
            mode="normal"
            shift
            ;;
        -c|--chakra)
            mode="chakra"
            shift
            ;;
        -k|--kyuubi)
            mode="kyuubi"
            shift
            ;;
        -a|--all)
            mode="all"
            shift
            ;;
        -r|--repeat)
            if [[ -n "${2:-}" ]] && validate_repeat "$2"; then
                repeat="$2"
                shift 2
            else
                log_error "繰り返し回数が無効です"
                return 1
            fi
            ;;
        -d|--delay)
            if [[ -n "${2:-}" ]] && validate_delay "$2"; then
                delay="$2"
                shift 2
            else
                log_error "遅延時間が無効です"
                return 1
            fi
            ;;
        -s|--silent)
            silent=true
            export SILENT=true
            shift
            ;;
        -V|--version)
            show_version
            return 0
            ;;
        -h|--help)
            show_help
            return 0
            ;;
        *)
            log_error "不明なオプション: '$1'"
            echo ""
            show_help
            return 1
            ;;
    esac
done

# 端末サイズのチェック
if ! check_terminal_size; then
    return 1
fi

# タイトルを表示
if [[ "$silent" != "true" ]]; then
    clear_screen
    echo -e "${COLOR_BOLD}${COLOR_CYAN}===== うずまきナルト変化スクリプト v${VERSION} =====${COLOR_RESET}"
    echo ""
    
    if [[ $repeat -gt 1 ]]; then
        log_info "${repeat}回繰り返します"
    fi
    if [[ "$mode" == "all" ]]; then
        log_info "${delay}秒間隔でモード変化します"
    fi
    echo ""
fi

# モード実行
execute_mode "$mode" "$repeat" "$delay"

# 完了メッセージ
if [[ "$silent" != "true" ]]; then
    echo ""
    log_success "スクリプトの実行が完了しました"
    echo -e "${COLOR_YELLOW}だってばよ！${COLOR_RESET}"
fi

return 0
```

}

#=========================================================

# スクリプト実行

#=========================================================
if [[ “${BASH_SOURCE[0]}” == “${0}” ]]; then
main “$@”
fi