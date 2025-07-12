#!/bin/bash
# Generate comprehensive test coverage report for AI orchestrator
# Analyzes test coverage across all components

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Directories
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$TEST_DIR/.." && pwd)"
SCRIPTS_DIR="$PROJECT_ROOT/scripts"
REPORT_FILE="${1:-$PROJECT_ROOT/test-coverage-report.md}"

# Track coverage
declare -A script_coverage
declare -A function_coverage
declare -A test_files

# Initialize coverage tracking
init_coverage() {
    # Scripts to analyze
    local scripts=(
        "ai-command-wrapper.sh"
        "ai-session.sh"
        "init-session.sh"
        "plan.sh"
        "implement.sh"
        "review.sh"
        "verify.sh"
        "status.sh"
        "escalate.sh"
    )
    
    for script in "${scripts[@]}"; do
        script_coverage["$script"]=0
        if [[ -f "$SCRIPTS_DIR/$script" ]]; then
            script_coverage["$script"]=1
        fi
    done
}

# Analyze test coverage for a script
analyze_script_coverage() {
    local script_name="$1"
    local script_path="$SCRIPTS_DIR/$script_name"
    
    if [[ ! -f "$script_path" ]]; then
        return
    fi
    
    # Extract functions from script
    local functions=$(grep -E '^[a-zA-Z_][a-zA-Z0-9_]*\(\)' "$script_path" | sed 's/().*//' || true)
    
    # Count total functions
    local total_functions=0
    if [[ -n "$functions" ]]; then
        total_functions=$(echo "$functions" | grep -c . || echo 0)
    fi
    
    # Find tests that cover this script
    local test_count=0
    local covered_functions=0
    
    # Search for tests mentioning this script
    local script_base=$(basename "$script_name" .sh)
    local related_tests=$(find "$TEST_DIR" -name "*.sh" -type f -exec grep -l "$script_base" {} \; 2>/dev/null || true)
    
    if [[ -n "$related_tests" ]]; then
        test_count=$(echo "$related_tests" | wc -l)
        
        # Estimate covered functions (simplified)
        for test_file in $related_tests; do
            local test_functions=$(grep -E 'test_[a-zA-Z0-9_]+\(\)' "$test_file" 2>/dev/null | wc -l)
            if [[ -n "$test_functions" ]] && [[ "$test_functions" =~ ^[0-9]+$ ]]; then
                covered_functions=$((covered_functions + test_functions))
            fi
        done
    fi
    
    # Store results
    function_coverage["$script_name"]="$covered_functions/$total_functions"
    test_files["$script_name"]=$test_count
}

# Generate coverage statistics
generate_stats() {
    local total_scripts=0
    local implemented_scripts=0
    local tested_scripts=0
    
    for script in "${!script_coverage[@]}"; do
        ((total_scripts++))
        if [[ "${script_coverage[$script]}" -eq 1 ]]; then
            ((implemented_scripts++))
            if [[ "${test_files[$script]:-0}" -gt 0 ]]; then
                ((tested_scripts++))
            fi
        fi
    done
    
    echo "Total scripts: $total_scripts"
    echo "Implemented: $implemented_scripts"
    echo "Tested: $tested_scripts"
    echo "Coverage: $((tested_scripts * 100 / implemented_scripts))%"
}

