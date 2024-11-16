#!/bin/bash

# Check if a filename is provided
if [ $# -lt 1 ]; then
    echo "Usage: ./extract_subents.sh <filename>"
    exit 1
fi

input_file=$1
output_file="extracted_subnets.txt"

# Check if the file exists
if [ ! -f "$input_file" ]; then
    echo "File not found!"
    exit 1
fi

# Prepare output file
echo "Unique /24 CIDR Notations:" > "$output_file"
echo "--------------------------" >> "$output_file"

# Temporary file to store subnets
temp_file=$(mktemp)

# Process the input file
while IFS= read -r line; do
    # Extract IP addresses using grep and regex
    ip=$(echo "$line" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')

    # Skip lines without valid IPs
    if [[ -z "$ip" ]]; then
        continue
    fi

    # Chop off the third octet and append /24
    cidr=$(echo "$ip" | awk -F. '{print $1 "." $2 "." $3 ".0/24"}')

    # Add to temporary file
    echo "$cidr" >> "$temp_file"
done < "$input_file"

# Sort and de-duplicate the subnets
sort -u "$temp_file" >> "$output_file"

# Clean up temporary file
rm -f "$temp_file"

echo "Processing complete. Unique subnets saved to $output_file"

