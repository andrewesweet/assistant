#!/bin/bash
# Test: All commands log to history with proper metadata
# Feature: AI Orchestrator History Logging
# Scenario: Commands maintain audit trail with comprehensive metadata

set -euo pipefail

# Set project root if not already set
if [[ -z "${PROJECT_ROOT:-}" ]]; then
    PROJECT_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
    export PROJECT_ROOT
fi

# Source test harness and utilities
source "$(dirname "$0")/../test-command.sh"
source "$(dirname "$0")/../utils/test_setup.sh"

test_history_logging_basic_fields() {
    setup_test_scripts
    
    # Initialize session
    feature_id="history-basic-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Mock claude for implement command
    mock_command "claude" "mock_claude() {
        echo '{\"status\": \"success\"}'
    }"
    
    # Execute a command to generate history
    start_time=$(date -u +%Y-%m-%dT%H:%M:%S)
    ./scripts/implement.sh "$feature_id" --task "test-task" --no-tests
    end_time=$(date -u +%Y-%m-%dT%H:%M:%S)
    
    # Read last history entry
    history_entry=$(tail -n1 ".ai-session/$feature_id/history.jsonl")
    
    # Verify required fields present
    assert_contains "$history_entry" '"timestamp"' "History should include timestamp"
    assert_contains "$history_entry" '"command":"implement"' "History should include command"
    assert_contains "$history_entry" '"arguments"' "History should include arguments"
    assert_contains "$history_entry" '"model"' "History should include model used"
    assert_contains "$history_entry" '"agent"' "History should include agent identifier"
    assert_contains "$history_entry" '"status"' "History should include execution status"
    assert_contains "$history_entry" '"duration_ms"' "History should include duration"
    
    # Verify timestamp format and range
    timestamp=$(echo "$history_entry" | grep -o '"timestamp":"[^"]*"' | cut -d'"' -f4)
    assert_contains "$timestamp" "T" "Timestamp should be ISO 8601"
    assert_contains "$timestamp" "Z" "Timestamp should be UTC"
    
    unmock_command "claude"
}

test_history_preserves_command_arguments() {
    setup_test_scripts
    
    # Initialize session
    feature_id="history-args-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Mock commands
    mock_command "gemini" "mock_gemini() {
        echo '{\"status\": \"success\"}'
    }"
    
    # Execute plan with specific arguments
    ./scripts/plan.sh "$feature_id" --full-context --retry --timeout 300 "Design microservices architecture"
    
    # Check history
    history_entry=$(tail -n1 ".ai-session/$feature_id/history.jsonl")
    
    # Verify all arguments captured
    args=$(echo "$history_entry" | grep -o '"arguments":"[^"]*"' | cut -d'"' -f4)
    assert_contains "$args" "--full-context" "Should capture full-context flag"
    assert_contains "$args" "--retry" "Should capture retry flag"
    assert_contains "$args" "--timeout 300" "Should capture timeout value"
    assert_contains "$args" "Design microservices" "Should capture prompt text"
    
    unmock_command "gemini"
}

test_history_tracks_model_usage() {
    setup_test_scripts
    
    # Initialize session
    feature_id="history-models-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Mock different models
    mock_command "gemini" "mock_gemini() {
        echo '{\"status\": \"success\"}'
    }"
    mock_command "claude" "mock_claude() {
        echo '{\"status\": \"success\"}'
    }"
    
    # Use different models
    ./scripts/plan.sh "$feature_id" "Plan with Gemini"
    ./scripts/implement.sh "$feature_id" --task "test" --model sonnet --no-tests
    ./scripts/implement.sh "$feature_id" --task "test2" --model opus --no-tests
    
    # Analyze history
    history_content=$(cat ".ai-session/$feature_id/history.jsonl")
    
    # Count model usage
    gemini_count=$(grep -c '"model":"gemini"' ".ai-session/$feature_id/history.jsonl" || true)
    sonnet_count=$(grep -c '"model":"sonnet"' ".ai-session/$feature_id/history.jsonl" || true)
    opus_count=$(grep -c '"model":"opus"' ".ai-session/$feature_id/history.jsonl" || true)
    
    assert_equals "1" "$gemini_count" "Should log Gemini usage"
    assert_equals "1" "$sonnet_count" "Should log Sonnet usage"
    assert_equals "1" "$opus_count" "Should log Opus usage"
    
    unmock_command "gemini"
    unmock_command "claude"
}

