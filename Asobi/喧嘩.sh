#!/bin/bash

# 喧嘩シェルスクリプト
# 二人のキャラが言い争う

RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

A="太郎"
B="次郎"

say_a() { echo -e "${RED}【$A】${NC} $1"; sleep 1; }
say_b() { echo -e "${BLUE}【$B】${NC} $1"; sleep 1; }
narration() { echo -e "${YELLOW}--- $1 ---${NC}"; sleep 0.5; }

clear
narration "ある日の昼下がり..."
echo

say_a "おい次郎！お前また俺のプリン食っただろ！！"
say_b "はぁ？知らねーし"
say_a "冷蔵庫に『太郎のプリン 食べたら殺す』って書いてあっただろうが！"
say_b "読めなかった。字が汚すぎて"
say_a "なんだとコラァ！！"

narration "太郎、キレる"

say_b "つーかお前さ、先週俺のからあげ食ったよな？"
say_a "......"
say_b "おい、聞いてんのか"
say_a "あれは...事故だ"
say_b "事故で5個全部食うかボケェ！！"

narration "次郎もキレた"

say_a "うるせぇ！からあげとプリンじゃ格が違うんだよ！"
say_b "は？からあげ舐めんな！！"
say_a "プリンのが上に決まってんだろ！"
say_b "からあげだ！"
say_a "プリン！"
say_b "からあげ！"

for i in {1..3}; do
    say_a "プリン！！"
    say_b "からあげ！！"
done

narration "そこに母ちゃん登場"

echo -e "\n${YELLOW}【母ちゃん】${NC} うっっっるさい！！！二人とも晩飯抜き！！！"
echo

say_a "......"
say_b "......"

narration "二人、仲良く正座"

echo -e "\n${YELLOW}＝＝＝ 完 ＝＝＝${NC}\n"
