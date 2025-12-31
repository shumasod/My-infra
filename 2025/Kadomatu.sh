#!/usr/bin/env bash
set -Eeuo pipefail

# =========================
# Terminal Color Utilities
# =========================
if [[ -t 1 ]]; then
  readonly GREEN='\033[0;32m'
  readonly BROWN='\033[0;33m'
  readonly RED='\033[0;31m'
  readonly WHITE='\033[1;37m'
  readonly NC='\033[0m'
else
  readonly GREEN='' BROWN='' RED='' WHITE='' NC=''
fi

# =========================
# Functions
# =========================
print_art() {
  echo -e "${GREEN}"
  cat <<'EOF'
⠀　　　_〆
　　 　 (∴:)
　　 （￣￣ ）
　＜(￣￣￣￣)＞
　[二▲二二▲二]
　　|▽　　▽|
　　|▲　　▲|
　　|＿ |⌒| ＿|
EOF
  echo -e "${NC}"
}

get_reiwa_year() {
  local year="$1"

  # 2019年 = 令和元年
  if (( year < 2019 )); then
    echo "令和以前"
  else
    echo "令和$((year - 2018))"
  fi
}

print_greeting() {
  local year reiwa
  year="$(date +%Y)"
  reiwa="$(get_reiwa_year "$year")"

  echo -e "${RED}明けましておめでとうございます${NC}"
  echo -e "${RED}謹んで新年のお慶びを申し上げます${NC}"
  echo
  echo -e "${WHITE}${year}年（${reiwa}年）も宜しくお願いいたします${NC}"
}

# =========================
# Main
# =========================
print_art
print_greeting