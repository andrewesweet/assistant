#!/bin/bash
# Test: Linting valid command prompts
# Feature: Prompt linting system
# Scenario: Valid prompts pass linting

set -euo pipefail

# Set project root if not already set
if [[ -z "${PROJECT_ROOT:-}" ]]; then
    PROJECT_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
    export PROJECT_ROOT
fi

# Source test harness and utilities
source "$(dirname "$0")/../test-command.sh"
source "$(dirname "$0")/../utils/test_setup.sh"

test_valid_prompt_structure() {
    # Setup test environment
    setup_test_scripts
    # Setup - Create valid command prompt
    cat > .claude/commands/valid-test.md <<'EOF'
---
description: Valid test command
category: testing
---

# Valid Command

You are an AI assistant helping with software development.

## Task

Implement the following feature: {{ARGUMENTS}}

## Requirements

1. Follow TDD principles
2. Write comprehensive tests
3. Use existing patterns

## Context

- Current directory: {{PWD}}
- User: {{USER}}
- Date: {{CURRENT_DATE}}
EOF

    # Run linter
    output=$(scripts/lint-prompts-minimal.sh .claude/commands/valid-test.md 2>&1)
    exit_code=$?
    
    # Verify linting passes
    assert_equals "0" "$exit_code" "Valid prompt should pass linting"
    assert_contains "$output" "PASS"
}

test_valid_metadata_fields() {
    # Setup test environment
    setup_test_scripts
    # Setup - Create command with all valid metadata fields
    cat > .claude/commands/full-metadata.md <<'EOF'
---
description: Command with full metadata
category: development
model_preference: gemini
requires_context: true
timeout_seconds: 300
max_retries: 3
---

# Full Metadata Command

This command has all valid metadata fields.
EOF

    # Run linter
    output=$(scripts/lint-prompts-minimal.sh .claude/commands/full-metadata.md 2>&1)
    exit_code=$?
    
    # Verify all metadata fields are accepted
    assert_equals "0" "$exit_code" "All valid metadata fields should be accepted"
    assert_not_contains "$output" "unknown field"
}

test_valid_template_variables() {
    # Setup test environment
    setup_test_scripts
    # Setup - Create command with standard template variables
    cat > .claude/commands/templates.md <<'EOF'
---
description: Template variable test
---

# Template Test

Standard variables:
- User: {{USER}}
- Arguments: {{ARGUMENTS}}
- Date: {{CURRENT_DATE}}
- Working Directory: {{PWD}}
- Feature ID: {{FEATURE_ID}}
- Session Path: {{SESSION_PATH}}
EOF

    # Run linter
    output=$(scripts/lint-prompts-minimal.sh .claude/commands/templates.md 2>&1)
    exit_code=$?
    
    # Verify standard template variables are recognized
    assert_equals "0" "$exit_code" "Standard template variables should be valid"
    assert_not_contains "$output" "undefined variable"
}

test_valid_command_categories() {
    # Setup test environment
    setup_test_scripts
    # Setup - Test all valid categories
    valid_categories=("planning" "development" "review" "testing" "ai" "utility")
    
    for category in "${valid_categories[@]}"; do
        cat > ".claude/commands/cat-$category.md" <<EOF
---
description: Test $category category
category: $category
---

Testing $category category.
EOF
        
        # Run linter
        output=$(scripts/lint-prompts-minimal.sh ".claude/commands/cat-$category.md" 2>&1)
        exit_code=$?
        
        # Verify category is valid
        assert_equals "0" "$exit_code" "Category '$category' should be valid"
    done
}

test_valid_markdown_formatting() {
    # Setup test environment
    setup_test_scripts
    # Setup - Create command with various markdown elements
    cat > .claude/commands/markdown.md <<'EOF'
---
description: Markdown formatting test
---

# Main Heading

## Subheading

Regular paragraph with **bold** and *italic* text.

### Lists

- Bullet point 1
- Bullet point 2
  - Nested point

1. Numbered item
2. Another item

### Code

Inline `code` and blocks:

```bash
#!/bin/bash
echo "Hello, world!"
```

```python
def hello():
    print("Hello from Python")
```

### Links and References

[Link text](https://example.com)

> Blockquote text

---

Horizontal rule above.
EOF

    # Run linter
    output=$(scripts/lint-prompts-minimal.sh .claude/commands/markdown.md 2>&1)
    exit_code=$?
    
    # Verify markdown formatting is valid
    assert_equals "0" "$exit_code" "Valid markdown should pass linting"
}

test_lint_multiple_valid_files() {
    # Setup test environment
    setup_test_scripts
    # Setup - Create multiple valid files
    for i in 1 2 3; do
        cat > ".claude/commands/valid$i.md" <<EOF
---
description: Valid command $i
category: testing
---

This is valid command number $i.
EOF
    done
    
    # Run linter on multiple files
    output=$(scripts/lint-prompts-minimal.sh .claude/commands/valid*.md 2>&1)
    exit_code=$?
    
    # Verify all files pass
    assert_equals "0" "$exit_code" "All valid files should pass"
    assert_contains "$output" "3 passed"
}

# Run all tests
echo "Testing valid prompt linting..."
run_test_scenario "Valid prompt structure" test_valid_prompt_structure
run_test_scenario "Valid metadata fields" test_valid_metadata_fields
run_test_scenario "Valid template variables" test_valid_template_variables
run_test_scenario "Valid command categories" test_valid_command_categories
run_test_scenario "Valid markdown formatting" test_valid_markdown_formatting
run_test_scenario "Lint multiple valid files" test_lint_multiple_valid_files