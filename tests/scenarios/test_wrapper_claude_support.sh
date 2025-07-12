#!/bin/bash
# Test: ai-command-wrapper.sh must support claude commands

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test configuration
WRAPPER_SCRIPT="scripts/ai-command-wrapper.sh"
TEST_PROMPT="Test prompt for wrapper validation"

echo "Testing ai-command-wrapper.sh Claude support..."
echo ""

# Check if wrapper exists
if [[ ! -f "$WRAPPER_SCRIPT" ]]; then
    echo -e "${RED}FAIL:${NC} $WRAPPER_SCRIPT not found"
    exit 1
fi

# Test 1: Basic claude command execution
test_claude_basic() {
    echo -e "${YELLOW}Test 1:${NC} Basic claude command"
    
    # Create a mock claude command for testing
    local mock_dir="/tmp/mock-claude-$$"
    mkdir -p "$mock_dir"
    
    cat > "$mock_dir/claude" << 'EOF'
#!/bin/bash
echo "MOCK_CLAUDE_EXECUTED"
echo "Arguments: $@"
exit 0
EOF
    chmod +x "$mock_dir/claude"
    
    # Add mock to PATH temporarily
    local original_path="$PATH"
    export PATH="$mock_dir:$PATH"
    
    # Test the wrapper
    local output
    local exit_code
    
    set +e
    output=$($WRAPPER_SCRIPT claude 5 -p "$TEST_PROMPT" 2>&1)
    exit_code=$?
    set -e
    
    # Restore PATH
    export PATH="$original_path"
    rm -rf "$mock_dir"
    
    # Check results
    if [[ $exit_code -eq 0 ]]; then
        if echo "$output" | grep -q "MOCK_CLAUDE_EXECUTED"; then
            echo -e "${GREEN}PASS:${NC} Wrapper executed claude command"
            return 0
        else
            echo -e "${RED}FAIL:${NC} Wrapper didn't execute claude properly"
            echo "Output: $output"
            return 1
        fi
    else
        echo -e "${RED}FAIL:${NC} Wrapper failed with exit code $exit_code"
        echo "Output: $output"
        return 1
    fi
}

# Test 2: Claude with model argument
test_claude_with_model() {
    echo -e "${YELLOW}Test 2:${NC} Claude with --model opus"
    
    # Create a mock claude command
    local mock_dir="/tmp/mock-claude-$$"
    mkdir -p "$mock_dir"
    
    cat > "$mock_dir/claude" << 'EOF'
#!/bin/bash
# Check if --model opus was passed
for arg in "$@"; do
    if [[ "$arg" == "--model" ]]; then
        model_next=true
    elif [[ "$model_next" == "true" ]]; then
        if [[ "$arg" == "opus" ]]; then
            echo "MOCK_CLAUDE_OPUS_MODE"
            exit 0
        fi
    fi
done
echo "MOCK_CLAUDE_DEFAULT_MODE"
exit 0
EOF
    chmod +x "$mock_dir/claude"
    
    # Add mock to PATH
    local original_path="$PATH"
    export PATH="$mock_dir:$PATH"
    
    # Set required environment variables
    export CLAUDE_CODE_SSE_PORT="${CLAUDE_CODE_SSE_PORT:-}"
    export CLAUDECODE="${CLAUDECODE:-}"
    
    # Test the wrapper with model argument
    local output
    local exit_code
    
    set +e
    output=$($WRAPPER_SCRIPT claude 5 --model opus -p "$TEST_PROMPT" 2>&1)
    exit_code=$?
    set -e
    
    # Restore PATH
    export PATH="$original_path"
    rm -rf "$mock_dir"
    
    # Check results
    if [[ $exit_code -eq 0 ]]; then
        if echo "$output" | grep -q "MOCK_CLAUDE_OPUS_MODE"; then
            echo -e "${GREEN}PASS:${NC} Wrapper correctly passed --model opus"
            return 0
        else
            echo -e "${RED}FAIL:${NC} Wrapper didn't pass model argument correctly"
            echo "Output: $output"
            return 1
        fi
    else
        echo -e "${RED}FAIL:${NC} Wrapper failed with exit code $exit_code"
        echo "Output: $output"
        return 1
    fi
}

# Test 3: Timeout functionality
test_claude_timeout() {
    echo -e "${YELLOW}Test 3:${NC} Timeout enforcement"
    
    # Create a mock claude that sleeps
    local mock_dir="/tmp/mock-claude-$$"
    mkdir -p "$mock_dir"
    
    cat > "$mock_dir/claude" << 'EOF'
#!/bin/bash
if [[ "$1" == "--help" ]]; then
    echo "Mock claude help"
    exit 0
fi
sleep 10
echo "SHOULD_NOT_SEE_THIS"
EOF
    chmod +x "$mock_dir/claude"
    
    # Add mock to PATH
    local original_path="$PATH"
    export PATH="$mock_dir:$PATH"
    
    # Set required environment variables
    export CLAUDE_CODE_SSE_PORT="${CLAUDE_CODE_SSE_PORT:-}"
    export CLAUDECODE="${CLAUDECODE:-}"
    
    # Test with 2 second timeout
    local start_time=$(date +%s)
    local output
    local exit_code
    
    set +e
    output=$($WRAPPER_SCRIPT claude 2 -p "$TEST_PROMPT" 2>&1)
    exit_code=$?
    set -e
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Restore PATH
    export PATH="$original_path"
    rm -rf "$mock_dir"
    
    # Check timeout worked (should complete in ~2 seconds, not 10)
    if [[ $duration -lt 5 ]]; then
        echo -e "${GREEN}PASS:${NC} Timeout enforced (completed in ${duration}s)"
        return 0
    else
        echo -e "${RED}FAIL:${NC} Timeout not enforced (took ${duration}s)"
        return 1
    fi
}

# Main test execution
main() {
    local failed=0
    
    # Run all tests
    if ! test_claude_basic; then
        ((failed++))
    fi
    echo ""
    
    if ! test_claude_with_model; then
        ((failed++))
    fi
    echo ""
    
    if ! test_claude_timeout; then
        ((failed++))
    fi
    echo ""
    
    # Summary
    if [[ $failed -eq 0 ]]; then
        echo -e "${GREEN}All tests PASSED${NC} - ai-command-wrapper.sh supports claude"
        exit 0
    else
        echo -e "${RED}$failed test(s) FAILED${NC} - ai-command-wrapper.sh needs claude support"
        echo ""
        echo "The wrapper must:"
        echo "1. Execute claude commands with proper argument passing"
        echo "2. Support --model argument for opus mode"
        echo "3. Enforce timeout limits"
        echo ""
        echo "Note: Current implementation may have issues with output redirection"
        echo "that prevent claude from working properly through the wrapper."
        exit 1
    fi
}

# Run tests
main "$@"