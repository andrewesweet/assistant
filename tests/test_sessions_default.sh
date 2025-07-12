#!/bin/bash
# Simple test to verify USE_SESSIONS default behavior

set -euo pipefail

# Test configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMPLEMENT_SCRIPT="$PROJECT_ROOT/scripts/implement.sh"
PLAN_SCRIPT="$PROJECT_ROOT/scripts/plan.sh"

echo "Testing USE_SESSIONS default behavior..."

# Test implement.sh default
echo -n "Checking implement.sh default... "
default_value=$(grep "USE_SESSIONS=" "$IMPLEMENT_SCRIPT" | grep -v export | grep ':-' | sed 's/.*:-//' | sed 's/}.*//')
if [[ "$default_value" == "true" ]]; then
    echo "PASS (default is true)"
else
    echo "FAIL (default is '$default_value', expected 'true')"
    exit 1
fi

# Test plan.sh default
echo -n "Checking plan.sh default... "
default_value=$(grep "USE_SESSIONS=" "$PLAN_SCRIPT" | grep -v export | grep ':-' | sed 's/.*:-//' | sed 's/}.*//')
if [[ "$default_value" == "true" ]]; then
    echo "PASS (default is true)"
else
    echo "FAIL (default is '$default_value', expected 'true')"
    exit 1
fi

echo
echo "All tests passed! Sessions are enabled by default."