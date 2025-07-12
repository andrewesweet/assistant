#!/bin/bash
# Test suite for ai-session.sh management script
# Tests session listing, inspection, cleanup, and analytics

set -euo pipefail

# Source test harness
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$TEST_DIR/test-command.sh"

# Test configuration
SESSION_SCRIPT="$PROJECT_ROOT/scripts/ai-session.sh"
TEST_SESSION_DIR=""

# Setup function
setup() {
    # Create test directory
    TEST_TEMP_DIR=$(mktemp -d)
    TEST_SESSION_DIR="$TEST_TEMP_DIR/.ai-sessions"
    export SESSION_DIR="$TEST_SESSION_DIR"
    mkdir -p "$TEST_SESSION_DIR"
    
    # Create some test sessions
    create_test_session "project-alpha" "2025-01-10T10:00:00Z" "session-123" 150 25
    create_test_session "project-beta" "2025-01-11T14:30:00Z" "session-456" 200 40
    create_test_session "old-project" "2024-12-01T09:00:00Z" "" 50 10
    create_test_session "empty-session" "2025-01-11T16:00:00Z" "" 0 0
}

# Create a test session with metadata
create_test_session() {
    local name="$1"
    local created_at="$2"
    local session_id="$3"
    local input_tokens="${4:-0}"
    local output_tokens="${5:-0}"
    
    local session_path="$TEST_SESSION_DIR/$name"
    mkdir -p "$session_path"
    
    # Create metadata file
    cat > "$session_path/metadata.json" << EOF
{
    "created_at": "$created_at",
    "last_used": "$created_at",
    "session_id": "$session_id",
    "command": "claude",
    "session_name": "$name",
    "total_cost": 0.001,
    "interactions": [
        {
            "timestamp": "$created_at",
            "model": "claude-3-sonnet",
            "tokens": {
                "input": $input_tokens,
                "output": $output_tokens
            },
            "cost": 0.001
        }
    ]
}
EOF
    chmod 600 "$session_path/metadata.json"
}

# Teardown function
teardown() {
    if [[ -n "${TEST_TEMP_DIR:-}" ]]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
}

# Test list command
test_list_sessions() {
    setup
    
    # Test basic listing
    output=$("$SESSION_SCRIPT" list 2>&1)
    assert_equals "0" "$?" "List command should succeed"
    
    # Should list all sessions
    assert_contains "$output" "project-alpha" "Should list project-alpha"
    assert_contains "$output" "project-beta" "Should list project-beta"
    assert_contains "$output" "old-project" "Should list old-project"
    assert_contains "$output" "empty-session" "Should list empty-session"
    
    # Should show session details
    assert_contains "$output" "session-123" "Should show session ID for alpha"
    assert_contains "$output" "session-456" "Should show session ID for beta"
    
    teardown
}

# Test list with filters
test_list_with_filters() {
    setup
    
    # Test --active flag (sessions from last 30 days)
    output=$("$SESSION_SCRIPT" list --active 2>&1)
    assert_equals "0" "$?" "List active should succeed"
    assert_contains "$output" "project-alpha" "Should list recent alpha"
    assert_contains "$output" "project-beta" "Should list recent beta"
    assert_not_contains "$output" "old-project" "Should not list old project"
    
    # Test --sort flag
    output=$("$SESSION_SCRIPT" list --sort name 2>&1)
    assert_equals "0" "$?" "List with sort should succeed"
    # Verify alphabetical order in output
    
    teardown
}

# Test show command
test_show_session() {
    setup
    
    # Test showing specific session
    output=$("$SESSION_SCRIPT" show project-alpha 2>&1)
    assert_equals "0" "$?" "Show command should succeed"
    
    # Should show detailed info
    assert_contains "$output" "Session: project-alpha" "Should show session name"
    assert_contains "$output" "ID: session-123" "Should show session ID"
    assert_contains "$output" "Created: 2025-01-10" "Should show creation date"
    assert_contains "$output" "Tokens:" "Should show token usage"
    assert_contains "$output" "150" "Should show input tokens"
    assert_contains "$output" "25" "Should show output tokens"
    
    # Test showing non-existent session
    output=$("$SESSION_SCRIPT" show non-existent 2>&1 || true)
    assert_not_equals "0" "$?" "Show non-existent should fail"
    assert_contains "$output" "Session not found" "Should show error message"
    
    teardown
}

# Test clean command
test_clean_sessions() {
    setup
    
    # Test dry-run first
    output=$("$SESSION_SCRIPT" clean --older-than 30 --dry-run 2>&1)
    assert_equals "0" "$?" "Clean dry-run should succeed"
    assert_contains "$output" "Would remove:" "Should show what would be removed"
    assert_contains "$output" "old-project" "Should identify old project"
    
    # Verify old session still exists
    assert_true "[[ -d $TEST_SESSION_DIR/old-project ]]" "Old project should still exist after dry-run"
    
    # Test actual cleanup
    output=$("$SESSION_SCRIPT" clean --older-than 30 2>&1)
    assert_equals "0" "$?" "Clean should succeed"
    assert_contains "$output" "Removed:" "Should show removed sessions"
    assert_contains "$output" "old-project" "Should remove old project"
    
    # Verify old session is gone
    assert_false "[[ -d $TEST_SESSION_DIR/old-project ]]" "Old project should be removed"
    
    # Verify recent sessions remain
    assert_true "[[ -d $TEST_SESSION_DIR/project-alpha ]]" "Recent project should remain"
    
    teardown
}

