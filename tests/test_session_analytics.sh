#!/bin/bash
# Test suite for session analytics functionality
# Tests token tracking, cost calculation, and analytics reporting

set -euo pipefail

# Source test harness
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$TEST_DIR/test-command.sh"

# Test configuration
WRAPPER_PATH="$PROJECT_ROOT/scripts/ai-command-wrapper.sh"
SESSION_SCRIPT="$PROJECT_ROOT/scripts/ai-session.sh"
TEST_SESSION_DIR=""

# Mock claude with token information
create_mock_claude_with_tokens() {
    local mock_path="$1"
    
    cat > "$mock_path" << 'EOF'
#!/bin/bash
# Mock claude with token information

while [[ $# -gt 0 ]]; do
    case "$1" in
        --help)
            echo "Mock claude help"
            exit 0
            ;;
        -p|--prompt)
            shift
            if [[ $# -gt 0 ]]; then
                prompt="$1"
                shift
            fi
            ;;
        --print)
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# Return response with token usage
cat << JSON
{
    "response": "This is a test response for analytics",
    "session_id": "test-session-123",
    "usage": {
        "input_tokens": 150,
        "output_tokens": 50
    },
    "model": "claude-3-sonnet-20240229"
}
JSON
EOF
    
    chmod +x "$mock_path"
}

# Setup function
setup() {
    # Create test directory
    TEST_TEMP_DIR=$(mktemp -d)
    export SESSION_DIR="$TEST_TEMP_DIR/.ai-sessions"
    mkdir -p "$SESSION_DIR"
    
    # Create mock claude
    create_mock_claude_with_tokens "$TEST_TEMP_DIR/claude"
    export PATH="$TEST_TEMP_DIR:$PATH"
}

# Teardown function
teardown() {
    if [[ -n "${TEST_TEMP_DIR:-}" ]]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
}

# Test token tracking in metadata
test_token_tracking() {
    setup
    
    # Create a session with analytics
    output=$("$WRAPPER_PATH" claude 60 --session-name "analytics-test" -p "Test prompt for analytics" 2>&1)
    assert_equals "0" "$?" "Command should succeed"
    
    # Check metadata file
    local metadata_file="$SESSION_DIR/analytics-test/metadata.json"
    assert_true "[[ -f $metadata_file ]]" "Metadata file should exist"
    
    if command -v jq >/dev/null 2>&1; then
        # Verify interactions array exists
        local has_interactions=$(jq -e '.interactions' "$metadata_file" >/dev/null 2>&1 && echo "true" || echo "false")
        assert_equals "true" "$has_interactions" "Should have interactions array"
        
        # Check first interaction
        local input_tokens=$(jq -r '.interactions[0].tokens.input // 0' "$metadata_file")
        local output_tokens=$(jq -r '.interactions[0].tokens.output // 0' "$metadata_file")
        
        # Should have token counts (either from response or estimated)
        assert_true "[[ $input_tokens -gt 0 ]]" "Should track input tokens"
        assert_true "[[ $output_tokens -gt 0 ]]" "Should track output tokens"
    fi
    
    teardown
}

# Test cost calculation
test_cost_calculation() {
    setup
    
    # Create session with known token counts
    output=$("$WRAPPER_PATH" claude 60 --session-name "cost-test" -p "Calculate costs" 2>&1)
    assert_equals "0" "$?" "Command should succeed"
    
    local metadata_file="$SESSION_DIR/cost-test/metadata.json"
    
    if command -v jq >/dev/null 2>&1; then
        # Check cost calculation
        local cost=$(jq -r '.interactions[0].cost // 0' "$metadata_file")
        assert_true "[[ $(echo "$cost > 0" | bc) -eq 1 ]]" "Should calculate non-zero cost"
        
        # Verify cost is reasonable (not astronomical)
        assert_true "[[ $(echo "$cost < 1" | bc) -eq 1 ]]" "Cost should be reasonable"
    fi
    
    teardown
}

# Test model-specific pricing
test_model_pricing() {
    setup
    
    # Test with Opus model (higher pricing)
    output=$("$WRAPPER_PATH" claude 60 --session-name "opus-test" --model opus -p "Opus test" 2>&1)
    
    # Test with Sonnet model (default pricing)
    output=$("$WRAPPER_PATH" claude 60 --session-name "sonnet-test" -p "Sonnet test" 2>&1)
    
    if command -v jq >/dev/null 2>&1 && command -v bc >/dev/null 2>&1; then
        # Compare costs (Opus should be more expensive for same token count)
        local opus_cost=$(jq -r '.interactions[0].cost // 0' "$SESSION_DIR/opus-test/metadata.json")
        local sonnet_cost=$(jq -r '.interactions[0].cost // 0' "$SESSION_DIR/sonnet-test/metadata.json")
        
        # Both should have costs
        assert_true "[[ $(echo "$opus_cost > 0" | bc) -eq 1 ]]" "Opus should have cost"
        assert_true "[[ $(echo "$sonnet_cost > 0" | bc) -eq 1 ]]" "Sonnet should have cost"
    fi
    
    teardown
}

# Test duration tracking
test_duration_tracking() {
    setup
    
    output=$("$WRAPPER_PATH" claude 60 --session-name "duration-test" -p "Track duration" 2>&1)
    assert_equals "0" "$?" "Command should succeed"
    
    local metadata_file="$SESSION_DIR/duration-test/metadata.json"
    
    if command -v jq >/dev/null 2>&1; then
        local duration=$(jq -r '.interactions[0].duration_ms // 0' "$metadata_file")
        assert_true "[[ $duration -gt 0 ]]" "Should track execution duration"
        
        # Duration should be reasonable (not 0, not hours)
        assert_true "[[ $duration -lt 60000 ]]" "Duration should be under 60 seconds"
    fi
    
    teardown
}

# Test prompt preview in metadata
test_prompt_preview() {
    setup
    
    # Test with long prompt
    local long_prompt=$(printf 'x%.0s' {1..200})  # 200 character prompt
    output=$("$WRAPPER_PATH" claude 60 --session-name "preview-test" -p "$long_prompt" 2>&1)
    
    local metadata_file="$SESSION_DIR/preview-test/metadata.json"
    
    if command -v jq >/dev/null 2>&1; then
        local preview=$(jq -r '.interactions[0].prompt_preview' "$metadata_file")
        
        # Preview should be truncated
        assert_equals "103" "${#preview}" "Preview should be 100 chars + ..."
        assert_contains "$preview" "..." "Preview should have ellipsis"
    fi
    
    teardown
}

# Test cumulative statistics
test_cumulative_stats() {
    setup
    
    # Create multiple interactions
    "$WRAPPER_PATH" claude 60 --session-name "stats-test" -p "First interaction" >/dev/null 2>&1
    "$WRAPPER_PATH" claude 60 --session-name "stats-test" -p "Second interaction" >/dev/null 2>&1
    "$WRAPPER_PATH" claude 60 --session-name "stats-test" -p "Third interaction" >/dev/null 2>&1
    
    # Check stats using ai-session.sh
    output=$("$SESSION_SCRIPT" stats --session stats-test 2>&1)
    assert_equals "0" "$?" "Stats command should succeed"
    
    # Verify cumulative data
    assert_contains "$output" "Interactions: 3" "Should show 3 interactions"
    assert_contains "$output" "Total:" "Should show total tokens"
    assert_contains "$output" "Cost:" "Should show estimated cost"
    
    teardown
}

# Test analytics export
test_analytics_export() {
    setup
    
    # Create sessions with analytics data
    "$WRAPPER_PATH" claude 60 --session-name "export-test-1" -p "Test 1" >/dev/null 2>&1
    "$WRAPPER_PATH" claude 60 --session-name "export-test-2" -p "Test 2" >/dev/null 2>&1
    
    # Export data
    local export_file="$TEST_TEMP_DIR/analytics-export.json"
    output=$("$SESSION_SCRIPT" export --output "$export_file" 2>&1)
    assert_equals "0" "$?" "Export should succeed"
    
    if command -v jq >/dev/null 2>&1; then
        # Verify export contains interaction data
        local has_interactions=$(jq -e '.[0].interactions' "$export_file" >/dev/null 2>&1 && echo "true" || echo "false")
        assert_equals "true" "$has_interactions" "Export should include interactions"
        
        # Check token data in export
        local total_tokens=$(jq '[.[] | .interactions[].tokens.input // 0] | add' "$export_file")
        assert_true "[[ $total_tokens -gt 0 ]]" "Export should contain token data"
    fi
    
    teardown
}

# Test token estimation fallback
test_token_estimation() {
    setup
    
    # Create mock claude without token info
    cat > "$TEST_TEMP_DIR/claude" << 'EOF'
#!/bin/bash
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help) echo "Mock"; exit 0 ;;
        *) shift ;;
    esac
