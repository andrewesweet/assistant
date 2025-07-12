#!/bin/bash
# Expand template variables in command files
set -euo pipefail

# Function to expand variables
expand_variables() {
    local content="$1"
    local date_now=$(date +%Y-%m-%d)
    local time_now=$(date +%H:%M:%S)
    local datetime_now=$(date +%Y-%m-%dT%H:%M:%S)
    
    # Expand standard variables
    content="${content//\{\{USER\}\}/${USER:-unknown}}"
    content="${content//\{\{ARGUMENTS\}\}/${ARGUMENTS:-}}"
    content="${content//\{\{CURRENT_DATE\}\}/$date_now}"
    content="${content//\{\{CURRENT_TIME\}\}/$time_now}"
    content="${content//\{\{CURRENT_DATETIME\}\}/$datetime_now}"
    content="${content//\{\{PWD\}\}/$PWD}"
    content="${content//\{\{HOME\}\}/$HOME}"
    content="${content//\{\{FEATURE_ID\}\}/${FEATURE_ID:-}}"
    content="${content//\{\{SESSION_PATH\}\}/${SESSION_PATH:-}}"
    content="${content//\{\{MODEL\}\}/${MODEL:-}}"
    
    echo "$content"
}

# Main
if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <command-file>"
    exit 1
fi

file="$1"

if [[ ! -f "$file" ]]; then
    echo "Error: File not found: $file" >&2
    exit 1
fi

# Read and expand content
content=$(cat "$file")
expand_variables "$content"