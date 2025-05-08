#!/bin/bash

# -----------------------------------------------------------------------
# IP to Hostname Resolver
# 
# This script takes a list of IP addresses from an input file and attempts
# to resolve each IP to its corresponding hostname using reverse DNS lookup.
# Only successfully resolved IPs are written to the output file.
# The script shows progress as it processes each IP address.
# 
# Output format: IP - hostname resolution result
# Example: ./ip_to_hostname.sh ip_list.txt
# -----------------------------------------------------------------------

# Check if input file is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <input_file>"
    exit 1
fi

input_file="$1"
output_file="all_hosts_resolved.txt"

# Check if input file exists
if [ ! -f "$input_file" ]; then
    echo "Input file $input_file does not exist"
    exit 1
fi

# Clear output file if it exists
> "$output_file"

# Count total lines for progress tracking
total_lines=$(grep -c ^ "$input_file")
current_line=0

# Read each IP from input file and resolve hostname
while IFS= read -r ip; do
    # Skip empty lines
    if [ -z "$ip" ]; then
        continue
    fi
    
    # Update progress counter
    ((current_line++))
    progress=$((current_line * 100 / total_lines))
    echo -ne "Progress: $progress% ($current_line/$total_lines)\r"
    
    # Resolve hostname using host command
    result=$(host "$ip" 2>/dev/null)
    
    # Only save results that successfully resolved
    if [ $? -eq 0 ] && [[ "$result" =~ "domain name pointer" ]]; then
        echo "$ip - $result" >> "$output_file"
    fi
done < "$input_file"

echo -e "\nResults written to $output_file"