test_history_tracks_task_context() {
    setup_test_scripts
    
    # Initialize session with tasks
    feature_id="history-tasks-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Create implementation plan
    cat > ".ai-session/$feature_id/implementation-plan.yaml" <<EOF
feature:
  id: "$feature_id"
phases:
  - phase_id: "phase-1"
    tasks:
      - task_id: "auth-service"
        description: "Authentication service"
        status: "pending"
      - task_id: "user-service"
        description: "User management"
        status: "pending"
EOF
    
    # Mock implementation
    mock_command "claude" "mock_claude() {
        echo '{\"status\": \"success\"}'
    }"
    
    # Execute commands for different tasks
    ./scripts/implement.sh "$feature_id" --task "auth-service" --no-tests
    ./scripts/implement.sh "$feature_id" --task "user-service" --no-tests
    
    # Verify task context in history
    history_content=$(cat ".ai-session/$feature_id/history.jsonl")
    
    # Check each entry has correct task
    auth_entry=$(grep '"task_id":"auth-service"' ".ai-session/$feature_id/history.jsonl")
    user_entry=$(grep '"task_id":"user-service"' ".ai-session/$feature_id/history.jsonl")
    
    assert_not_equals "" "$auth_entry" "Should log auth-service task"
    assert_not_equals "" "$user_entry" "Should log user-service task"
    
    unmock_command "claude"
}

test_history_tracks_failures() {
    setup_test_scripts
    
    # Initialize session
    feature_id="history-failures-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Mock command to fail
    mock_command "claude" "mock_claude() {
        echo 'Error: Model overloaded' >&2
        return 1
    }"
    
    # Execute failing command
    set +e
    ./scripts/implement.sh "$feature_id" --task "failing-task" --no-tests 2>&1
    exit_code=$?
    set -e
    
    # Check history for failure
    history_entry=$(tail -n1 ".ai-session/$feature_id/history.jsonl")
    
    # Verify failure recorded
    assert_contains "$history_entry" '"status":"failure"' "Should record failure status"
    assert_contains "$history_entry" '"error"' "Should include error field"
    assert_contains "$history_entry" "Model overloaded" "Should capture error message"
    assert_not_equals "0" "$exit_code" "Command should fail"
    
    unmock_command "claude"
}

test_history_agent_identification() {
    setup_test_scripts
    
    # Initialize session
    feature_id="history-agents-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Mock commands with agent tracking
    mock_command "claude" "mock_claude() {
        echo '{\"status\": \"success\"}'
    }"
    
    # Set different agent identifiers
    export AGENT_ID="agent-1-morning"
    ./scripts/implement.sh "$feature_id" --task "task1" --no-tests
    
    export AGENT_ID="agent-2-afternoon"
    ./scripts/implement.sh "$feature_id" --task "task2" --no-tests
    
    # Verify agents tracked
    history_content=$(cat ".ai-session/$feature_id/history.jsonl")
    assert_contains "$history_content" '"agent":"agent-1-morning"' "Should track agent 1"
    assert_contains "$history_content" '"agent":"agent-2-afternoon"' "Should track agent 2"
    
    unset AGENT_ID
    unmock_command "claude"
}

test_history_performance_metrics() {
    setup_test_scripts
    
    # Initialize session
    feature_id="history-perf-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Mock with controlled delays
    mock_command "claude" "mock_claude() {
        sleep 0.15  # 150ms delay
        echo '{\"status\": \"success\"}'
    }"
    
    # Execute command
    ./scripts/implement.sh "$feature_id" --task "perf-test" --no-tests
    
    # Check duration tracking
    history_entry=$(tail -n1 ".ai-session/$feature_id/history.jsonl")
    duration=$(echo "$history_entry" | grep -o '"duration_ms":[0-9]*' | cut -d: -f2)
    
    # Verify reasonable duration (should be >140ms due to sleep)
    assert_less_than "140" "$duration" "Duration should reflect execution time"
    
    unmock_command "claude"
}

test_history_file_integrity() {
    setup_test_scripts
    
    # Initialize session
    feature_id="history-integrity-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Mock multiple commands
    mock_command "claude" "mock_claude() {
        echo '{\"status\": \"success\"}'
    }"
    mock_command "gemini" "mock_gemini() {
        echo '{\"status\": \"success\"}'
    }"
    
    # Execute multiple commands rapidly
    for i in {1..5}; do
        ./scripts/plan.sh "$feature_id" "Plan $i" &
        ./scripts/implement.sh "$feature_id" --task "task-$i" --no-tests &
    done
    
    # Wait for all to complete
    wait
    
    # Verify history file integrity
    line_count=$(wc -l < ".ai-session/$feature_id/history.jsonl")
    assert_less_than "9" "$line_count" "Should have multiple history entries"
    
    # Verify each line is valid JSON
    while IFS= read -r line; do
        if ! echo "$line" | jq empty 2>/dev/null; then
            echo "Invalid JSON in history: $line"
            return 1
        fi
    done < ".ai-session/$feature_id/history.jsonl"
    
    unmock_command "claude"
    unmock_command "gemini"
}

