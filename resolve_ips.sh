#!/bin/bash

# Input file containing hostnames
input_file="./ADComps.txt"

# Loop through each line of the input file
while IFS= read -r line; do
    # Extract the DNS Hostname (column 2)
    hostname=$(echo "$line" | awk '{print $2}')

    # Check if the hostname is valid before resolving
    if [[ "$hostname" =~ ^[a-zA-Z0-9.-]+$ ]]; then
        # Resolve the IP address
        ip_address=$(dig +short "$hostname")

        if [ -n "$ip_address" ]; then
            echo "Hostname: $hostname - IP Address: $ip_address"
        else
            echo "Hostname: $hostname - IP Address not found"
        fi
    fi
done < "$input_file"
