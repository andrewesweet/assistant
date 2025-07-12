#!/bin/bash
# Basic test harness for testing orchestrator commands
# This provides the foundation for all test scenarios

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test configuration
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$TEST_DIR/.." && pwd)"
TEST_TEMP_DIR=""

# Test utilities
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Values should be equal}"
    
    if [[ "$expected" != "$actual" ]]; then
        echo -e "${RED}FAIL:${NC} $message"
        echo "  Expected: '$expected'"
        echo "  Actual:   '$actual'"
        return 1
    fi
}

assert_not_equals() {
    local value1="$1"
    local value2="$2"
    local message="${3:-Values should not be equal}"
    
    if [[ "$value1" == "$value2" ]]; then
        echo -e "${RED}FAIL:${NC} $message"
        echo "  Both values: '$value1'"
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-String should contain substring}"
    
    if [[ "$haystack" != *"$needle"* ]]; then
        echo -e "${RED}FAIL:${NC} $message"
        echo "  Looking for: '$needle'"
        echo "  In: '$haystack'"
        return 1
    fi
}

assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-String should not contain substring}"
    
    if [[ "$haystack" == *"$needle"* ]]; then
        echo -e "${RED}FAIL:${NC} $message"
        echo "  Found: '$needle'"
        echo "  In: '$haystack'"
        return 1
    fi
}

assert_exists() {
    local path="$1"
    local message="${2:-Path should exist}"
    
    if [[ ! -e "$path" ]]; then
        echo -e "${RED}FAIL:${NC} $message"
        echo "  Missing: '$path'"
        return 1
    fi
}

assert_not_exists() {
    local path="$1"
    local message="${2:-Path should not exist}"
    
    if [[ -e "$path" ]]; then
        echo -e "${RED}FAIL:${NC} $message"
        echo "  Exists: '$path'"
        return 1
    fi
}

assert_file_contains() {
    local file="$1"
    local content="$2"
    local message="${3:-File should contain content}"
    
    if [[ ! -f "$file" ]]; then
        echo -e "${RED}FAIL:${NC} File not found: $file"
        return 1
    fi
    
    if ! grep -q "$content" "$file"; then
        echo -e "${RED}FAIL:${NC} $message"
        echo "  File: '$file'"
        echo "  Missing: '$content'"
        return 1
    fi
}

assert_json_valid() {
    local file="$1"
    local message="${2:-File should contain valid JSON}"
    
    if [[ ! -f "$file" ]]; then
        echo -e "${RED}FAIL:${NC} File not found: $file"
        return 1
    fi
    
    if ! jq empty "$file" 2>/dev/null; then
        echo -e "${RED}FAIL:${NC} $message"
        echo "  File: '$file'"
        echo "  Error: Invalid JSON"
        return 1
    fi
}

assert_yaml_valid() {
    local file="$1"
    local message="${2:-File should contain valid YAML}"
    
    if [[ ! -f "$file" ]]; then
        echo -e "${RED}FAIL:${NC} File not found: $file"
        return 1
    fi
    
    # Basic YAML validation (checks for common issues)
    if grep -E '^\t' "$file" >/dev/null; then
        echo -e "${RED}FAIL:${NC} $message"
        echo "  File: '$file'"
        echo "  Error: YAML contains tabs (use spaces)"
        return 1
    fi
}

assert_exit_code() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Exit code should match}"
    
    if [[ "$expected" != "$actual" ]]; then
        echo -e "${RED}FAIL:${NC} $message"
        echo "  Expected: $expected"
        echo "  Actual:   $actual"
        return 1
    fi
}

assert_sorted() {
    local input="$1"
    local message="${2:-Output should be sorted}"
    
    local sorted=$(echo "$input" | sort)
    if [[ "$input" != "$sorted" ]]; then
        echo -e "${RED}FAIL:${NC} $message"
        return 1
    fi
}

assert_less_than() {
    local value="$1"
    local threshold="$2"
    local message="${3:-Value should be less than threshold}"
    
    if [[ "$value" -ge "$threshold" ]]; then
        echo -e "${RED}FAIL:${NC} $message"
        echo "  Value: $value"
        echo "  Threshold: $threshold"
        return 1
    fi
}

# Command execution wrapper
run_command() {
    local cmd_file="$1"
    shift
    local args="$@"
    
    # Check if command file exists
    if [[ ! -f "$cmd_file" ]]; then
        echo -e "${RED}ERROR:${NC} Command file not found: $cmd_file"
        return 1
    fi
    
    # Set up test environment
    export ARGUMENTS="$args"
    export USER="${TEST_USER:-test-user}"
    export TEST_MODE="true"
    
    # Execute command
    # Note: In real implementation, this would use claude command
    # For now, we'll simulate the execution
    echo "Executing: $cmd_file with args: $args"
    
    # Simulate command execution
    # In real implementation:
    # claude --dangerously-skip-permissions --model opus -p "$(cat "$cmd_file")"
}

# Mock utilities
mock_command() {
    local command="$1"
    local func_body="$2"
    
    # Create mock function with proper body
    eval "$func_body"
    
    # Create alias
    alias "${command}=mock_${command}"
    
    # Also export function for subshells
    export -f "mock_${command}"
}

# Helper to create file-based mock tracking
create_mock_tracker() {
    local prefix="$1"
    echo "/tmp/${prefix}_$$"
}

# Create mock command script that overrides real commands
create_mock_script() {
    local command="$1"
    local script_body="$2"
    
    # Create bin directory if it doesn't exist
    mkdir -p bin
    
    # Create mock script
    cat > "bin/$command" << EOF
#!/bin/bash
$script_body
EOF
    
    chmod +x "bin/$command"
    
    # Add bin to PATH (at the beginning to override system commands)
    export PATH="$PWD/bin:$PATH"
}

unmock_command() {
    local command="$1"
    unalias "$command" 2>/dev/null || true
}

# Session utilities
create_test_session() {
    local feature_id="${1:-test-feature-$(date +%s)}"
    local session_dir="$TEST_TEMP_DIR/.ai-session/$feature_id"
    
    mkdir -p "$session_dir/artifacts"
    
    # Create initial state
    cat > "$session_dir/state.yaml" <<EOF
version: "1.0"
feature_id: "$feature_id"
current_state:
  active_task: null
  model_in_use: "sonnet"
  started_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  last_updated: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
EOF
    
    # Create empty history
    touch "$session_dir/history.jsonl"
    
    echo "$feature_id"
}

cleanup_test_sessions() {
    if [[ -n "$TEST_TEMP_DIR" ]] && [[ -d "$TEST_TEMP_DIR/.ai-session" ]]; then
        rm -rf "$TEST_TEMP_DIR/.ai-session/test-"*
    fi
}

# Test runner utilities
setup_test_env() {
    # Create temporary test directory
    TEST_TEMP_DIR=$(mktemp -d -t "ai-orchestrator-test-XXXXXX")
    
    # Change to temp directory
    cd "$TEST_TEMP_DIR"
    
    # Create basic structure
    mkdir -p .claude/commands
    mkdir -p .ai-session
    
    # Set up environment
    export TEST_ENV="true"
    export AI_ORCHESTRATOR_ROOT="$TEST_TEMP_DIR"
}

cleanup_test_env() {
    # Return to original directory
    cd "$PROJECT_ROOT"
    
    # Remove temporary directory
    if [[ -n "$TEST_TEMP_DIR" ]] && [[ -d "$TEST_TEMP_DIR" ]]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
}

# Test execution helpers
run_test_scenario() {
    local test_name="$1"
    local test_function="$2"
    
    echo -e "\n${YELLOW}Running:${NC} $test_name"
    
    # Save project root before changing directory
    export PROJECT_ROOT="$PROJECT_ROOT"
    
    # Set up test environment
    setup_test_env
    
    # Set trap for cleanup
    trap cleanup_test_env EXIT
    
    # Run the test
    set +e
    (
        set -e
        $test_function
    )
    local result=$?
    set -e
    
    # Report result
    if [[ $result -eq 0 ]]; then
        echo -e "${GREEN}PASS:${NC} $test_name"
    else
        echo -e "${RED}FAIL:${NC} $test_name"
    fi
    
    # Clean up
    cleanup_test_env
    trap - EXIT
    
    return $result
}

# Performance measurement
measure_time() {
    local start=$(date +%s%N)
    "$@"
    local end=$(date +%s%N)
    echo $((($end - $start) / 1000000))  # milliseconds
}

# Help function
show_help() {
    cat <<EOF
AI Orchestrator Test Harness

Usage: $0 [options]

Options:
  -h, --help     Show this help message
  -v, --verbose  Enable verbose output
  -t, --test     Run specific test function

Examples:
  $0                    # Run default test
  $0 -t test_basic      # Run specific test
  $0 -v                 # Run with verbose output

Environment Variables:
  TEST_VERBOSE=1        Enable verbose output
  TEST_USER=username    Set test user name

EOF
}

# Main function for standalone execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--verbose)
                export TEST_VERBOSE=1
                shift
                ;;
            -t|--test)
                TEST_FUNCTION="$2"
                shift 2
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Run test or show help
    if [[ -n "${TEST_FUNCTION:-}" ]]; then
        run_test_scenario "$TEST_FUNCTION" "$TEST_FUNCTION"
    else
        echo "Test harness loaded. Use -t to run a specific test."
        show_help
    fi
fi