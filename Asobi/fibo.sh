#!/bin/bash

# 端末の色サポートを確認
if [ -t 1 ] && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    MAGENTA='\033[0;35m'
    CYAN='\033[0;36m'
    NC='\033[0m'    # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    MAGENTA=''
    CYAN=''
    NC=''
fi

# タイトル表示
clear 2>/dev/null || printf "\033c"
echo -e "${YELLOW}================================${NC}"
echo -e "${CYAN}  フィボナッチ数列の星アート！  ${NC}"
echo -e "${YELLOW}================================${NC}\n"

# フィボナッチ数列の計算と星の表示
a=0
b=1
fibonacci=()

# 最初に数列を計算（値も保存）
for i in {1..15}; do
    fn=$((a + b))
    fibonacci+=($b)
    a=$b
    b=$fn
done

# 上昇パターン
echo -e "${BLUE}【上昇パターン】${NC}"
for i in {0..9}; do
    # 色をローテーション
    case $((i % 6)) in
        0) color=$RED ;;
        1) color=$GREEN ;;
        2) color=$YELLOW ;;
        3) color=$BLUE ;;
        4) color=$MAGENTA ;;
        5) color=$CYAN ;;
    esac
    
    # 星を表示
    echo -e "$color$(printf "%${fibonacci[$i]}s" | tr ' ' '*') (${fibonacci[$i]})${NC}"
done

echo ""

# 下降パターン
echo -e "${BLUE}【下降パターン】${NC}"
for i in {9..0}; do
    # 色をローテーション
    case $((i % 6)) in
        0) color=$RED ;;
        1) color=$GREEN ;;
        2) color=$YELLOW ;;
        3) color=$BLUE ;;
        4) color=$MAGENTA ;;
        5) color=$CYAN ;;
    esac
    
    # 星を表示（中央揃え）
    padding=$((40 - fibonacci[$i]))
    left_pad=$((padding / 2))
    
    echo -e "$(printf "%${left_pad}s" "")$color$(printf "%${fibonacci[$i]}s" | tr ' ' '*') (${fibonacci[$i]})${NC}"
done

echo ""

# ピラミッドパターン
echo -e "${BLUE}【ピラミッドパターン】${NC}"
for i in {0..7}; do
    # 色をローテーション
    case $((i % 6)) in
        0) color=$RED ;;
        1) color=$GREEN ;;
        2) color=$YELLOW ;;
        3) color=$BLUE ;;
        4) color=$MAGENTA ;;
        5) color=$CYAN ;;
    esac
    
    # 中央揃えで星を表示
    padding=$((40 - fibonacci[$i]))
    left_pad=$((padding / 2))
    
    echo -e "$(printf "%${left_pad}s" "")$color$(printf "%${fibonacci[$i]}s" | tr ' ' '*')${NC}"
done

echo -e "\n${YELLOW}================================${NC}"
echo -e "${GREEN}フィボナッチ数列：1, 1, 2, 3, 5, 8, 13, 21, 34, 55, ...${NC}"
echo -e "${YELLOW}================================${NC}"