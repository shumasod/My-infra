#!/bin/bash
art=("(* ^ ω ^)" "(´ ∀ \` *)" "⊂(・▽・⊂)" "＼(≧▽≦)／" "(/≧▽≦)/")
echo "今日の気分にぴったりな顔文字: ${art[$RANDOM % ${#art[@]}]}"