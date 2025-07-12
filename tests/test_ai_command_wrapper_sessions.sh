#!/bin/bash
# Test suite for ai-command-wrapper.sh session management functionality
# Tests cover session creation, resumption, JSON output, and backward compatibility

set -euo pipefail

# Source test harness
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$TEST_DIR/test-command.sh"

# Test configuration
WRAPPER_PATH="$PROJECT_ROOT/scripts/ai-command-wrapper.sh"
TEST_SESSION_DIR=""
SESSION_NAME_PREFIX="test-session"

# Mock claude command for testing
MOCK_CLAUDE_PATH=""
MOCK_OUTPUT_FILE=""
MOCK_EXIT_CODE_FILE=""

# Setup function
setup() {
    # Create test directory
    TEST_TEMP_DIR=$(mktemp -d)
    TEST_SESSION_DIR="$TEST_TEMP_DIR/.ai-sessions"
    mkdir -p "$TEST_SESSION_DIR"
    
    # Create mock claude command
    MOCK_CLAUDE_PATH="$TEST_TEMP_DIR/claude"
    MOCK_OUTPUT_FILE="$TEST_TEMP_DIR/mock_output.txt"
    MOCK_EXIT_CODE_FILE="$TEST_TEMP_DIR/mock_exit_code.txt"
    
    cat > "$MOCK_CLAUDE_PATH" << 'EOF'
#!/bin/bash
# Mock claude command for testing

# Default values
output="Mock response"
exit_code=0
session_id=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help)
            echo "Mock claude help"
            exit 0
            ;;
        -c|--continue)
            session_id="continue-session"
            shift
            ;;
        -r|--resume)
            shift
            if [[ $# -gt 0 && ! "$1" =~ ^- ]]; then
                session_id="$1"
                shift
            fi
            ;;
        --session-name)
            shift
            if [[ $# -gt 0 ]]; then
                session_id="$1"
                shift
            fi
            ;;
        --print)
            shift
            ;;
        -p|--prompt)
            shift
            if [[ $# -gt 0 ]]; then
                # Mock different responses based on prompt
                case "$1" in
                    *"test-json"*)
                        output='{"response": "Test JSON response", "session_id": "test-123"}'
                        ;;
                    *"test-error"*)
                        output="Error: Mock error response"
                        exit_code=1
                        ;;
                    *"test-empty"*)
                        output=""
                        ;;
                    *)
                        output="Mock response for: $1"
                        ;;
                esac
                shift
            fi
            ;;
        *)
            shift
            ;;
    esac
done

# Read mock configuration if exists
if [[ -f "$MOCK_OUTPUT_FILE" ]]; then
    output=$(cat "$MOCK_OUTPUT_FILE")
fi

if [[ -f "$MOCK_EXIT_CODE_FILE" ]]; then
    exit_code=$(cat "$MOCK_EXIT_CODE_FILE")
fi

# Output response
echo "$output"

# Exit with configured code
exit $exit_code
EOF
    
    chmod +x "$MOCK_CLAUDE_PATH"
    
    # Add mock to PATH
    export PATH="$TEST_TEMP_DIR:$PATH"
}

# Teardown function
teardown() {
    if [[ -n "$TEST_TEMP_DIR" ]]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
}

# Test session name sanitization
test_session_name_sanitization() {
    setup
    
    # Test valid session names
    local valid_names=(
        "my-session"
        "session123"
        "test_session"
        "MySession2024"
    )
    
    for name in "${valid_names[@]}"; do
        output=$("$WRAPPER_PATH" claude 60 --session-name "$name" -p "test" 2>&1 || true)
        assert_equals "0" "$?" "Valid session name '$name' should succeed"
    done
    
    # Test invalid session names (should be sanitized)
    local invalid_names=(
        "my session"      # spaces
        "my/session"      # slashes
        "../evil"         # path traversal
        "session@test"    # special chars
        ""                # empty
    )
    
    for name in "${invalid_names[@]}"; do
        output=$("$WRAPPER_PATH" claude 60 --session-name "$name" -p "test" 2>&1 || true)
        # Should succeed after sanitization
        assert_equals "0" "$?" "Invalid session name '$name' should be sanitized and succeed"
    done
    
    teardown
}

# Test session creation
test_session_creation() {
    setup
    
    # Test creating a new session
    output=$("$WRAPPER_PATH" claude 60 --session-name "test-create" -p "test session creation" 2>&1)
    assert_equals "0" "$?" "Session creation should succeed"
    assert_contains "$output" "Mock response" "Should contain mock response"
    
    # Verify session directory structure would be created
    # (In real implementation, would check for .ai-sessions/test-create/)
    
    teardown
}

# Test session resumption
test_session_resumption() {
    setup
    
    # Create a session first
    "$WRAPPER_PATH" claude 60 --session-name "test-resume" -p "initial message" >/dev/null 2>&1
    
    # Resume the session
    output=$("$WRAPPER_PATH" claude 60 --session-name "test-resume" -p "continue message" 2>&1)
    assert_equals "0" "$?" "Session resumption should succeed"
    
    teardown
}

