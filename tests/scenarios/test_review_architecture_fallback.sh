#!/bin/bash
# Test: Review-architecture command uses appropriate model with fallback
# Feature: AI Orchestrator Review Commands
# Scenario: Architecture review uses Gemini for system-wide perspective with Opus fallback

set -euo pipefail

# Set project root if not already set
if [[ -z "${PROJECT_ROOT:-}" ]]; then
    PROJECT_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
    export PROJECT_ROOT
fi

# Source test harness and utilities
source "$(dirname "$0")/../test-command.sh"
source "$(dirname "$0")/../utils/test_setup.sh"

test_review_architecture_prefers_gemini() {
    setup_test_scripts
    
    # Initialize session
    feature_id="review-arch-gemini-test-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Create test architecture files
    mkdir -p {src,docs,config}
    cat > docs/architecture.md <<'EOF'
# System Architecture

## Overview
Microservices architecture with API Gateway

## Services
- User Service
- Auth Service
- Payment Service
EOF
    
    cat > src/main.go <<'EOF'
package main

import "github.com/gin-gonic/gin"

func main() {
    r := gin.Default()
    r.Run(":8080")
}
EOF
    
    # Mock both commands, track which gets called
    mock_gemini_invoked=0
    mock_claude_invoked=0
    mock_command "gemini" "mock_gemini() { 
        mock_gemini_invoked=1
        echo '{\"status\": \"success\", \"review\": \"Architecture follows microservices best practices\"}'
    }"
    mock_command "claude" "mock_claude() { 
        mock_claude_invoked=1
        echo '{\"status\": \"success\", \"review\": \"Should not be called\"}'
    }"
    
    # Execute review-architecture command
    ./scripts/review-architecture.sh "$feature_id"
    
    # Verify Gemini was invoked, not Claude
    assert_equals "1" "$mock_gemini_invoked" "Gemini should be invoked for architecture review"
    assert_equals "0" "$mock_claude_invoked" "Claude should not be invoked when Gemini available"
    
    # Verify history log shows gemini usage
    history_entry=$(tail -n1 ".ai-session/$feature_id/history.jsonl")
    assert_contains "$history_entry" '"model":"gemini"' "History should record Gemini usage"
    assert_contains "$history_entry" '"command":"review-architecture"' "History should record review-architecture command"
    
    # Verify state updated to show gemini in use
    state_content=$(cat ".ai-session/$feature_id/state.yaml")
    assert_contains "$state_content" 'model_in_use: "gemini"' "State should show Gemini in use"
    
    unmock_command "gemini"
    unmock_command "claude"
}

