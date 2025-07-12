#!/bin/bash
# Test: Review commands history logging
# Feature: AI Orchestrator Review Commands
# Scenario: All review commands log comprehensive history with context and findings

set -euo pipefail

# Set project root if not already set
if [[ -z "${PROJECT_ROOT:-}" ]]; then
    PROJECT_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
    export PROJECT_ROOT
fi

# Source test harness and utilities
source "$(dirname "$0")/../test-command.sh"
source "$(dirname "$0")/../utils/test_setup.sh"

test_review_history_basic_logging() {
    setup_test_scripts
    
    # Initialize session
    feature_id="review-history-basic-test-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Create test file
    mkdir -p src
    echo "package main" > src/test.go
    
    # Mock claude for review
    mock_command "claude" "mock_claude() {
        echo '{\"status\": \"success\", \"review\": \"Basic review\"}'
    }"
    
    # Execute review-code command
    start_time=$(date +%s%N)
    ./scripts/review-code.sh "$feature_id" "src/test.go"
    end_time=$(date +%s%N)
    
    # Verify history entry created
    history_file=".ai-session/$feature_id/history.jsonl"
    assert_exists "$history_file" "History file should exist"
    
    # Parse last history entry
    history_entry=$(tail -n1 "$history_file")
    assert_json_valid <(echo "$history_entry") "History entry should be valid JSON"
    
    # Verify required fields
    assert_contains "$history_entry" '"timestamp"' "History should have timestamp"
    assert_contains "$history_entry" '"command":"review-code"' "History should record command"
    assert_contains "$history_entry" '"arguments":"src/test.go"' "History should record arguments"
    assert_contains "$history_entry" '"model":"opus"' "History should record model used"
    assert_contains "$history_entry" '"status":"success"' "History should record status"
    assert_contains "$history_entry" '"duration_ms"' "History should record duration"
    
    # Verify timestamp is recent
    timestamp=$(echo "$history_entry" | grep -o '"timestamp":"[^"]*"' | cut -d'"' -f4)
    timestamp_epoch=$(date -d "$timestamp" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$timestamp" +%s)
    current_epoch=$(date +%s)
    time_diff=$((current_epoch - timestamp_epoch))
    assert_less_than "$time_diff" "5" "Timestamp should be within 5 seconds"
    
    unmock_command "claude"
}

test_review_history_context_capture() {
    setup_test_scripts
    
    # Initialize session with description
    feature_id="review-history-context-test-$(date +%Y-%m-%d)"
    description="Implement secure authentication system"
    ./scripts/init-session.sh "$feature_id" "$description"
    
    # Create test files
    mkdir -p src/auth
    cat > src/auth/login.go <<'EOF'
package auth

func Login(username, password string) bool {
    return username == "admin"
}
EOF
    
    # Mock claude with detailed findings
    mock_command "claude" "mock_claude() {
        cat <<'REVIEW_EOF'
{
    "status": "success",
    "review": {
        "summary": "Security issues found",
        "findings": [
            {
                "severity": "critical",
                "issue": "Hardcoded credentials",
                "line": 4
            }
        ]
    }
}
REVIEW_EOF
    }"
    
    # Execute review
    ./scripts/review-code.sh "$feature_id" "src/auth/login.go"
    
    # Parse history entry
    history_entry=$(tail -n1 ".ai-session/$feature_id/history.jsonl")
    
    # Verify context captured
    assert_contains "$history_entry" '"feature_context":"Implement secure authentication system"' \
        "History should include feature context"
    assert_contains "$history_entry" '"review_context":{' "History should include review context"
    assert_contains "$history_entry" '"files_reviewed":["src/auth/login.go"]' \
        "History should list reviewed files"
    assert_contains "$history_entry" '"findings_count":1' "History should count findings"
    assert_contains "$history_entry" '"critical_findings":1' "History should count critical findings"
    
    unmock_command "claude"
}

