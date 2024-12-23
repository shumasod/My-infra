#!/bin/bash

# Text formatting
BOLD='\033[1m'
ITALIC='\033[3m'
RESET='\033[0m'
BLUE='\033[34m'
PURPLE='\033[35m'
CYAN='\033[36m'

# Function to display formatted text
print_formatted() {
    local type=$1
    local text=$2
    case $type in
        "title")   echo -e "${BOLD}${BLUE}$text${RESET}" ;;
        "lyrics")  echo -e "${ITALIC}${PURPLE}$text${RESET}" ;;
        "single")  echo -e "${CYAN}$text${RESET}" ;;
    esac
}

# Function to display a decorative separator
print_separator() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
}

# Store Aimyon's songs with additional metadata
# Format: "Song title:Lyrics:Single:Year:Additional note"
declare -A songs=(
    ["marigold"]="マリーゴールド:風の強さがちょっと心を揺さぶりすぎて まじめに見つめた君が恋しい:Marigold:2018:Breaking through single"
    ["kimi_rock"]="君はロックを聴かない:少し寂しそうな君に こんな歌を聞かそう 手を叩く合図:君はロックを聴かない:2017:Major debut single"
    ["hadaka"]="裸の心:一体このままいつまで 一人でいるつもりだろう だんだん自分を憎んだり:裸の心:2019:Oricon weekly first place"
    ["harunohi"]="春の日:北千住駅のplatform 銀色の改札 思い出ばなしと 思い出深し:春の日:2018:Spring-themed song"
    ["ai"]="愛を伝えたいだとか:健康的な朝だな こんな時に君の「愛してる」が聞きたいや 揺れるカーテン:愛を伝えたいだとか:2019:Love song"
)

# Function to display song information with formatting
display_song() {
    local song_data=$1
    IFS=':' read -r title lyrics single year note <<< "$song_data"
    
    print_separator
    print_formatted "title" "♪ $title"
    echo -e "\n${BOLD}Lyrics:${RESET}"
    print_formatted "lyrics" "$lyrics"
    echo -e "\n${BOLD}Single:${RESET}"
    print_formatted "single" "$single ($year)"
    echo -e "\n${BOLD}Note:${RESET} $note"
    print_separator
}

# Main execution
echo -e "${BOLD}${BLUE}Welcome to Aimyon Song Selector!${RESET}\n"

# Get all keys (song identifiers)
song_keys=("${!songs[@]}")

# Select random song
random_index=$((RANDOM % ${#song_keys[@]}))
random_key=${song_keys[$random_index]}
random_song="${songs[$random_key]}"

# Display the selected song
display_song "$random_song"

# Add usage hint
echo -e "Run the script again for another random Aimyon song!\n"