#!/bin/bash

# Check if a filename is provided
if [ $# -lt 1 ]; then
    echo "Usage: ./resolve_hostnames.sh <filename>"
    exit 1
fi

filename=$1
output_file="resolved_hostnames.txt"

# Check if the file exists
if [ ! -f "$filename" ]; then
    echo "File not found!"
    exit 1
fi

# Prepare output file
echo "Hostname to IP resolution:" > "$output_file"
echo "--------------------------" >> "$output_file"

echo "Processing file: $filename"
echo "Resolving hostnames..."

# Read through the file and parse lines
while IFS= read -r line; do
    # Skip header and non-relevant lines
    if [[ "$line" == SAM* ]] || [[ "$line" == Impacket* ]] || [[ "$line" == "[*]"* ]] || [[ -z "$line" ]]; then
        continue
    fi

    # Extract DNS Hostname (assumes hostname is in the second column)
    dns_hostname=$(echo "$line" | awk '{print $2}')

    # Check if DNS hostname field is empty
    if [[ -z "$dns_hostname" ]]; then
        echo "No DNS hostname found on line: $line"
        continue
    fi

    # Perform DNS lookup
    ip_address=$(dig +short "$dns_hostname" | tail -n1)

    # Check if the lookup was successful
    if [[ -z "$ip_address" ]]; then
        echo "Failed to resolve IP for $dns_hostname"
        echo "$dns_hostname - Resolution failed" >> "$output_file"
    else
        echo "$dns_hostname - $ip_address"
        echo "$dns_hostname - $ip_address" >> "$output_file"
    fi
done < "$filename"

echo "Finished processing file: $filename"
echo "Results saved to $output_file"
