#!/bin/bash

# ==============================================================================
# 武士の抜刀姿 ASCII Art Animation - 高再現性版
# Samurai Drawing Sword - Improved Reproducibility Version
# ==============================================================================

# エラー処理とデバッグ設定
set -euo pipefail

# 端末互換性チェック関数
check_terminal_compatibility() {
    local color_support=0
    local clear_support=0
    
    # 色サポートの確認（複数の方法で試行）
    if [ -t 1 ]; then
        if command -v tput >/dev/null 2>&1; then
            local colors=$(tput colors 2>/dev/null || echo 0)
            [ "$colors" -ge 8 ] && color_support=1
        elif [ -n "${TERM:-}" ] && [ "$TERM" != "dumb" ]; then
            color_support=1
        fi
    fi
    
    # クリア機能の確認
    if command -v clear >/dev/null 2>&1; then
        clear_support=1
    elif command -v tput >/dev/null 2>&1 && tput clear >/dev/null 2>&1; then
        clear_support=1
    fi
    
    echo "${color_support}:${clear_support}"
}

# 端末機能の検出
TERMINAL_CAPS=$(check_terminal_compatibility)
COLOR_SUPPORT=$(echo "$TERMINAL_CAPS" | cut -d: -f1)
CLEAR_SUPPORT=$(echo "$TERMINAL_CAPS" | cut -d: -f2)

# カラー設定（端末サポートに基づく）
if [ "$COLOR_SUPPORT" -eq 1 ]; then
    readonly BLACK='\033[0;30m'
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly BLUE='\033[0;34m'
    readonly CYAN='\033[0;36m'
    readonly WHITE='\033[1;37m'
    readonly GRAY='\033[1;30m'
    readonly NC='\033[0m'
    readonly CLEAR_SCREEN='\033[2J\033[H'
else
    readonly BLACK=''
    readonly RED=''
    readonly GREEN=''
    readonly YELLOW=''
    readonly BLUE=''
    readonly CYAN=''
    readonly WHITE=''
    readonly GRAY=''
    readonly NC=''
    readonly CLEAR_SCREEN=''
fi

# スリープ関数（クロスプラットフォーム対応）
portable_sleep() {
    local duration=${1:-1}
    
    # 高精度sleepを試行
    if command -v sleep >/dev/null 2>&1; then
        if sleep 0.1 2>/dev/null; then
            sleep "$duration"
            return 0
        fi
    fi
    
    # Bashの組み込み機能を使用
    if command -v read >/dev/null 2>&1; then
        read -t "$duration" -n 1 2>/dev/null || true
        return 0
    fi
    
    # フォールバック: busy wait
    local end_time=$(($(date +%s) + duration))
    while [ $(date +%s) -lt $end_time ]; do
        :
    done
}

# 画面クリア関数（互換性重視）
clear_screen() {
    if [ "$CLEAR_SUPPORT" -eq 1 ]; then
        if command -v clear >/dev/null 2>&1; then
            clear 2>/dev/null || true
        elif command -v tput >/dev/null 2>&1; then
            tput clear 2>/dev/null || true
        fi
    fi
    
    # ANSIエスケープシーケンスによるクリア
    if [ -n "$CLEAR_SCREEN" ]; then
        printf "%b" "$CLEAR_SCREEN"
    else
        # フォールバック: 空行で画面を埋める
        printf '\n%.0s' {1..50}
    fi
}

# ASCII Art関数群
samurai_standing() {
    cat << "EOF"
                    ___
                   /   \
                  | o   o |
                   \  -  /
                    \___/
                     |||
              ┌─────┴┴┴─────┐
              │    髷 (まげ)   │
              └─────────────┘
                     |||
             ╔═══════╤═══════╗
             ║       │       ║
             ║   着  │  物   ║
             ║       │       ║
             ╠═══════╪═══════╣
             ║       │       ║
             ║       │       ║
             ║       │       ║
             ╚═══════╧═══════╝
                    / \
                   /   \
                  /     \
                 /       \
                /         \
               =============
              草履 (zōri)
EOF
}

