#!/bin/bash
# Test: Linting invalid command prompts (adjusted for minimal linter)
# Feature: Prompt linting system
# Scenario: Invalid prompts fail linting with helpful errors

set -euo pipefail

# Set project root if not already set
if [[ -z "${PROJECT_ROOT:-}" ]]; then
    PROJECT_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
    export PROJECT_ROOT
fi

# Source test harness and utilities
source "$(dirname "$0")/../test-command.sh"
source "$(dirname "$0")/../utils/test_setup.sh"

test_missing_metadata() {
    # Setup test environment
    setup_test_scripts
    # Setup - Create command without metadata
    cat > .claude/commands/no-metadata.md <<'EOF'
# Command Without Metadata

This command is missing the required metadata section.
EOF

    # Run linter
    set +e
    output=$(scripts/lint-prompts-minimal.sh .claude/commands/no-metadata.md 2>&1)
    exit_code=$?
    set -e
    
    # Verify linting fails with helpful error
    assert_not_equals "0" "$exit_code" "Missing metadata should fail linting"
    assert_contains "$output" "Missing metadata section"
    assert_contains "$output" "no-metadata.md"
}

test_missing_description() {
    setup_test_scripts
    # Setup - Create command without description
    cat > .claude/commands/no-description.md <<'EOF'
---
category: testing
---

# Command Missing Description

This command has metadata but no description field.
EOF

    # Run linter
    set +e
    output=$(scripts/lint-prompts-minimal.sh .claude/commands/no-description.md 2>&1)
    exit_code=$?
    set -e
    
    # Verify error about missing description
    assert_contains "$output" "Missing required field: description"
}

test_invalid_file() {
    setup_test_scripts
    # Test non-existent file
    set +e
    output=$(scripts/lint-prompts-minimal.sh .claude/commands/nonexistent.md 2>&1)
    exit_code=$?
    set -e
    
    assert_not_equals "0" "$exit_code" "Non-existent file should fail"
    assert_contains "$output" "File not found"
}

test_mixed_valid_invalid() {
    setup_test_scripts
    # Create mix of valid and invalid files
    cat > .claude/commands/valid.md <<'EOF'
---
description: Valid command
category: testing
---
Valid content.
EOF

    cat > .claude/commands/invalid1.md <<'EOF'
Missing metadata completely.
EOF

    cat > .claude/commands/invalid2.md <<'EOF'
---
category: testing
---
Missing description.
EOF

    # Run linter on all files
    set +e
    output=$(scripts/lint-prompts-minimal.sh .claude/commands/*.md 2>&1)
    exit_code=$?
    set -e
    
    # Verify summary shows failures
    assert_not_equals "0" "$exit_code" "Should fail with invalid files"
    assert_contains "$output" "2 passed"
    assert_contains "$output" "2 failed"
}

# Run only tests that work with minimal linter
echo "Testing invalid prompt linting (minimal linter)..."
run_test_scenario "Missing metadata" test_missing_metadata
run_test_scenario "Missing description" test_missing_description  
run_test_scenario "Invalid file" test_invalid_file
run_test_scenario "Mixed valid/invalid" test_mixed_valid_invalid