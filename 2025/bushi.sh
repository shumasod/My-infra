#!/usr/bin/env bash
set -Eeuo pipefail

# =========================
# Constants / Config
# =========================
readonly FRAME_INTERVAL="0.07"
readonly TITLE="🐎 2026年 午年 — 駆ける馬 🐎"

# =========================
# Terminal Color Utilities
# =========================
if [[ -t 1 ]] && [[ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]]; then
  readonly BROWN='\033[0;33m'
  readonly WHITE='\033[1;37m'
  readonly CYAN='\033[0;36m'
  readonly NC='\033[0m'
else
  readonly BROWN='' WHITE='' CYAN='' NC=''
fi

# =========================
# Cleanup / Signal Handling
# =========================
cleanup() {
  echo -e "${NC}"
  echo
}

trap cleanup INT TERM EXIT

# =========================
# Horse Frames (Running)
# =========================
readonly FRAMES=(
"🐎💨        "
" 🐎💨       "
"  🐎💨      "
"   🐎💨     "
"    🐎💨    "
"     🐎💨   "
"      🐎💨  "
"       🐎💨 "
"        🐎💨"
"       🐎💨 "
"      🐎💨  "
"     🐎💨   "
"    🐎💨    "
"   🐎💨     "
"  🐎💨      "
" 🐎💨       "
)

# =========================
# Functions
# =========================
print_title() {
  local year
  year="$(date +%Y)"
  echo -e "${CYAN}${year}年 午年 — 駆ける馬 🐎${NC}"
  echo
}

animate_horse() {
  while true; do
    for frame in "${FRAMES[@]}"; do
      echo -ne "\r${BROWN}${frame}${NC}"
      sleep "${FRAME_INTERVAL}"
    done
  done
}

# =========================
# Main
# =========================
main() {
  clear
  print_title
  animate_horse
}

main