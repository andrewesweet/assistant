#!/bin/bash
# Resolve command path from logical name
set -euo pipefail

# Configuration
COMMAND_DIR="${COMMAND_DIR:-.claude/commands}"

# Function to resolve command path
resolve_path() {
    local command_name="$1"
    
    # Remove leading slash if present
    command_name="${command_name#/}"
    
    # Check if it's already a full path
    if [[ "$command_name" == *.md ]]; then
        if [[ -f "$command_name" ]]; then
            echo "$command_name"
            return 0
        fi
    fi
    
    # Try various path combinations
    local paths=(
        "$COMMAND_DIR/${command_name}.md"
        "$COMMAND_DIR/${command_name}"
        "${command_name}.md"
        "$command_name"
    )
    
    for path in "${paths[@]}"; do
        if [[ -f "$path" ]]; then
            echo "$path"
            return 0
        fi
    done
    
    # Not found
    return 1
}

# Main
if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <command-name>"
    exit 1
fi

if path=$(resolve_path "$1"); then
    echo "$path"
else
    echo "Error: Command not found: $1" >&2
    exit 1
fi