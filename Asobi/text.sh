#!/bin/bash
text="遊び心満載！"
for color in {31..36}; do
  echo -e "\033[${color}m$text\033[0m"
done
