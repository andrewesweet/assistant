#!/bin/bash
# Simple test: Verify implement.sh is configured to use claude, not gemini

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Testing implement.sh model routing configuration..."
echo ""

# Check if implement.sh exists
if [[ ! -f "scripts/implement.sh" ]]; then
    echo -e "${RED}FAIL:${NC} scripts/implement.sh not found"
    exit 1
fi

# Check for incorrect gemini usage in model routing
echo "Checking for hardcoded gemini usage in implement.sh..."

# Look for the specific lines where model routing happens
found_issues=0

# Check line ~213 for sonnet model routing
if grep -n 'if \[\[ "$model_name" == "sonnet" \]\]' scripts/implement.sh | head -1; then
    # Get the next few lines to see what command is called
    line_num=$(grep -n 'if \[\[ "$model_name" == "sonnet" \]\]' scripts/implement.sh | head -1 | cut -d: -f1)
    sed -n "${line_num},$((line_num+5))p" scripts/implement.sh | grep -n "gemini" && {
        echo -e "${RED}FAIL:${NC} Found gemini usage when model is sonnet (should be claude)"
        found_issues=$((found_issues + 1))
    }
fi

# Check line ~219 for opus model routing  
if grep -n 'elif \[\[ "$model_name" == "opus" \]\]' scripts/implement.sh | head -1; then
    # Get the next few lines to see what command is called
    line_num=$(grep -n 'elif \[\[ "$model_name" == "opus" \]\]' scripts/implement.sh | head -1 | cut -d: -f1)
    sed -n "${line_num},$((line_num+5))p" scripts/implement.sh | grep -n "gemini" && {
        echo -e "${RED}FAIL:${NC} Found gemini usage when model is opus (should be claude)"
        found_issues=$((found_issues + 1))
    }
fi

echo ""

# Check current implementation
echo "Current implementation details:"
echo "================================"
echo ""
echo "Model routing for sonnet:"
grep -A3 'if \[\[ "$model_name" == "sonnet" \]\]' scripts/implement.sh | head -4 || true
echo ""
echo "Model routing for opus:"
grep -A3 'elif \[\[ "$model_name" == "opus" \]\]' scripts/implement.sh | head -4 || true
echo ""

# Summary
if [[ $found_issues -gt 0 ]]; then
    echo -e "${RED}Test FAILED${NC}: implement.sh is using gemini instead of claude"
    echo ""
    echo "Expected behavior:"
    echo "  - When model is 'sonnet': should call 'claude' (not gemini)"
    echo "  - When model is 'opus': should call 'claude --model opus' (not gemini)"
    echo ""
    echo "This violates the original specification that requires Claude for implementation"
    echo "due to cost/quota considerations."
    exit 1
else
    echo -e "${GREEN}Test PASSED${NC}: implement.sh correctly uses claude for implementation"
    exit 0
fi