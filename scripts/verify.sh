#!/bin/bash
# AI Orchestrator - Verify Command
# Runs tests with fresh context, no state references
# Each verification gets a unique agent ID for complete isolation

set -euo pipefail

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Common utilities will be sourced as needed

# Default values
FEATURE_ID=""
TEST_TYPE="all"
FRAMEWORK=""
FILTER=""
EXCLUDE=""
PARALLEL=false
CI_MODE=false
WATCH_MODE=false
WATCH_ONCE=false
DISCOVER_ONLY=false
CUSTOM_COMMAND=""
COVERAGE=false
RACE=false
VERBOSE=false
JSON_OUTPUT=false
AUTO_DETECT=false

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Usage function
usage() {
    echo "Usage: $0 <feature-id> [options]"
    echo ""
    echo "Run tests with fresh context and no state references"
    echo ""
    echo "Options:"
    echo "  --unit              Run unit tests only"
    echo "  --integration       Run integration tests only"
    echo "  --acceptance        Run acceptance tests only"
    echo "  --all               Run all tests (default)"
    echo "  --go                Run Go tests"
    echo "  --python            Run Python tests"
    echo "  --javascript        Run JavaScript tests"
    echo "  --auto              Auto-detect test framework"
    echo "  --filter <pattern>  Filter tests by pattern"
    echo "  --exclude <pattern> Exclude tests matching pattern"
    echo "  --parallel          Run tests in parallel"
    echo "  --ci                CI mode with structured output"
    echo "  --coverage          Enable coverage reporting"
    echo "  --race              Enable race detector (Go only)"
    echo "  --verbose           Verbose output"
    echo "  --custom <cmd>      Run custom test command"
    echo "  --discover-only     Only discover tests, don't run"
    echo "  --watch             Watch mode (continuous testing)"
    echo "  --watch-once        Run once in watch mode (for testing)"
    echo "  --json              Output results as JSON"
    echo "  -h, --help          Show this help message"
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --unit)
            TEST_TYPE="unit"
            shift
            ;;
        --integration)
            TEST_TYPE="integration"
            shift
            ;;
        --acceptance)
            TEST_TYPE="acceptance"
            shift
            ;;
        --all)
            TEST_TYPE="all"
            shift
            ;;
        --go)
            FRAMEWORK="go"
            shift
            ;;
        --python)
            FRAMEWORK="python"
            shift
            ;;
        --javascript)
            FRAMEWORK="javascript"
            shift
            ;;
        --auto)
            AUTO_DETECT=true
            shift
            ;;
        --filter)
            FILTER="$2"
            shift 2
            ;;
        --exclude)
            EXCLUDE="$2"
            shift 2
            ;;
        --parallel)
            PARALLEL=true
            shift
            ;;
        --ci)
            CI_MODE=true
            shift
            ;;
        --coverage)
            COVERAGE=true
            shift
            ;;
        --race)
            RACE=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --custom)
            CUSTOM_COMMAND="$2"
            shift 2
            ;;
        --discover-only|--discover)
            DISCOVER_ONLY=true
            shift
            ;;
        --watch)
            WATCH_MODE=true
            shift
            ;;
        --watch-once)
            WATCH_ONCE=true
            shift
            ;;
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            if [[ -z "$FEATURE_ID" ]]; then
                FEATURE_ID="$1"
            else
                echo "Error: Unknown argument: $1"
                usage
            fi
            shift
            ;;
    esac
done

# Check if feature ID is provided
if [[ -z "$FEATURE_ID" ]]; then
    echo "Error: Feature ID is required"
    usage
fi

# Validate feature exists
SESSION_DIR="$PROJECT_ROOT/.ai-session/$FEATURE_ID"
if [[ ! -d "$SESSION_DIR" ]]; then
    echo "Error: Session not found for feature: $FEATURE_ID"
    exit 1
fi

# Generate unique agent ID for this verification
AGENT_ID="verify-$(date +%s)-$$-$(openssl rand -hex 4)"