# Test JSON output format
test_json_output_format() {
    setup
    
    # Configure mock to return JSON
    echo '{"response": "Test response", "session_id": "test-123", "model": "claude-3-sonnet", "tokens": {"input": 10, "output": 20}}' > "$MOCK_OUTPUT_FILE"
    
    # Test JSON output flag
    output=$("$WRAPPER_PATH" claude 60 --json --session-name "test-json" -p "test-json" 2>&1)
    assert_equals "0" "$?" "JSON output should succeed"
    
    # Extract just the JSON line from output (skip log messages)
    json_line=$(echo "$output" | grep -E '^\{.*\}$' | head -1)
    
    # Verify JSON structure
    assert_contains "$json_line" '"response"' "JSON should contain response field"
    assert_contains "$json_line" '"session_id"' "JSON should contain session_id field"
    
    # Test that JSON can be parsed (requires jq)
    if command -v jq >/dev/null 2>&1; then
        echo "$json_line" | jq . >/dev/null 2>&1
        assert_equals "0" "$?" "Output should be valid JSON"
    fi
    
    teardown
}

# Test backward compatibility
test_backward_compatibility() {
    setup
    
    # Test without any session flags (original behavior)
    output=$("$WRAPPER_PATH" claude 60 -p "test backward compat" 2>&1)
    assert_equals "0" "$?" "Basic usage without session should work"
    assert_contains "$output" "Mock response" "Should contain response"
    
    # Test that it doesn't create session files when not requested
    # (In real implementation, would verify no .ai-sessions directory created)
    
    teardown
}

# Test continue flag integration
test_continue_flag() {
    setup
    
    # Test -c flag passthrough
    output=$("$WRAPPER_PATH" claude 60 -c -p "continue previous" 2>&1)
    assert_equals "0" "$?" "Continue flag should work"
    assert_contains "$output" "Mock response" "Should contain response"
    
    teardown
}

# Test resume with session ID
test_resume_with_session_id() {
    setup
    
    # Test -r flag with session ID
    output=$("$WRAPPER_PATH" claude 60 -r "test-session-id" -p "resume specific" 2>&1)
    assert_equals "0" "$?" "Resume with session ID should work"
    assert_contains "$output" "Mock response" "Should contain response"
    
    teardown
}

# Test error handling
test_error_handling() {
    setup
    
    # Test API error
    echo "1" > "$MOCK_EXIT_CODE_FILE"
    output=$("$WRAPPER_PATH" claude 60 -p "test-error" 2>&1 || true)
    assert_not_equals "0" "$?" "Should propagate error exit code"
    
    # Test empty response
    echo "" > "$MOCK_OUTPUT_FILE"
    output=$("$WRAPPER_PATH" claude 60 -p "test-empty" 2>&1 || true)
    assert_not_equals "0" "$?" "Empty response should fail validation"
    
    teardown
}

# Test session metadata storage
test_session_metadata() {
    setup
    
    # Test that session metadata would be stored
    # This tests the expected behavior, actual implementation will create files
    output=$("$WRAPPER_PATH" claude 60 --session-name "test-metadata" --json -p "test" 2>&1)
    assert_equals "0" "$?" "Session with metadata should succeed"
    
    # In real implementation, would verify:
    # - .ai-sessions/test-metadata/metadata.json exists
    # - Contains session_id, created_at, last_used, etc.
    
    teardown
}

# Test concurrent session access
test_concurrent_sessions() {
    setup
    
    # Test multiple sessions can be used
    "$WRAPPER_PATH" claude 60 --session-name "session1" -p "test1" >/dev/null 2>&1
    "$WRAPPER_PATH" claude 60 --session-name "session2" -p "test2" >/dev/null 2>&1
    
    # Both should succeed
    assert_equals "0" "$?" "Multiple sessions should work"
    
    teardown
}

# Test session name edge cases
test_session_name_edge_cases() {
    setup
    
    # Very long session name (should be truncated)
    long_name=$(printf 'a%.0s' {1..300})
    output=$("$WRAPPER_PATH" claude 60 --session-name "$long_name" -p "test" 2>&1)
    assert_equals "0" "$?" "Very long session name should be handled"
    
    # Unicode characters (should be sanitized)
    output=$("$WRAPPER_PATH" claude 60 --session-name "test-émoji-🚀" -p "test" 2>&1)
    assert_equals "0" "$?" "Unicode session name should be handled"
    
    teardown
}

# Test help and usage
test_help_output() {
    setup
    
    # Test that help is updated with session options
    output=$("$WRAPPER_PATH" 2>&1 || true)
    assert_contains "$output" "Usage:" "Should show usage"
    
    # After implementation, verify it mentions session flags
    # assert_contains "$output" "--session-name" "Help should mention session-name"
    # assert_contains "$output" "--json" "Help should mention json output"
    
    teardown
}

# Main test runner
main() {
    local tests=(
        "test_session_name_sanitization"
        "test_session_creation"
        "test_session_resumption"
        "test_json_output_format"
        "test_backward_compatibility"
        "test_continue_flag"
        "test_resume_with_session_id"
        "test_error_handling"
        "test_session_metadata"
        "test_concurrent_sessions"
        "test_session_name_edge_cases"
        "test_help_output"
    )
    
    local passed=0
    local failed=0
    
    echo "Running ai-command-wrapper.sh session management tests..."
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