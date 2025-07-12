#!/bin/bash
# Test for required documentation files

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Testing for required documentation..."
echo ""

# Required documentation files
REQUIRED_DOCS=(
    "docs/ORCHESTRATOR_DEVIATIONS.md"
    "docs/CONTRACTS.md"
    "docs/session-state-spec.md"
    "docs/AI_ORCHESTRATOR_GUIDE.md"
)

# Check each required file
failed=0
for doc in "${REQUIRED_DOCS[@]}"; do
    if [[ -f "$doc" ]]; then
        echo -e "${GREEN}PASS:${NC} Found $doc"
        
        # Additional checks for specific files
        case "$doc" in
            "docs/ORCHESTRATOR_DEVIATIONS.md")
                # Check for required sections
                if grep -q "Critical Deviations" "$doc" && \
                   grep -q "Model Routing" "$doc" && \
                   grep -q "Technical Constraints" "$doc"; then
                    echo "  ✓ Contains required sections"
                else
                    echo -e "  ${YELLOW}WARNING:${NC} Missing required sections"
                fi
                ;;
            "docs/CONTRACTS.md")
                # Check for session state contract reference
                if grep -q "Session State Specification" "$doc"; then
                    echo "  ✓ References session state contract"
                else
                    echo -e "  ${YELLOW}WARNING:${NC} Missing session state reference"
                fi
                ;;
        esac
    else
        echo -e "${RED}FAIL:${NC} Missing $doc"
        ((failed++))
    fi
done

echo ""

# Summary
if [[ $failed -eq 0 ]]; then
    echo -e "${GREEN}All documentation tests passed!${NC}"
    exit 0
else
    echo -e "${RED}$failed documentation file(s) missing${NC}"
    exit 1
fi