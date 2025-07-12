#!/bin/bash
# Test: Status command displays comprehensive session information
# Feature: AI Orchestrator Status Display
# Scenario: Status shows current task, model, duration, history and session state

set -euo pipefail

# Set project root if not already set
if [[ -z "${PROJECT_ROOT:-}" ]]; then
    PROJECT_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
    export PROJECT_ROOT
fi

# Source test harness and utilities
source "$(dirname "$0")/../test-command.sh"
source "$(dirname "$0")/../utils/test_setup.sh"

test_status_basic_display() {
    setup_test_scripts
    
    # Initialize session
    feature_id="status-basic-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id" "Test feature for status display"
    
    # Update state with active task
    cat > ".ai-session/$feature_id/state.yaml" <<EOF
version: "1.0"
feature_id: "$feature_id"
current_state:
  active_task: "implement-auth"
  model_in_use: "opus"
  started_at: "2025-01-09T10:00:00Z"
  last_updated: "2025-01-09T14:30:00Z"
EOF
    
    # Run status command
    output=$(./scripts/status.sh "$feature_id")
    
    # Verify basic information displayed
    assert_contains "$output" "Feature: $feature_id" "Should show feature ID"
    assert_contains "$output" "Test feature for status display" "Should show description"
    assert_contains "$output" "Active Task: implement-auth" "Should show active task"
    assert_contains "$output" "Model: opus" "Should show current model"
    assert_contains "$output" "Started: 2025-01-09T10:00:00Z" "Should show start time"
}

test_status_duration_calculation() {
    setup_test_scripts
    
    # Initialize session
    feature_id="status-duration-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Set specific timestamps for duration calculation
    start_time="2025-01-09T10:00:00Z"
    current_time=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    cat > ".ai-session/$feature_id/state.yaml" <<EOF
version: "1.0"
feature_id: "$feature_id"
current_state:
  active_task: "database-migration"
  model_in_use: "sonnet"
  started_at: "$start_time"
  last_updated: "$current_time"
EOF
    
    # Run status
    output=$(./scripts/status.sh "$feature_id")
    
    # Verify duration is calculated and displayed
    assert_contains "$output" "Duration:" "Should show duration"
    # Should show hours, minutes, or days depending on actual duration
    if [[ "$output" =~ Duration:[[:space:]]*([0-9]+[[:space:]]*(hours?|minutes?|days?)) ]]; then
        assert_not_equals "" "${BASH_REMATCH[1]}" "Duration should have value"
    else
        echo "Duration format not found in output"
        return 1
    fi
}

test_status_history_summary() {
    setup_test_scripts
    
    # Initialize session
    feature_id="status-history-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Mock commands to generate history
    mock_command "gemini" "mock_gemini() {
        echo '{\"status\": \"success\"}'
    }"
    mock_command "claude" "mock_claude() {
        echo '{\"status\": \"success\"}'
    }"
    
    # Generate diverse history
    ./scripts/plan.sh "$feature_id" "Initial planning"
    ./scripts/implement.sh "$feature_id" --task "task1" --model sonnet --no-tests
    ./scripts/implement.sh "$feature_id" --task "task2" --model opus --no-tests
    ./scripts/review.sh "$feature_id" --code
    
    # Add a failure
    mock_command "claude" "mock_claude() {
        return 1
    }"
    ./scripts/implement.sh "$feature_id" --task "failing" --no-tests 2>/dev/null || true
    
    # Run status
    output=$(./scripts/status.sh "$feature_id")
    
    # Verify history summary
    assert_contains "$output" "Command History:" "Should have history section"
    assert_contains "$output" "Total Commands: 5" "Should count total commands"
    assert_contains "$output" "plan: 1" "Should count plan commands"
    assert_contains "$output" "implement: 3" "Should count implement commands"
    assert_contains "$output" "review: 1" "Should count review commands"
    assert_contains "$output" "Failures: 1" "Should count failures"
    
    unmock_command "gemini"
    unmock_command "claude"
}

