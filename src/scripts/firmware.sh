#!/bin/sh
# Firmware upgrade proxy for firmd — POSIX shell compatible.
# Created by: Naitik
# Date: 2025-05-24

# Store the current time in the format YYYYMMDD_HHMMSS
current_time=$(date +"%Y%m%d_%H%M%S")

# Check if firmd.log exists; if not, create it
log_file="/flash2/firmd/firmd.log"
if [ ! -f "$log_file" ]; then
    mkdir -p /flash2/firmd/
    touch "$log_file"
fi

# Append the current time and all arguments to the log file
echo "$current_time - Arguments: $*" >> "$log_file"

echo "Environment Variables:" >> "$log_file"
env >> "$log_file"
echo "--- End Environment Variables ---" >> "$log_file"
echo "" >> "$log_file"

# Create a folder with the current time as the folder name
# and copy all /tmp/tr69* files into it
new_folder="/flash2/firmd/$current_time"
mkdir -p "$new_folder"
cp /tmp/tr69* "$new_folder" 2>/dev/null

# Check for "-f" argument and copy specified file to our folder if provided
# POSIX-compliant argument parsing: consume the next argument after -f
set -- "$@"
while [ $# -gt 0 ]; do
    case "$1" in
        -f)
            shift
            if [ $# -gt 0 ]; then
                file_location="$1"
                if [ -f "$file_location" ]; then
                    cp "$file_location" "$new_folder"
                else
                    echo "File not found: $file_location" >> "$log_file"
                fi
            fi
            break
            ;;
    esac
    shift
done