samurai_battle() {
    cat << "EOF"
      △ △    
     (｀_´)ノ
    ξ/⌒Y⌒\⚔
   ξ  | |   |
     ／\| |  ｜
    ｜  | |  ｜
   ／＼ | |  ｜
  ｜  ｜| |／｜
  ｜  ｜L/ ＼|
  ｜  ｜ \  ｜
  ｜  ｜  \ ｜
  し  し   ＼)
EOF
}

samurai_attack() {
    cat << "EOF"
       △ △    
      (｀皿´)   
     ξ/   \⚔≡≡≡
    ξ    |   |
      ／\  |  ｜
     ｜    |  ｜
    ／＼   |  ｜
   ｜  ｜ |／｜
   ｜  ｜L/ ＼|
   ｜  ｜ \  ｜
   ｜  ｜  \ ｜
   し  し   ＼)
EOF
}

# メッセージ表示関数
show_message() {
    local message="$1"
    local color="${2:-$NC}"
    printf "\n    %b%s%b\n" "$color" "$message" "$NC"
}

# ヘッダー表示関数
show_header() {
    printf "%b" "$CYAN"
    echo "========================================"
    echo "     武士の抜刀姿 - Samurai Iaido"
    echo "========================================"
    printf "%b" "$NC"
    echo
}

# アニメーションシーケンス実行関数
run_animation_sequence() {
    local cycle_count="${1:-3}"
    local frame_duration="${2:-0.8}"
    
    for i in $(seq 1 "$cycle_count"); do
        # フレーム1: 立ち姿
        clear_screen
        printf "%b" "$WHITE"
        samurai_standing
        printf "%b" "$NC"
        show_message "見参！" "$BLUE"
        portable_sleep "$frame_duration"
        
        # フレーム2: 抜刀姿
        clear_screen
        printf "%b" "$BLUE"
        samurai_battle
        printf "%b" "$NC"
        show_message "覚悟！" "$YELLOW"
        portable_sleep "$frame_duration"
        
        # フレーム3: 切りかかる姿
        clear_screen
        printf "%b" "$RED"
        samurai_attack
        printf "%b" "$NC"
        show_message "や〜！" "$RED"
        portable_sleep "$frame_duration"
    done
}

# エンディングメッセージ表示関数
show_ending() {
    echo
    printf "%b=============================%b\n" "$BLUE" "$NC"
    echo
    printf "侍「拙者、%b弐千弐拾伍年%bの守護を仰せつかりました」\n" "$RED" "$NC"
    printf "侍「%b貴殿のご多幸%bを祈っておる」\n" "$BLUE" "$NC"
    echo
}

# メイン実行関数
main() {
    # 引数の解析（オプション）
    local cycles=3
    local speed=0.8
    
    while [ $# -gt 0 ]; do
        case "$1" in
            -c|--cycles)
                cycles="$2"
                shift 2
                ;;
            -s|--speed)
                speed="$2"
                shift 2
                ;;
            -h|--help)
                echo "使用法: $0 [-c cycles] [-s speed]"
                echo "  -c, --cycles  アニメーションサイクル数 (デフォルト: 3)"
                echo "  -s, --speed   フレーム間隔秒数 (デフォルト: 0.8)"
                exit 0
                ;;
            *)
                echo "不明なオプション: $1" >&2
                exit 1
                ;;
        esac
    done
    
    # 初期画面クリア
    clear_screen
    
    # ヘッダー表示
    show_header
    
    # アニメーション実行
    printf "%b=============================%b\n" "$BLUE" "$NC"
    printf "%b        侍、参上！        %b\n" "$BLUE" "$NC"
    printf "%b=============================%b\n" "$BLUE" "$NC"
    echo
    
    run_animation_sequence "$cycles" "$speed"
    
    # エンディング
    clear_screen
    show_ending
}

# スクリプト実行（main関数呼び出し）
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