test_review_history_multiple_files() {
    setup_test_scripts
    
    # Initialize session
    feature_id="review-history-multi-test-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Create multiple test files
    mkdir -p src/{models,handlers}
    echo "package models" > src/models/user.go
    echo "package handlers" > src/handlers/user.go
    echo "package handlers" > src/handlers/auth.go
    
    # Mock claude
    mock_command "claude" "mock_claude() {
        echo '{\"status\": \"success\"}'
    }"
    
    # Execute review with multiple files
    ./scripts/review-code.sh "$feature_id" \
        "src/models/user.go" \
        "src/handlers/user.go" \
        "src/handlers/auth.go"
    
    # Parse history entry
    history_entry=$(tail -n1 ".ai-session/$feature_id/history.jsonl")
    
    # Verify all files logged
    assert_contains "$history_entry" '"files_reviewed":[' "Should have files array"
    assert_contains "$history_entry" '"src/models/user.go"' "Should include models file"
    assert_contains "$history_entry" '"src/handlers/user.go"' "Should include first handler"
    assert_contains "$history_entry" '"src/handlers/auth.go"' "Should include second handler"
    assert_contains "$history_entry" '"file_count":3' "Should count total files"
    
    unmock_command "claude"
}

test_review_history_architecture_metadata() {
    setup_test_scripts
    
    # Initialize session
    feature_id="review-history-arch-test-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Create architecture files
    mkdir -p {docs,architecture,design}
    echo "# System Architecture" > docs/architecture.md
    echo "# API Design" > design/api.md
    echo "# Database Schema" > architecture/database.md
    
    # Mock gemini with architecture insights
    mock_command "gemini" "mock_gemini() {
        cat <<'REVIEW_EOF'
{
    "status": "success",
    "review": {
        "architecture_type": "microservices",
        "components_identified": 5,
        "patterns_found": ["CQRS", "Event Sourcing"],
        "technology_stack": ["Go", "PostgreSQL", "Redis"]
    }
}
REVIEW_EOF
    }"
    
    # Execute architecture review
    ./scripts/review-architecture.sh "$feature_id"
    
    # Parse history entry
    history_entry=$(tail -n1 ".ai-session/$feature_id/history.jsonl")
    
    # Verify architecture-specific metadata
    assert_contains "$history_entry" '"command":"review-architecture"' "Should log architecture command"
    assert_contains "$history_entry" '"model":"gemini"' "Should use Gemini model"
    assert_contains "$history_entry" '"architecture_context":{' "Should have architecture context"
    assert_contains "$history_entry" '"directories_analyzed":[' "Should list analyzed directories"
    assert_contains "$history_entry" '"architecture_type":"microservices"' "Should capture arch type"
    assert_contains "$history_entry" '"components_count":5' "Should count components"
    
    unmock_command "gemini"
}

test_review_history_error_logging() {
    setup_test_scripts
    
    # Initialize session
    feature_id="review-history-error-test-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Create test file
    mkdir -p src
    echo "package main" > src/test.go
    
    # Mock claude to fail
    mock_command "claude" "mock_claude() {
        echo 'Error: Rate limit exceeded' >&2
        return 1
    }"
    
    # Execute review (will fail)
    set +e
    ./scripts/review-code.sh "$feature_id" "src/test.go" 2>&1
    set -e
    
    # Parse history entry
    history_entry=$(tail -n1 ".ai-session/$feature_id/history.jsonl")
    
    # Verify error logged
    assert_contains "$history_entry" '"status":"failure"' "Should log failure status"
    assert_contains "$history_entry" '"error":"Rate limit exceeded"' "Should capture error message"
    assert_contains "$history_entry" '"error_type":"model_error"' "Should categorize error type"
    assert_contains "$history_entry" '"retry_possible":true' "Should indicate retry possibility"
    
    unmock_command "claude"
}

