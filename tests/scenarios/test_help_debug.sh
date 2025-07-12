#!/bin/bash
# Debug help generation

set -euo pipefail

# Set project root
PROJECT_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
export PROJECT_ROOT

# Source test harness
source "$(dirname "$0")/../test-command.sh"
source "$(dirname "$0")/../utils/test_setup.sh"

test_help_debug() {
    # Setup
    setup_test_scripts
    
    # Create test commands
    mkdir -p .claude/commands/ai
    
    cat > .claude/commands/test.md <<'EOF'
---
description: Test command
category: testing
---
Test content.
EOF

    echo "Current directory: $(pwd)"
    echo "Commands directory contents:"
    ls -la .claude/commands/
    
    echo -e "\nRunning discover-commands.sh:"
    scripts/discover-commands.sh
    
    echo -e "\nRunning generate-help.sh:"
    scripts/generate-help.sh | head -20
}

# Run test
run_test_scenario "Help debug" test_help_debug