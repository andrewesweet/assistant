#!/bin/bash
# Test: Initialize new session
# Feature: Session state infrastructure
# Scenario: Creating and initializing new feature sessions

set -euo pipefail

# Set project root if not already set
if [[ -z "${PROJECT_ROOT:-}" ]]; then
    PROJECT_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
    export PROJECT_ROOT
fi

# Source test harness and utilities
source "$(dirname "$0")/../test-command.sh"
source "$(dirname "$0")/../utils/test_setup.sh"

test_init_basic_session() {
    setup_test_scripts
    # Execute session initialization
    feature_id="test-feature-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Verify directory structure created
    assert_exists ".ai-session/$feature_id"
    assert_exists ".ai-session/$feature_id/implementation-plan.yaml"
    assert_exists ".ai-session/$feature_id/history.jsonl"
    assert_exists ".ai-session/$feature_id/state.yaml"
    assert_exists ".ai-session/$feature_id/artifacts"
    
    # Verify session added to active features
    assert_file_contains ".ai-session/active-features.yaml" "$feature_id"
}

test_init_session_state_format() {
    setup_test_scripts
    # Initialize session
    feature_id="state-test-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Verify state.yaml format matches contract
    assert_yaml_valid ".ai-session/$feature_id/state.yaml"
    
    # Check required fields
    state_content=$(cat ".ai-session/$feature_id/state.yaml")
    assert_contains "$state_content" "version: \"1.0\""
    assert_contains "$state_content" "feature_id: \"$feature_id\""
    assert_contains "$state_content" "active_task: null"
    assert_contains "$state_content" "model_in_use:"
    assert_contains "$state_content" "started_at:"
    assert_contains "$state_content" "last_updated:"
}

test_init_duplicate_session() {
    setup_test_scripts
    # Create first session
    feature_id="duplicate-test-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Attempt to create duplicate
    set +e
    output=$(./scripts/init-session.sh "$feature_id" 2>&1)
    exit_code=$?
    set -e
    
    # Verify duplicate is rejected
    assert_not_equals "0" "$exit_code" "Duplicate session should fail"
    assert_contains "$output" "already exists"
}

test_init_session_with_description() {
    setup_test_scripts
    # Initialize with description
    feature_id="described-$(date +%Y-%m-%d)"
    description="Test feature with description"
    ./scripts/init-session.sh "$feature_id" "$description"
    
    # Verify description is stored
    plan_content=$(cat ".ai-session/$feature_id/implementation-plan.yaml")
    assert_contains "$plan_content" "$description"
}

test_init_invalid_feature_id() {
    setup_test_scripts
    # Test various invalid feature IDs
    invalid_ids=("test feature" "test/feature" "TEST-FEATURE" "test.feature" "")
    
    for invalid_id in "${invalid_ids[@]}"; do
        set +e  # Temporarily disable exit on error
        output=$(./scripts/init-session.sh "$invalid_id" 2>&1)
        exit_code=$?
        set -e  # Re-enable exit on error
        
        assert_not_equals "0" "$exit_code" "Invalid ID '$invalid_id' should fail"
        assert_contains "$output" "Error: Invalid feature ID"
    done
}

test_init_session_permissions() {
    setup_test_scripts
    # Initialize session
    feature_id="perms-test-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Check directory permissions
    dir_perms=$(stat -c %a ".ai-session/$feature_id" 2>/dev/null || stat -f %A ".ai-session/$feature_id")
    
    # Verify appropriate permissions (owner rwx)
    assert_contains "$dir_perms" "7" "Owner should have full permissions"
}

test_init_session_atomic() {
    setup_test_scripts
    # Setup - Create session init that will fail partway
    feature_id="atomic-test-$(date +%Y-%m-%d)"
    
    # Pre-create artifacts dir to cause failure
    mkdir -p ".ai-session/$feature_id/artifacts"
    touch ".ai-session/$feature_id/artifacts/blocker"
    
    # Attempt initialization
    output=$(./scripts/init-session.sh "$feature_id" 2>&1 || true)
    
    # Verify no partial state remains
    if [[ -d ".ai-session/$feature_id" ]]; then
        # Should either be completely initialized or unchanged
        assert_exists ".ai-session/$feature_id/artifacts/blocker" "Pre-existing state should remain"
        assert_not_exists ".ai-session/$feature_id/state.yaml" "Partial init should not occur"
    fi
}

test_init_session_timestamp_format() {
    setup_test_scripts
    # Initialize session
    feature_id="timestamp-test-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Extract timestamps
    state_yaml=".ai-session/$feature_id/state.yaml"
    started_at=$(grep "started_at:" "$state_yaml" | cut -d'"' -f2)
    last_updated=$(grep "last_updated:" "$state_yaml" | cut -d'"' -f2)
    
    # Verify ISO 8601 format
    assert_contains "$started_at" "T" "Should be ISO 8601 format"
    assert_contains "$started_at" "Z" "Should be UTC timezone"
    
    # Verify timestamps are recent (within last minute)
    current_timestamp=$(date -u +%Y-%m-%dT%H:%M)
    assert_contains "$started_at" "$current_timestamp" "Timestamp should be recent"
}

test_init_creates_readme() {
    setup_test_scripts
    # Initialize session
    feature_id="readme-test-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Verify README created if not exists
    if [[ ! -f ".ai-session/README.md" ]]; then
        assert_exists ".ai-session/README.md" "Session README should be created"
    fi
    
    # Verify README contains basic info
    assert_file_contains ".ai-session/README.md" "AI Orchestrator Session"
}

# Run all tests
echo "Testing session initialization..."
run_test_scenario "Init basic session" test_init_basic_session
run_test_scenario "Init session state format" test_init_session_state_format
run_test_scenario "Init duplicate session" test_init_duplicate_session
run_test_scenario "Init session with description" test_init_session_with_description
run_test_scenario "Init invalid feature ID" test_init_invalid_feature_id
run_test_scenario "Init session permissions" test_init_session_permissions
run_test_scenario "Init session atomic" test_init_session_atomic
run_test_scenario "Init session timestamp format" test_init_session_timestamp_format
run_test_scenario "Init creates README" test_init_creates_readme