#!/bin/bash
# Test suite for TodoWrite integration with AI sessions
# Tests session lifecycle tracking in todo system

set -euo pipefail

# Source test harness
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$TEST_DIR/test-command.sh"

# Test configuration
TRACK_SCRIPT="$PROJECT_ROOT/scripts/track-session-todo.sh"
TEST_TODO_FILE=""

# Setup function
setup() {
    # Create test directory
    TEST_TEMP_DIR=$(mktemp -d)
    TEST_TODO_FILE="$TEST_TEMP_DIR/todos.jsonl"
    export TODO_FILE="$TEST_TODO_FILE"
}

# Teardown function
teardown() {
    if [[ -n "${TEST_TEMP_DIR:-}" ]]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
}

# Test session start tracking
test_session_start() {
    setup
    
    # Track session start
    todo_id=$("$TRACK_SCRIPT" start "test-session-1" "feature-123" "task-1" "0.15")
    assert_not_empty "$todo_id" "Should return todo ID"
    
    # Verify todo was created
    assert_true "[[ -f $TEST_TODO_FILE ]]" "Todo file should exist"
    
    # Check todo content
    local todo_content=$(cat "$TEST_TODO_FILE")
    assert_contains "$todo_content" "test-session-1" "Should contain session name"
    assert_contains "$todo_content" "feature-123" "Should contain feature ID"
    assert_contains "$todo_content" "task-1" "Should contain task ID"
    assert_contains "$todo_content" "in_progress" "Should be in progress"
    assert_contains "$todo_content" "0.15" "Should contain estimated cost"
    
    teardown
}

# Test session end tracking
test_session_end() {
    setup
    
    # Create initial todo
    local todo_id=$("$TRACK_SCRIPT" start "test-session-2" "feature-456" "task-2" "0.20")
    
    # End session
    "$TRACK_SCRIPT" end "test-session-2" "$todo_id" "0.25" "1500" "completed"
    
    # Verify update was recorded
    local updates=$(grep '"action": "update"' "$TEST_TODO_FILE" | wc -l)
    assert_equals "1" "$updates" "Should have one update"
    
    # Check update content
    local update_content=$(grep '"action": "update"' "$TEST_TODO_FILE")
    assert_contains "$update_content" "completed" "Should be completed"
    assert_contains "$update_content" "0.25" "Should contain actual cost"
    assert_contains "$update_content" "1500" "Should contain token count"
    
    teardown
}

# Test session error tracking
test_session_error() {
    setup
    
    # Create initial todo
    local todo_id=$("$TRACK_SCRIPT" start "test-session-3" "feature-789" "" "0.10")
    
    # Track error
    "$TRACK_SCRIPT" error "test-session-3" "$todo_id" "Connection timeout"
    
    # Verify error was tracked
    local error_entries=$(grep '"type": "ai_session_error"' "$TEST_TODO_FILE" | wc -l)
    assert_equals "1" "$error_entries" "Should have error entry"
    
    # Check error content
    local error_content=$(grep '"type": "ai_session_error"' "$TEST_TODO_FILE")
    assert_contains "$error_content" "Connection timeout" "Should contain error message"
    assert_contains "$error_content" "test-session-3" "Should reference session"
    
    teardown
}

# Test session report generation
test_session_report() {
    setup
    
    # Create multiple session entries
    "$TRACK_SCRIPT" start "report-session-1" "feature-A" "task-1" "0.10" >/dev/null
    "$TRACK_SCRIPT" start "report-session-2" "feature-A" "task-2" "0.15" >/dev/null
    "$TRACK_SCRIPT" start "report-session-3" "feature-B" "task-1" "0.20" >/dev/null
    
    # Generate report
    output=$("$TRACK_SCRIPT" report 2>&1)
    assert_equals "0" "$?" "Report should succeed"
    
    # Verify report content
    assert_contains "$output" "Total sessions: 3" "Should count sessions"
    assert_contains "$output" "AI Session Report" "Should have report header"
    
    teardown
}

# Test without todo ID
test_find_todo_by_session() {
    setup
    
    # Create todo
    "$TRACK_SCRIPT" start "find-session" "feature-X" "" "0.30" >/dev/null
    
    # End session without todo ID (should find by name)
    "$TRACK_SCRIPT" end "find-session" "" "0.35" "2000" "completed"
    
    # Should still find and update
    local updates=$(grep '"action": "update"' "$TEST_TODO_FILE" | wc -l)
    assert_equals "1" "$updates" "Should find and update todo"
    
    teardown
}

