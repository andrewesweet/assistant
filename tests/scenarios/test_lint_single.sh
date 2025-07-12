#!/bin/bash
# Test single linting scenario for debugging

set -euo pipefail

# Set project root
PROJECT_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
export PROJECT_ROOT

# Source test harness
source "$(dirname "$0")/../test-command.sh"
source "$(dirname "$0")/../utils/test_setup.sh"

test_lint_debug() {
    # Setup
    setup_test_scripts
    
    # Create valid command
    cat > .claude/commands/valid-test.md <<'EOF'
---
description: Valid test command
category: testing
---

# Valid Command

This is a valid command.
EOF

    echo "Created file:"
    cat .claude/commands/valid-test.md
    
    echo -e "\nRunning linter:"
    scripts/lint-prompts-minimal.sh .claude/commands/valid-test.md 2>&1 || echo "Exit code: $?"
}

# Run test
run_test_scenario "Lint debug" test_lint_debug