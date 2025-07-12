#!/bin/bash
# Test: Plan command falls back to Opus when Gemini unavailable
# Feature: AI Orchestrator Planning Commands
# Scenario: Graceful fallback to Opus model when Gemini is unavailable

set -euo pipefail

# Set project root if not already set
if [[ -z "${PROJECT_ROOT:-}" ]]; then
    PROJECT_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
    export PROJECT_ROOT
fi

# Source test harness and utilities
source "$(dirname "$0")/../test-command.sh"
source "$(dirname "$0")/../utils/test_setup.sh"

test_plan_fallback_to_opus_on_gemini_failure() {
    setup_test_scripts
    
    # Initialize session
    feature_id="plan-fallback-test-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Track invocation order using files
    rm -f /tmp/gemini_invoked_$$ /tmp/opus_invoked_$$ /tmp/invocation_order_$$
    touch /tmp/invocation_order_$$
    
    # Mock gemini to fail
    create_mock_script "gemini" '
echo "1" > /tmp/gemini_invoked_'$$'
echo -n "gemini," >> /tmp/invocation_order_'$$'
echo "Error: Gemini model unavailable" >&2
exit 1
'
    
    # Mock claude/opus to succeed
    create_mock_script "claude" '
# Check if --model opus is passed
for arg in "$@"; do
    if [[ "$arg" == "--model" ]]; then
        next_is_model=1
    elif [[ "$next_is_model" == "1" ]] && [[ "$arg" == "opus" ]]; then
        echo "1" > /tmp/opus_invoked_'$$'
        echo -n "opus," >> /tmp/invocation_order_'$$'
        echo '"'"'{"status": "success", "plan": "Opus generated plan"}'"'"'
        exit 0
    fi
done
echo "Error: Wrong model" >&2
exit 1
'
    
    # Execute plan command
    output=$(./scripts/plan.sh "$feature_id" "Test fallback behavior" 2>&1)
    exit_code=$?
    
    # Verify fallback occurred
    gemini_invoked=$(cat /tmp/gemini_invoked_$$ 2>/dev/null || echo "0")
    opus_invoked=$(cat /tmp/opus_invoked_$$ 2>/dev/null || echo "0")
    invocation_order=$(cat /tmp/invocation_order_$$ 2>/dev/null || echo "")
    
    assert_equals "0" "$exit_code" "Plan should succeed with Opus fallback"
    assert_equals "1" "$gemini_invoked" "Gemini should be tried first"
    assert_equals "1" "$opus_invoked" "Opus should be used as fallback"
    assert_equals "gemini,opus," "$invocation_order" "Should try Gemini then Opus"
    
    # Verify history shows both attempts
    history_content=$(cat ".ai-session/$feature_id/history.jsonl")
    assert_contains "$history_content" '"model":"gemini"' "History should show Gemini attempt"
    assert_contains "$history_content" '"status":"failure"' "History should show Gemini failure"
    assert_contains "$history_content" '"model":"opus"' "History should show Opus fallback"
    assert_contains "$history_content" '"status":"success"' "History should show Opus success"
    
    # Verify final state shows opus
    state_content=$(cat ".ai-session/$feature_id/state.yaml")
    assert_contains "$state_content" 'model_in_use: "opus"' "State should show Opus in use"
    
    unmock_command "gemini"
    unmock_command "claude"
}

test_plan_fallback_preserves_arguments() {
    setup_test_scripts
    
    # Initialize session
    feature_id="plan-args-test-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Variables to capture arguments
    gemini_args=""
    opus_args=""
    
    # Mock gemini to fail and capture args
    mock_command "gemini" "mock_gemini() {
        gemini_args=\"\$*\"
        return 1
    }"
    
    # Mock claude to capture args
    mock_command "claude" "mock_claude() {
        opus_args=\"\$*\"
        echo '{\"status\": \"success\", \"plan\": \"Test plan\"}'
    }"
    
    # Execute plan with specific arguments
    ./scripts/plan.sh "$feature_id" --full-context "Complex planning task with special requirements"
    
    # Verify arguments preserved in fallback
    assert_contains "$gemini_args" "-a" "Gemini should receive full context flag"
    assert_contains "$gemini_args" "Complex planning task" "Gemini should receive full prompt"
    assert_contains "$opus_args" "Complex planning task" "Opus should receive same prompt"
    assert_contains "$opus_args" "--model opus" "Opus should be specified as model"
    
    unmock_command "gemini"
    unmock_command "claude"
}

