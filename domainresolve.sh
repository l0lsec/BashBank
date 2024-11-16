#!/bin/bash

#File with IP addresses to loop through
domains="domains.txt"

#loop through and resolve domains
while IFS= read -r domains; do 
    echo "Resolving $domains"
    host $domains | tee -a domains_resolved.txt

done < "$domains"