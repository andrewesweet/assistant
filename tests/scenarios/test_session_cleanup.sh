#!/bin/bash
# Test: Session cleanup functionality (simplified)
# Feature: Session state infrastructure
# Scenario: Cleaning up completed and stale sessions

set -euo pipefail

# Set project root if not already set
if [[ -z "${PROJECT_ROOT:-}" ]]; then
    PROJECT_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
    export PROJECT_ROOT
fi

# Source test harness and utilities
source "$(dirname "$0")/../test-command.sh"
source "$(dirname "$0")/../utils/test_setup.sh"

test_cleanup_completed_sessions() {
    setup_test_scripts
    # Create multiple sessions with different statuses
    active="cleanup-active-$(date +%Y-%m-%d)"
    completed="cleanup-completed-$(date +%Y-%m-%d)"
    
    ./scripts/init-session.sh "$active"
    ./scripts/init-session.sh "$completed"
    
    # Update statuses - add status field to state file
    echo "  status: \"completed\"" >> ".ai-session/$completed/state.yaml"
    
    # Run cleanup for completed only
    ./scripts/cleanup-sessions.sh --completed
    
    # Verify only completed removed
    assert_exists ".ai-session/$active"
    assert_not_exists ".ai-session/$completed"
}

test_cleanup_dry_run() {
    setup_test_scripts
    # Create sessions to cleanup
    session1="dry-run-1-$(date +%Y-%m-%d)"
    session2="dry-run-2-$(date +%Y-%m-%d)"
    
    ./scripts/init-session.sh "$session1"
    ./scripts/init-session.sh "$session2"
    
    # Mark for cleanup
    echo "  status: \"completed\"" >> ".ai-session/$session1/state.yaml"
    echo "  status: \"completed\"" >> ".ai-session/$session2/state.yaml"
    
    # Run cleanup in dry-run mode
    output=$(./scripts/cleanup-sessions.sh --completed --dry-run)
    
    # Verify sessions still exist
    assert_exists ".ai-session/$session1"
    assert_exists ".ai-session/$session2"
    
    # Verify dry-run output
    assert_contains "$output" "Would remove: $session1"
    assert_contains "$output" "Would remove: $session2"
}

test_cleanup_empty_sessions() {
    setup_test_scripts
    # Create empty session (no history, no artifacts)
    empty="empty-session-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$empty"
    
    # Create session with content
    active="active-session-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$active"
    echo "content" > ".ai-session/$active/artifacts/file.txt"
    
    # Cleanup empty sessions
    ./scripts/cleanup-sessions.sh --empty
    
    # Verify only empty removed
    assert_not_exists ".ai-session/$empty"
    assert_exists ".ai-session/$active"
}

test_cleanup_active_features_sync() {
    setup_test_scripts
    # Create sessions
    keep="keep-session-$(date +%Y-%m-%d)"
    remove="remove-session-$(date +%Y-%m-%d)"
    
    ./scripts/init-session.sh "$keep"
    ./scripts/init-session.sh "$remove"
    
    # Verify both in active features
    assert_file_contains ".ai-session/active-features.yaml" "$keep"
    assert_file_contains ".ai-session/active-features.yaml" "$remove"
    
    # Mark one as completed and cleanup
    echo "  status: \"completed\"" >> ".ai-session/$remove/state.yaml"
    ./scripts/cleanup-sessions.sh --completed
    
    # Verify active features updated
    active_content=$(cat ".ai-session/active-features.yaml")
    assert_contains "$active_content" "$keep"
    assert_not_contains "$active_content" "$remove"
}

# Run all tests
echo "Testing session cleanup (simplified)..."
run_test_scenario "Cleanup completed sessions" test_cleanup_completed_sessions
run_test_scenario "Cleanup dry run" test_cleanup_dry_run
run_test_scenario "Cleanup empty sessions" test_cleanup_empty_sessions
run_test_scenario "Cleanup active features sync" test_cleanup_active_features_sync