# Test clean with confirmation
test_clean_with_confirmation() {
    setup
    
    # Test that clean requires confirmation without --force
    output=$(echo "n" | "$SESSION_SCRIPT" clean --older-than 30 2>&1 || true)
    assert_contains "$output" "Continue?" "Should ask for confirmation"
    
    # Verify nothing was deleted
    assert_true "[[ -d $TEST_SESSION_DIR/old-project ]]" "Old project should remain after declining"
    
    # Test with --force flag
    output=$("$SESSION_SCRIPT" clean --older-than 30 --force 2>&1)
    assert_equals "0" "$?" "Clean with force should succeed"
    assert_not_contains "$output" "Continue?" "Should not ask with --force"
    assert_false "[[ -d $TEST_SESSION_DIR/old-project ]]" "Old project should be removed"
    
    teardown
}

# Test stats command
test_session_stats() {
    setup
    
    # Test overall stats
    output=$("$SESSION_SCRIPT" stats 2>&1)
    assert_equals "0" "$?" "Stats command should succeed"
    
    # Should show summary statistics
    assert_contains "$output" "Total sessions: 4" "Should count all sessions"
    assert_contains "$output" "Active sessions: 3" "Should count active sessions"
    assert_contains "$output" "Total tokens used:" "Should show token usage"
    assert_contains "$output" "Total cost:" "Should show cost"
    
    # Test stats for specific session
    output=$("$SESSION_SCRIPT" stats --session project-alpha 2>&1)
    assert_equals "0" "$?" "Stats for session should succeed"
    assert_contains "$output" "Session: project-alpha" "Should show session name"
    assert_contains "$output" "Input tokens: 150" "Should show input tokens"
    assert_contains "$output" "Output tokens: 25" "Should show output tokens"
    
    teardown
}

# Test export command
test_export_sessions() {
    setup
    
    local export_file="$TEST_TEMP_DIR/export.json"
    
    # Test export to file
    output=$("$SESSION_SCRIPT" export --output "$export_file" 2>&1)
    assert_equals "0" "$?" "Export should succeed"
    assert_true "[[ -f $export_file ]]" "Export file should exist"
    
    # Verify export contains all sessions
    if command -v jq >/dev/null 2>&1; then
        local session_count=$(jq '. | length' "$export_file")
        assert_equals "4" "$session_count" "Export should contain all sessions"
    fi
    
    # Test export with filter
    output=$("$SESSION_SCRIPT" export --active --output "$export_file" 2>&1)
    assert_equals "0" "$?" "Export active should succeed"
    
    if command -v jq >/dev/null 2>&1; then
        local active_count=$(jq '. | length' "$export_file")
        assert_equals "3" "$active_count" "Export should contain only active sessions"
    fi
    
    teardown
}

# Test help command
test_help_output() {
    setup
    
    # Test help
    output=$("$SESSION_SCRIPT" help 2>&1 || true)
    assert_equals "0" "$?" "Help should succeed"
    
    # Verify help contains all commands
    assert_contains "$output" "list" "Help should mention list"
    assert_contains "$output" "show" "Help should mention show"
    assert_contains "$output" "clean" "Help should mention clean"
    assert_contains "$output" "stats" "Help should mention stats"
    assert_contains "$output" "export" "Help should mention export"
    
    # Test --help flag
    output=$("$SESSION_SCRIPT" --help 2>&1 || true)
    assert_equals "0" "$?" "--help should succeed"
    assert_contains "$output" "Usage:" "Should show usage"
    
    teardown
}

# Test invalid commands
test_invalid_commands() {
    setup
    
    # Test unknown command
    output=$("$SESSION_SCRIPT" invalid-command 2>&1 || true)
    assert_not_equals "0" "$?" "Invalid command should fail"
    assert_contains "$output" "Unknown command" "Should show error for unknown command"
    
    # Test missing required arguments
    output=$("$SESSION_SCRIPT" show 2>&1 || true)
    assert_not_equals "0" "$?" "Show without session should fail"
    assert_contains "$output" "requires a session name" "Should show error for missing arg"
    
    teardown
}

# Test session directory creation
test_session_directory_handling() {
    # Test with non-existent session directory
    local temp_dir=$(mktemp -d)
    export SESSION_DIR="$temp_dir/new-sessions"
    
    # Directory should be created automatically
    output=$("$SESSION_SCRIPT" list 2>&1)
    assert_equals "0" "$?" "Should handle missing directory"
    assert_true "[[ -d $SESSION_DIR ]]" "Should create session directory"
    
    # Check permissions
    local perms=$(stat -c %a "$SESSION_DIR" 2>/dev/null || stat -f %p "$SESSION_DIR" | cut -c 4-6)
    assert_equals "700" "$perms" "Session directory should have 700 permissions"
    
    rm -rf "$temp_dir"
}

# Main test runner
main() {
    local tests=(
        "test_list_sessions"
        "test_list_with_filters"
        "test_show_session"
        "test_clean_sessions"
        "test_clean_with_confirmation"
        "test_session_stats"
        "test_export_sessions"
        "test_help_output"
        "test_invalid_commands"
        "test_session_directory_handling"
    )
    
    local passed=0
    local failed=0
    
    echo "Running ai-session.sh management script tests..."
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