# Test cost calculation
test_cost_tracking() {
    setup
    
    # Create sessions with different costs
    local todo1=$("$TRACK_SCRIPT" start "cost-session-1" "feature-Y" "" "0.10")
    local todo2=$("$TRACK_SCRIPT" start "cost-session-2" "feature-Y" "" "0.20")
    
    # End with actual costs
    "$TRACK_SCRIPT" end "cost-session-1" "$todo1" "0.12" "800" "completed"
    "$TRACK_SCRIPT" end "cost-session-2" "$todo2" "0.25" "1200" "completed"
    
    # Generate report
    output=$("$TRACK_SCRIPT" report 2>&1)
    
    if command -v jq >/dev/null 2>&1; then
        # Calculate total from todos
        local total_cost=$(grep '"actual_cost"' "$TEST_TODO_FILE" | jq -s '[.[] | .metadata.actual_cost // 0] | add')
        assert_equals "0.37" "$total_cost" "Should sum actual costs"
    fi
    
    teardown
}

# Test emoji in todo content
test_emoji_formatting() {
    setup
    
    # Create session
    todo_id=$("$TRACK_SCRIPT" start "emoji-session" "feature-Z" "" "0.05")
    
    # Check emoji presence
    local content=$(grep "$todo_id" "$TEST_TODO_FILE")
    assert_contains "$content" "🤖" "Should have robot emoji"
    
    # Track error
    "$TRACK_SCRIPT" error "emoji-session" "$todo_id" "Test error"
    
    # Check error emoji
    local error_content=$(grep "ai_session_error" "$TEST_TODO_FILE")
    assert_contains "$error_content" "❌" "Should have error emoji"
    
    teardown
}

# Test concurrent sessions
test_concurrent_sessions() {
    setup
    
    # Start multiple sessions concurrently
    local todo1=$("$TRACK_SCRIPT" start "concurrent-1" "feature-C1" "" "0.10")
    local todo2=$("$TRACK_SCRIPT" start "concurrent-2" "feature-C2" "" "0.15")
    local todo3=$("$TRACK_SCRIPT" start "concurrent-3" "feature-C3" "" "0.20")
    
    # All should have unique IDs
    assert_not_equals "$todo1" "$todo2" "Todo IDs should be unique"
    assert_not_equals "$todo2" "$todo3" "Todo IDs should be unique"
    assert_not_equals "$todo1" "$todo3" "Todo IDs should be unique"
    
    # End all sessions
    "$TRACK_SCRIPT" end "concurrent-1" "$todo1" "0.11" "500" "completed"
    "$TRACK_SCRIPT" end "concurrent-2" "$todo2" "0.16" "700" "completed"
    "$TRACK_SCRIPT" end "concurrent-3" "$todo3" "0.21" "900" "completed"
    
    # All should be tracked
    local total_todos=$(grep '"type": "ai_session"' "$TEST_TODO_FILE" | wc -l)
    assert_equals "3" "$total_todos" "Should track all sessions"
    
    teardown
}

# Test edge cases
test_edge_cases() {
    setup
    
    # Empty session name
    output=$("$TRACK_SCRIPT" start "" "feature" "" "0.10" 2>&1 || true)
    assert_contains "$output" "AI Session:" "Should handle empty session name"
    
    # Very long session name
    long_name=$(printf 'a%.0s' {1..200})
    todo_id=$("$TRACK_SCRIPT" start "$long_name" "" "" "0.10")
    assert_not_empty "$todo_id" "Should handle long names"
    
    # Invalid action
    output=$("$TRACK_SCRIPT" invalid "session" 2>&1 || true)
    assert_not_equals "0" "$?" "Invalid action should fail"
    assert_contains "$output" "Usage:" "Should show usage"
    
    teardown
}

# Test integration with implement.sh
test_implement_integration() {
    setup
    
    # Simulate implement.sh behavior
    local session_name="implement-test-feature"
    local feature_id="test-feature"
    local task_id="task-123"
    
    # Start session
    local todo_id=$("$TRACK_SCRIPT" start "$session_name" "$feature_id" "$task_id" "0.20")
    
    # Simulate work
    sleep 0.1
    
    # End session with cost/tokens
    "$TRACK_SCRIPT" end "$session_name" "$todo_id" "0.18" "1200" "completed"
    
    # Verify complete lifecycle
    local start_entry=$(grep "$todo_id" "$TEST_TODO_FILE" | head -1)
    local end_entry=$(grep '"action": "update"' "$TEST_TODO_FILE" | grep "$todo_id")
    
    assert_not_empty "$start_entry" "Should have start entry"
    assert_not_empty "$end_entry" "Should have end entry"
    
    teardown
}

# Main test runner
main() {
    local tests=(
        "test_session_start"
        "test_session_end"
        "test_session_error"
        "test_session_report"
        "test_find_todo_by_session"
        "test_cost_tracking"
        "test_emoji_formatting"
        "test_concurrent_sessions"
        "test_edge_cases"
        "test_implement_integration"
    )
    
    local passed=0
    local failed=0
    
    echo "Running TodoWrite integration tests..."
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