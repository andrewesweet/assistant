#!/bin/bash
# Test: Review-code command routes to Opus for deep analysis
# Feature: AI Orchestrator Review Commands
# Scenario: Code review uses Opus model for deep code analysis capabilities

set -euo pipefail

# Set project root if not already set
if [[ -z "${PROJECT_ROOT:-}" ]]; then
    PROJECT_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
    export PROJECT_ROOT
fi

# Source test harness and utilities
source "$(dirname "$0")/../test-command.sh"
source "$(dirname "$0")/../utils/test_setup.sh"

test_review_code_routes_to_opus() {
    setup_test_scripts
    
    # Initialize session
    feature_id="review-code-opus-test-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Create test files to review
    mkdir -p src
    cat > src/example.go <<'EOF'
package main

import "fmt"

func calculateSum(a, b int) int {
    // TODO: Add validation
    return a + b
}

func main() {
    result := calculateSum(5, 3)
    fmt.Printf("Sum: %d\n", result)
}
EOF
    
    # Mock claude command to capture invocation
    mock_claude_invoked=0
    mock_claude_model=""
    mock_claude_args=""
    mock_command "claude" "mock_claude() { 
        mock_claude_invoked=1
        # Parse model from arguments
        while [[ \$# -gt 0 ]]; do
            if [[ \"\$1\" == \"--model\" ]]; then
                shift
                mock_claude_model=\"\$1\"
                break
            fi
            shift
        done
        mock_claude_args=\"\$*\"
        echo '{\"status\": \"success\", \"review\": \"Code looks good with minor suggestions\"}'
    }"
    
    # Execute review-code command
    ./scripts/review-code.sh "$feature_id" "src/example.go"
    
    # Verify Opus was invoked
    assert_equals "1" "$mock_claude_invoked" "Claude should be invoked for code review"
    assert_equals "opus" "$mock_claude_model" "Code review should use Opus model"
    assert_contains "$mock_claude_args" "-p" "Claude should receive prompt"
    
    # Verify history log shows opus usage
    history_entry=$(tail -n1 ".ai-session/$feature_id/history.jsonl")
    assert_contains "$history_entry" '"model":"opus"' "History should record Opus usage"
    assert_contains "$history_entry" '"command":"review-code"' "History should record review-code command"
    
    # Verify state updated to show opus in use
    state_content=$(cat ".ai-session/$feature_id/state.yaml")
    assert_contains "$state_content" 'model_in_use: "opus"' "State should show Opus in use"
    
    unmock_command "claude"
}

test_review_code_multiple_files() {
    setup_test_scripts
    
    # Initialize session
    feature_id="review-multi-test-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Create multiple test files
    mkdir -p src/{handlers,models}
    cat > src/handlers/user.go <<'EOF'
package handlers

type UserHandler struct{}

func (h *UserHandler) Create(name string) error {
    // Implementation needed
    return nil
}
EOF
    
    cat > src/models/user.go <<'EOF'
package models

type User struct {
    ID   int
    Name string
}
EOF
    
    # Mock claude to track file content
    captured_prompt=""
    mock_command "claude" "mock_claude() {
        # Extract prompt after -p flag
        while [[ \$# -gt 0 ]]; do
            if [[ \"\$1\" == \"-p\" ]]; then
                shift
                captured_prompt=\"\$1\"
                break
            fi
            shift
        done
        echo '{\"status\": \"success\", \"review\": \"Multiple files reviewed\"}'
    }"
    
    # Execute review-code with multiple files
    ./scripts/review-code.sh "$feature_id" "src/handlers/user.go" "src/models/user.go"
    
    # Verify both files included in prompt
    assert_contains "$captured_prompt" "handlers/user.go" "Prompt should include first file"
    assert_contains "$captured_prompt" "models/user.go" "Prompt should include second file"
    assert_contains "$captured_prompt" "UserHandler" "Prompt should include file contents"
    assert_contains "$captured_prompt" "type User struct" "Prompt should include model definition"
    
    unmock_command "claude"
}

test_review_code_with_context() {
    setup_test_scripts
    
    # Initialize session with description
    feature_id="review-context-test-$(date +%Y-%m-%d)"
    description="Implement user authentication service"
    ./scripts/init-session.sh "$feature_id" "$description"
    
    # Create test file
    mkdir -p src
    cat > src/auth.go <<'EOF'
package auth

func Authenticate(username, password string) bool {
    // Simplified for testing
    return username == "admin" && password == "secret"
}
EOF
    
    # Mock claude to capture prompt
    captured_prompt=""
    mock_command "claude" "mock_claude() {
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
    
    # Execute review-code command
    ./scripts/review-code.sh "$feature_id" "src/auth.go"
    
    # Verify prompt includes feature context
    assert_contains "$captured_prompt" "user authentication service" "Prompt should include feature description"
    assert_contains "$captured_prompt" "security" "Prompt should mention security for auth code"
    assert_contains "$captured_prompt" "best practices" "Prompt should ask for best practices"
    
    unmock_command "claude"
}

test_review_code_fresh_context() {
    setup_test_scripts
    
    # Initialize session
    feature_id="review-fresh-test-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Create two files to review separately
    mkdir -p src
    cat > src/file1.go <<'EOF'
package main
const Version = "1.0.0"
EOF
    
    cat > src/file2.go <<'EOF'
package main
const AppName = "TestApp"
EOF
    
    # Track prompts from both reviews
    prompts=()
    prompt_index=0
    mock_command "claude" "mock_claude() {
        while [[ \$# -gt 0 ]]; do
            if [[ \"\$1\" == \"-p\" ]]; then
                shift
                prompts[\$prompt_index]=\"\$1\"
                ((prompt_index++))
                break
            fi
            shift
        done
        echo '{\"status\": \"success\"}'
    }"
    
    # Execute two separate reviews
    ./scripts/review-code.sh "$feature_id" "src/file1.go"
    ./scripts/review-code.sh "$feature_id" "src/file2.go"
    
    # Verify each review has fresh context (no bleed)
    assert_contains "${prompts[0]}" "Version" "First review should contain file1 content"
    assert_not_contains "${prompts[0]}" "AppName" "First review should not contain file2 content"
    
    assert_contains "${prompts[1]}" "AppName" "Second review should contain file2 content"
    assert_not_contains "${prompts[1]}" "Version" "Second review should not contain file1 content"
    
    unmock_command "claude"
}

test_review_code_artifact_storage() {
    setup_test_scripts
    
    # Initialize session
    feature_id="review-artifact-test-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Create test file
    mkdir -p src
    cat > src/example.go <<'EOF'
package main
func main() {}
EOF
    
    # Mock claude with detailed review
    mock_command "claude" "mock_claude() {
        cat <<'REVIEW_EOF'
{
    "status": "success",
    "review": {
        "summary": "Code review completed",
        "findings": [
            {
                "severity": "minor",
                "file": "src/example.go",
                "line": 2,
                "issue": "Missing documentation"
            }
        ],
        "recommendations": [
            "Add package documentation",
            "Consider error handling"
        ]
    }
}
REVIEW_EOF
    }"
    
    # Execute review-code command
    ./scripts/review-code.sh "$feature_id" "src/example.go"
    
    # Verify review artifact saved
    assert_exists ".ai-session/$feature_id/artifacts/review-code-$(date +%Y%m%d)-*.json" \
        "Review artifact should be saved"
    
    # Verify artifact contains review details
    review_file=$(ls .ai-session/$feature_id/artifacts/review-code-*.json | head -1)
    assert_json_valid "$review_file" "Review artifact should be valid JSON"
    assert_file_contains "$review_file" "findings" "Review should contain findings"
    assert_file_contains "$review_file" "recommendations" "Review should contain recommendations"
    
    unmock_command "claude"
}

test_review_code_error_handling() {
    setup_test_scripts
    
    # Initialize session
    feature_id="review-error-test-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Test with non-existent file
    set +e
    output=$(./scripts/review-code.sh "$feature_id" "nonexistent.go" 2>&1)
    exit_code=$?
    set -e
    
    # Verify error handled gracefully
    assert_not_equals "0" "$exit_code" "Review should fail for non-existent file"
    assert_contains "$output" "not found" "Error message should mention missing file"
    
    # Create file but mock claude error
    mkdir -p src
    echo "package main" > src/test.go
    
    mock_command "claude" "mock_claude() {
        echo 'Error: Model unavailable' >&2
        return 1
    }"
    
    # Execute review and capture result
    set +e
    output=$(./scripts/review-code.sh "$feature_id" "src/test.go" 2>&1)
    exit_code=$?
    set -e
    
    # Verify error handled
    assert_not_equals "0" "$exit_code" "Review should fail when Claude errors"
    assert_contains "$output" "Error" "Error message should be shown"
    
    # Verify history logs the failure
    history_entry=$(tail -n1 ".ai-session/$feature_id/history.jsonl")
    assert_contains "$history_entry" '"status":"failure"' "History should record failure"
    assert_contains "$history_entry" '"error"' "History should include error details"
    
    unmock_command "claude"
}

test_review_code_requires_active_session() {
    setup_test_scripts
    
    # Create a file to review
    mkdir -p src
    echo "package main" > src/test.go
    
    # Attempt to review without session
    feature_id="nonexistent-session"
    
    set +e
    output=$(./scripts/review-code.sh "$feature_id" "src/test.go" 2>&1)
    exit_code=$?
    set -e
    
    # Verify review rejected without session
    assert_not_equals "0" "$exit_code" "Review should fail without active session"
    assert_contains "$output" "not found" "Error should mention missing session"
}

test_review_code_duration_tracking() {
    setup_test_scripts
    
    # Initialize session
    feature_id="review-duration-test-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Create test file
    mkdir -p src
    echo "package main" > src/test.go
    
    # Mock claude with delay
    mock_command "claude" "mock_claude() {
        sleep 0.1  # 100ms delay
        echo '{\"status\": \"success\"}'
    }"
    
    # Execute review command
    ./scripts/review-code.sh "$feature_id" "src/test.go"
    
    # Verify duration tracked in history
    history_entry=$(tail -n1 ".ai-session/$feature_id/history.jsonl")
    assert_contains "$history_entry" '"duration_ms"' "History should include duration"
    
    # Extract and verify duration is reasonable (>90ms due to sleep)
    duration=$(echo "$history_entry" | grep -o '"duration_ms":[0-9]*' | cut -d: -f2)
    assert_less_than "90" "$duration" "Duration should reflect execution time"
    
    unmock_command "claude"
}

test_review_code_file_type_support() {
    setup_test_scripts
    
    # Initialize session
    feature_id="review-filetype-test-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Create files of different types
    mkdir -p src
    cat > src/app.py <<'EOF'
def calculate_sum(a, b):
    """Calculate sum of two numbers"""
    return a + b
EOF
    
    cat > src/styles.css <<'EOF'
.container {
    margin: 0 auto;
    padding: 20px;
}
EOF
    
    cat > src/config.yaml <<'EOF'
server:
  host: localhost
  port: 8080
EOF
    
    # Mock claude to track file types
    reviewed_files=""
    mock_command "claude" "mock_claude() {
        while [[ \$# -gt 0 ]]; do
            if [[ \"\$1\" == \"-p\" ]]; then
                shift
                reviewed_files=\"\$1\"
                break
            fi
            shift
        done
        echo '{\"status\": \"success\"}'
    }"
    
    # Review different file types
    ./scripts/review-code.sh "$feature_id" "src/app.py"
    assert_contains "$reviewed_files" "calculate_sum" "Python file should be reviewed"
    
    ./scripts/review-code.sh "$feature_id" "src/styles.css"
    assert_contains "$reviewed_files" "container" "CSS file should be reviewed"
    
    ./scripts/review-code.sh "$feature_id" "src/config.yaml"
    assert_contains "$reviewed_files" "localhost" "YAML file should be reviewed"
    
    unmock_command "claude"
}

# Run all tests
echo "Testing review-code command Opus routing..."
run_test_scenario "Review-code routes to Opus" test_review_code_routes_to_opus
run_test_scenario "Review-code multiple files" test_review_code_multiple_files
run_test_scenario "Review-code with context" test_review_code_with_context
run_test_scenario "Review-code fresh context" test_review_code_fresh_context
run_test_scenario "Review-code artifact storage" test_review_code_artifact_storage
run_test_scenario "Review-code error handling" test_review_code_error_handling
run_test_scenario "Review-code requires session" test_review_code_requires_active_session
run_test_scenario "Review-code duration tracking" test_review_code_duration_tracking
run_test_scenario "Review-code file type support" test_review_code_file_type_support