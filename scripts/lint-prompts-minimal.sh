#!/bin/bash
# Minimal prompt linter for testing

set -euo pipefail

# Counters
PASSED=0
FAILED=0

# Lint a file
lint_file() {
    local file="$1"
    local has_errors=false
    
    echo "Checking: $file"
    
    # Check file exists
    if [[ ! -f "$file" ]]; then
        echo "  Error: File not found"
        return 1
    fi
    
    # Check for YAML markers
    if ! grep -q "^---$" "$file"; then
        echo "  Error: Missing metadata section"
        has_errors=true
    fi
    
    # Check for description
    if ! grep -q "^description:" "$file"; then
        echo "  Error: Missing required field: description"
        has_errors=true
    fi
    
    # Check category
    if ! grep -q "^category:" "$file"; then
        echo "  Warning: Missing category"
    fi
    
    if [[ "$has_errors" == "true" ]]; then
        echo "  FAIL"
        return 1
    else
        echo "  PASS"
        return 0
    fi
}

# Main
for file in "$@"; do
    if lint_file "$file"; then
        PASSED=$((PASSED + 1))
    else
        FAILED=$((FAILED + 1))
    fi
done

echo ""
echo "Summary: $PASSED passed, $FAILED failed"

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi

exit 0