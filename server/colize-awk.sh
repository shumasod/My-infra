#!/usr/bin/awk -f

BEGIN {
    RESET="\033[0m"
    BOLD="\033[1m"
    ITALIC="\033[3m"
    UNDERLINE="\033[4m"
    BLINK="\033[5m"
    REVERSE="\033[7m"
    BLACK="\033[30m"
    RED="\033[31m"
    GREEN="\033[32m"
    BROWN="\033[33m"
    BLUE="\033[34m"
    PURPLE="\033[35m"
    CYAN="\033[36m"
    WHITE="\033[37m"
    BG_BLACK="\033[40m"
    BG_RED="\033[41m"
    BG_GREEN="\033[42m"
    BG_BROWN="\033[43m"
    BG_BLUE="\033[44m"
    BG_PURPLE="\033[45m"
    BG_CYAN="\033[46m"
    BG_WHITE="\033[47m"
    SLOW_WARN=50000
    SLOW_FATAL=100000
    slow=0
}

function sleep(ms) {
    system("awk 'BEGIN{system(\"sleep " ms/1000 "\")}' > /dev/null 2>&1")
}

$6 ~ /PURGE/ {
    gsub("PURGE", GREEN BOLD "PURGE" RESET, $6)
}

$NF ~ /TCP(.*)HIT/ {
    status = $NF
    gsub(status, BLUE BOLD status RESET, $NF)
}

$NF ~ /TCP(.*)MISS/ {
    status = $NF
    gsub(status, CYAN BOLD status RESET, $NF)
}

{
    response = $2 + 0  # Convert to number
    if (response <= 100) {
        gsub($2, GREEN BOLD $2 RESET, $2)
    } else if (response <= 500) {
        gsub($2, BLUE BOLD $2 RESET, $2)
    } else if (response <= 1000) {
        gsub($2, PURPLE BOLD $2 RESET, $2)
    } else if (response > 1000) {
        gsub($2, RED BOLD $2 RESET, $2)
        slow=SLOW_FATAL
    }
}

{
    status = $9 + 0  # Convert to number
    if (status == 0 || status >= 500) {
        gsub($9, RED BOLD $9 RESET, $9)
        slow=SLOW_FATAL
    } else if (status < 400) {
        gsub($9, GREEN BOLD $9 RESET, $9)
    } else if (status < 500) {
        gsub($9, PURPLE BOLD $9 RESET, $9)
        slow=SLOW_WARN
    }
}

{
    print $0

    if (slow > 0) {
        sleep(slow)
        slow=0
    }
}