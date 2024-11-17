#!/bin/bash

# List all .txt files in the current directory
for file in *.txt; do
    # Check if the file exists to avoid errors
    if [ -f "$file" ]; then
        # Define the output file name
        output_file="${file%.txt}_hits.txt"

        # Search for lines containing "+" and write to the output file
        grep '+' "$file" > "$output_file"

        # Print a message if hits were found or not
        if [ -s "$output_file" ]; then
            echo "Hits found in $file. Results saved to $output_file."
        else
            echo "No hits found in $file. Empty $output_file created."
            rm "$output_file" # Remove empty output file
        fi
    fi
done

echo "Processing complete."

