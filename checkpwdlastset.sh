#!/bin/bash

# Check if a filename is provided
if [ $# -lt 1 ]; then
    echo "Usage: ./checkpwdlastset.sh <filename>"
    exit 1
fi

filename=$1
output_file="outdated_passwords.txt"
email_output_file="extracted_emails.txt"
six_months_ago=$(date -d "6 months ago" +%s)

# Check if the file exists
if [ ! -f "$filename" ]; then
    echo "File not found!"
    exit 1
fi

# Prepare output files
echo "Users who haven't reset their passwords in over 6 months:" > "$output_file"
echo "----------------------------------------------------------" >> "$output_file"
echo "Extracted Emails:" > "$email_output_file"
echo "-----------------" >> "$email_output_file"

echo "Processing file: $filename"
echo "Checking for users who haven't reset their passwords in over 6 months..."
echo "Results will be saved to $output_file and $email_output_file"

# Counter for processed lines
line_count=0

# Read through the file and parse lines
while IFS= read -r line; do
    line_count=$((line_count + 1))

    # Skip header and other non-relevant lines
    if [[ "$line" == Name* ]] || [[ "$line" == Impacket* ]] || [[ -z "$line" ]]; then
        continue
    fi

    # Extract fields
    username=$(echo "$line" | awk '{print $1}')
    email=$(echo "$line" | awk '{print $2}')
    password_last_set=$(echo "$line" | awk '{print $3}')

    # Print progress
    echo "Processing user: $username (line $line_count)"

    # Append the email to the email output file
    echo "$email" >> "$email_output_file"

    # Skip users with "N/A" or no valid PasswordLastSet date
    if [[ "$password_last_set" == "N/A" ]] || [[ -z "$password_last_set" ]]; then
        echo "Skipping $username (No valid PasswordLastSet date found)"
        continue
    fi

    # Convert PasswordLastSet date to seconds since epoch
    password_last_set_epoch=$(date -d "$password_last_set" +%s 2>/dev/null)

    # Check if conversion was successful
    if [ $? -ne 0 ]; then
        echo "Error parsing date for user $username. Skipping..."
        continue
    fi

    # Check if the password was last set more than 6 months ago
    if [ "$password_last_set_epoch" -lt "$six_months_ago" ]; then
        echo "$username has not reset their password in over 6 months. Last set on: $password_last_set"
        echo "$username - Last Password Set: $password_last_set" >> "$output_file"
    fi
done < "$filename"

echo "Finished processing file: $filename"
echo "Results saved to $output_file"
echo "All emails saved to $email_output_file"