test_plan_fallback_with_both_models_failing() {
    setup_test_scripts
    
    # Initialize session
    feature_id="plan-both-fail-test-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Mock both models to fail
    mock_command "gemini" "mock_gemini() {
        echo 'Error: Gemini unavailable' >&2
        return 1
    }"
    
    mock_command "claude" "mock_claude() {
        echo 'Error: Opus also unavailable' >&2
        return 1
    }"
    
    # Execute plan command
    set +e
    output=$(./scripts/plan.sh "$feature_id" "Test both failing" 2>&1)
    exit_code=$?
    set -e
    
    # Verify appropriate error handling
    assert_not_equals "0" "$exit_code" "Plan should fail when both models unavailable"
    assert_contains "$output" "Gemini unavailable" "Should show Gemini error"
    assert_contains "$output" "Opus also unavailable" "Should show Opus error"
    assert_contains "$output" "All models failed" "Should indicate total failure"
    
    # Verify history shows both failures
    history_content=$(cat ".ai-session/$feature_id/history.jsonl")
    gemini_failures=$(grep -c '"model":"gemini".*"status":"failure"' ".ai-session/$feature_id/history.jsonl" || true)
    opus_failures=$(grep -c '"model":"opus".*"status":"failure"' ".ai-session/$feature_id/history.jsonl" || true)
    
    assert_equals "1" "$gemini_failures" "Should log Gemini failure"
    assert_equals "1" "$opus_failures" "Should log Opus failure"
    
    unmock_command "gemini"
    unmock_command "claude"
}

test_plan_explicit_model_selection() {
    setup_test_scripts
    
    # Initialize session
    feature_id="plan-explicit-test-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Track what gets invoked
    gemini_invoked=0
    opus_invoked=0
    
    # Mock both models
    mock_command "gemini" "mock_gemini() {
        gemini_invoked=1
        echo '{\"status\": \"success\", \"plan\": \"Gemini plan\"}'
    }"
    
    mock_command "claude" "mock_claude() {
        if [[ \"\$*\" == *\"--model opus\"* ]]; then
            opus_invoked=1
            echo '{\"status\": \"success\", \"plan\": \"Opus plan\"}'
        fi
    }"
    
    # Execute plan with explicit opus selection
    ./scripts/plan.sh "$feature_id" --model opus "Use opus explicitly"
    
    # Verify only opus was invoked
    assert_equals "0" "$gemini_invoked" "Gemini should not be invoked with explicit model"
    assert_equals "1" "$opus_invoked" "Opus should be invoked when explicitly selected"
    
    # Verify history shows direct opus usage
    history_entry=$(tail -n1 ".ai-session/$feature_id/history.jsonl")
    assert_contains "$history_entry" '"model":"opus"' "History should show Opus usage"
    assert_not_contains "$history_entry" "gemini" "History should not mention Gemini"
    
    unmock_command "gemini"
    unmock_command "claude"
}

test_plan_fallback_notification() {
    setup_test_scripts
    
    # Initialize session
    feature_id="plan-notify-test-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Mock gemini to fail
    mock_command "gemini" "mock_gemini() {
        echo 'Connection timeout' >&2
        return 1
    }"
    
    # Mock claude to succeed
    mock_command "claude" "mock_claude() {
        echo '{\"status\": \"success\", \"plan\": \"Fallback plan\"}'
    }"
    
    # Execute plan and capture output
    output=$(./scripts/plan.sh "$feature_id" "Test notifications" 2>&1)
    
    # Verify user notified of fallback
    assert_contains "$output" "Gemini unavailable" "Should notify of Gemini failure"
    assert_contains "$output" "Falling back to Opus" "Should notify of fallback"
    assert_contains "$output" "Using Opus model" "Should confirm Opus usage"
    
    unmock_command "gemini"
    unmock_command "claude"
}