done
echo "Simple response without token info"
EOF
    chmod +x "$TEST_TEMP_DIR/claude"
    
    output=$("$WRAPPER_PATH" claude 60 --session-name "estimate-test" -p "Test prompt for estimation" 2>&1)
    
    local metadata_file="$SESSION_DIR/estimate-test/metadata.json"
    
    if command -v jq >/dev/null 2>&1; then
        # Should have estimated tokens
        local input_tokens=$(jq -r '.interactions[0].tokens.input // 0' "$metadata_file")
        local output_tokens=$(jq -r '.interactions[0].tokens.output // 0' "$metadata_file")
        
        assert_true "[[ $input_tokens -gt 0 ]]" "Should estimate input tokens"
        assert_true "[[ $output_tokens -gt 0 ]]" "Should estimate output tokens"
        
        # Rough check: "Test prompt for estimation" is ~26 chars, so ~6-7 tokens
        assert_true "[[ $input_tokens -ge 5 && $input_tokens -le 10 ]]" "Input estimation should be reasonable"
    fi
    
    teardown
}

# Test analytics with JSON output mode
test_analytics_json_mode() {
    setup
    
    output=$("$WRAPPER_PATH" claude 60 --session-name "json-analytics" --json -p "JSON test" 2>&1)
    assert_equals "0" "$?" "JSON mode should succeed"
    
    # Analytics should still be tracked
    local metadata_file="$SESSION_DIR/json-analytics/metadata.json"
    assert_true "[[ -f $metadata_file ]]" "Metadata should be created in JSON mode"
    
    if command -v jq >/dev/null 2>&1; then
        local interaction_count=$(jq '.interactions | length' "$metadata_file")
        assert_equals "1" "$interaction_count" "Should track interaction in JSON mode"
    fi
    
    teardown
}

# Main test runner
main() {
    local tests=(
        "test_token_tracking"
        "test_cost_calculation"
        "test_model_pricing"
        "test_duration_tracking"
        "test_prompt_preview"
        "test_cumulative_stats"
        "test_analytics_export"
        "test_token_estimation"
        "test_analytics_json_mode"
    )
    
    local passed=0
    local failed=0
    
    echo "Running session analytics tests..."
    echo
    
    for test in "${tests[@]}"; do
        echo -n "Running $test... "
        if output=$($test 2>&1); then
            echo -e "${GREEN}PASS${NC}"
            ((passed++))
        else
            echo -e "${RED}FAIL${NC}"
            echo "$output"
            ((failed++))
        fi
    done
    
    echo
    echo "Results: $passed passed, $failed failed"
    
    if [[ $failed -gt 0 ]]; then
        return 1
    fi
    
    return 0
}

# Run tests if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi