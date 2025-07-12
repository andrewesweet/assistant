#!/bin/bash
# Simplified command validator for testing

set -euo pipefail

validate_file() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        echo "Error: File not found: $file"
        return 1
    fi
    
    # Check for YAML markers
    if ! grep -q "^---$" "$file"; then
        echo "Error: Missing metadata section in $file"
        return 1
    fi
    
    # Check for description
    if ! grep -q "^description:" "$file"; then
        echo "Error: Missing required field: description in $file"
        return 1
    fi
    
    echo "✓ Valid"
    return 0
}

# Main
if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <file>"
    exit 1
fi

validate_file "$1"