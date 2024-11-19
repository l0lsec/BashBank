#!/bin/bash

# Loop through each directory in the current working directory
for dir in */; do
  # Check if the directory contains a .git folder
  if [ -d "$dir/.git" ]; then
    echo "Updating repository in $dir"
    (cd "$dir" && git pull)
  else
    echo "Skipping $dir (not a git repository)"
  fi
done

echo "Update complete for all repositories."

