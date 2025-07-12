#!/bin/bash
set -euo pipefail

if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <file>"
    exit 1
fi

file="$1"
echo "Validating: $file"

if [[ ! -f "$file" ]]; then
    echo "Error: File not found: $file"
    exit 1
fi

# Check YAML
if ! grep -q "^---$" "$file"; then
    echo "Error: Missing metadata section in $file"
    exit 1
fi

# Extract YAML
yaml=$(awk '/^---$/{f++} f==1{print} /^---$/ && f==2{exit}' "$file")

# Check description
if ! echo "$yaml" | grep -q "^description:"; then
    echo "Error: Missing required field: description in $file"
    exit 1
fi

# Check category
if ! echo "$yaml" | grep -q "^category:"; then
    echo "Warning: Missing category in $file"
fi

echo "  ✓ Valid"
exit 0