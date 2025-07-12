#!/bin/bash
# Test suite for implement.sh session integration
# Tests USE_SESSIONS environment variable and session continuity

set -euo pipefail

# Source test harness
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$TEST_DIR/test-command.sh"

# Test configuration
IMPLEMENT_SCRIPT="$PROJECT_ROOT/scripts/implement.sh"
WRAPPER_SCRIPT="$PROJECT_ROOT/scripts/ai-command-wrapper.sh"
TEST_SESSION_ROOT=""
TEST_AI_SESSIONS=""

# Mock implementation plan
create_test_plan() {
    local feature_id="$1"
    local task_id="$2"
    
    cat > "$TEST_SESSION_ROOT/$feature_id/implementation-plan.yaml" << EOF
feature_id: $feature_id
title: Test Feature
tasks:
  - task_id: "$task_id"
    status: "pending"
    description: "Test task for session integration"
    agent: "claude"
    test_requirements:
      - Unit tests required
      - Integration tests required
EOF
}

# Create test state file
create_test_state() {
    local feature_id="$1"
    
    cat > "$TEST_SESSION_ROOT/$feature_id/state.yaml" << EOF
feature_id: $feature_id
status: active
active_task: ""
model: ""
EOF
}

# Setup function
setup() {
    # Create test directories
    TEST_TEMP_DIR=$(mktemp -d)
    TEST_SESSION_ROOT="$TEST_TEMP_DIR/.ai-session"
    TEST_AI_SESSIONS="$TEST_TEMP_DIR/.ai-sessions"
    
    export SESSION_ROOT="$TEST_SESSION_ROOT"
    export SESSION_DIR="$TEST_AI_SESSIONS"
    
    mkdir -p "$TEST_AI_SESSIONS"
    mkdir -p "$TEST_SESSION_ROOT"
    
    # Create active features file to avoid warnings
    touch "$TEST_SESSION_ROOT/active-features.txt"
    
    # Create mock claude with session tracking
    cat > "$TEST_TEMP_DIR/claude" << 'EOF'
#!/bin/bash
# Mock claude that tracks session usage

# Initialize session tracking
session_used=false
session_name=""
continue_flag=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help)
            echo "Mock claude help"
            exit 0
            ;;
        --session-name)
            shift
            session_name="$1"
            session_used=true
            shift
            ;;
        -c|--continue)
            continue_flag=true
            shift
            ;;
        -p|--prompt)
            shift
            prompt="$1"
            shift
            ;;
        --print)
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# Output response with session info
if [[ "$session_used" == "true" ]]; then
    echo "MOCK: Using session: $session_name"
fi

if [[ "$continue_flag" == "true" ]]; then
    echo "MOCK: Continuing previous session"
fi

# Provide appropriate response based on prompt
if [[ "$prompt" == *"write tests"* ]]; then
    echo "MOCK: Writing comprehensive tests for the task"
elif [[ "$prompt" == *"implement"* ]]; then
    echo "MOCK: Implementing code to make tests pass"
fi

# Return session ID for tracking
echo "Session-ID: test-session-$(date +%s)"
EOF
    chmod +x "$TEST_TEMP_DIR/claude"
    
    # Create wrapper script that uses mock
    mkdir -p "$TEST_TEMP_DIR/scripts"
    cat > "$TEST_TEMP_DIR/scripts/ai-command-wrapper.sh" << 'EOF'
#!/bin/bash
# Mock wrapper that calls our mock claude
shift 2  # Skip command and timeout
exec claude "$@"
EOF
    chmod +x "$TEST_TEMP_DIR/scripts/ai-command-wrapper.sh"
    
    # Add mock to PATH
    export PATH="$TEST_TEMP_DIR:$PATH"
    export SCRIPT_DIR="$TEST_TEMP_DIR/scripts"
}

# Teardown function
teardown() {
    if [[ -n "${TEST_TEMP_DIR:-}" ]]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
}

