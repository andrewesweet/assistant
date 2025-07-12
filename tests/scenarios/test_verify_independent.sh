#!/bin/bash
# Test: Verify command uses fresh agent with no prior context
# Feature: AI Orchestrator Verification System
# Scenario: Verify commands run with independent context for accurate testing

set -euo pipefail

# Set project root if not already set
if [[ -z "${PROJECT_ROOT:-}" ]]; then
    PROJECT_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
    export PROJECT_ROOT
fi

# Source test harness and utilities
source "$(dirname "$0")/../test-command.sh"
source "$(dirname "$0")/../utils/test_setup.sh"

test_verify_fresh_agent_context() {
    setup_test_scripts
    
    # Initialize session with multiple commands in history
    feature_id="verify-fresh-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Mock commands to track context
    mock_command "claude" "mock_claude() {
        # Echo any context references we see
        if [[ \"\${ARGUMENTS}\" == *\"previous\"* ]] || [[ \"\${ARGUMENTS}\" == *\"context\"* ]]; then
            echo '{\"error\": \"Found context reference in verify\"}'
            return 1
        fi
        echo '{\"status\": \"tests_passed\"}'
    }"
    
    # First, execute some commands to build up context
    ./scripts/implement.sh "$feature_id" --task "build-context" --no-tests
    ./scripts/implement.sh "$feature_id" --task "more-context" --no-tests
    
    # Update session state to have active task
    cat > ".ai-session/$feature_id/state.yaml" <<EOF
version: "1.0"
feature_id: "$feature_id"
current_state:
  active_task: "verify-tests"
  model_in_use: "sonnet"
  started_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  last_updated: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
EOF
    
    # Now run verify - it should NOT have any prior context
    ./scripts/verify.sh "$feature_id" --all
    
    # Check that verify logged its fresh context
    history_entry=$(tail -n1 ".ai-session/$feature_id/history.jsonl")
    assert_contains "$history_entry" '"command":"verify"' "Should log verify command"
    assert_contains "$history_entry" '"fresh_context":true' "Should indicate fresh context"
    
    unmock_command "claude"
}

test_verify_no_state_references() {
    setup_test_scripts
    
    # Initialize session with complex state
    feature_id="verify-nostate-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Create implementation plan with multiple phases
    cat > ".ai-session/$feature_id/implementation-plan.yaml" <<EOF
feature:
  id: "$feature_id"
  name: "Complex Feature"
phases:
  - phase_id: "phase-1"
    tasks:
      - task_id: "api-service"
        status: "completed"
        artifacts: ["api.go", "api_test.go"]
      - task_id: "database"
        status: "in_progress"
        artifacts: ["db.go"]
EOF
    
    # Mock verify to check for state references
    mock_command "claude" "mock_claude() {
        # The prompt should NOT contain session state info
        if [[ \"\${ARGUMENTS}\" == *\"api-service\"* ]] || [[ \"\${ARGUMENTS}\" == *\"in_progress\"* ]]; then
            echo '{\"error\": \"Session state leaked into verify\"}'
            return 1
        fi
        echo '{\"status\": \"tests_passed\", \"results\": {\"passed\": 10, \"failed\": 0}}'
    }"
    
    # Run verify
    ./scripts/verify.sh "$feature_id" --unit
    exit_code=$?
    
    assert_equals "0" "$exit_code" "Verify should succeed without state references"
    
    unmock_command "claude"
}

test_verify_multiple_concurrent_sessions() {
    setup_test_scripts
    
    # Initialize multiple sessions
    feature1="verify-multi1-$(date +%Y-%m-%d)"
    feature2="verify-multi2-$(date +%Y-%m-%d)"
    feature3="verify-multi3-$(date +%Y-%m-%d)"
    
    ./scripts/init-session.sh "$feature1"
    ./scripts/init-session.sh "$feature2"
    ./scripts/init-session.sh "$feature3"
    
    # Set different states for each
    for feature in "$feature1" "$feature2" "$feature3"; do
        cat > ".ai-session/$feature/state.yaml" <<EOF
version: "1.0"
feature_id: "$feature"
current_state:
  active_task: "task-$feature"
  model_in_use: "sonnet"
  started_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  last_updated: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
EOF
    done
    
    # Mock verify to ensure no cross-contamination
    mock_command "claude" "mock_claude() {
        # Check that we don't see other feature IDs
        for check_feature in \"$feature1\" \"$feature2\" \"$feature3\"; do
            if [[ \"\$check_feature\" != \"\$CURRENT_FEATURE\" ]] && [[ \"\${ARGUMENTS}\" == *\"\$check_feature\"* ]]; then
                echo '{\"error\": \"Cross-session contamination detected\"}'
                return 1
            fi
        done
        echo '{\"status\": \"tests_passed\"}'
    }"
    
    # Run verify on each concurrently
    export CURRENT_FEATURE="$feature1"
    ./scripts/verify.sh "$feature1" --all &
    pid1=$!
    
    export CURRENT_FEATURE="$feature2"
    ./scripts/verify.sh "$feature2" --all &
    pid2=$!
    
    export CURRENT_FEATURE="$feature3"
    ./scripts/verify.sh "$feature3" --all &
    pid3=$!
    
    # Wait for all to complete
    wait $pid1 $pid2 $pid3
    
    # Verify each had independent execution
    for feature in "$feature1" "$feature2" "$feature3"; do
        history_entry=$(grep '"command":"verify"' ".ai-session/$feature/history.jsonl" | tail -n1)
        assert_contains "$history_entry" '"fresh_context":true' "Each verify should be independent"
    done
    
    unmock_command "claude"
}

test_verify_no_history_context() {
    setup_test_scripts
    
    # Initialize session with rich history
    feature_id="verify-nohistory-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Mock commands to build history
    mock_command "gemini" "mock_gemini() {
        echo '{\"status\": \"success\", \"plan\": \"Complex architecture\"}'
    }"
    mock_command "claude" "mock_claude() {
        echo '{\"status\": \"success\"}'
    }"
    
    # Execute various commands to build history
    ./scripts/plan.sh "$feature_id" "Design microservices"
    ./scripts/implement.sh "$feature_id" --task "service-a" --no-tests
    ./scripts/implement.sh "$feature_id" --task "service-b" --no-tests
    ./scripts/review.sh "$feature_id" --code
    
    # Now mock verify to check it doesn't see history
    mock_command "claude" "mock_claude() {
        # Should not see any previous command details
        if [[ \"\${ARGUMENTS}\" == *\"microservices\"* ]] || \
           [[ \"\${ARGUMENTS}\" == *\"service-a\"* ]] || \
           [[ \"\${ARGUMENTS}\" == *\"service-b\"* ]]; then
            echo '{\"error\": \"History context leaked into verify\"}'
            return 1
        fi
        echo '{\"status\": \"tests_passed\"}'
    }"
    
    # Run verify
    ./scripts/verify.sh "$feature_id" --integration
    exit_code=$?
    
    assert_equals "0" "$exit_code" "Verify should not have history context"
    
    unmock_command "gemini"
    unmock_command "claude"
}

test_verify_isolated_test_discovery() {
    setup_test_scripts
    
    # Initialize session
    feature_id="verify-discovery-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Create test files in artifacts
    mkdir -p ".ai-session/$feature_id/artifacts"
    echo "package main" > ".ai-session/$feature_id/artifacts/main_test.go"
    echo "def test_feature():" > ".ai-session/$feature_id/artifacts/test_feature.py"
    echo "describe('Feature'," > ".ai-session/$feature_id/artifacts/feature.spec.js"
    
    # Mock verify to check test discovery
    mock_command "claude" "mock_claude() {
        # Should discover tests independently
        echo '{\"status\": \"success\", \"discovered_tests\": [\"main_test.go\", \"test_feature.py\", \"feature.spec.js\"]}'
    }"
    
    # Run verify
    output=$(./scripts/verify.sh "$feature_id" --discover)
    
    # Check that tests were discovered fresh
    assert_contains "$output" "Discovering tests with fresh context"
    assert_contains "$output" "main_test.go"
    assert_contains "$output" "test_feature.py"
    assert_contains "$output" "feature.spec.js"
    
    unmock_command "claude"
}

test_verify_agent_identifier_unique() {
    setup_test_scripts
    
    # Initialize session
    feature_id="verify-agent-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Track agent IDs used
    agent_ids_file="/tmp/verify_agent_ids.txt"
    : > "$agent_ids_file"
    
    # Mock to capture agent IDs
    mock_command "claude" "mock_claude() {
        # Extract and save agent ID from prompt
        if [[ \"\${ARGUMENTS}\" =~ agent[[:space:]]*:[[:space:]]*([^[:space:]]+) ]]; then
            echo \"\${BASH_REMATCH[1]}\" >> \"$agent_ids_file\"
        fi
        echo '{\"status\": \"tests_passed\"}'
    }"
    
    # Run verify multiple times
    for i in {1..3}; do
        ./scripts/verify.sh "$feature_id" --unit
    done
    
    # Check that each verify had a unique agent ID
    agent_count=$(wc -l < "$agent_ids_file")
    unique_count=$(sort -u "$agent_ids_file" | wc -l)
    
    assert_equals "$agent_count" "$unique_count" "Each verify should have unique agent ID"
    assert_equals "3" "$unique_count" "Should have 3 unique agent IDs"
    
    unmock_command "claude"
}

test_verify_clean_environment() {
    setup_test_scripts
    
    # Initialize session with environment variables
    feature_id="verify-cleanenv-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Set session-specific environment
    export SESSION_VAR="should-not-leak"
    export FEATURE_CONTEXT="$feature_id-context"
    
    # Mock verify to check environment
    mock_command "claude" "mock_claude() {
        # Check for leaked environment
        env_dump=\$(env)
        if [[ \"\$env_dump\" == *\"SESSION_VAR\"* ]] || [[ \"\$env_dump\" == *\"FEATURE_CONTEXT\"* ]]; then
            echo '{\"error\": \"Environment variables leaked into verify\"}'
            return 1
        fi
        echo '{\"status\": \"tests_passed\"}'
    }"
    
    # Run verify
    ./scripts/verify.sh "$feature_id" --all
    exit_code=$?
    
    assert_equals "0" "$exit_code" "Verify should have clean environment"
    
    # Cleanup
    unset SESSION_VAR FEATURE_CONTEXT
    unmock_command "claude"
}

test_verify_error_independence() {
    setup_test_scripts
    
    # Initialize session
    feature_id="verify-error-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # First verify fails
    mock_command "claude" "mock_claude() {
        echo '{\"status\": \"tests_failed\", \"failed\": 5}'
        return 1
    }"
    
    set +e
    ./scripts/verify.sh "$feature_id" --unit
    first_exit=$?
    set -e
    
    assert_not_equals "0" "$first_exit" "First verify should fail"
    
    # Second verify should not be affected by first failure
    mock_command "claude" "mock_claude() {
        # Should not see any indication of previous failure
        if [[ \"\${ARGUMENTS}\" == *\"failed\"* ]] || [[ \"\${ARGUMENTS}\" == *\"retry\"* ]]; then
            echo '{\"error\": \"Previous failure context leaked\"}'
            return 1
        fi
        echo '{\"status\": \"tests_passed\"}'
    }"
    
    ./scripts/verify.sh "$feature_id" --unit
    second_exit=$?
    
    assert_equals "0" "$second_exit" "Second verify should succeed independently"
    
    unmock_command "claude"
}

test_verify_parallel_independence() {
    setup_test_scripts
    
    # Initialize session
    feature_id="verify-parallel-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Create a flag file to track parallel execution
    parallel_flag="/tmp/verify_parallel_$(date +%s).flag"
    
    # Mock that delays to test parallel execution
    mock_command "claude" "mock_claude() {
        # Mark that we're running
        echo \"\$\$\" >> \"$parallel_flag\"
        
        # Small delay to ensure overlap
        sleep 0.1
        
        # Count concurrent processes
        concurrent=\$(wc -l < \"$parallel_flag\")
        
        # Each should run independently
        echo '{\"status\": \"tests_passed\", \"concurrent\": '\"$concurrent\"'}'
    }"
    
    # Run multiple verifies in parallel
    : > "$parallel_flag"
    
    ./scripts/verify.sh "$feature_id" --unit &
    ./scripts/verify.sh "$feature_id" --integration &
    ./scripts/verify.sh "$feature_id" --acceptance &
    
    # Wait for all
    wait
    
    # Check that they ran concurrently
    process_count=$(wc -l < "$parallel_flag")
    assert_equals "3" "$process_count" "Should have 3 parallel verify processes"
    
    # Cleanup
    rm -f "$parallel_flag"
    unmock_command "claude"
}

test_verify_no_artifact_sharing() {
    setup_test_scripts
    
    # Initialize two sessions
    feature1="verify-artifacts1-$(date +%Y-%m-%d)"
    feature2="verify-artifacts2-$(date +%Y-%m-%d)"
    
    ./scripts/init-session.sh "$feature1"
    ./scripts/init-session.sh "$feature2"
    
    # Create different artifacts in each
    mkdir -p ".ai-session/$feature1/artifacts"
    mkdir -p ".ai-session/$feature2/artifacts"
    
    echo "Feature 1 test" > ".ai-session/$feature1/artifacts/test.go"
    echo "Feature 2 test" > ".ai-session/$feature2/artifacts/test.go"
    
    # Mock verify to check artifact isolation
    mock_command "claude" "mock_claude() {
        # Should only see artifacts from current feature
        artifact_content=\$(cat \".ai-session/\$VERIFY_FEATURE/artifacts/test.go\" 2>/dev/null || echo \"missing\")
        
        if [[ \"\$VERIFY_FEATURE\" == \"$feature1\" ]] && [[ \"\$artifact_content\" != \"Feature 1 test\" ]]; then
            echo '{\"error\": \"Wrong artifacts accessed\"}'
            return 1
        fi
        if [[ \"\$VERIFY_FEATURE\" == \"$feature2\" ]] && [[ \"\$artifact_content\" != \"Feature 2 test\" ]]; then
            echo '{\"error\": \"Wrong artifacts accessed\"}'
            return 1
        fi
        
        echo '{\"status\": \"tests_passed\"}'
    }"
    
    # Verify each feature
    export VERIFY_FEATURE="$feature1"
    ./scripts/verify.sh "$feature1" --all
    
    export VERIFY_FEATURE="$feature2"
    ./scripts/verify.sh "$feature2" --all
    
    unset VERIFY_FEATURE
    unmock_command "claude"
}

# Run all tests
echo "Testing verify command independence..."
run_test_scenario "Verify fresh agent context" test_verify_fresh_agent_context
run_test_scenario "Verify no state references" test_verify_no_state_references
run_test_scenario "Verify multiple concurrent sessions" test_verify_multiple_concurrent_sessions
run_test_scenario "Verify no history context" test_verify_no_history_context
run_test_scenario "Verify isolated test discovery" test_verify_isolated_test_discovery
run_test_scenario "Verify agent identifier unique" test_verify_agent_identifier_unique
run_test_scenario "Verify clean environment" test_verify_clean_environment
run_test_scenario "Verify error independence" test_verify_error_independence
run_test_scenario "Verify parallel independence" test_verify_parallel_independence
run_test_scenario "Verify no artifact sharing" test_verify_no_artifact_sharing