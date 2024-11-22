#!/bin/bash

# Check if the input file is provided
if [ $# -eq 0 ]; then
  echo "Usage: $0 <Files containing IPs>"
  exit 1
fi

# Input file passed as argument
INPUT_FILE="$1"

# Output file name
OUTPUT_FILE="resolved_hosts.txt"

# Check if the input file exists
if [ ! -f "$INPUT_FILE" ]; then
  echo "Error: File '$INPUT_FILE' not found."
  exit 1
fi

# Clear the output file if it exists
> "$OUTPUT_FILE"

# Loop through each IP in the input file
while read -r ip; do
  # Perform the host command
  result=$(host "$ip" 2>&1)
  
  # Check if the IP resolves (does not contain NXDOMAIN)
  if [[ $result != *"NXDOMAIN"* && $result == *"pointer"* ]]; then
    # Extract all hostnames and write each as "HOSTNAME, IP"
    echo "$result" | awk '/pointer/ {print $5}' | sed 's/\.$//' | while read -r hostname; do
      echo "$hostname, $ip" >> "$OUTPUT_FILE"
    done
  fi
done < "$INPUT_FILE"

echo "Resolution complete. Results saved to $OUTPUT_FILE."