# Test implement without sessions (explicitly disabled)
test_implement_without_sessions() {
    setup
    
    # Create test session
    local feature_id="test-feature-no-session"
    mkdir -p "$TEST_SESSION_ROOT/$feature_id"
    create_test_plan "$feature_id" "task-1"
    create_test_state "$feature_id"
    
    # Create mock update-session-state.sh
    cat > "$TEST_TEMP_DIR/scripts/update-session-state.sh" << 'EOF'
#!/bin/bash
exit 0
EOF
    chmod +x "$TEST_TEMP_DIR/scripts/update-session-state.sh"
    
    # Run implement with USE_SESSIONS=false
    USE_SESSIONS=false output=$("$IMPLEMENT_SCRIPT" "$feature_id" --task task-1 --no-tests 2>&1)
    assert_equals "0" "$?" "Implement should succeed without sessions"
    
    # Should NOT use session features
    assert_not_contains "$output" "Using session:" "Should not use sessions when disabled"
    
    teardown
}

# Test implement with sessions enabled
test_implement_with_sessions() {
    setup
    
    # Create test session
    local feature_id="test-feature-with-session"
    mkdir -p "$TEST_SESSION_ROOT/$feature_id"
    create_test_plan "$feature_id" "task-1"
    create_test_state "$feature_id"
    
    # Create mock update-session-state.sh
    cat > "$TEST_TEMP_DIR/scripts/update-session-state.sh" << 'EOF'
#!/bin/bash
exit 0
EOF
    chmod +x "$TEST_TEMP_DIR/scripts/update-session-state.sh"
    
    # Enable sessions
    export USE_SESSIONS=true
    
    # Run implement
    output=$("$IMPLEMENT_SCRIPT" "$feature_id" --task task-1 --no-tests 2>&1)
    assert_equals "0" "$?" "Implement should succeed with sessions"
    
    # Should use session features
    assert_contains "$output" "Using session:" "Should use sessions when enabled"
    assert_contains "$output" "implement-$feature_id" "Should use feature-based session name"
    
    teardown
}

# Test session continuity across multiple tasks
test_session_continuity() {
    setup
    
    # Create test session
    local feature_id="test-continuity"
    mkdir -p "$TEST_SESSION_ROOT/$feature_id"
    create_test_state "$feature_id"
    
    # Create plan with multiple tasks
    cat > "$TEST_SESSION_ROOT/$feature_id/implementation-plan.yaml" << EOF
feature_id: $feature_id
tasks:
  - task_id: "task-1"
    status: "pending"
  - task_id: "task-2"
    status: "pending"
EOF
    
    # Create mock update-session-state.sh
    cat > "$TEST_TEMP_DIR/scripts/update-session-state.sh" << 'EOF'
#!/bin/bash
exit 0
EOF
    chmod +x "$TEST_TEMP_DIR/scripts/update-session-state.sh"
    
    export USE_SESSIONS=true
    
    # Implement first task
    output1=$("$IMPLEMENT_SCRIPT" "$feature_id" --task task-1 --no-tests 2>&1)
    assert_equals "0" "$?" "First task should succeed"
    
    # Implement second task
    output2=$("$IMPLEMENT_SCRIPT" "$feature_id" --task task-2 --no-tests 2>&1)
    assert_equals "0" "$?" "Second task should succeed"
    
    # Both should use the same session
    assert_contains "$output2" "Continuing previous session" "Should continue session for task 2"
    
    teardown
}

# Test session naming convention
test_session_naming() {
    setup
    
    # Create test sessions with different feature IDs
    local features=("auth-service" "user-api" "payment-gateway")
    
    export USE_SESSIONS=true
    
    for feature in "${features[@]}"; do
        mkdir -p "$TEST_SESSION_ROOT/$feature"
        create_test_plan "$feature" "task-1"
        create_test_state "$feature"
        
        # Create mock update-session-state.sh
        cat > "$TEST_TEMP_DIR/scripts/update-session-state.sh" << 'EOF'
#!/bin/bash
exit 0
EOF
        chmod +x "$TEST_TEMP_DIR/scripts/update-session-state.sh"
        
        output=$("$IMPLEMENT_SCRIPT" "$feature" --task task-1 --no-tests 2>&1)
        assert_equals "0" "$?" "Should succeed for $feature"
        
        # Verify session name follows convention
        assert_contains "$output" "implement-$feature" "Session name should be implement-<feature-id>"
    done
    
    teardown
}

