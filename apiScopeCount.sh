#!/bin/bash

# Iterate through each folder in the current working directory where Swagger JSON files are stored
for dir in */; do
  # Check if the folder contains any JSON files
  if ls "$dir"*.json >/dev/null 2>&1; then
    echo "Processing folder: $dir"  # Notify which folder is being processed
    
    # Count the occurrences of "basePath" in all JSON files in the current folder
    # The `-h` flag suppresses filenames in the grep output
    base_path_count=$(grep -h basePath "$dir"*.json | wc -l)
    
    # Count unique occurrences of "operationId" in all JSON files in the current folder
    # First, grep for "operationId", then sort the results uniquely using `sort -u`, and count the lines
    operation_id_count=$(grep -h operationId "$dir"*.json | sort -u | wc -l)
    
    # Display the results in the required format
    echo "$base_path_count Base Path Endpoints in $dir"  # Output the count of "basePath" matches
    echo "$operation_id_count Total Endpoint/OperationIds in $dir"  # Output the count of unique "operationId" matches
    echo  # Add an empty line for better readability between folder outputs
  else
    # If no JSON files are found, notify the user
    echo "No JSON files found in folder: $dir"
  fi
done
