#!/usr/bin/env bash
set -Eeuo pipefail

# =========================
# Terminal Color Utilities
# =========================
if [[ -t 1 ]] && [[ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]]; then
  readonly BROWN='\033[0;33m'
  readonly YELLOW='\033[1;33m'
  readonly RED='\033[0;31m'
  readonly CYAN='\033[0;36m'
  readonly WHITE='\033[1;37m'
  readonly NC='\033[0m'
else
  readonly BROWN='' YELLOW='' RED='' CYAN='' WHITE='' NC=''
fi

# =========================
# Cleanup
# =========================
cleanup() {
  echo -e "${NC}"
}
trap cleanup INT TERM EXIT

# =========================
# New Year Decoration
# =========================
draw_decoration() {
  echo -e "${RED}     ❀ 迎春 ❀${NC}"
  echo "    ================="
}

# =========================
# Horse ASCII Art
# =========================
draw_horse() {
  echo -e "${BROWN}"
  cat <<'HORSE'
            ,w.
          _/o o\_
   .--._ /  ^_^  \ _.--.
  /     `-._\___/_.-'     \
 |   .-"""""`     `"""-.   |
 |  /    _..-"""-.._    \  |
 | |   .-'               '-.|
  \ \  |     _.-"""-._      |
   '.'. \_.-'"         "-._/
      '-._                 \
           "-._             |
                "--..____..-'
HORSE
  echo -e "${NC}"
}

# =========================
# Functions
# =========================
print_messages() {
  local year
  year="$(date +%Y)"

  local messages=(
    "${year}年 午年"
    "明けまして"
    "おめでとうございます"
    "本年も宜しく"
    "お願いいたします"
  )

  for msg in "${messages[@]}"; do
    sleep 1
    echo -e "\n    ${CYAN}${msg}${NC}"
  done
}

print_comment() {
  echo
  echo -e "🐎 馬「${YELLOW}今年は全力疾走。止まらず前へ進みます！${NC}」"
}

# =========================
# Main
# =========================
main() {
  clear 2>/dev/null || printf "\033c"
  draw_decoration
  echo
  draw_horse
  print_messages
  print_comment
}

main