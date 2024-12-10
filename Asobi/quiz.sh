#!/bin/bash
echo "Q: リンゴは英語で何？"
read answer
if [ "$answer" == "apple" ]; then
  echo "正解！🍎"
else
  echo "残念、不正解！"
fi
