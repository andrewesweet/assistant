#!/bin/bash
# Test: Help command lists all available commands
# Feature: Help system
# Scenario: Basic help functionality

set -euo pipefail

# Set project root if not already set
if [[ -z "${PROJECT_ROOT:-}" ]]; then
    PROJECT_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
    export PROJECT_ROOT
fi

# Source test harness and utilities
source "$(dirname "$0")/../test-command.sh"
source "$(dirname "$0")/../utils/test_setup.sh"

test_help_lists_commands() {
    # Setup test environment
    setup_test_scripts
    # Setup - Create test commands
    mkdir -p .claude/commands/ai
    
    cat > .claude/commands/test.md <<'EOF'
---
description: Test command
category: testing
---

This is a test command.
EOF

    cat > .claude/commands/ai/test.md <<'EOF'
---
description: AI test command
category: ai
---

This is an AI test command.
EOF

    cat > .claude/commands/plan.md <<'EOF'
---
description: Create implementation plan
category: planning
---

Creates an implementation plan using Gemini.
EOF

    # Execute help command
    output=$(scripts/generate-help-simple.sh)
    
    # Verify output contains all commands
    assert_contains "$output" "/test - Test command"
    assert_contains "$output" "/ai/test - AI test command" 
    assert_contains "$output" "/plan - Create implementation plan"
    
    # Verify commands are sorted (they should appear in alphabetical order)
    # Extract just the command lines
    command_lines=$(echo "$output" | grep "^/" || true)
    sorted_lines=$(echo "$command_lines" | sort)
    assert_equals "$sorted_lines" "$command_lines" "Commands should be sorted alphabetically"
}

test_help_handles_nested_directories() {
    # Setup test environment
    setup_test_scripts
    # Setup - Create nested command structure
    mkdir -p .claude/commands/ai/advanced
    mkdir -p .claude/commands/review
    
    cat > .claude/commands/ai/advanced/escalate.md <<'EOF'
---
description: Escalate to higher model
category: ai
---
EOF

    cat > .claude/commands/review/code.md <<'EOF'
---
description: Review code changes
category: review
---
EOF

    # Execute help command
    output=$(scripts/generate-help-simple.sh)
    
    # Verify nested commands are discovered
    assert_contains "$output" "/ai/advanced/escalate"
    assert_contains "$output" "/review/code"
}

test_help_ignores_invalid_files() {
    # Setup test environment
    setup_test_scripts
    # Setup - Create invalid files
    touch .claude/commands/README.md
    touch .claude/commands/.hidden
    echo "invalid yaml" > .claude/commands/broken.md
    
    cat > .claude/commands/valid.md <<'EOF'
---
description: Valid command
---
EOF

    # Execute help generation
    output=$(scripts/generate-help-simple.sh 2>/dev/null)
    
    # Verify only valid commands are included
    assert_contains "$output" "/valid - Valid command"
    assert_not_contains "$output" "README"
    assert_not_contains "$output" ".hidden"
    assert_not_contains "$output" "broken"
}

test_help_shows_categories() {
    # Setup test environment
    setup_test_scripts
    # Setup - Create commands in different categories
    cat > .claude/commands/plan.md <<'EOF'
---
description: Create plan
category: planning
---
EOF

    cat > .claude/commands/implement.md <<'EOF'
---
description: Implement feature
category: development
---
EOF

    cat > .claude/commands/review-code.md <<'EOF'
---
description: Review code
category: review
---
EOF

    # Execute help generation with categories  
    output=$(scripts/generate-help-simple.sh --with-categories)
    
    # Verify categories are shown
    assert_contains "$output" "Planning:"
    assert_contains "$output" "Development:"
    assert_contains "$output" "Review:"
}

# Run all tests
echo "Testing help command functionality..."
run_test_scenario "Help lists commands" test_help_lists_commands
run_test_scenario "Help handles nested directories" test_help_handles_nested_directories
run_test_scenario "Help ignores invalid files" test_help_ignores_invalid_files
run_test_scenario "Help shows categories" test_help_shows_categories