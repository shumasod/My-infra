#!/bin/bash

# Set the input Excel file path
INPUT_FILE="path/to/your/excel/file.xlsx"

# Convert the Excel file to CSV
in2csv "$INPUT_FILE" > temp.csv

# Loop through each row in the CSV file
cat temp.csv | csvcut -c 'A' | while read word; do
    # Check the spelling of the word using aspell
    if ! aspell list <<< "$word" >/dev/null; then
        echo "Possible misspelling: $word"
    fi
done

# Clean up the temporary file
rm temp.csv