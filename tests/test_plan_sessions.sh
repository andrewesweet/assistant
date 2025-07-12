#!/bin/bash
# Test suite for plan.sh session integration
# Tests USE_SESSIONS environment variable and multi-phase planning support

set -euo pipefail

# Source test harness
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$TEST_DIR/test-command.sh"

# Test configuration
PLAN_SCRIPT="$PROJECT_ROOT/scripts/plan.sh"
TEST_SESSION_ROOT=""
TEST_AI_SESSIONS=""

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
    
    # Create mock gemini with session tracking
    cat > "$TEST_TEMP_DIR/gemini" << 'EOF'
#!/bin/bash
# Mock gemini that tracks session usage

session_used=false
session_name=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --session-name)
            shift
            session_name="$1"
            session_used=true
            shift
            ;;
        -p|--prompt)
            shift
            prompt="$1"
            shift
            ;;
        -a)
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

# Generate mock plan
cat << JSON
{
  "phases": [
    {
      "phase_id": "phase1",
      "name": "Setup",
      "tasks": [
        {
          "task_id": "task1",
          "description": "Initial setup",
          "agent": "claude",
          "status": "pending"
        }
      ]
    }
  ]
}
JSON
EOF
    chmod +x "$TEST_TEMP_DIR/gemini"
    
    # Create mock claude
    cat > "$TEST_TEMP_DIR/claude" << 'EOF'
#!/bin/bash
while [[ $# -gt 0 ]]; do
    case "$1" in
        --session-name)
            shift
            echo "MOCK: Opus using session: $1"
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# Generate Opus plan
echo '{"phases": [{"phase_id": "opus_phase", "name": "Opus Plan", "tasks": [{"task_id": "opus_task", "description": "Opus task", "agent": "opus", "status": "pending"}]}]}'
EOF
    chmod +x "$TEST_TEMP_DIR/claude"
    
    # Create wrapper mock
    mkdir -p "$TEST_TEMP_DIR/scripts"
    cat > "$TEST_TEMP_DIR/scripts/ai-command-wrapper.sh" << 'EOF'
#!/bin/bash
command="$1"
timeout="$2"
shift 2
exec "$command" "$@"
EOF
    chmod +x "$TEST_TEMP_DIR/scripts/ai-command-wrapper.sh"
    
    # Create update-session-state mock
    cat > "$TEST_TEMP_DIR/scripts/update-session-state.sh" << 'EOF'
#!/bin/bash
exit 0
EOF
    chmod +x "$TEST_TEMP_DIR/scripts/update-session-state.sh"
    
    # Add mocks to PATH
    export PATH="$TEST_TEMP_DIR:$PATH"
    export SCRIPT_DIR="$TEST_TEMP_DIR/scripts"
}

# Teardown function
teardown() {
    if [[ -n "${TEST_TEMP_DIR:-}" ]]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
}

# Create test session
create_test_session() {
    local feature_id="$1"
    mkdir -p "$TEST_SESSION_ROOT/$feature_id"
    
    # Create state file
    cat > "$TEST_SESSION_ROOT/$feature_id/state.yaml" << EOF
feature_id: $feature_id
status: active
active_task: ""
model: ""
EOF
}

# Test plan without sessions (explicitly disabled)
test_plan_without_sessions() {
    setup
    
    local feature_id="test-plan-no-session"
    create_test_session "$feature_id"
    
    # Run plan with USE_SESSIONS=false
    USE_SESSIONS=false output=$("$PLAN_SCRIPT" "$feature_id" "Create a test plan" 2>&1)
    assert_equals "0" "$?" "Plan should succeed without sessions"
    
    # Should NOT use session features
    assert_not_contains "$output" "Using session:" "Should not use sessions when disabled"
    
    # Should create plan file
    assert_true "[[ -f $TEST_SESSION_ROOT/$feature_id/implementation-plan.yaml ]]" "Plan file should be created"
    
    teardown
}

