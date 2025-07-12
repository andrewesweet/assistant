#!/bin/bash
# Test: Multiple concurrent sessions don't conflict (simplified)
# Feature: Session state infrastructure
# Scenario: Managing multiple active sessions simultaneously

set -euo pipefail

# Set project root if not already set
if [[ -z "${PROJECT_ROOT:-}" ]]; then
    PROJECT_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
    export PROJECT_ROOT
fi

# Source test harness and utilities
source "$(dirname "$0")/../test-command.sh"
source "$(dirname "$0")/../utils/test_setup.sh"

test_multiple_active_sessions() {
    setup_test_scripts
    # Create multiple sessions
    session1="feature-a-$(date +%Y-%m-%d)"
    session2="feature-b-$(date +%Y-%m-%d)"
    session3="feature-c-$(date +%Y-%m-%d)"
    
    ./scripts/init-session.sh "$session1"
    ./scripts/init-session.sh "$session2"
    ./scripts/init-session.sh "$session3"
    
    # Verify all sessions exist independently
    assert_exists ".ai-session/$session1/state.yaml"
    assert_exists ".ai-session/$session2/state.yaml"
    assert_exists ".ai-session/$session3/state.yaml"
    
    # Verify active features lists all sessions
    active_content=$(cat ".ai-session/active-features.yaml")
    assert_contains "$active_content" "$session1"
    assert_contains "$active_content" "$session2"
    assert_contains "$active_content" "$session3"
}

test_concurrent_state_updates() {
    setup_test_scripts
    # Initialize two sessions
    session1="concurrent-1-$(date +%Y-%m-%d)"
    session2="concurrent-2-$(date +%Y-%m-%d)"
    
    ./scripts/init-session.sh "$session1"
    ./scripts/init-session.sh "$session2"
    
    # Update both states (simplified - no concurrent execution)
    ./scripts/update-session-state.sh "$session1" \
        --task="task-1" \
        --model="gemini"
    
    ./scripts/update-session-state.sh "$session2" \
        --task="task-2" \
        --model="opus"
    
    # Verify both updates succeeded without conflict
    state1=$(cat ".ai-session/$session1/state.yaml")
    state2=$(cat ".ai-session/$session2/state.yaml")
    
    assert_contains "$state1" "active_task: \"task-1\""
    assert_contains "$state1" "model_in_use: \"gemini\""
    assert_contains "$state2" "active_task: \"task-2\""
    assert_contains "$state2" "model_in_use: \"opus\""
}

test_session_isolation() {
    setup_test_scripts
    # Create two sessions with same task names
    session1="isolated-1-$(date +%Y-%m-%d)"
    session2="isolated-2-$(date +%Y-%m-%d)"
    
    ./scripts/init-session.sh "$session1"
    ./scripts/init-session.sh "$session2"
    
    # Update both with same task name
    ./scripts/update-session-state.sh "$session1" --task="implement-feature"
    ./scripts/update-session-state.sh "$session2" --task="implement-feature"
    
    # Create artifacts in both
    echo "Session 1 artifact" > ".ai-session/$session1/artifacts/output.txt"
    echo "Session 2 artifact" > ".ai-session/$session2/artifacts/output.txt"
    
    # Verify isolation
    content1=$(cat ".ai-session/$session1/artifacts/output.txt")
    content2=$(cat ".ai-session/$session2/artifacts/output.txt")
    
    assert_contains "$content1" "Session 1"
    assert_contains "$content2" "Session 2"
    assert_not_equals "$content1" "$content2" "Sessions should be isolated"
}

test_session_list_consistency() {
    setup_test_scripts
    # Create sessions rapidly
    base_time=$(date +%Y-%m-%d-%H%M%S)
    
    for i in {1..3}; do
        ./scripts/init-session.sh "rapid-$i-$base_time"
    done
    
    # List all sessions
    sessions=$(./scripts/list-sessions.sh --active)
    
    # Verify all sessions appear
    for i in {1..3}; do
        assert_contains "$sessions" "rapid-$i-$base_time"
    done
}

# Run all tests
echo "Testing concurrent session management (simplified)..."
run_test_scenario "Multiple active sessions" test_multiple_active_sessions
run_test_scenario "Concurrent state updates" test_concurrent_state_updates
run_test_scenario "Session isolation" test_session_isolation
run_test_scenario "Session list consistency" test_session_list_consistency