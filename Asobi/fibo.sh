#!/bin/bash
echo "フィボナッチ数列の星アート！"
a=0
b=1
for i in {1..10}; do
  echo $(printf "%${b}s" | tr ' ' '*')
  fn=$((a + b))
  a=$b
  b=$fn
done