# Test default behavior (sessions enabled by default)
test_plan_default_sessions_enabled() {
    setup
    
    local feature_id="test-plan-default"
    create_test_session "$feature_id"
    
    # Unset USE_SESSIONS to test default
    unset USE_SESSIONS
    
    # Run plan (should use sessions by default)
    output=$("$PLAN_SCRIPT" "$feature_id" "Create a test plan with default" 2>&1)
    assert_equals "0" "$?" "Plan should succeed with default sessions"
    
    # Should use session features by default
    assert_contains "$output" "Using session:" "Should use sessions by default"
    assert_contains "$output" "plan-$feature_id" "Should use correct session name"
    
    teardown
}

# Test plan with sessions enabled
test_plan_with_sessions() {
    setup
    
    local feature_id="test-plan-with-session"
    create_test_session "$feature_id"
    
    # Enable sessions
    export USE_SESSIONS=true
    
    # Run plan
    output=$("$PLAN_SCRIPT" "$feature_id" "Create a test plan with sessions" 2>&1)
    assert_equals "0" "$?" "Plan should succeed with sessions"
    
    # Should use session features
    assert_contains "$output" "Using session:" "Should use sessions when enabled"
    assert_contains "$output" "plan-$feature_id" "Should use plan-<feature-id> session name"
    
    teardown
}

# Test multi-phase planning with sessions
test_multi_phase_planning() {
    setup
    
    local feature_id="test-multi-phase"
    create_test_session "$feature_id"
    
    export USE_SESSIONS=true
    
    # First planning phase
    output1=$("$PLAN_SCRIPT" "$feature_id" "Create initial plan" 2>&1)
    assert_equals "0" "$?" "First plan should succeed"
    
    # Second planning phase (refinement)
    output2=$("$PLAN_SCRIPT" "$feature_id" "Refine the plan with more details" 2>&1)
    assert_equals "0" "$?" "Second plan should succeed"
    
    # Should maintain session context
    assert_contains "$output1" "plan-$feature_id" "First phase should use session"
    assert_contains "$output2" "plan-$feature_id" "Second phase should use same session"
    
    teardown
}

# Test session naming convention
test_plan_session_naming() {
    setup
    
    export USE_SESSIONS=true
    
    # Test various feature IDs
    local features=("auth-service" "user-api-v2" "payment_gateway")
    
    for feature in "${features[@]}"; do
        create_test_session "$feature"
        
        output=$("$PLAN_SCRIPT" "$feature" "Create plan" 2>&1)
        assert_equals "0" "$?" "Plan should succeed for $feature"
        
        # Verify session name convention
        assert_contains "$output" "plan-$feature" "Session should be plan-<feature-id>"
    done
    
    teardown
}

# Test Opus fallback with sessions
test_opus_fallback_with_sessions() {
    setup
    
    local feature_id="test-opus-fallback"
    create_test_session "$feature_id"
    
    export USE_SESSIONS=true
    
    # Make gemini fail
    cat > "$TEST_TEMP_DIR/gemini" << 'EOF'
#!/bin/bash
echo "MOCK: Gemini error" >&2
exit 1
EOF
    chmod +x "$TEST_TEMP_DIR/gemini"
    
    # Run plan (should fallback to Opus)
    output=$("$PLAN_SCRIPT" "$feature_id" "Create plan with fallback" 2>&1)
    assert_equals "0" "$?" "Plan should succeed with Opus fallback"
    
    # Should use Opus with session
    assert_contains "$output" "Opus using session:" "Opus should use sessions"
    assert_contains "$output" "plan-$feature_id" "Opus should use same session name"
    
    teardown
}

# Test full context flag with sessions
test_full_context_with_sessions() {
    setup
    
    local feature_id="test-full-context"
    create_test_session "$feature_id"
    
    export USE_SESSIONS=true
    
    # Enhanced mock to track full context
    cat > "$TEST_TEMP_DIR/gemini" << 'EOF'
#!/bin/bash
full_context=false
session_used=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -a)
            full_context=true
            shift
            ;;
        --session-name)
            shift
            session_used=true
            echo "MOCK: Session $1 with full context: $full_context"
            shift
            ;;
        *)
            shift
            ;;
    esac
done

echo '{"phases": [{"phase_id": "p1", "name": "Test", "tasks": []}]}'
EOF
    chmod +x "$TEST_TEMP_DIR/gemini"
    
    # Run with full context
    output=$("$PLAN_SCRIPT" "$feature_id" --full-context "Create comprehensive plan" 2>&1)
    assert_equals "0" "$?" "Plan with full context should succeed"
    
    # Should show both session and context
    assert_contains "$output" "full context: true" "Should use full context with session"
    
    teardown
}