# Generate detailed report
generate_report() {
    cat > "$REPORT_FILE" << EOF
# AI Orchestrator Test Coverage Report

Generated: $(date)

## Summary

$(generate_stats)

## Script Coverage Details

| Script | Status | Functions | Test Files | Coverage |
|--------|--------|-----------|------------|----------|
EOF
    
    # Sort scripts for consistent output
    local sorted_scripts=($(printf '%s\n' "${!script_coverage[@]}" | sort))
    
    for script in "${sorted_scripts[@]}"; do
        local status="❌ Not Found"
        local functions="-"
        local tests="-"
        local coverage="0%"
        
        if [[ "${script_coverage[$script]}" -eq 1 ]]; then
            status="✅ Implemented"
            analyze_script_coverage "$script"
            functions="${function_coverage[$script]:-0/0}"
            tests="${test_files[$script]:-0}"
            
            # Calculate coverage percentage
            if [[ "$functions" =~ ([0-9]+)/([0-9]+) ]]; then
                local covered="${BASH_REMATCH[1]}"
                local total="${BASH_REMATCH[2]}"
                if [[ "$total" -gt 0 ]]; then
                    coverage="$((covered * 100 / total))%"
                fi
            fi
        fi
        
        echo "| $script | $status | $functions | $tests | $coverage |" >> "$REPORT_FILE"
    done
    
    cat >> "$REPORT_FILE" << 'EOF'

## Test Categories

| Category | Test Count | Status |
|----------|------------|--------|
EOF
    
    # Analyze test categories
    # Extract test categories without running the script
    local test_categories_str=$(grep -A 20 "declare -A test_categories" "$TEST_DIR/run-ai-orchestrator-tests.sh" 2>/dev/null | grep -E '^\s*\[' | head -10 || true)
    
    if [[ -n "$test_categories_str" ]]; then
        for category in "${!test_categories[@]}"; do
            local tests="${test_categories[$category]}"
            local test_count=$(echo "$tests" | wc -w)
            local existing_count=0
            
            for test in $tests; do
                if [[ -f "$TEST_DIR/$test" ]]; then
                    ((existing_count++))
                fi
            done
            
            local status="✅ Complete"
            if [[ "$existing_count" -lt "$test_count" ]]; then
                status="⚠️  Partial ($existing_count/$test_count)"
            elif [[ "$existing_count" -eq 0 ]]; then
                status="❌ Missing"
            fi
            
            echo "| $category | $test_count | $status |" >> "$REPORT_FILE"
        done | sort >> "$REPORT_FILE"
    fi
    
    cat >> "$REPORT_FILE" << 'EOF'

## Test Execution Results

Run `./test/run-ai-orchestrator-tests.sh` for detailed test results.

### Recent Test Run
```
EOF
    
    # Try to include recent test results
    if [[ -f "$TEST_DIR/.last-test-run.log" ]]; then
        tail -20 "$TEST_DIR/.last-test-run.log" >> "$REPORT_FILE"
    else
        echo "No recent test run found." >> "$REPORT_FILE"
    fi
    
    cat >> "$REPORT_FILE" << 'EOF'
```

## Coverage Gaps

### High Priority
EOF
    
    # Identify coverage gaps
    for script in "${sorted_scripts[@]}"; do
        if [[ "${script_coverage[$script]}" -eq 1 ]] && [[ "${test_files[$script]:-0}" -eq 0 ]]; then
            echo "- **$script**: No tests found" >> "$REPORT_FILE"
        fi
    done
    
    cat >> "$REPORT_FILE" << 'EOF'

### Recommendations

1. **Increase Function Coverage**: Focus on testing core functions in each script
2. **Add Integration Tests**: Test script interactions and workflows
3. **Performance Tests**: Add benchmarks for session operations
4. **Security Tests**: Validate input sanitization and permissions

## Test Infrastructure

### Prerequisites
- bash 4.0+
- jq (JSON processing)
- bc (calculations)
- flock (file locking)

### Test Frameworks
- Custom test harness: `test-command.sh`
- Assertion functions: `assert_equals`, `assert_contains`, etc.
- Mock utilities for isolated testing

### CI Integration
- GitHub Actions: `.github/workflows/build.yml`
- Makefile target: `make test-ai-orchestrator`
- Automated on all pushes

## Next Steps

1. Achieve 90%+ function coverage for all scripts
2. Add performance benchmarks
3. Implement security vulnerability tests
4. Create end-to-end workflow tests
5. Add mutation testing for critical functions

---
*This report is automatically generated. To update, run: `./test/generate-coverage-report.sh`*
EOF
}

# Run test suite and capture results
run_tests_with_logging() {
    echo -e "${BLUE}Running test suite for coverage analysis...${NC}"
    
    local log_file="$TEST_DIR/.last-test-run.log"
    "$TEST_DIR/run-ai-orchestrator-tests.sh" > "$log_file" 2>&1 || true
    
    # Show summary
    if grep -q "passed.*failed" "$log_file"; then
        tail -5 "$log_file"
    fi
}

# Main execution
main() {
    echo -e "${BLUE}AI Orchestrator Test Coverage Analysis${NC}"
    echo "======================================="
    echo
    
    # Initialize coverage tracking
    init_coverage
    
    # Run tests if requested
    if [[ "${1:-}" == "--run-tests" ]]; then
        run_tests_with_logging
        shift
    fi
    
    # Generate report
    echo "Generating coverage report..."
    generate_report
    
    echo
    echo -e "${GREEN}✓${NC} Coverage report generated: $REPORT_FILE"
    echo
    
    # Show summary
    generate_stats
    
    # Open report if possible
    if command -v xdg-open >/dev/null 2>&1; then
        echo
        echo -n "Open report in browser? [y/N] "
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            xdg-open "$REPORT_FILE"
        fi
    fi
}

# Handle arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [--run-tests] [output-file]"
        echo
        echo "Generate test coverage report for AI orchestrator"
        echo
        echo "Options:"
        echo "  --run-tests    Run test suite before generating report"
        echo "  output-file    Path for report (default: test-coverage-report.md)"
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac