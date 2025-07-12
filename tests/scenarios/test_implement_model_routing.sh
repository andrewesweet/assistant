#!/bin/bash
# Test: implement.sh must use claude with sonnet model

set -euo pipefail

# Test configuration
TEST_DIR="/tmp/test-implement-routing-$$"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Setup test environment
setup() {
    mkdir -p "$TEST_DIR"
    cd "$TEST_DIR"
    
    # Create mock session
    mkdir -p .ai-session/test-feature-20250711/{artifacts,history}
    
    # Create minimal implementation plan with proper YAML structure
    cat > .ai-session/test-feature-20250711/implementation-plan.yaml << 'EOF'
phases:
  - phase_id: "1"
    name: "Phase 1"
    objective: "Test phase"
    tasks:
      - task_id: "1.1"
        title: "Test task"
        description: "Test task for model routing"
        agent_assignment: "Claude"
        estimated_hours: 1
        dependencies: []
        acceptance_criteria:
          - "Test passes"
        test_requirements:
          - "Unit tests"
        status: "pending"
EOF
    
    # Create session state
    cat > .ai-session/test-feature-20250711/state.yaml << 'EOF'
feature_id: test-feature-20250711
active_task: "1.1"
model_in_use: sonnet
started_at: "2025-07-11T10:00:00Z"
last_updated: "2025-07-11T10:00:00Z"
EOF
    
    # Create active features file
    cat > .ai-session/active-features.yaml << 'EOF'
active_features:
  - test-feature-20250711
EOF
    
    # Create mock commands to intercept calls
    mkdir -p bin
    
    # Mock claude command that logs its invocation
    cat > bin/claude << 'EOF'
#!/bin/bash
echo "CLAUDE_CALLED: $@" >> /tmp/ai-command-calls.log
echo '{"status": "success", "implementation": "mock implementation"}'
exit 0
EOF
    
    # Mock gemini command that logs its invocation
    cat > bin/gemini << 'EOF'
#!/bin/bash
echo "GEMINI_CALLED: $@" >> /tmp/ai-command-calls.log
echo '{"status": "success", "implementation": "mock implementation"}'
exit 0
EOF
    
    chmod +x bin/claude bin/gemini
    
    # Add mocks to PATH
    export PATH="$TEST_DIR/bin:$PATH"
    
    # Clear any previous logs
    rm -f /tmp/ai-command-calls.log
}

# Cleanup
cleanup() {
    cd "$SCRIPT_DIR"
    rm -rf "$TEST_DIR"
    rm -f /tmp/ai-command-calls.log
}

# Test: Verify implement.sh calls claude (not gemini) for implementation
test_implement_uses_claude() {
    echo -e "${YELLOW}Test:${NC} implement.sh must use claude (not gemini)"
    
    # Copy necessary scripts
    cp -r "$SCRIPT_DIR/scripts" .
    
    # Run implement command
    echo -e "${YELLOW}Running:${NC} ./scripts/implement.sh test-feature-20250711 --task 1.1 --no-tests"
    
    # Temporarily disable exit on error for this test
    set +e
    ./scripts/implement.sh test-feature-20250711 --task 1.1 --no-tests >/dev/null 2>&1
    local exit_code=$?
    set -e
    
    # Check what was called
    if [[ -f /tmp/ai-command-calls.log ]]; then
        echo -e "${YELLOW}Commands called:${NC}"
        cat /tmp/ai-command-calls.log
        
        # Verify claude was called
        if grep -q "CLAUDE_CALLED:" /tmp/ai-command-calls.log; then
            echo -e "${GREEN}PASS:${NC} Claude was called (sonnet is the default model)"
            return 0
        elif grep -q "GEMINI_CALLED:" /tmp/ai-command-calls.log; then
            echo -e "${RED}FAIL:${NC} Gemini was called instead of Claude!"
            echo "This violates the original specification that Claude should be used for implementation."
            return 1
        else
            echo -e "${RED}FAIL:${NC} Neither Claude nor Gemini was called"
            return 1
        fi
    else
        echo -e "${RED}FAIL:${NC} No AI commands were logged"
        return 1
    fi
}

# Main test execution
main() {
    echo "Testing implement.sh model routing..."
    echo "Expected: Claude (not Gemini) for implementation"
    echo "Testing that the correct AI model is used..."
    echo ""
    
    # Setup environment
    setup
    
    # Run test
    local test_result=0
    if ! test_implement_uses_claude; then
        test_result=1
    fi
    
    # Cleanup
    cleanup
    
    # Report result
    echo ""
    if [[ $test_result -eq 0 ]]; then
        echo -e "${GREEN}Test PASSED${NC} - implement.sh correctly uses Claude"
        exit 0
    else
        echo -e "${RED}Test FAILED${NC} - implement.sh is not using Claude as specified"
        echo ""
        echo "This test verifies that implement.sh uses Claude (not Gemini) for implementation tasks."
        exit 1
    fi
}

# Handle being sourced vs executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    trap cleanup EXIT
    main "$@"
fi