# Test ATDD with sessions
test_atdd_with_sessions() {
    setup
    
    local feature_id="test-atdd-session"
    mkdir -p "$TEST_SESSION_ROOT/$feature_id"
    create_test_plan "$feature_id" "task-1"
    create_test_state "$feature_id"
    
    # Create mock update-session-state.sh
    cat > "$TEST_TEMP_DIR/scripts/update-session-state.sh" << 'EOF'
#!/bin/bash
exit 0
EOF
    chmod +x "$TEST_TEMP_DIR/scripts/update-session-state.sh"
    
    export USE_SESSIONS=true
    
    # Run without --no-tests (ATDD mode)
    output=$("$IMPLEMENT_SCRIPT" "$feature_id" --task task-1 2>&1)
    assert_equals "0" "$?" "ATDD should succeed with sessions"
    
    # Should write tests first
    assert_contains "$output" "Writing comprehensive tests" "Should write tests in ATDD mode"
    
    # Should use same session for implementation
    assert_contains "$output" "Implementing code to make tests pass" "Should implement after tests"
    
    teardown
}

# Test TDD cycle with sessions
test_tdd_cycle_with_sessions() {
    setup
    
    local feature_id="test-tdd-session"
    mkdir -p "$TEST_SESSION_ROOT/$feature_id"
    create_test_plan "$feature_id" "task-1"
    create_test_state "$feature_id"
    
    # Create mock update-session-state.sh
    cat > "$TEST_TEMP_DIR/scripts/update-session-state.sh" << 'EOF'
#!/bin/bash
exit 0
EOF
    chmod +x "$TEST_TEMP_DIR/scripts/update-session-state.sh"
    
    export USE_SESSIONS=true
    
    # Enhanced mock claude for TDD
    cat > "$TEST_TEMP_DIR/claude" << 'EOF'
#!/bin/bash
while [[ $# -gt 0 ]]; do
    case "$1" in
        -p|--prompt)
            shift
            prompt="$1"
            ;;
        --session-name)
            shift
            echo "MOCK: Using session: $1"
            ;;
        *)
            shift
            ;;
    esac
done

if [[ "$prompt" == *"write tests"* ]]; then
    echo "MOCK: RED phase - Writing failing tests"
elif [[ "$prompt" == *"implement"* ]]; then
    echo "MOCK: GREEN phase - Making tests pass"
elif [[ "$prompt" == *"refactor"* ]]; then
    echo "MOCK: REFACTOR phase - Improving code"
fi
EOF
    
    # Run with --tdd flag
    output=$("$IMPLEMENT_SCRIPT" "$feature_id" --task task-1 --tdd 2>&1)
    assert_equals "0" "$?" "TDD cycle should succeed"
    
    # Verify all TDD phases
    assert_contains "$output" "RED phase" "Should have RED phase"
    assert_contains "$output" "GREEN phase" "Should have GREEN phase"
    assert_contains "$output" "REFACTOR phase" "Should have REFACTOR phase"
    
    # All phases should use the same session
    local session_count=$(echo "$output" | grep -c "Using session: implement-$feature_id")
    assert_true "[[ $session_count -ge 3 ]]" "Should use same session for all TDD phases"
    
    teardown
}

# Test session metadata tracking
test_session_metadata() {
    setup
    
    local feature_id="test-metadata"
    mkdir -p "$TEST_SESSION_ROOT/$feature_id"
    create_test_plan "$feature_id" "task-1"
    create_test_state "$feature_id"
    
    # Create mock update-session-state.sh
    cat > "$TEST_TEMP_DIR/scripts/update-session-state.sh" << 'EOF'
#!/bin/bash
exit 0
EOF
    chmod +x "$TEST_TEMP_DIR/scripts/update-session-state.sh"
    
    export USE_SESSIONS=true
    
    # Run implement
    "$IMPLEMENT_SCRIPT" "$feature_id" --task task-1 --no-tests >/dev/null 2>&1
    
    # Check if session directory was created
    local session_name="implement-$feature_id"
    assert_true "[[ -d $TEST_AI_SESSIONS/$session_name ]]" "Session directory should be created"
    
    # Check for metadata file (would be created by real ai-command-wrapper.sh)
    # In real implementation, this would contain interaction history
    
    teardown
}

