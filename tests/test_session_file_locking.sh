#!/bin/bash
# Test suite for ai-command-wrapper.sh file locking functionality
# Tests concurrent access to session metadata files

set -euo pipefail

# Source test harness
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$TEST_DIR/test-command.sh"

# Test configuration
WRAPPER_PATH="$PROJECT_ROOT/scripts/ai-command-wrapper.sh"
TEST_SESSION_DIR=""

# Setup function
setup() {
    # Create test directory
    TEST_TEMP_DIR=$(mktemp -d)
    export SESSION_DIR="$TEST_TEMP_DIR/.ai-sessions"
    mkdir -p "$SESSION_DIR"
}

# Teardown function
teardown() {
    if [[ -n "${TEST_TEMP_DIR:-}" ]]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
}

# Test concurrent metadata writes don't corrupt file
test_concurrent_metadata_writes() {
    setup
    
    local session_name="concurrent-test"
    local session_path="$SESSION_DIR/$session_name"
    mkdir -p "$session_path"
    
    # Create initial metadata
    cat > "$session_path/metadata.json" << EOF
{
    "created_at": "2025-01-11T00:00:00Z",
    "last_used": "2025-01-11T00:00:00Z",
    "session_id": "initial-id",
    "command": "claude",
    "session_name": "$session_name"
}
EOF
    
    # Function to update metadata
    update_metadata() {
        local id=$1
        # Source the wrapper functions directly
        source "$WRAPPER_PATH"
        store_session_metadata "$session_path" "session-$id" "claude" "test-$id"
    }
    
    # Run concurrent updates
    for i in {1..5}; do
        update_metadata "$i" &
    done
    
    # Wait for all background jobs
    wait
    
    # Verify metadata is still valid JSON
    if command -v jq >/dev/null 2>&1; then
        jq . "$session_path/metadata.json" >/dev/null 2>&1
        assert_equals "0" "$?" "Metadata should still be valid JSON after concurrent writes"
        
        # Check that we have a session_id (from one of the updates)
        local session_id=$(jq -r '.session_id' "$session_path/metadata.json")
        assert_contains "$session_id" "session-" "Session ID should be from one of the updates"
    fi
    
    teardown
}

# Test concurrent reads don't block each other
test_concurrent_reads() {
    setup
    
    local session_name="read-test"
    local session_path="$SESSION_DIR/$session_name"
    mkdir -p "$session_path"
    
    # Create metadata
    cat > "$session_path/metadata.json" << EOF
{
    "created_at": "2025-01-11T00:00:00Z",
    "last_used": "2025-01-11T00:00:00Z",
    "session_id": "read-test-id",
    "command": "claude",
    "session_name": "$session_name"
}
EOF
    
    # Function to read session ID
    read_session_id() {
        # Source the wrapper functions directly
        source "$WRAPPER_PATH"
        get_session_id "$session_path"
    }
    
    # Time concurrent reads
    local start_time=$(date +%s%N)
    
    # Run concurrent reads
    for i in {1..5}; do
        read_session_id &
    done
    
    # Wait for all background jobs
    wait
    
    local end_time=$(date +%s%N)
    local duration=$(( (end_time - start_time) / 1000000 ))  # Convert to milliseconds
    
    # Concurrent reads should complete quickly (under 1 second)
    assert_true "[[ $duration -lt 1000 ]]" "Concurrent reads should complete in under 1 second (took ${duration}ms)"
    
    teardown
}

# Test write blocks read
test_write_blocks_read() {
    setup
    
    local session_name="block-test"
    local session_path="$SESSION_DIR/$session_name"
    mkdir -p "$session_path"
    
    # Create initial metadata
    cat > "$session_path/metadata.json" << EOF
{
    "created_at": "2025-01-11T00:00:00Z",
    "last_used": "2025-01-11T00:00:00Z",
    "session_id": "block-test-id",
    "command": "claude",
    "session_name": "$session_name"
}
EOF
    
    # Create a flag file to track operation order
    local flag_file="$TEST_TEMP_DIR/operations.log"
    
    # Function to simulate long write
    long_write() {
        echo "write_start" >> "$flag_file"
        # Manually acquire exclusive lock
        exec 200>"$session_path/.lock"
        flock 200
        sleep 0.5  # Hold lock for 500ms
        echo "write_end" >> "$flag_file"
        exec 200>&-
    }
    
    # Function to read with timing
    timed_read() {
        echo "read_attempt" >> "$flag_file"
        source "$WRAPPER_PATH"
        get_session_id "$session_path" >/dev/null
        echo "read_complete" >> "$flag_file"
    }
    
    # Start long write in background
    long_write &
    local write_pid=$!
    
    # Give write time to acquire lock
    sleep 0.1
    
    # Attempt read (should block until write completes)
    timed_read
    
    # Wait for write to complete
    wait $write_pid
    
    # Check operation order
    local operations=$(cat "$flag_file")
    assert_contains "$operations" "write_start.*read_attempt.*write_end.*read_complete" \
        "Read should wait for write to complete"
    
    teardown
}

# Test lock timeout
test_lock_timeout() {
    setup
    
    local session_name="timeout-test"
    local session_path="$SESSION_DIR/$session_name"
    mkdir -p "$session_path"
    
    # Create metadata
    cat > "$session_path/metadata.json" << EOF
{
    "created_at": "2025-01-11T00:00:00Z",
    "last_used": "2025-01-11T00:00:00Z",
    "session_id": "timeout-test-id",
    "command": "claude",
    "session_name": "$session_name"
}
EOF
    
    # Acquire lock manually and hold it
    exec 200>"$session_path/.lock"
    flock 200 &
    local lock_pid=$!
    
    # Try to update metadata (should timeout after 5 seconds)
    local start_time=$(date +%s)
    source "$WRAPPER_PATH"
    store_session_metadata "$session_path" "new-id" "claude" "test" 2>&1 | grep -q "Failed to acquire lock"
    local exit_code=$?
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Kill the lock holder
    kill $lock_pid 2>/dev/null || true
    exec 200>&-
    
    assert_equals "0" "$exit_code" "Should detect lock timeout"
    assert_true "[[ $duration -ge 4 && $duration -le 6 ]]" \
        "Lock timeout should be around 5 seconds (was ${duration}s)"
    
    teardown
}

# Main test runner
main() {
    local tests=(
        "test_concurrent_metadata_writes"
        "test_concurrent_reads"
        "test_write_blocks_read"
        "test_lock_timeout"
    )
    
    local passed=0
    local failed=0
    
    echo "Running ai-command-wrapper.sh file locking tests..."
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