test_plan_fallback_performance_tracking() {
    setup_test_scripts
    
    # Initialize session
    feature_id="plan-perf-test-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Mock gemini with delay then fail
    mock_command "gemini" "mock_gemini() {
        sleep 0.2  # 200ms delay
        return 1
    }"
    
    # Mock claude with different delay
    mock_command "claude" "mock_claude() {
        sleep 0.1  # 100ms delay
        echo '{\"status\": \"success\", \"plan\": \"Plan output\"}'
    }"
    
    # Execute plan
    start_time=$(date +%s%N)
    ./scripts/plan.sh "$feature_id" "Test performance"
    end_time=$(date +%s%N)
    
    # Calculate total duration in milliseconds
    total_duration=$(( (end_time - start_time) / 1000000 ))
    
    # Verify both attempts are tracked
    history_content=$(cat ".ai-session/$feature_id/history.jsonl")
    
    # Extract durations from history
    gemini_duration=$(echo "$history_content" | grep '"model":"gemini"' | grep -o '"duration_ms":[0-9]*' | cut -d: -f2)
    opus_duration=$(echo "$history_content" | grep '"model":"opus"' | grep -o '"duration_ms":[0-9]*' | cut -d: -f2)
    
    # Verify reasonable durations
    assert_less_than "180" "$gemini_duration" "Gemini duration should be tracked"
    assert_less_than "80" "$opus_duration" "Opus duration should be tracked"
    assert_less_than "280" "$total_duration" "Total should reflect both attempts"
    
    unmock_command "gemini"
    unmock_command "claude"
}

test_plan_fallback_preserves_session_context() {
    setup_test_scripts
    
    # Initialize session with existing context
    feature_id="plan-context-preserve-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id" "E-commerce platform with microservices"
    
    # Set initial state
    ./scripts/update-session-state.sh "$feature_id" --task "design-api"
    
    # Mock gemini to fail
    mock_command "gemini" "mock_gemini() { return 1; }"
    
    # Mock claude to succeed
    captured_prompt=""
    mock_command "claude" "mock_claude() {
        # Capture the prompt to verify context preserved
        while [[ \$# -gt 0 ]]; do
            if [[ \"\$1\" == \"-p\" ]]; then
                shift
                captured_prompt=\"\$1\"
                break
            fi
            shift
        done
        echo '{\"status\": \"success\", \"plan\": \"Context-aware plan\"}'
    }"
    
    # Execute plan
    ./scripts/plan.sh "$feature_id" "Design authentication service"
    
    # Verify context preserved in fallback
    assert_contains "$captured_prompt" "E-commerce platform" "Context should be preserved"
    assert_contains "$captured_prompt" "design-api" "Active task should be included"
    assert_contains "$captured_prompt" "authentication service" "New request should be included"
    
    unmock_command "gemini"
    unmock_command "claude"
}

test_plan_fallback_retry_logic() {
    setup_test_scripts
    
    # Initialize session
    feature_id="plan-retry-test-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Track retry attempts
    gemini_attempts=0
    
    # Mock gemini with intermittent failure
    mock_command "gemini" "mock_gemini() {
        ((gemini_attempts++))
        if [[ \$gemini_attempts -lt 3 ]]; then
            echo 'Temporary failure' >&2
            return 1
        fi
        echo '{\"status\": \"success\", \"plan\": \"Success after retries\"}'
    }"
    
    # Mock claude (should not be called if retry succeeds)
    opus_invoked=0
    mock_command "claude" "mock_claude() {
        opus_invoked=1
        echo '{\"status\": \"success\", \"plan\": \"Opus plan\"}'
    }"
    
    # Execute plan with retry enabled
    ./scripts/plan.sh "$feature_id" --retry "Test retry logic"
    
    # Verify retry behavior
    assert_equals "3" "$gemini_attempts" "Should retry Gemini before fallback"
    assert_equals "0" "$opus_invoked" "Should not fall back if retry succeeds"
    
    unmock_command "gemini"
    unmock_command "claude"
}

# Run all tests
echo "Testing plan command Opus fallback..."
run_test_scenario "Plan fallback to Opus" test_plan_fallback_to_opus_on_gemini_failure
run_test_scenario "Plan fallback preserves args" test_plan_fallback_preserves_arguments
run_test_scenario "Plan both models failing" test_plan_fallback_with_both_models_failing
run_test_scenario "Plan explicit model selection" test_plan_explicit_model_selection
run_test_scenario "Plan fallback notification" test_plan_fallback_notification
run_test_scenario "Plan fallback performance" test_plan_fallback_performance_tracking
run_test_scenario "Plan fallback context" test_plan_fallback_preserves_session_context
run_test_scenario "Plan fallback retry logic" test_plan_fallback_retry_logic