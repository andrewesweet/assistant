#!/bin/bash

echo "Testing script execution..."
echo "Args: $@"

# Try sourcing the problematic parts
set -euo pipefail

REQUIRED_FIELDS=("description")
echo "Required fields: ${REQUIRED_FIELDS[@]}"

# Test awk
echo "Testing awk..."
echo -e "---\ndescription: test\n---" | awk '/^---$/{f++} f==1{print} /^---$/ && f==2{exit}'

echo "Script completed successfully"