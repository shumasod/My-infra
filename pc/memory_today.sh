#!/bin/bash -eu

# Set the directory to store the memory data
memo_dir="${HOME}/memory_data"
mkdir -p "${memo_dir}"

# Get the current date
today="$(date +%Y-%m-%d)"
file="${memo_dir}/${today}.txt"

# Record the memory data from the task manager
get_memory_data() {
    # Get the available memory in MB
    available_mem=$(free -m | awk '/Mem/ {print $7}')
    echo "${available_mem}" >> "${file}"
}

# Calculate the average memory usage
calculate_average() {
    total=0
    count=0

    # Read the memory data from the file
    while read -r line; do
        total=$((total + line))
        count=$((count + 1))
    done < "${file}"

    # Calculate the average
    average=$((total / count))
    echo "Average memory usage (MB): ${average}"
}

# Record the memory data every minute
while true; do
    get_memory_data
    sleep 60
done

# Calculate the average memory usage at the end of the day
calculate_average