#!/bin/bash
# AI Orchestrator Test Suite Runner
# Runs all tests related to AI session management and orchestration

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test directory
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$TEST_DIR/.." && pwd)"

# Test categories
declare -A test_categories=(
    ["Session Management"]="test_ai_command_wrapper_sessions.sh test_session_file_locking.sh test_ai_session_management.sh"
    ["Analytics & Tracking"]="test_session_analytics.sh test_todowrite_integration.sh"
    ["Core Scripts"]="scenarios/test_wrapper_claude_support.sh scenarios/test_wrapper_claude_timeout_isolated.sh"
    ["Init & Setup"]="scenarios/test_init_session.sh scenarios/test_concurrent_sessions.sh"
    ["Planning"]="scenarios/test_plan_gemini_routing.sh scenarios/test_plan_opus_fallback.sh test_plan_sessions.sh"
    ["Implementation"]="scenarios/test_implement_atdd.sh scenarios/test_implement_model_routing.sh scenarios/test_implement_history.sh test_implement_sessions.sh"
    ["Review & Verify"]="scenarios/test_review_code_routing.sh scenarios/test_review_architecture_fallback.sh scenarios/test_verify_fresh_context.sh"
    ["Status & History"]="scenarios/test_status_display.sh scenarios/test_review_history_logging.sh"
    ["Session Cleanup"]="scenarios/test_session_cleanup.sh"
)

# Track results
total_tests=0
passed_tests=0
failed_tests=0
skipped_tests=0
failed_test_names=()

# Check if test file exists
test_exists() {
    local test_file="$1"
    if [[ -f "$TEST_DIR/$test_file" ]]; then
        return 0
    else
        return 1
    fi
}

# Run a single test
run_test() {
    local test_file="$1"
    local test_name=$(basename "$test_file" .sh)
    
    echo -n "  Running $test_name... "
    
    if ! test_exists "$test_file"; then
        echo -e "${YELLOW}SKIP${NC} (file not found)"
        ((skipped_tests++))
        return 0
    fi
    
    # Create temp file for output
    local output_file=$(mktemp)
    
    # Run test with timeout
    if timeout 60 bash "$TEST_DIR/$test_file" > "$output_file" 2>&1; then
        echo -e "${GREEN}PASS${NC}"
        ((passed_tests++))
        rm -f "$output_file"
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        ((failed_tests++))
        failed_test_names+=("$test_name")
        
        # Show error output
        echo -e "${RED}--- Error output for $test_name ---${NC}"
        cat "$output_file"
        echo -e "${RED}--- End of error output ---${NC}"
        echo
        
        rm -f "$output_file"
        return 1
    fi
}

# Run tests in a category
run_category() {
    local category="$1"
    local tests="${test_categories[$category]}"
    
    echo -e "${BLUE}Running $category tests...${NC}"
    
    for test in $tests; do
        ((total_tests++))
        run_test "$test" || true
    done
    
    echo
}

# Check prerequisites
check_prerequisites() {
    echo "Checking prerequisites..."
    
    # Check for required tools
    local required_tools=("jq" "flock" "timeout")
    local missing_tools=()
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        echo -e "${RED}Missing required tools: ${missing_tools[*]}${NC}"
        echo "Please install the missing tools and try again."
        return 1
    fi
    
    # Check for test harness
    if [[ ! -f "$TEST_DIR/test-command.sh" ]]; then
        echo -e "${RED}Missing test harness: test-command.sh${NC}"
        return 1
    fi
    
    echo -e "${GREEN}All prerequisites met${NC}"
    echo
    return 0
}

# Generate test report
generate_report() {
    echo
    echo "========================================="
    echo "AI Orchestrator Test Suite Results"
    echo "========================================="
    echo "Total tests:    $total_tests"
    echo -e "Passed:         ${GREEN}$passed_tests${NC}"
    echo -e "Failed:         ${RED}$failed_tests${NC}"
    echo -e "Skipped:        ${YELLOW}$skipped_tests${NC}"
    echo
    
    if [[ $failed_tests -gt 0 ]]; then
        echo -e "${RED}Failed tests:${NC}"
        for test in "${failed_test_names[@]}"; do
            echo "  - $test"
        done
        echo
    fi
    
    # Calculate pass rate
    if [[ $((total_tests - skipped_tests)) -gt 0 ]]; then
        local run_tests=$((total_tests - skipped_tests))
        local pass_rate=$(( passed_tests * 100 / run_tests ))
        echo "Pass rate: $pass_rate% (excluding skipped tests)"
    fi
    
    echo "========================================="
}

# Main function
main() {
    echo "AI Orchestrator Test Suite"
    echo "=========================="
    echo
    
    # Check prerequisites
    if ! check_prerequisites; then
        exit 1
    fi
    
    # Run tests by category
    for category in "${!test_categories[@]}"; do
        run_category "$category"
    done
    
    # Generate report
    generate_report
    
    # Exit with appropriate code
    if [[ $failed_tests -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

# Handle options
while [[ $# -gt 0 ]]; do
    case "$1" in
        --category)
            if [[ $# -lt 2 ]]; then
                echo "Error: --category requires an argument"
                exit 1
            fi
            # Run only specific category
            if [[ -n "${test_categories[$2]:-}" ]]; then
                run_category "$2"
                generate_report
                exit $([[ $failed_tests -gt 0 ]] && echo 1 || echo 0)
            else
                echo "Error: Unknown category '$2'"
                echo "Available categories:"
                for cat in "${!test_categories[@]}"; do
                    echo "  - $cat"
                done
                exit 1
            fi
            ;;
        --list)
            echo "Available test categories:"
            for cat in "${!test_categories[@]}"; do
                echo "  - $cat"
                echo "    Tests: ${test_categories[$cat]}"
            done
            exit 0
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo
            echo "Options:"
            echo "  --category CATEGORY  Run only tests in specified category"
            echo "  --list              List available test categories"
            echo "  --help              Show this help message"
            echo
            echo "Examples:"
            echo "  $0                          # Run all tests"
            echo "  $0 --category 'Session Management'  # Run session tests only"
            echo "  $0 --list                   # List test categories"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
    shift
done

# Run main if no options provided
main