test_status_model_usage_stats() {
    setup_test_scripts
    
    # Initialize session
    feature_id="status-models-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Mock commands with different models
    mock_command "gemini" "mock_gemini() {
        echo '{\"status\": \"success\"}'
    }"
    mock_command "claude" "mock_claude() {
        echo '{\"status\": \"success\"}'
    }"
    
    # Use different models
    ./scripts/plan.sh "$feature_id" "Design"  # Uses Gemini
    ./scripts/implement.sh "$feature_id" --task "t1" --model sonnet --no-tests
    ./scripts/implement.sh "$feature_id" --task "t2" --model sonnet --no-tests
    ./scripts/implement.sh "$feature_id" --task "t3" --model opus --no-tests
    
    # Run status
    output=$(./scripts/status.sh "$feature_id")
    
    # Verify model usage statistics
    assert_contains "$output" "Model Usage:" "Should have model usage section"
    assert_contains "$output" "gemini: 1" "Should show Gemini usage"
    assert_contains "$output" "sonnet: 2" "Should show Sonnet usage"
    assert_contains "$output" "opus: 1" "Should show Opus usage"
    
    unmock_command "gemini"
    unmock_command "claude"
}

test_status_task_progress() {
    setup_test_scripts
    
    # Initialize session with tasks
    feature_id="status-tasks-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Create implementation plan with multiple tasks
    cat > ".ai-session/$feature_id/implementation-plan.yaml" <<EOF
feature:
  id: "$feature_id"
  name: "E-commerce Platform"
phases:
  - phase_id: "phase-1"
    name: "Core Services"
    tasks:
      - task_id: "auth-service"
        description: "Authentication service"
        status: "completed"
      - task_id: "user-service"
        description: "User management"
        status: "completed"
      - task_id: "product-service"
        description: "Product catalog"
        status: "in_progress"
      - task_id: "order-service"
        description: "Order processing"
        status: "pending"
      - task_id: "payment-service"
        description: "Payment processing"
        status: "pending"
EOF
    
    # Set current task
    cat > ".ai-session/$feature_id/state.yaml" <<EOF
version: "1.0"
feature_id: "$feature_id"
current_state:
  active_task: "product-service"
  model_in_use: "sonnet"
  started_at: "2025-01-09T10:00:00Z"
  last_updated: "2025-01-09T12:00:00Z"
EOF
    
    # Run status
    output=$(./scripts/status.sh "$feature_id")
    
    # Verify task progress
    assert_contains "$output" "Task Progress:" "Should have task progress section"
    assert_contains "$output" "Completed: 2/5" "Should show completed count"
    assert_contains "$output" "In Progress: 1" "Should show in-progress count"
    assert_contains "$output" "Pending: 2" "Should show pending count"
    assert_contains "$output" "Progress: 40%" "Should show percentage"
}

test_status_multiple_sessions() {
    setup_test_scripts
    
    # Initialize multiple sessions
    feature1="status-multi1-$(date +%Y-%m-%d)"
    feature2="status-multi2-$(date +%Y-%m-%d)"
    feature3="status-multi3-$(date +%Y-%m-%d)"
    
    ./scripts/init-session.sh "$feature1" "First feature"
    ./scripts/init-session.sh "$feature2" "Second feature"
    ./scripts/init-session.sh "$feature3" "Third feature"
    
    # Set different states
    cat > ".ai-session/$feature1/state.yaml" <<EOF
version: "1.0"
feature_id: "$feature1"
current_state:
  active_task: "task-1"
  model_in_use: "opus"
  started_at: "2025-01-09T08:00:00Z"
  last_updated: "2025-01-09T10:00:00Z"
EOF
    
    cat > ".ai-session/$feature2/state.yaml" <<EOF
version: "1.0"
feature_id: "$feature2"
current_state:
  active_task: null
  model_in_use: "sonnet"
  started_at: "2025-01-09T09:00:00Z"
  last_updated: "2025-01-09T11:00:00Z"
EOF
    
    # Update active features
    cat > ".ai-session/active-features.yaml" <<EOF
active_features:
  - feature_id: "$feature1"
    started_at: "2025-01-09T08:00:00Z"
    last_active: "2025-01-09T10:00:00Z"
    status: "active"
  - feature_id: "$feature2"
    started_at: "2025-01-09T09:00:00Z"
    last_active: "2025-01-09T11:00:00Z"
    status: "active"
  - feature_id: "$feature3"
    started_at: "2025-01-09T12:00:00Z"
    last_active: "2025-01-09T12:00:00Z"
    status: "paused"
EOF
    
    # Run status without feature ID (show all)
    output=$(./scripts/status.sh)
    
    # Verify all sessions shown
    assert_contains "$output" "Active Sessions:" "Should show active sessions header"
    assert_contains "$output" "$feature1" "Should show first feature"
    assert_contains "$output" "$feature2" "Should show second feature"
    assert_contains "$output" "$feature3" "Should show third feature"
    assert_contains "$output" "Status: active" "Should show active status"
    assert_contains "$output" "Status: paused" "Should show paused status"
}

