#!/bin/bash
quotes=("継続は力なり" "失敗は成功のもと" "笑う門には福来る")
echo "今日の名言: ${quotes[$RANDOM % ${#quotes[@]}]}"