test_history_append_only() {
    setup_test_scripts
    
    # Initialize session
    feature_id="history-append-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Mock command
    mock_command "claude" "mock_claude() {
        echo '{\"status\": \"success\"}'
    }"
    
    # Execute first command
    ./scripts/implement.sh "$feature_id" --task "task1" --no-tests
    
    # Capture initial history
    cp ".ai-session/$feature_id/history.jsonl" "/tmp/history_snapshot.jsonl"
    initial_lines=$(wc -l < "/tmp/history_snapshot.jsonl")
    
    # Execute second command
    ./scripts/implement.sh "$feature_id" --task "task2" --no-tests
    
    # Verify append-only behavior
    final_lines=$(wc -l < ".ai-session/$feature_id/history.jsonl")
    assert_less_than "$initial_lines" "$final_lines" "History should grow"
    
    # Verify original entries unchanged
    head -n "$initial_lines" ".ai-session/$feature_id/history.jsonl" > "/tmp/history_head.jsonl"
    diff "/tmp/history_snapshot.jsonl" "/tmp/history_head.jsonl" || {
        echo "History entries were modified (should be append-only)"
        return 1
    }
    
    unmock_command "claude"
}

test_history_session_metadata() {
    setup_test_scripts
    
    # Initialize session with metadata
    feature_id="history-metadata-$(date +%Y-%m-%d)"
    description="E-commerce platform with microservices"
    ./scripts/init-session.sh "$feature_id" "$description"
    
    # Mock command
    mock_command "gemini" "mock_gemini() {
        echo '{\"status\": \"success\"}'
    }"
    
    # Execute command
    ./scripts/plan.sh "$feature_id" "Design API gateway"
    
    # Verify session metadata in history
    history_entry=$(tail -n1 ".ai-session/$feature_id/history.jsonl")
    
    # Should include session context
    assert_contains "$history_entry" '"feature_id":"'"$feature_id"'"' "Should include feature ID"
    
    # Verify session state tracked
    state_before=$(grep -o '"session_state":{[^}]*}' ".ai-session/$feature_id/history.jsonl" | head -1)
    assert_contains "$state_before" "active_task" "Should track session state"
    
    unmock_command "gemini"
}

test_history_query_capabilities() {
    setup_test_scripts
    
    # Initialize session
    feature_id="history-query-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Mock commands
    mock_command "claude" "mock_claude() {
        echo '{\"status\": \"success\"}'
    }"
    mock_command "gemini" "mock_gemini() {
        echo '{\"status\": \"success\"}'
    }"
    
    # Generate diverse history
    ./scripts/plan.sh "$feature_id" "Initial plan"
    sleep 1
    ./scripts/implement.sh "$feature_id" --task "auth" --no-tests
    ./scripts/implement.sh "$feature_id" --task "database" --no-tests
    
    # Mock failure
    mock_command "claude" "mock_claude() {
        return 1
    }"
    ./scripts/implement.sh "$feature_id" --task "failing" --no-tests 2>/dev/null || true
    
    # Test query script
    if [[ -f "./scripts/query-history.sh" ]]; then
        # Query by command
        impl_count=$(./scripts/query-history.sh "$feature_id" --command implement --count)
        assert_equals "3" "$impl_count" "Should count implement commands"
        
        # Query by status
        failure_count=$(./scripts/query-history.sh "$feature_id" --status failure --count)
        assert_equals "1" "$failure_count" "Should count failures"
        
        # Query by model
        gemini_entries=$(./scripts/query-history.sh "$feature_id" --model gemini)
        assert_contains "$gemini_entries" "Initial plan" "Should find Gemini entries"
    fi
    
    unmock_command "claude"
    unmock_command "gemini"
}

# Run all tests
echo "Testing command history logging..."
run_test_scenario "History basic fields" test_history_logging_basic_fields
run_test_scenario "History preserves arguments" test_history_preserves_command_arguments
run_test_scenario "History tracks models" test_history_tracks_model_usage
run_test_scenario "History tracks tasks" test_history_tracks_task_context
run_test_scenario "History tracks failures" test_history_tracks_failures
run_test_scenario "History agent identification" test_history_agent_identification
run_test_scenario "History performance metrics" test_history_performance_metrics
run_test_scenario "History file integrity" test_history_file_integrity
run_test_scenario "History append only" test_history_append_only
run_test_scenario "History session metadata" test_history_session_metadata
run_test_scenario "History query capabilities" test_history_query_capabilities