test_review_history_artifact_references() {
    setup_test_scripts
    
    # Initialize session
    feature_id="review-history-artifact-test-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Create test file
    mkdir -p src
    echo "package main" > src/test.go
    
    # Mock claude with review that generates artifact
    mock_command "claude" "mock_claude() {
        echo '{\"status\": \"success\", \"review\": \"Detailed review\", \"artifact_id\": \"review-12345\"}'
    }"
    
    # Execute review
    ./scripts/review-code.sh "$feature_id" "src/test.go"
    
    # Parse history entry
    history_entry=$(tail -n1 ".ai-session/$feature_id/history.jsonl")
    
    # Verify artifact reference
    assert_contains "$history_entry" '"artifacts":[' "Should have artifacts array"
    assert_contains "$history_entry" '"type":"review"' "Should specify artifact type"
    assert_contains "$history_entry" '"path":".ai-session/' "Should include artifact path"
    assert_contains "$history_entry" '/artifacts/review-' "Should reference review artifact"
    
    unmock_command "claude"
}

test_review_history_incremental_logging() {
    setup_test_scripts
    
    # Initialize session
    feature_id="review-history-incremental-test-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Create test files
    mkdir -p src
    echo "package main" > src/file1.go
    echo "package main" > src/file2.go
    echo "package main" > src/file3.go
    
    # Mock claude
    mock_command "claude" "mock_claude() {
        echo '{\"status\": \"success\"}'
    }"
    
    # Execute multiple reviews
    ./scripts/review-code.sh "$feature_id" "src/file1.go"
    ./scripts/review-code.sh "$feature_id" "src/file2.go"
    ./scripts/review-code.sh "$feature_id" "src/file3.go"
    
    # Count history entries
    history_count=$(wc -l < ".ai-session/$feature_id/history.jsonl")
    assert_less_than "2" "$history_count" "Should have at least 3 history entries"
    
    # Verify each entry is valid JSON
    while IFS= read -r line; do
        assert_json_valid <(echo "$line") "Each history line should be valid JSON"
    done < ".ai-session/$feature_id/history.jsonl"
    
    # Verify entries are in chronological order
    timestamps=$(grep -o '"timestamp":"[^"]*"' ".ai-session/$feature_id/history.jsonl" | cut -d'"' -f4)
    assert_sorted "$timestamps" "History entries should be chronologically ordered"
    
    unmock_command "claude"
}

test_review_history_session_summary() {
    setup_test_scripts
    
    # Initialize session
    feature_id="review-history-summary-test-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Create test files
    mkdir -p {src,docs}
    echo "package main" > src/main.go
    echo "package auth" > src/auth.go
    echo "# Architecture" > docs/arch.md
    
    # Mock commands with different findings
    mock_command "claude" "mock_claude() {
        if [[ \"\$*\" == *\"main.go\"* ]]; then
            echo '{\"status\": \"success\", \"findings_count\": 2}'
        else
            echo '{\"status\": \"success\", \"findings_count\": 1}'
        fi
    }"
    mock_command "gemini" "mock_gemini() {
        echo '{\"status\": \"success\", \"issues_found\": 3}'
    }"
    
    # Execute multiple review types
    ./scripts/review-code.sh "$feature_id" "src/main.go"
    ./scripts/review-code.sh "$feature_id" "src/auth.go"
    ./scripts/review-architecture.sh "$feature_id"
    
    # Generate summary from history
    history_file=".ai-session/$feature_id/history.jsonl"
    total_reviews=$(grep -c '"command":"review-' "$history_file")
    code_reviews=$(grep -c '"command":"review-code"' "$history_file")
    arch_reviews=$(grep -c '"command":"review-architecture"' "$history_file")
    
    # Verify counts
    assert_equals "3" "$total_reviews" "Should have 3 total reviews"
    assert_equals "2" "$code_reviews" "Should have 2 code reviews"
    assert_equals "1" "$arch_reviews" "Should have 1 architecture review"
    
    # Verify session metadata in last entry includes summary
    tail -n1 "$history_file" > last_entry.json
    
    # Each review should update session statistics
    # (In real implementation, this would be tracked in state.yaml)
    
    unmock_command "claude"
    unmock_command "gemini"
}

