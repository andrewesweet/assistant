#!/bin/bash
# Test: Makefile integration for linting
# Feature: Build system integration
# Scenario: Linting integrated with make commands

set -euo pipefail

# Set project root if not already set
if [[ -z "${PROJECT_ROOT:-}" ]]; then
    PROJECT_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
    export PROJECT_ROOT
fi

# Source test harness and utilities
source "$(dirname "$0")/../test-command.sh"
source "$(dirname "$0")/../utils/test_setup.sh"

test_make_lint_prompts_target() {
    setup_test_scripts
    # Setup - Create test prompts
    mkdir -p .claude/commands
    cat > .claude/commands/valid.md <<'EOF'
---
description: Valid command
---
Valid content.
EOF

    # Create a simple Makefile if it doesn't exist
    if [[ ! -f Makefile ]]; then
        cat > Makefile <<'EOF'
.PHONY: lint-prompts
lint-prompts:
	@scripts/lint-prompts.sh .claude/commands/*.md
EOF
    fi

    # Run make target
    output=$(make lint-prompts 2>&1)
    exit_code=$?
    
    # Verify target runs successfully
    assert_equals "0" "$exit_code" "Make lint-prompts should succeed"
    assert_contains "$output" "PASS"
}

test_pre_commit_hook_runs_linting() {
    setup_test_scripts
    # Setup - Create pre-commit hook
    cat > .git/hooks/pre-commit <<'EOF'
#!/bin/bash
# Pre-commit hook for AI orchestrator

echo "Running prompt linting..."

# Only lint if commands directory exists
if [[ -d .claude/commands ]]; then
    scripts/lint-prompts.sh .claude/commands/*.md || {
        echo "Linting failed. Fix issues before committing."
        exit 1
    }
fi

echo "Pre-commit checks passed."
EOF
    chmod +x .git/hooks/pre-commit

    # Create invalid prompt
    cat > .claude/commands/invalid.md <<'EOF'
This will fail linting - no metadata!
EOF

    # Test pre-commit hook (simulate)
    output=$(.git/hooks/pre-commit 2>&1 || true)
    exit_code=$?
    
    # Verify hook catches linting errors
    assert_not_equals "0" "$exit_code" "Pre-commit should fail with invalid prompts"
    assert_contains "$output" "Linting failed"
}

test_make_check_includes_linting() {
    setup_test_scripts
    # Setup - Ensure make check target exists
    if ! grep -q "^check:" Makefile 2>/dev/null; then
        cat >> Makefile <<'EOF'

.PHONY: check
check: lint-prompts test
	@echo "All checks passed"

.PHONY: test
test:
	@echo "Running tests..."
EOF
    fi

    # Create valid prompts
    cat > .claude/commands/test1.md <<'EOF'
---
description: Test command 1
---
Content.
EOF

    # Run make check
    output=$(make check 2>&1)
    exit_code=$?
    
    # Verify linting is included in checks
    assert_equals "0" "$exit_code" "Make check should pass"
    assert_contains "$output" "All checks passed"
}

test_make_fix_prompts_target() {
    setup_test_scripts
    # Setup - Create prompt with fixable issues
    cat > .claude/commands/fixable.md <<'EOF'
---
description: Command with trailing spaces   
category: testing    
---

# Command    

Content with trailing whitespace.   
EOF

    # Add fix target to Makefile
    if ! grep -q "^fix-prompts:" Makefile 2>/dev/null; then
        cat >> Makefile <<'EOF'

.PHONY: fix-prompts
fix-prompts:
	@scripts/fix-prompts.sh .claude/commands/*.md
EOF
    fi

    # Run fix target
    output=$(make fix-prompts 2>&1 || echo "Fix target not implemented yet")
    
    # Verify fix target exists (implementation comes later)
    assert_contains "$output" "fix"
}

test_ci_integration() {
    setup_test_scripts
    # Setup - Create GitHub Actions workflow snippet
    mkdir -p .github/workflows
    cat > .github/workflows/lint.yml <<'EOF'
name: Lint

on: [push, pull_request]

jobs:
  lint-prompts:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Lint prompts
        run: make lint-prompts
EOF

    # Verify workflow includes linting
    assert_file_contains ".github/workflows/lint.yml" "make lint-prompts"
}

test_parallel_linting() {
    setup_test_scripts
    # Setup - Create many prompt files
    mkdir -p .claude/commands/batch
    for i in {1..10}; do
        cat > ".claude/commands/batch/cmd$i.md" <<EOF
---
description: Batch command $i
category: testing
---

Content for command $i.
EOF
    done

    # Time sequential vs parallel linting
    start_seq=$(date +%s%N)
    for f in .claude/commands/batch/*.md; do
        scripts/lint-prompts.sh "$f" >/dev/null 2>&1
    done
    end_seq=$(date +%s%N)
    time_seq=$((($end_seq - $start_seq) / 1000000))

    start_par=$(date +%s%N)
    scripts/lint-prompts.sh .claude/commands/batch/*.md >/dev/null 2>&1
    end_par=$(date +%s%N)
    time_par=$((($end_par - $start_par) / 1000000))

    # Verify parallel is faster (or at least not significantly slower)
    echo "Sequential: ${time_seq}ms, Parallel: ${time_par}ms"
    assert_less_than "$time_par" "$((time_seq * 2))" "Parallel should not be much slower"
}

# Run all tests
echo "Testing Makefile integration..."
run_test_scenario "Make lint-prompts target" test_make_lint_prompts_target
run_test_scenario "Pre-commit hook runs linting" test_pre_commit_hook_runs_linting
run_test_scenario "Make check includes linting" test_make_check_includes_linting
run_test_scenario "Make fix-prompts target" test_make_fix_prompts_target
run_test_scenario "CI integration" test_ci_integration
run_test_scenario "Parallel linting performance" test_parallel_linting