test_review_architecture_opus_fallback() {
    setup_test_scripts
    
    # Initialize session
    feature_id="review-arch-fallback-test-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Create architecture files
    mkdir -p docs
    echo "# Architecture" > docs/README.md
    
    # Mock gemini to fail, claude to succeed
    mock_gemini_attempted=0
    mock_claude_model=""
    mock_command "gemini" "mock_gemini() { 
        mock_gemini_attempted=1
        echo 'Error: Gemini unavailable' >&2
        return 1
    }"
    mock_command "claude" "mock_claude() {
        # Parse model from arguments
        while [[ \$# -gt 0 ]]; do
            if [[ \"\$1\" == \"--model\" ]]; then
                shift
                mock_claude_model=\"\$1\"
                break
            fi
            shift
        done
        echo '{\"status\": \"success\", \"review\": \"Architecture reviewed with Opus\"}'
    }"
    
    # Execute review-architecture command
    ./scripts/review-architecture.sh "$feature_id"
    
    # Verify fallback to Opus occurred
    assert_equals "1" "$mock_gemini_attempted" "Gemini should be attempted first"
    assert_equals "opus" "$mock_claude_model" "Should fallback to Opus model"
    
    # Verify history shows fallback
    history_entry=$(tail -n1 ".ai-session/$feature_id/history.jsonl")
    assert_contains "$history_entry" '"model":"opus"' "History should show Opus was used"
    assert_contains "$history_entry" '"fallback":true' "History should indicate fallback occurred"
    
    unmock_command "gemini"
    unmock_command "claude"
}

test_review_architecture_full_context() {
    setup_test_scripts
    
    # Initialize session
    feature_id="review-arch-context-test-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Create comprehensive architecture
    mkdir -p {src/{api,services,models},docs,config,scripts}
    
    echo "# API Design" > docs/api.md
    echo "# Database Schema" > docs/database.md
    echo "version: 1.0" > config/app.yaml
    echo "FROM golang:1.21" > Dockerfile
    
    # Mock gemini to capture arguments
    mock_gemini_args=""
    mock_command "gemini" "mock_gemini() {
        mock_gemini_args=\"\$*\"
        echo '{\"status\": \"success\"}'
    }"
    
    # Execute review-architecture with full context flag
    ./scripts/review-architecture.sh "$feature_id" --full-context
    
    # Verify -a flag passed for complete codebase analysis
    assert_contains "$mock_gemini_args" "-a" "Gemini should receive -a flag for full context"
    
    unmock_command "gemini"
}

test_review_architecture_directory_discovery() {
    setup_test_scripts
    
    # Initialize session
    feature_id="review-arch-discovery-test-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Create various architecture-related files
    mkdir -p {architecture,design,docs/technical}
    cat > architecture/overview.md <<'EOF'
# System Overview
Distributed system with event sourcing
EOF
    
    cat > design/patterns.md <<'EOF'
# Design Patterns
- Repository Pattern
- CQRS
- Event Sourcing
EOF
    
    cat > docs/technical/stack.md <<'EOF'
# Technology Stack
- Go 1.21
- PostgreSQL
- Redis
- Kubernetes
EOF
    
    # Mock gemini to capture prompt
    captured_prompt=""
    mock_command "gemini" "mock_gemini() {
        while [[ \$# -gt 0 ]]; do
            if [[ \"\$1\" == \"-p\" ]]; then
                shift
                captured_prompt=\"\$1\"
                break
            fi
            shift
        done
        echo '{\"status\": \"success\"}'
    }"
    
    # Execute review-architecture
    ./scripts/review-architecture.sh "$feature_id"
    
    # Verify discovered architecture files included
    assert_contains "$captured_prompt" "System Overview" "Should include architecture/overview.md"
    assert_contains "$captured_prompt" "Design Patterns" "Should include design/patterns.md"
    assert_contains "$captured_prompt" "Technology Stack" "Should include docs/technical/stack.md"
    
    unmock_command "gemini"
}

test_review_architecture_artifact_generation() {
    setup_test_scripts
    
    # Initialize session
    feature_id="review-arch-artifact-test-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Create minimal architecture
    mkdir -p docs
    echo "# Architecture" > docs/arch.md
    
    # Mock gemini with detailed review
    mock_command "gemini" "mock_gemini() {
        cat <<'REVIEW_EOF'
{
    "status": "success",
    "review": {
        "summary": "Architecture review completed",
        "strengths": [
            "Clear separation of concerns",
            "Scalable design"
        ],
        "weaknesses": [
            "Missing monitoring strategy",
            "No disaster recovery plan"
        ],
        "recommendations": [
            "Add observability layer",
            "Document failure scenarios",
            "Consider service mesh"
        ],
        "diagram": "graph TD\n  A[Client] --> B[API Gateway]\n  B --> C[Services]"
    }
}
REVIEW_EOF
    }"
    
    # Execute review-architecture
    ./scripts/review-architecture.sh "$feature_id"
    
    # Verify review artifact saved
    assert_exists ".ai-session/$feature_id/artifacts/review-architecture-$(date +%Y%m%d)-*.json" \
        "Architecture review artifact should be saved"
    
    # Verify artifact contains review details
    review_file=$(ls .ai-session/$feature_id/artifacts/review-architecture-*.json | head -1)
    assert_json_valid "$review_file" "Review artifact should be valid JSON"
    assert_file_contains "$review_file" "strengths" "Review should contain strengths"
    assert_file_contains "$review_file" "weaknesses" "Review should contain weaknesses"
    assert_file_contains "$review_file" "recommendations" "Review should contain recommendations"
    
    # Verify diagram artifact if provided
    assert_file_contains "$review_file" "diagram" "Review should contain architecture diagram"
    
    unmock_command "gemini"
}

test_review_architecture_specific_focus() {
    setup_test_scripts
    
    # Initialize session
    feature_id="review-arch-focus-test-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Create architecture files
    mkdir -p docs/{security,performance,scalability}
    echo "# Security Architecture" > docs/security/overview.md
    echo "# Performance Considerations" > docs/performance/metrics.md
    echo "# Scalability Design" > docs/scalability/patterns.md
    
    # Mock gemini to capture prompts
    captured_prompt=""
    mock_command "gemini" "mock_gemini() {
        while [[ \$# -gt 0 ]]; do
            if [[ \"\$1\" == \"-p\" ]]; then
                shift
                captured_prompt=\"\$1\"
                break
            fi
            shift
        done
        echo '{\"status\": \"success\"}'
    }"
    
    # Test security-focused review
    ./scripts/review-architecture.sh "$feature_id" --focus security
    assert_contains "$captured_prompt" "security" "Prompt should focus on security"
    assert_contains "$captured_prompt" "vulnerabilities" "Should look for security issues"
    
    # Test performance-focused review
    ./scripts/review-architecture.sh "$feature_id" --focus performance
    assert_contains "$captured_prompt" "performance" "Prompt should focus on performance"
    assert_contains "$captured_prompt" "bottlenecks" "Should look for performance issues"
    
    # Test scalability-focused review
    ./scripts/review-architecture.sh "$feature_id" --focus scalability
    assert_contains "$captured_prompt" "scalability" "Prompt should focus on scalability"
    assert_contains "$captured_prompt" "scaling" "Should analyze scaling patterns"
    
    unmock_command "gemini"
}

test_review_architecture_error_handling() {
    setup_test_scripts
    
    # Initialize session
    feature_id="review-arch-error-test-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Test with no architecture files
    set +e
    output=$(./scripts/review-architecture.sh "$feature_id" 2>&1)
    exit_code=$?
    set -e
    
    # Should warn but not fail completely
    assert_equals "0" "$exit_code" "Should handle missing architecture files gracefully"
    assert_contains "$output" "Warning" "Should warn about missing architecture files"
    
    # Mock both models failing
    mock_command "gemini" "mock_gemini() {
        echo 'Error: Gemini unavailable' >&2
        return 1
    }"
    mock_command "claude" "mock_claude() {
        echo 'Error: Claude unavailable' >&2
        return 1
    }"
    
    # Execute review
    set +e
    output=$(./scripts/review-architecture.sh "$feature_id" 2>&1)
    exit_code=$?
    set -e
    
    # Verify complete failure handled
    assert_not_equals "0" "$exit_code" "Should fail when no models available"
    assert_contains "$output" "Error" "Should show error message"
    
    # Verify history logs the failure
    history_entry=$(tail -n1 ".ai-session/$feature_id/history.jsonl")
    assert_contains "$history_entry" '"status":"failure"' "History should record failure"
    assert_contains "$history_entry" '"error"' "History should include error details"
    
    unmock_command "gemini"
    unmock_command "claude"
}

test_review_architecture_comparison_mode() {
    setup_test_scripts
    
    # Initialize session
    feature_id="review-arch-compare-test-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Create current and proposed architectures
    mkdir -p {docs/current,docs/proposed}
    cat > docs/current/architecture.md <<'EOF'
# Current Architecture
- Monolithic application
- Single database
- Synchronous communication
EOF
    
    cat > docs/proposed/architecture.md <<'EOF'
# Proposed Architecture
- Microservices
- Database per service
- Event-driven communication
EOF
    
    # Mock gemini to capture comparison request
    captured_prompt=""
    mock_command "gemini" "mock_gemini() {
        while [[ \$# -gt 0 ]]; do
            if [[ \"\$1\" == \"-p\" ]]; then
                shift
                captured_prompt=\"\$1\"
                break
            fi
            shift
        done
        echo '{\"status\": \"success\", \"comparison\": \"Migration path defined\"}'
    }"
    
    # Execute comparison review
    ./scripts/review-architecture.sh "$feature_id" --compare docs/current docs/proposed
    
    # Verify comparison mode activated
    assert_contains "$captured_prompt" "Current Architecture" "Should include current state"
    assert_contains "$captured_prompt" "Proposed Architecture" "Should include proposed state"
    assert_contains "$captured_prompt" "compare" "Should request comparison"
    assert_contains "$captured_prompt" "migration" "Should consider migration path"
    
    unmock_command "gemini"
}

test_review_architecture_requires_active_session() {
    setup_test_scripts
    
    # Create architecture files
    mkdir -p docs
    echo "# Architecture" > docs/arch.md
    
    # Attempt to review without session
    feature_id="nonexistent-session"
    
    set +e
    output=$(./scripts/review-architecture.sh "$feature_id" 2>&1)
    exit_code=$?
    set -e
    
    # Verify review rejected without session
    assert_not_equals "0" "$exit_code" "Review should fail without active session"
    assert_contains "$output" "not found" "Error should mention missing session"
}

test_review_architecture_duration_tracking() {
    setup_test_scripts
    
    # Initialize session
    feature_id="review-arch-duration-test-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Create architecture files
    mkdir -p docs
    echo "# Architecture" > docs/arch.md
    
    # Mock gemini with delay
    mock_command "gemini" "mock_gemini() {
        sleep 0.1  # 100ms delay
        echo '{\"status\": \"success\"}'
    }"
    
    # Execute review command
    ./scripts/review-architecture.sh "$feature_id"
    
    # Verify duration tracked in history
    history_entry=$(tail -n1 ".ai-session/$feature_id/history.jsonl")
    assert_contains "$history_entry" '"duration_ms"' "History should include duration"
    
    # Extract and verify duration is reasonable (>90ms due to sleep)
    duration=$(echo "$history_entry" | grep -o '"duration_ms":[0-9]*' | cut -d: -f2)
    assert_less_than "90" "$duration" "Duration should reflect execution time"
    
    unmock_command "gemini"
}

# Run all tests
echo "Testing review-architecture command model routing and fallback..."
run_test_scenario "Review-architecture prefers Gemini" test_review_architecture_prefers_gemini
run_test_scenario "Review-architecture Opus fallback" test_review_architecture_opus_fallback
run_test_scenario "Review-architecture full context" test_review_architecture_full_context
run_test_scenario "Review-architecture directory discovery" test_review_architecture_directory_discovery
run_test_scenario "Review-architecture artifact generation" test_review_architecture_artifact_generation
run_test_scenario "Review-architecture specific focus" test_review_architecture_specific_focus
run_test_scenario "Review-architecture error handling" test_review_architecture_error_handling
run_test_scenario "Review-architecture comparison mode" test_review_architecture_comparison_mode
run_test_scenario "Review-architecture requires session" test_review_architecture_requires_active_session
run_test_scenario "Review-architecture duration tracking" test_review_architecture_duration_tracking