# Test session continuity in planning
test_planning_session_continuity() {
    setup
    
    local feature_id="test-continuity"
    create_test_session "$feature_id"
    
    export USE_SESSIONS=true
    
    # Create initial plan
    "$PLAN_SCRIPT" "$feature_id" "Initial architecture plan" >/dev/null 2>&1
    
    # Update task status to simulate progress
    echo 'active_task: "task1"' >> "$TEST_SESSION_ROOT/$feature_id/state.yaml"
    
    # Refine plan with context awareness
    output=$("$PLAN_SCRIPT" "$feature_id" "Add implementation details for current task" 2>&1)
    assert_equals "0" "$?" "Plan refinement should succeed"
    
    # Should maintain session throughout
    assert_contains "$output" "plan-$feature_id" "Should continue using same session"
    
    teardown
}

# Test history logging with sessions
test_plan_history_with_sessions() {
    setup
    
    local feature_id="test-history"
    create_test_session "$feature_id"
    
    export USE_SESSIONS=true
    
    # Run plan
    "$PLAN_SCRIPT" "$feature_id" "Create plan with history tracking" >/dev/null 2>&1
    
    # Check history file
    local history_file="$TEST_SESSION_ROOT/$feature_id/history.jsonl"
    assert_true "[[ -f $history_file ]]" "History file should exist"
    
    # Verify session info in history
    if command -v jq >/dev/null 2>&1; then
        local has_session=$(grep '"session_enabled":true' "$history_file" || echo "")
        assert_not_empty "$has_session" "History should track session usage"
        
        local session_name=$(jq -r '.session_name // empty' "$history_file" 2>/dev/null | head -1)
        assert_equals "plan-$feature_id" "$session_name" "History should record session name"
    fi
    
    teardown
}

# Test backward compatibility
test_plan_backward_compatibility() {
    setup
    
    local feature_id="test-backward-compat"
    create_test_session "$feature_id"
    
    # Explicitly disable sessions
    USE_SESSIONS=false output=$("$PLAN_SCRIPT" "$feature_id" "Create plan without sessions" 2>&1)
    assert_equals "0" "$?" "Plan should work without sessions"
    
    # Should not mention sessions
    assert_not_contains "$output" "Session" "Should not mention sessions when disabled"
    
    # Should still create plan
    assert_true "[[ -f $TEST_SESSION_ROOT/$feature_id/implementation-plan.yaml ]]" "Plan should be created"
    
    teardown
}

# Test error handling with sessions
test_plan_error_with_sessions() {
    setup
    
    local feature_id="test-error"
    create_test_session "$feature_id"
    
    export USE_SESSIONS=true
    
    # Make both models fail
    cat > "$TEST_TEMP_DIR/gemini" << 'EOF'
#!/bin/bash
echo "MOCK: Gemini error" >&2
exit 1
EOF
    
    cat > "$TEST_TEMP_DIR/claude" << 'EOF'
#!/bin/bash
echo "MOCK: Opus error" >&2
exit 1
EOF
    chmod +x "$TEST_TEMP_DIR/gemini" "$TEST_TEMP_DIR/claude"
    
    # Run plan (should fail)
    output=$("$PLAN_SCRIPT" "$feature_id" "Create plan" 2>&1 || true)
    assert_not_equals "0" "$?" "Plan should fail when all models fail"
    
    # History should still be updated
    assert_true "[[ -f $TEST_SESSION_ROOT/$feature_id/history.jsonl ]]" "History should exist even on failure"
    
    teardown
}

# Main test runner
main() {
    local tests=(
        "test_plan_without_sessions"
        "test_plan_default_sessions_enabled"
        "test_plan_with_sessions"
        "test_multi_phase_planning"
        "test_plan_session_naming"
        "test_opus_fallback_with_sessions"
        "test_full_context_with_sessions"
        "test_planning_session_continuity"
        "test_plan_history_with_sessions"
        "test_plan_backward_compatibility"
        "test_plan_error_with_sessions"
    )
    
    local passed=0
    local failed=0
    
    echo "Running plan.sh session integration tests..."
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