# Function to log to history
log_history() {
    local status="$1"
    local details="$2"
    local duration_ms="${3:-0}"
    
    "$SCRIPT_DIR/log-command.sh" "$FEATURE_ID" "verify" \
        --status "$status" \
        --details "$details" \
        --model "claude" \
        --duration "$duration_ms" \
        --metadata "{\"agent_id\": \"$AGENT_ID\", \"fresh_context\": true, \"test_type\": \"$TEST_TYPE\"}"
}

# Function to discover tests
discover_tests() {
    local artifacts_dir="$SESSION_DIR/artifacts"
    local discovered_tests=()
    local frameworks_found=()
    
    if [[ ! -d "$artifacts_dir" ]]; then
        echo "No artifacts directory found"
        return 1
    fi
    
    # Discover Go tests
    while IFS= read -r -d '' file; do
        discovered_tests+=("$file")
        [[ ! " ${frameworks_found[@]} " =~ " go " ]] && frameworks_found+=("go")
    done < <(find "$artifacts_dir" -name "*_test.go" -print0 2>/dev/null)
    
    # Discover Python tests
    while IFS= read -r -d '' file; do
        discovered_tests+=("$file")
        [[ ! " ${frameworks_found[@]} " =~ " python " ]] && frameworks_found+=("python")
    done < <(find "$artifacts_dir" \( -name "test_*.py" -o -name "*_test.py" \) -print0 2>/dev/null)
    
    # Discover JavaScript/TypeScript tests
    while IFS= read -r -d '' file; do
        discovered_tests+=("$file")
        [[ ! " ${frameworks_found[@]} " =~ " javascript " ]] && frameworks_found+=("javascript")
    done < <(find "$artifacts_dir" \( -name "*.test.js" -o -name "*.spec.js" -o -name "*.test.ts" -o -name "*.spec.ts" \) -print0 2>/dev/null)
    
    # Discover Ruby tests
    while IFS= read -r -d '' file; do
        discovered_tests+=("$file")
        [[ ! " ${frameworks_found[@]} " =~ " ruby " ]] && frameworks_found+=("ruby")
    done < <(find "$artifacts_dir" \( -name "*_spec.rb" -o -name "*_test.rb" \) -print0 2>/dev/null)
    
    if [[ $JSON_OUTPUT == true ]]; then
        echo -n '{"discovered_tests": ['
        local first=true
        for test in "${discovered_tests[@]}"; do
            [[ $first == false ]] && echo -n ", "
            echo -n "\"$(basename "$test")\""
            first=false
        done
        echo -n '], "frameworks": ['
        first=true
        for fw in "${frameworks_found[@]}"; do
            [[ $first == false ]] && echo -n ", "
            echo -n "\"$fw\""
            first=false
        done
        echo '], "total": '${#discovered_tests[@]}'}'
    else
        echo -e "${BLUE}Discovering tests with fresh context${NC}"
        echo "Found ${#discovered_tests[@]} test files"
        for fw in "${frameworks_found[@]}"; do
            echo "  - $fw framework detected"
        done
        if [[ ${#discovered_tests[@]} -gt 0 ]]; then
            echo "Test files:"
            for test in "${discovered_tests[@]}"; do
                echo "  - $(basename "$test")"
            done
        fi
    fi
    
    if [[ $DISCOVER_ONLY == true ]]; then
        return 0
    fi
    
    return 0
}

# Function to auto-detect frameworks
auto_detect_framework() {
    local artifacts_dir="$SESSION_DIR/artifacts"
    local detected_frameworks=()
    
    # Check for Node.js/JavaScript
    if [[ -f "$artifacts_dir/package.json" ]]; then
        if grep -q "jest" "$artifacts_dir/package.json" 2>/dev/null; then
            detected_frameworks+=("jest")
        elif grep -q "mocha" "$artifacts_dir/package.json" 2>/dev/null; then
            detected_frameworks+=("mocha")
        else
            detected_frameworks+=("javascript")
        fi
    fi
    
    # Check for Python
    if [[ -f "$artifacts_dir/requirements.txt" ]]; then
        if grep -q "pytest" "$artifacts_dir/requirements.txt" 2>/dev/null; then
            detected_frameworks+=("pytest")
        elif grep -q "unittest" "$artifacts_dir/requirements.txt" 2>/dev/null; then
            detected_frameworks+=("unittest")
        else
            detected_frameworks+=("python")
        fi
    elif [[ -f "$artifacts_dir/setup.py" ]] || [[ -f "$artifacts_dir/pyproject.toml" ]]; then
        detected_frameworks+=("python")
    fi
    
    # Check for Go
    if [[ -f "$artifacts_dir/go.mod" ]]; then
        detected_frameworks+=("go")
    fi
    
    # Check for Ruby
    if [[ -f "$artifacts_dir/Gemfile" ]]; then
        if grep -q "rspec" "$artifacts_dir/Gemfile" 2>/dev/null; then
            detected_frameworks+=("rspec")
        else
            detected_frameworks+=("ruby")
        fi
    fi
    
    if [[ ${#detected_frameworks[@]} -gt 0 ]]; then
        echo -e "${BLUE}Auto-detecting test frameworks...${NC}"
        for fw in "${detected_frameworks[@]}"; do
            echo "  - Detected: $fw"
        done
    fi
    
    # Set framework if only one detected and none specified
    if [[ -z "$FRAMEWORK" ]] && [[ ${#detected_frameworks[@]} -eq 1 ]]; then
        FRAMEWORK="${detected_frameworks[0]}"
    fi
}

# Function to create verify prompt
create_verify_prompt() {
    local test_files="$1"
    local prompt=""
    
    # Create fresh context prompt with no session state
    prompt="You are a fresh verification agent with ID: $AGENT_ID

You have NO prior context, history, or state from any previous operations.
You must verify tests independently without any references to:
- Previous commands or their outputs
- Session state or active tasks
- Implementation history or artifacts
- Any context from other agents

Your task is to verify the following tests:

Test Type: $TEST_TYPE"

    if [[ -n "$FRAMEWORK" ]]; then
        prompt="$prompt
Framework: $FRAMEWORK"
    fi

    if [[ -n "$FILTER" ]]; then
        prompt="$prompt
Filter: $FILTER"
    fi

    if [[ -n "$EXCLUDE" ]]; then
        prompt="$prompt
Exclude: $EXCLUDE"
    fi

    if [[ $COVERAGE == true ]]; then
        prompt="$prompt
Coverage: enabled"
    fi

    if [[ $RACE == true ]]; then
        prompt="$prompt
Race Detection: enabled"
    fi

    if [[ -n "$CUSTOM_COMMAND" ]]; then
        prompt="$prompt
Custom Command: $CUSTOM_COMMAND"
    fi

    prompt="$prompt

Test Files Found:
$test_files

Please run these tests and provide a detailed report including:
1. Total tests discovered
2. Tests passed
3. Tests failed
4. Tests skipped
5. Coverage percentage (if enabled)
6. Performance metrics
7. Any errors or issues

Respond in JSON format with the structure:
{
    \"status\": \"success\" or \"failure\",
    \"framework\": \"detected framework\",
    \"tests\": {
        \"total\": number,
        \"passed\": number,
        \"failed\": number,
        \"skipped\": number
    },
    \"coverage\": \"percentage if enabled\",
    \"duration_ms\": number,
    \"errors\": [\"any errors\"]
}"

    echo "$prompt"
}

# Function to run verification
run_verification() {
    local start_time=$(date +%s%N)
    
    # Auto-detect if requested
    if [[ $AUTO_DETECT == true ]]; then
        auto_detect_framework
    fi
    
    # Discover tests
    if [[ $DISCOVER_ONLY == true ]]; then
        discover_tests
        return 0
    fi
    
    # Get test files
    local test_files=$(discover_tests 2>&1)
    
    if [[ -z "$test_files" ]] || [[ "$test_files" == *"No artifacts"* ]]; then
        echo "Error: No test files found"
        log_history "failure" "No test files found"
        return 1
    fi
    
    # Create verification prompt
    local prompt=$(create_verify_prompt "$test_files")
    
    # Run verification with claude
    if [[ $VERBOSE == true ]]; then
        echo -e "${BLUE}Running verification with agent: $AGENT_ID${NC}"
    fi
    
    # Execute verification
    local cmd="claude -p"
    local output
    
    if [[ -n "$CUSTOM_COMMAND" ]]; then
        # For custom commands, pass them through
        output=$(echo "$prompt" | $cmd 2>&1)
    else
        # Standard verification
        output=$(echo "$prompt" | $cmd 2>&1)
    fi
    
    local exit_code=$?
    local end_time=$(date +%s%N)
    local duration_ms=$(( (end_time - start_time) / 1000000 ))
    
    # Process output
    if [[ $JSON_OUTPUT == true ]]; then
        echo "$output"
    else
        # Parse JSON output for display
        if command -v jq >/dev/null 2>&1 && echo "$output" | jq empty 2>/dev/null; then
            local status=$(echo "$output" | jq -r '.status // "unknown"')
            local framework=$(echo "$output" | jq -r '.framework // "unknown"')
            local total=$(echo "$output" | jq -r '.tests.total // 0')
            local passed=$(echo "$output" | jq -r '.tests.passed // 0')
            local failed=$(echo "$output" | jq -r '.tests.failed // 0')
            local skipped=$(echo "$output" | jq -r '.tests.skipped // 0')
            
            echo -e "\n${BLUE}Verification Results${NC}"
            echo "Agent ID: $AGENT_ID"
            echo "Framework: $framework"
            echo "Status: $status"
            echo ""
            echo "Tests:"
            echo "  Total: $total"
            echo -e "  ${GREEN}Passed: $passed${NC}"
            if [[ $failed -gt 0 ]]; then
                echo -e "  ${RED}Failed: $failed${NC}"
            else
                echo "  Failed: $failed"
            fi
            if [[ $skipped -gt 0 ]]; then
                echo -e "  ${YELLOW}Skipped: $skipped${NC}"
            fi
            
            if [[ $COVERAGE == true ]]; then
                local coverage=$(echo "$output" | jq -r '.coverage // "N/A"')
                echo "  Coverage: $coverage"
            fi
            
            echo ""
            echo "Duration: ${duration_ms}ms"
        else
            # Fallback display
            echo "$output"
        fi
    fi
    
    # Log to history
    if [[ $exit_code -eq 0 ]]; then
        log_history "success" "Tests verified" "$duration_ms"
    else
        log_history "failure" "Verification failed" "$duration_ms"
    fi
    
    # CI mode - create test results file
    if [[ $CI_MODE == true ]]; then
        local results_file="$SESSION_DIR/artifacts/test-results.xml"
        echo '<?xml version="1.0" encoding="UTF-8"?>' > "$results_file"
        echo '<testsuites>' >> "$results_file"
        echo "  <testsuite name=\"$FEATURE_ID\" tests=\"$total\" failures=\"$failed\" skipped=\"$skipped\" time=\"$(( duration_ms / 1000 ))\">" >> "$results_file"
        echo '  </testsuite>' >> "$results_file"
        echo '</testsuites>' >> "$results_file"
        echo "Test results written to: $results_file"
    fi
    
    return $exit_code
}

# Main execution
if [[ $WATCH_MODE == true ]] || [[ $WATCH_ONCE == true ]]; then
    # Watch mode
    if [[ $WATCH_ONCE == true ]]; then
        # Run once for testing
        run_verification
    else
        echo -e "${BLUE}Watch mode enabled. Press Ctrl+C to stop.${NC}"
        while true; do
            run_verification
            echo -e "\n${YELLOW}Waiting for file changes...${NC}"
            sleep 2
        done
    fi
else
    # Single run
    run_verification
fi