test_status_recent_activity() {
    setup_test_scripts
    
    # Initialize session
    feature_id="status-activity-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Mock commands to create recent activity
    mock_command "claude" "mock_claude() {
        echo '{\"status\": \"success\"}'
    }"
    
    # Generate recent commands with timestamps
    ./scripts/implement.sh "$feature_id" --task "morning-task" --no-tests
    sleep 1
    ./scripts/implement.sh "$feature_id" --task "afternoon-task" --no-tests
    sleep 1
    ./scripts/review.sh "$feature_id" --code
    
    # Run status
    output=$(./scripts/status.sh "$feature_id")
    
    # Verify recent activity section
    assert_contains "$output" "Recent Activity:" "Should have recent activity section"
    assert_contains "$output" "review" "Should show most recent command"
    assert_contains "$output" "implement" "Should show implement commands"
    # Should show in reverse chronological order
    
    unmock_command "claude"
}

test_status_no_active_task() {
    setup_test_scripts
    
    # Initialize session without active task
    feature_id="status-notask-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # State with no active task
    cat > ".ai-session/$feature_id/state.yaml" <<EOF
version: "1.0"
feature_id: "$feature_id"
current_state:
  active_task: null
  model_in_use: "sonnet"
  started_at: "2025-01-09T10:00:00Z"
  last_updated: "2025-01-09T10:00:00Z"
EOF
    
    # Run status
    output=$(./scripts/status.sh "$feature_id")
    
    # Verify handling of no active task
    assert_contains "$output" "Active Task: none" "Should show 'none' for no task"
    assert_not_contains "$output" "Active Task: null" "Should not show 'null'"
}

test_status_error_handling() {
    setup_test_scripts
    
    # Test non-existent session
    output=$(./scripts/status.sh "non-existent-feature" 2>&1 || true)
    assert_contains "$output" "Error" "Should show error for missing session"
    assert_contains "$output" "not found" "Should indicate session not found"
    
    # Test corrupted state file
    feature_id="status-corrupt-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Corrupt the state file
    echo "invalid yaml content {" > ".ai-session/$feature_id/state.yaml"
    
    output=$(./scripts/status.sh "$feature_id" 2>&1 || true)
    assert_contains "$output" "Error" "Should handle corrupted state"
}

test_status_performance_metrics() {
    setup_test_scripts
    
    # Initialize session
    feature_id="status-perf-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Generate history with timing data
    for i in {1..5}; do
        cat >> ".ai-session/$feature_id/history.jsonl" <<EOF
{"timestamp":"2025-01-09T10:0$i:00Z","command":"implement","model":"sonnet","status":"success","duration_ms":$((1000 + i * 500))}
EOF
    done
    
    # Run status
    output=$(./scripts/status.sh "$feature_id")
    
    # Verify performance metrics
    assert_contains "$output" "Performance:" "Should have performance section"
    assert_contains "$output" "Avg Duration:" "Should show average duration"
    assert_contains "$output" "Total Time:" "Should show total execution time"
}

test_status_artifact_summary() {
    setup_test_scripts
    
    # Initialize session
    feature_id="status-artifacts-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Create various artifacts
    mkdir -p ".ai-session/$feature_id/artifacts"
    touch ".ai-session/$feature_id/artifacts/api.go"
    touch ".ai-session/$feature_id/artifacts/api_test.go"
    touch ".ai-session/$feature_id/artifacts/database.sql"
    touch ".ai-session/$feature_id/artifacts/README.md"
    mkdir -p ".ai-session/$feature_id/artifacts/docs"
    touch ".ai-session/$feature_id/artifacts/docs/design.md"
    
    # Run status
    output=$(./scripts/status.sh "$feature_id")
    
    # Verify artifact summary
    assert_contains "$output" "Artifacts:" "Should have artifacts section"
    assert_contains "$output" "Total Files: 5" "Should count all files"
    assert_contains "$output" ".go: 2" "Should count Go files"
    assert_contains "$output" ".md: 2" "Should count Markdown files"
    assert_contains "$output" ".sql: 1" "Should count SQL files"
}

test_status_json_output() {
    setup_test_scripts
    
    # Initialize session
    feature_id="status-json-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Set up state
    cat > ".ai-session/$feature_id/state.yaml" <<EOF
version: "1.0"
feature_id: "$feature_id"
current_state:
  active_task: "json-test"
  model_in_use: "opus"
  started_at: "2025-01-09T10:00:00Z"
  last_updated: "2025-01-09T11:00:00Z"
EOF
    
    # Run status with JSON output
    output=$(./scripts/status.sh "$feature_id" --json)
    
    # Verify valid JSON
    if ! echo "$output" | jq empty 2>/dev/null; then
        echo "Invalid JSON output"
        return 1
    fi
    
    # Verify JSON contains expected fields
    feature_id_json=$(echo "$output" | jq -r '.feature_id')
    active_task_json=$(echo "$output" | jq -r '.active_task')
    model_json=$(echo "$output" | jq -r '.model')
    
    assert_equals "$feature_id" "$feature_id_json" "JSON should contain feature ID"
    assert_equals "json-test" "$active_task_json" "JSON should contain active task"
    assert_equals "opus" "$model_json" "JSON should contain model"
}

test_status_session_health() {
    setup_test_scripts
    
    # Initialize session
    feature_id="status-health-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Create a healthy session with recent activity
    cat > ".ai-session/$feature_id/state.yaml" <<EOF
version: "1.0"
feature_id: "$feature_id"
current_state:
  active_task: "health-check"
  model_in_use: "sonnet"
  started_at: "$(date -u -d '2 hours ago' +%Y-%m-%dT%H:%M:%SZ)"
  last_updated: "$(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%SZ)"
EOF
    
    # Add recent history
    cat >> ".ai-session/$feature_id/history.jsonl" <<EOF
{"timestamp":"$(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%SZ)","command":"implement","status":"success"}
EOF
    
    # Run status
    output=$(./scripts/status.sh "$feature_id")
    
    # Verify session health indicators
    assert_contains "$output" "Session Health:" "Should have health section"
    assert_contains "$output" "Active" "Should show active status"
    assert_contains "$output" "Last Activity: 5 minutes ago" "Should show recent activity"
    
    # Create a stale session
    feature_stale="status-stale-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_stale"
    
    cat > ".ai-session/$feature_stale/state.yaml" <<EOF
version: "1.0"
feature_id: "$feature_stale"
current_state:
  active_task: "old-task"
  model_in_use: "sonnet"
  started_at: "$(date -u -d '3 days ago' +%Y-%m-%dT%H:%M:%SZ)"
  last_updated: "$(date -u -d '2 days ago' +%Y-%m-%dT%H:%M:%SZ)"
EOF
    
    output=$(./scripts/status.sh "$feature_stale")
    assert_contains "$output" "Stale" "Should indicate stale session"
}

# Run all tests
echo "Testing status display functionality..."
run_test_scenario "Status basic display" test_status_basic_display
run_test_scenario "Status duration calculation" test_status_duration_calculation
run_test_scenario "Status history summary" test_status_history_summary
run_test_scenario "Status model usage stats" test_status_model_usage_stats
run_test_scenario "Status task progress" test_status_task_progress
run_test_scenario "Status multiple sessions" test_status_multiple_sessions
run_test_scenario "Status recent activity" test_status_recent_activity
run_test_scenario "Status no active task" test_status_no_active_task
run_test_scenario "Status error handling" test_status_error_handling
run_test_scenario "Status performance metrics" test_status_performance_metrics
run_test_scenario "Status artifact summary" test_status_artifact_summary
run_test_scenario "Status JSON output" test_status_json_output
run_test_scenario "Status session health" test_status_session_health