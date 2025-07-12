#!/bin/bash
# Test: Command structure validation
# Feature: Command system
# Scenario: Command file structure and metadata

set -euo pipefail

# Set project root if not already set
if [[ -z "${PROJECT_ROOT:-}" ]]; then
    PROJECT_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
    export PROJECT_ROOT
fi

# Source test harness and utilities
source "$(dirname "$0")/../test-command.sh"
source "$(dirname "$0")/../utils/test_setup.sh"

test_command_requires_metadata() {
    # Setup test environment
    setup_test_scripts
    # Setup - Create command without metadata
    cat > .claude/commands/invalid.md <<'EOF'
This command has no metadata section.
EOF

    # Validate command structure
    set +e
    output=$(scripts/validate-simple.sh .claude/commands/invalid.md 2>&1)
    exit_code=$?
    set -e
    
    # Verify validation fails
    assert_not_equals "0" "$exit_code" "Validation should fail for missing metadata"
    assert_contains "$output" "Missing metadata"
}

test_command_metadata_validation() {
    # Setup test environment
    setup_test_scripts
    # Setup - Create command with incomplete metadata
    cat > .claude/commands/incomplete.md <<'EOF'
---
description: Missing category
---

Command content here.
EOF

    # Validate command structure
    output=$(scripts/validate-simple.sh .claude/commands/incomplete.md 2>&1 || true)
    
    # Verify warning about missing category
    assert_contains "$output" "Warning: Missing category"
}

test_command_valid_structure() {
    # Setup test environment
    setup_test_scripts
    # Setup - Create properly structured command
    cat > .claude/commands/valid.md <<'EOF'
---
description: Valid test command
category: testing
model_preference: gemini
requires_context: true
---

# Valid Command

This is a properly structured command.

## Arguments

- `feature_name` - Name of the feature to implement

## Usage

This command does something useful.
EOF

    # Validate command structure
    output=$(scripts/validate-simple.sh .claude/commands/valid.md 2>&1)
    exit_code=$?
    
    # Verify validation passes
    assert_equals "0" "$exit_code" "Validation should pass for valid command"
    assert_contains "$output" "Valid"
}

test_command_path_resolution() {
    # Setup test environment
    setup_test_scripts
    # Setup - Create commands at different depths
    mkdir -p .claude/commands/ai/advanced
    
    cat > .claude/commands/simple.md <<'EOF'
---
description: Simple command
---
EOF

    cat > .claude/commands/ai/nested.md <<'EOF'
---
description: Nested command
---
EOF

    cat > .claude/commands/ai/advanced/deep.md <<'EOF'
---
description: Deep command
---
EOF

    # Test path resolution
    simple_path=$(scripts/resolve-command-path.sh "/simple")
    nested_path=$(scripts/resolve-command-path.sh "/ai/nested")
    deep_path=$(scripts/resolve-command-path.sh "/ai/advanced/deep")
    
    # Verify paths resolve correctly
    assert_equals ".claude/commands/simple.md" "$simple_path"
    assert_equals ".claude/commands/ai/nested.md" "$nested_path"
    assert_equals ".claude/commands/ai/advanced/deep.md" "$deep_path"
}

test_command_discovery() {
    # Setup test environment
    setup_test_scripts
    # Setup - Create various command files
    mkdir -p .claude/commands/{planning,development,review}
    
    # Create commands
    echo -e "---\ndescription: Plan\n---" > .claude/commands/planning/plan.md
    echo -e "---\ndescription: Implement\n---" > .claude/commands/development/implement.md
    echo -e "---\ndescription: Review\n---" > .claude/commands/review/code.md
    
    # Create non-command files
    echo "# README" > .claude/commands/README.md
    touch .claude/commands/.gitkeep
    
    # Discover commands
    commands=$(scripts/discover-commands.sh)
    
    # Verify only valid commands are discovered
    assert_contains "$commands" "planning/plan"
    assert_contains "$commands" "development/implement"
    assert_contains "$commands" "review/code"
    assert_not_contains "$commands" "README"
    assert_not_contains "$commands" ".gitkeep"
}

test_command_template_expansion() {
    # Setup test environment
    setup_test_scripts
    # Setup - Create command with template variables
    cat > .claude/commands/template.md <<'EOF'
---
description: Template command
variables:
  - CURRENT_DATE
  - USER
  - ARGUMENTS
---

# Command for {{USER}}

Date: {{CURRENT_DATE}}
Arguments: {{ARGUMENTS}}
EOF

    # Expand template
    export USER="test-user"
    export ARGUMENTS="test args"
    expanded=$(scripts/expand-command-template.sh .claude/commands/template.md)
    
    # Verify template expansion
    assert_contains "$expanded" "Command for test-user"
    assert_contains "$expanded" "Arguments: test args"
    assert_contains "$expanded" "Date: $(date +%Y-%m-%d)"
}

# Run all tests
echo "Testing command structure..."
run_test_scenario "Command requires metadata" test_command_requires_metadata
run_test_scenario "Command metadata validation" test_command_metadata_validation
run_test_scenario "Command valid structure" test_command_valid_structure
run_test_scenario "Command path resolution" test_command_path_resolution
run_test_scenario "Command discovery" test_command_discovery
run_test_scenario "Command template expansion" test_command_template_expansion