# Test error handling with sessions
test_error_handling_with_sessions() {
    setup
    
    local feature_id="test-error-session"
    mkdir -p "$TEST_SESSION_ROOT/$feature_id"
    create_test_plan "$feature_id" "task-1"
    create_test_state "$feature_id"
    
    # Create failing mock
    cat > "$TEST_TEMP_DIR/claude" << 'EOF'
#!/bin/bash
echo "MOCK: Error occurred" >&2
exit 1
EOF
    chmod +x "$TEST_TEMP_DIR/claude"
    
    # Create mock update-session-state.sh
    cat > "$TEST_TEMP_DIR/scripts/update-session-state.sh" << 'EOF'
#!/bin/bash
exit 0
EOF
    chmod +x "$TEST_TEMP_DIR/scripts/update-session-state.sh"
    
    export USE_SESSIONS=true
    
    # Run implement (should fail)
    output=$("$IMPLEMENT_SCRIPT" "$feature_id" --task task-1 --no-tests 2>&1 || true)
    assert_not_equals "0" "$?" "Should fail when AI command fails"
    
    # Session should still be tracked in history
    assert_true "[[ -f $TEST_SESSION_ROOT/$feature_id/history.jsonl ]]" "History should be updated even on failure"
    
    teardown
}

# Test default behavior (sessions enabled by default)
test_default_sessions_enabled() {
    setup
    
    local feature_id="test-default-sessions"
    mkdir -p "$TEST_SESSION_ROOT/$feature_id"
    create_test_plan "$feature_id" "task-1"
    create_test_state "$feature_id"
    
    # Create mock update-session-state.sh
    cat > "$TEST_TEMP_DIR/scripts/update-session-state.sh" << 'EOF'
#!/bin/bash
exit 0
EOF
    chmod +x "$TEST_TEMP_DIR/scripts/update-session-state.sh"
    
    # Unset USE_SESSIONS to test default
    unset USE_SESSIONS
    
    # Run implement (should use sessions by default)
    output=$("$IMPLEMENT_SCRIPT" "$feature_id" --task task-1 --no-tests 2>&1)
    assert_equals "0" "$?" "Should work with default sessions"
    
    # Should use sessions by default
    assert_contains "$output" "Using session:" "Should use sessions by default"
    assert_contains "$output" "implement-$feature_id" "Should use correct session name"
    
    teardown
}

# Test backward compatibility (explicit disable)
test_backward_compatibility() {
    setup
    
    local feature_id="test-backward-compat"
    mkdir -p "$TEST_SESSION_ROOT/$feature_id"
    create_test_plan "$feature_id" "task-1"
    create_test_state "$feature_id"
    
    # Create mock update-session-state.sh
    cat > "$TEST_TEMP_DIR/scripts/update-session-state.sh" << 'EOF'
#!/bin/bash
exit 0
EOF
    chmod +x "$TEST_TEMP_DIR/scripts/update-session-state.sh"
    
    # Explicitly disable sessions
    USE_SESSIONS=false output=$("$IMPLEMENT_SCRIPT" "$feature_id" --task task-1 --no-tests 2>&1)
    assert_equals "0" "$?" "Should work without sessions"
    
    # Should not use sessions
    assert_not_contains "$output" "Using session" "Should not use sessions when disabled"
    
    teardown
}

# Main test runner
main() {
    local tests=(
        "test_implement_without_sessions"
        "test_implement_with_sessions"
        "test_default_sessions_enabled"
        "test_session_continuity"
        "test_session_naming"
        "test_atdd_with_sessions"
        "test_tdd_cycle_with_sessions"
        "test_session_metadata"
        "test_error_handling_with_sessions"
        "test_backward_compatibility"
    )
    
    local passed=0
    local failed=0
    
    echo "Running implement.sh session integration tests..."
    echo
    
    for test in "${tests[@]}"; do
        echo -n "Running $test... "
        if output=$($test 2>&1); then
            echo -e "${GREEN}PASS${NC}"
            ((passed++))
        else
            echo -e "${RED}FAIL${NC}"
            echo "$output"
            ((failed++))
        fi
    done
    
    echo
    echo "Results: $passed passed, $failed failed"
    
    if [[ $failed -gt 0 ]]; then
        return 1
    fi
    
    return 0
}

# Run tests if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi