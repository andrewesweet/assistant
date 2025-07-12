#!/bin/bash
# Test: Plan command routes to Gemini by default
# Feature: AI Orchestrator Planning Commands
# Scenario: Planning tasks use Gemini model for superior planning capabilities

set -euo pipefail

# Set project root if not already set
if [[ -z "${PROJECT_ROOT:-}" ]]; then
    PROJECT_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
    export PROJECT_ROOT
fi

# Source test harness and utilities
source "$(dirname "$0")/../test-command.sh"
source "$(dirname "$0")/../utils/test_setup.sh"

test_plan_command_routes_to_gemini() {
    setup_test_scripts
    
    # Initialize session
    feature_id="plan-gemini-test-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Mock gemini command to capture invocation
    # Use files to track invocation since subshells can't modify parent variables
    rm -f /tmp/gemini_invoked_$$
    rm -f /tmp/gemini_args_$$
    
    # Create mock script that overrides the real gemini
    create_mock_script "gemini" '
echo "1" > /tmp/gemini_invoked_'$$'
echo "$*" > /tmp/gemini_args_'$$'
echo '"'"'{"status": "success", "plan": "Test plan output"}'"'"'
'
    
    # Execute plan command
    ./scripts/plan.sh "$feature_id" "Create authentication system"
    
    # Verify Gemini was invoked
    mock_gemini_invoked=$(cat /tmp/gemini_invoked_$$ 2>/dev/null || echo "0")
    mock_gemini_args=$(cat /tmp/gemini_args_$$ 2>/dev/null || echo "")
    assert_equals "1" "$mock_gemini_invoked" "Gemini should be invoked for planning"
    assert_contains "$mock_gemini_args" "-p" "Gemini should receive prompt"
    
    # Verify history log shows gemini usage
    history_entry=$(tail -n1 ".ai-session/$feature_id/history.jsonl")
    assert_contains "$history_entry" '"model":"gemini"' "History should record Gemini usage"
    assert_contains "$history_entry" '"command":"plan"' "History should record plan command"
    
    # Verify state updated to show gemini in use
    state_content=$(cat ".ai-session/$feature_id/state.yaml")
    assert_contains "$state_content" 'model_in_use: "gemini"' "State should show Gemini in use"
    
    # Cleanup temp files and mock script
    rm -f /tmp/gemini_invoked_$$ /tmp/gemini_args_$$
    rm -f bin/gemini
}

test_plan_command_with_context_flag() {
    setup_test_scripts
    
    # Initialize session
    feature_id="plan-context-test-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Mock gemini to verify -a flag
    rm -f /tmp/gemini_args_$$
    create_mock_script "gemini" '
echo "$*" > /tmp/gemini_args_'$$'
echo '"'"'{"status": "success", "plan": "Test plan with context"}'"'"'
'
    
    # Execute plan with full context flag
    ./scripts/plan.sh "$feature_id" --full-context "Analyze entire codebase structure"
    
    # Verify -a flag was passed to gemini
    mock_gemini_args=$(cat /tmp/gemini_args_$$ 2>/dev/null || echo "")
    assert_contains "$mock_gemini_args" "-a" "Gemini should receive -a flag for full context"
    rm -f /tmp/gemini_args_$$
    rm -f bin/gemini
}

test_plan_command_prompt_construction() {
    setup_test_scripts
    
    # Initialize session with description
    feature_id="plan-prompt-test-$(date +%Y-%m-%d)"
    description="Build a REST API with authentication"
    ./scripts/init-session.sh "$feature_id" "$description"
    
    # Mock gemini to capture prompt
    rm -f /tmp/gemini_prompt_$$
    create_mock_script "gemini" '
# Extract prompt after -p flag
while [[ $# -gt 0 ]]; do
    if [[ "$1" == "-p" ]]; then
        shift
        echo "$1" > /tmp/gemini_prompt_'$$'
        break
    fi
    shift
done
echo '"'"'{"status": "success", "plan": "Generated plan"}'"'"'
'
    
    # Execute plan command
    ./scripts/plan.sh "$feature_id" "Design authentication flow"
    
    # Verify prompt includes context
    captured_prompt=$(cat /tmp/gemini_prompt_$$ 2>/dev/null || echo "")
    assert_contains "$captured_prompt" "REST API with authentication" "Prompt should include feature description"
    assert_contains "$captured_prompt" "Design authentication flow" "Prompt should include plan request"
    assert_contains "$captured_prompt" "ATDD" "Prompt should mention test-driven approach"
    rm -f /tmp/gemini_prompt_$$
    rm -f bin/gemini
}

test_plan_updates_implementation_plan() {
    setup_test_scripts
    
    # Initialize session
    feature_id="plan-update-test-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Mock gemini with structured plan response
    create_mock_script "gemini" '
cat <<'"'"'EOF'"'"'
{
  "status": "success",
  "plan": {
    "phases": [
      {
        "phase_id": "phase-1",
        "name": "Setup Infrastructure",
        "tasks": [
          {
            "task_id": "task-1-1",
            "description": "Create project structure",
            "agent": "agent-1",
            "status": "pending"
          }
        ]
      }
    ]
  }
}
EOF
'
    
    # Execute plan command
    ./scripts/plan.sh "$feature_id" "Create project structure"
    
    # Verify implementation plan updated
    plan_content=$(cat ".ai-session/$feature_id/implementation-plan.yaml")
    assert_contains "$plan_content" "phase-1" "Plan should contain phase ID"
    assert_contains "$plan_content" "Setup Infrastructure" "Plan should contain phase name"
    assert_contains "$plan_content" "task-1-1" "Plan should contain task ID"
    
    rm -f bin/gemini
}

test_plan_command_error_handling() {
    setup_test_scripts
    
    # Initialize session
    feature_id="plan-error-test-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Mock gemini to simulate error
    create_mock_script "gemini" '
echo "Error: Model unavailable" >&2
exit 1
'
    
    # Also mock claude to succeed (for fallback test)
    create_mock_script "claude" '
# Check for --model opus
for arg in "$@"; do
    if [[ "$arg" == "--model" ]]; then
        next_is_model=1
    elif [[ "$next_is_model" == "1" ]] && [[ "$arg" == "opus" ]]; then
        echo '"'"'{"status": "success", "plan": "Fallback plan from Opus"}'"'"'
        exit 0
    fi
done
echo "Error: Wrong model" >&2
exit 1
'
    
    # Execute plan command and capture result
    set +e
    output=$(./scripts/plan.sh "$feature_id" "Test error handling" 2>&1)
    exit_code=$?
    set -e
    
    # Plan should succeed due to fallback
    assert_equals "0" "$exit_code" "Plan should succeed with Opus fallback"
    assert_contains "$output" "Gemini unavailable" "Should notify about Gemini failure"
    assert_contains "$output" "Using Opus" "Should indicate Opus usage"
    
    # Verify history logs both attempts
    history_content=$(cat ".ai-session/$feature_id/history.jsonl")
    # Check for Gemini failure entry
    gemini_failure=$(grep '"model":"gemini"' ".ai-session/$feature_id/history.jsonl" | grep '"status":"failure"' || echo "")
    assert_not_equals "" "$gemini_failure" "History should record Gemini failure"
    # Check for Opus success entry
    opus_success=$(grep '"model":"opus"' ".ai-session/$feature_id/history.jsonl" | grep '"status":"success"' || echo "")
    assert_not_equals "" "$opus_success" "History should record Opus success"
    
    rm -f bin/gemini bin/claude
}

test_plan_requires_active_session() {
    setup_test_scripts
    
    # Attempt to plan without session
    feature_id="nonexistent-session"
    
    set +e
    output=$(./scripts/plan.sh "$feature_id" "Test planning" 2>&1)
    exit_code=$?
    set -e
    
    # Verify plan rejected without session
    assert_not_equals "0" "$exit_code" "Plan should fail without active session"
    assert_contains "$output" "not found" "Error should mention missing session"
}

test_plan_command_duration_tracking() {
    setup_test_scripts
    
    # Initialize session
    feature_id="plan-duration-test-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Mock gemini with delay
    create_mock_script "gemini" '
sleep 0.1  # 100ms delay
echo '"'"'{"status": "success", "plan": "Test plan"}'"'"'
'
    
    # Execute plan command
    ./scripts/plan.sh "$feature_id" "Test timing"
    
    # Verify duration tracked in history
    history_entry=$(tail -n1 ".ai-session/$feature_id/history.jsonl")
    assert_contains "$history_entry" '"duration_ms"' "History should include duration"
    
    # Extract and verify duration is reasonable (>90ms due to sleep)
    duration=$(echo "$history_entry" | grep -o '"duration_ms":[0-9]*' | cut -d: -f2)
    assert_less_than "90" "$duration" "Duration should reflect execution time"
    
    rm -f bin/gemini
}

test_plan_command_concurrent_execution() {
    setup_test_scripts
    
    # Initialize two sessions
    session1="plan-concurrent-1-$(date +%Y-%m-%d)"
    session2="plan-concurrent-2-$(date +%Y-%m-%d)"
    
    ./scripts/init-session.sh "$session1"
    ./scripts/init-session.sh "$session2"
    
    # Mock gemini to track invocations
    rm -f /tmp/gemini_count_$$
    echo "0" > /tmp/gemini_count_$$
    create_mock_script "gemini" '
count=$(cat /tmp/gemini_count_'$$')
((count++))
echo "$count" > /tmp/gemini_count_'$$'
echo "{\"status\": \"success\", \"plan\": \"Plan $count\"}"
'
    
    # Execute plans for both sessions
    ./scripts/plan.sh "$session1" "Plan for session 1" &
    pid1=$!
    ./scripts/plan.sh "$session2" "Plan for session 2" &
    pid2=$!
    
    # Wait for both to complete
    wait $pid1
    wait $pid2
    
    # Verify both sessions have independent history
    history1=$(tail -n1 ".ai-session/$session1/history.jsonl")
    history2=$(tail -n1 ".ai-session/$session2/history.jsonl")
    
    assert_contains "$history1" "$session1" "History 1 should reference session 1"
    assert_contains "$history2" "$session2" "History 2 should reference session 2"
    assert_not_equals "$history1" "$history2" "Histories should be independent"
    
    # Cleanup
    rm -f /tmp/gemini_count_$$
    
    rm -f bin/gemini
}

# Run all tests
echo "Testing plan command Gemini routing..."
run_test_scenario "Plan routes to Gemini" test_plan_command_routes_to_gemini
run_test_scenario "Plan with context flag" test_plan_command_with_context_flag
run_test_scenario "Plan prompt construction" test_plan_command_prompt_construction
run_test_scenario "Plan updates implementation" test_plan_updates_implementation_plan
run_test_scenario "Plan error handling" test_plan_command_error_handling
run_test_scenario "Plan requires session" test_plan_requires_active_session
run_test_scenario "Plan duration tracking" test_plan_command_duration_tracking
run_test_scenario "Plan concurrent execution" test_plan_command_concurrent_execution