test_review_history_performance_metrics() {
    setup_test_scripts
    
    # Initialize session
    feature_id="review-history-perf-test-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Create test files of different sizes
    mkdir -p src
    
    # Small file
    echo "package small" > src/small.go
    
    # Medium file (100 lines)
    for i in {1..100}; do
        echo "// Line $i" >> src/medium.go
    done
    
    # Large file (1000 lines)
    for i in {1..1000}; do
        echo "// Line $i" >> src/large.go
    done
    
    # Mock claude with variable delays
    mock_command "claude" "mock_claude() {
        if [[ \"\$*\" == *\"small.go\"* ]]; then
            sleep 0.05  # 50ms
        elif [[ \"\$*\" == *\"medium.go\"* ]]; then
            sleep 0.1   # 100ms
        else
            sleep 0.2   # 200ms
        fi
        echo '{\"status\": \"success\"}'
    }"
    
    # Execute reviews
    ./scripts/review-code.sh "$feature_id" "src/small.go"
    ./scripts/review-code.sh "$feature_id" "src/medium.go"
    ./scripts/review-code.sh "$feature_id" "src/large.go"
    
    # Extract performance metrics from history
    history_file=".ai-session/$feature_id/history.jsonl"
    
    # Verify each entry has performance data
    while IFS= read -r line; do
        assert_contains "$line" '"duration_ms"' "Each entry should have duration"
        assert_contains "$line" '"file_size_bytes"' "Should track file size"
        assert_contains "$line" '"lines_reviewed"' "Should track lines count"
    done < "$history_file"
    
    # Verify duration correlates with file size
    small_duration=$(grep "small.go" "$history_file" | grep -o '"duration_ms":[0-9]*' | cut -d: -f2)
    large_duration=$(grep "large.go" "$history_file" | grep -o '"duration_ms":[0-9]*' | cut -d: -f2)
    assert_less_than "$small_duration" "$large_duration" "Small file should review faster"
    
    unmock_command "claude"
}

test_review_history_concurrent_safety() {
    setup_test_scripts
    
    # Initialize session
    feature_id="review-history-concurrent-test-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Create multiple test files
    mkdir -p src
    for i in {1..5}; do
        echo "package main // File $i" > "src/file$i.go"
    done
    
    # Mock claude with counter
    review_count=0
    mock_command "claude" "mock_claude() {
        ((review_count++))
        echo \"{\\\"status\\\": \\\"success\\\", \\\"review_id\\\": $review_count}\"
    }"
    
    # Execute reviews concurrently
    for i in {1..5}; do
        ./scripts/review-code.sh "$feature_id" "src/file$i.go" &
    done
    
    # Wait for all to complete
    wait
    
    # Verify all entries logged
    history_count=$(wc -l < ".ai-session/$feature_id/history.jsonl")
    assert_equals "5" "$history_count" "All concurrent reviews should be logged"
    
    # Verify no corrupted entries
    while IFS= read -r line; do
        assert_json_valid <(echo "$line") "No corrupted JSON from concurrent writes"
    done < ".ai-session/$feature_id/history.jsonl"
    
    # Verify all review IDs present (no lost writes)
    for i in {1..5}; do
        assert_file_contains ".ai-session/$feature_id/history.jsonl" "\"review_id\": $i" \
            "Review $i should be logged"
    done
    
    unmock_command "claude"
}

# Run all tests
echo "Testing review commands history logging..."
run_test_scenario "Review history basic logging" test_review_history_basic_logging
run_test_scenario "Review history context capture" test_review_history_context_capture
run_test_scenario "Review history multiple files" test_review_history_multiple_files
run_test_scenario "Review history architecture metadata" test_review_history_architecture_metadata
run_test_scenario "Review history error logging" test_review_history_error_logging
run_test_scenario "Review history artifact references" test_review_history_artifact_references
run_test_scenario "Review history incremental logging" test_review_history_incremental_logging
run_test_scenario "Review history session summary" test_review_history_session_summary
run_test_scenario "Review history performance metrics" test_review_history_performance_metrics
run_test_scenario "Review history concurrent safety" test_review_history_concurrent_safety