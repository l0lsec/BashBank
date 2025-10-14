#!/bin/bash

# Script to split a file of IPs into multiple files with max 750 IPs per file
# Usage: ./ipsplit.sh <ip_file>

# Check if a filename was provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <ip_file>"
    echo "Example: $0 myips.txt"
    exit 1
fi

input_file="$1"

# Check if file exists
if [ ! -f "$input_file" ]; then
    echo "Error: File '$input_file' not found"
    exit 1
fi

# Count total IPs
total_ips=$(wc -l < "$input_file")
echo "Total IPs: $total_ips"

# Calculate expected number of output files
expected_files=$(( (total_ips + 749) / 750 ))
echo "Will create approximately $expected_files file(s)"

# Get the base filename without extension
base_name=$(basename "$input_file" | sed 's/\.[^.]*$//')

# Split the file into chunks of 750 lines
echo "Splitting into files with max 750 IPs each..."
split -l 750 "$input_file" "${base_name}_part_"

# Count how many files were created
file_count=$(ls -1 ${base_name}_part_* 2>/dev/null | wc -l)
echo ""
echo "✓ Successfully created $file_count file(s) in current directory"
echo "Files have prefix: ${base_name}_part_"
echo ""
echo "Output files:"
ls -lh ${base_name}_part_*

