#!/bin/bash
# Test: Verify command maintains fresh context across different test frameworks
# Feature: AI Orchestrator Verification Fresh Context
# Scenario: Verify handles multiple test frameworks with independent context

set -euo pipefail

# Set project root if not already set
if [[ -z "${PROJECT_ROOT:-}" ]]; then
    PROJECT_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
    export PROJECT_ROOT
fi

# Source test harness and utilities
source "$(dirname "$0")/../test-command.sh"
source "$(dirname "$0")/../utils/test_setup.sh"

test_verify_go_tests_fresh() {
    setup_test_scripts
    
    # Initialize session
    feature_id="verify-go-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Create Go test files
    mkdir -p ".ai-session/$feature_id/artifacts"
    cat > ".ai-session/$feature_id/artifacts/main.go" <<'EOF'
package main

func Add(a, b int) int {
    return a + b
}

func Multiply(a, b int) int {
    return a * b
}
EOF
    
    cat > ".ai-session/$feature_id/artifacts/main_test.go" <<'EOF'
package main

import "testing"

func TestAdd(t *testing.T) {
    result := Add(2, 3)
    if result != 5 {
        t.Errorf("Add(2, 3) = %d; want 5", result)
    }
}

func TestMultiply(t *testing.T) {
    result := Multiply(3, 4)
    if result != 12 {
        t.Errorf("Multiply(3, 4) = %d; want 12", result)
    }
}
EOF
    
    # Mock verify for Go tests
    mock_command "claude" "mock_claude() {
        # Should receive only test context, no session state
        if [[ \"\${ARGUMENTS}\" == *\"session\"* ]] || [[ \"\${ARGUMENTS}\" == *\"state\"* ]]; then
            echo '{\"error\": \"Session context leaked\"}'
            return 1
        fi
        
        # Should identify Go test framework
        if [[ \"\${ARGUMENTS}\" == *\"main_test.go\"* ]]; then
            echo '{\"status\": \"success\", \"framework\": \"go\", \"tests\": {\"passed\": 2, \"failed\": 0}}'
        else
            echo '{\"error\": \"Go tests not found\"}'
            return 1
        fi
    }"
    
    # Run verify
    output=$(./scripts/verify.sh "$feature_id" --go)
    
    # Verify fresh Go context
    assert_contains "$output" "Running Go tests" "Should identify Go framework"
    assert_contains "$output" "passed: 2" "Should run Go tests"
    assert_not_contains "$output" "previous" "Should have no previous context"
    
    unmock_command "claude"
}

test_verify_python_tests_fresh() {
    setup_test_scripts
    
    # Initialize session
    feature_id="verify-python-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Create Python test files
    mkdir -p ".ai-session/$feature_id/artifacts"
    cat > ".ai-session/$feature_id/artifacts/calculator.py" <<'EOF'
def add(a, b):
    return a + b

def multiply(a, b):
    return a * b

class Calculator:
    def divide(self, a, b):
        if b == 0:
            raise ValueError("Cannot divide by zero")
        return a / b
EOF
    
    cat > ".ai-session/$feature_id/artifacts/test_calculator.py" <<'EOF'
import unittest
from calculator import add, multiply, Calculator

class TestCalculator(unittest.TestCase):
    def test_add(self):
        self.assertEqual(add(2, 3), 5)
    
    def test_multiply(self):
        self.assertEqual(multiply(3, 4), 12)
    
    def test_divide(self):
        calc = Calculator()
        self.assertEqual(calc.divide(10, 2), 5)
    
    def test_divide_by_zero(self):
        calc = Calculator()
        with self.assertRaises(ValueError):
            calc.divide(10, 0)

if __name__ == '__main__':
    unittest.main()
EOF
    
    # Mock verify for Python tests
    mock_command "claude" "mock_claude() {
        # Fresh context check
        if [[ \"\${ARGUMENTS}\" == *\"history\"* ]] || [[ \"\${ARGUMENTS}\" == *\"previous\"* ]]; then
            echo '{\"error\": \"Context contamination detected\"}'
            return 1
        fi
        
        # Should identify Python/unittest
        if [[ \"\${ARGUMENTS}\" == *\"test_calculator.py\"* ]]; then
            echo '{\"status\": \"success\", \"framework\": \"unittest\", \"tests\": {\"passed\": 4, \"failed\": 0, \"skipped\": 0}}'
        else
            echo '{\"error\": \"Python tests not found\"}'
            return 1
        fi
    }"
    
    # Run verify
    output=$(./scripts/verify.sh "$feature_id" --python)
    
    # Verify fresh Python context
    assert_contains "$output" "Running Python tests" "Should identify Python framework"
    assert_contains "$output" "unittest" "Should detect unittest framework"
    assert_contains "$output" "passed: 4" "Should run Python tests"
    
    unmock_command "claude"
}

test_verify_javascript_tests_fresh() {
    setup_test_scripts
    
    # Initialize session
    feature_id="verify-js-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Create JavaScript test files (Jest style)
    mkdir -p ".ai-session/$feature_id/artifacts"
    cat > ".ai-session/$feature_id/artifacts/math.js" <<'EOF'
function add(a, b) {
    return a + b;
}

function multiply(a, b) {
    return a * b;
}

module.exports = { add, multiply };
EOF
    
    cat > ".ai-session/$feature_id/artifacts/math.test.js" <<'EOF'
const { add, multiply } = require('./math');

describe('Math functions', () => {
    test('adds 1 + 2 to equal 3', () => {
        expect(add(1, 2)).toBe(3);
    });
    
    test('multiplies 3 * 4 to equal 12', () => {
        expect(multiply(3, 4)).toBe(12);
    });
    
    describe('edge cases', () => {
        test('handles negative numbers', () => {
            expect(add(-1, -1)).toBe(-2);
        });
    });
});
EOF
    
    # Mock verify for JavaScript tests
    mock_command "claude" "mock_claude() {
        # Ensure fresh context
        if [[ \"\${ARGUMENTS}\" == *\"feature_id\"* ]] || [[ \"\${ARGUMENTS}\" == *\"active_task\"* ]]; then
            echo '{\"error\": \"Session state leaked into verify\"}'
            return 1
        fi
        
        # Should identify Jest tests
        if [[ \"\${ARGUMENTS}\" == *\"math.test.js\"* ]]; then
            echo '{\"status\": \"success\", \"framework\": \"jest\", \"tests\": {\"passed\": 3, \"failed\": 0}, \"suites\": 2}'
        else
            echo '{\"error\": \"Jest tests not found\"}'
            return 1
        fi
    }"
    
    # Run verify
    output=$(./scripts/verify.sh "$feature_id" --javascript)
    
    # Verify fresh Jest context
    assert_contains "$output" "Running JavaScript tests" "Should identify JS framework"
    assert_contains "$output" "jest" "Should detect Jest framework"
    assert_contains "$output" "passed: 3" "Should run Jest tests"
    
    unmock_command "claude"
}

test_verify_mixed_frameworks_isolation() {
    setup_test_scripts
    
    # Initialize session with multiple test types
    feature_id="verify-mixed-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Create tests in different languages
    mkdir -p ".ai-session/$feature_id/artifacts"
    
    # Go tests
    echo "package main; import \"testing\"; func TestGo(t *testing.T) {}" > \
        ".ai-session/$feature_id/artifacts/service_test.go"
    
    # Python tests
    echo "import unittest; class TestPy(unittest.TestCase): pass" > \
        ".ai-session/$feature_id/artifacts/test_service.py"
    
    # JavaScript tests
    echo "describe('JS', () => { test('test', () => {}); });" > \
        ".ai-session/$feature_id/artifacts/service.spec.js"
    
    # Ruby tests (RSpec style)
    echo "describe 'Ruby' do; it 'works' do; end; end" > \
        ".ai-session/$feature_id/artifacts/service_spec.rb"
    
    # Mock verify to handle each framework
    mock_command "claude" "mock_claude() {
        # Each framework should be verified independently
        if [[ \"\${ARGUMENTS}\" == *\"_test.go\"* ]]; then
            echo '{\"framework\": \"go\", \"isolated\": true}'
        elif [[ \"\${ARGUMENTS}\" == *\"test_\"*.py* ]]; then
            echo '{\"framework\": \"python\", \"isolated\": true}'
        elif [[ \"\${ARGUMENTS}\" == *\".spec.js\"* ]]; then
            echo '{\"framework\": \"jest\", \"isolated\": true}'
        elif [[ \"\${ARGUMENTS}\" == *\"_spec.rb\"* ]]; then
            echo '{\"framework\": \"rspec\", \"isolated\": true}'
        else
            echo '{\"status\": \"success\", \"frameworks_detected\": [\"go\", \"python\", \"jest\", \"rspec\"]}'
        fi
    }"
    
    # Run verify for all frameworks
    output=$(./scripts/verify.sh "$feature_id" --all)
    
    # Verify each framework tested independently
    assert_contains "$output" "go" "Should detect Go tests"
    assert_contains "$output" "python" "Should detect Python tests"
    assert_contains "$output" "jest" "Should detect JavaScript tests"
    assert_contains "$output" "rspec" "Should detect Ruby tests"
    
    unmock_command "claude"
}

test_verify_framework_specific_options() {
    setup_test_scripts
    
    # Initialize session
    feature_id="verify-options-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Create test file
    mkdir -p ".ai-session/$feature_id/artifacts"
    echo "func TestOptions(t *testing.T) {}" > ".ai-session/$feature_id/artifacts/options_test.go"
    
    # Mock verify with framework-specific options
    mock_command "claude" "mock_claude() {
        # Check for framework-specific flags
        if [[ \"\${ARGUMENTS}\" == *\"--coverage\"* ]]; then
            echo '{\"framework\": \"go\", \"coverage\": \"85.2%\"}'
        elif [[ \"\${ARGUMENTS}\" == *\"--race\"* ]]; then
            echo '{\"framework\": \"go\", \"race_detector\": true}'
        elif [[ \"\${ARGUMENTS}\" == *\"--verbose\"* ]]; then
            echo '{\"framework\": \"go\", \"verbose\": true}'
        else
            echo '{\"status\": \"success\"}'
        fi
    }"
    
    # Test with coverage
    output=$(./scripts/verify.sh "$feature_id" --go --coverage)
    assert_contains "$output" "coverage" "Should support coverage option"
    
    # Test with race detector
    output=$(./scripts/verify.sh "$feature_id" --go --race)
    assert_contains "$output" "race" "Should support race detector"
    
    # Test with verbose
    output=$(./scripts/verify.sh "$feature_id" --go --verbose)
    assert_contains "$output" "verbose" "Should support verbose option"
    
    unmock_command "claude"
}

test_verify_test_discovery_fresh() {
    setup_test_scripts
    
    # Initialize session
    feature_id="verify-discover-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Create various test patterns
    mkdir -p ".ai-session/$feature_id/artifacts"
    mkdir -p ".ai-session/$feature_id/artifacts/tests"
    mkdir -p ".ai-session/$feature_id/artifacts/src/__tests__"
    
    # Different test file patterns
    touch ".ai-session/$feature_id/artifacts/test_main.py"              # Python
    touch ".ai-session/$feature_id/artifacts/main_test.go"             # Go
    touch ".ai-session/$feature_id/artifacts/main.test.js"             # Jest
    touch ".ai-session/$feature_id/artifacts/main.spec.ts"             # TypeScript
    touch ".ai-session/$feature_id/artifacts/tests/integration_test.rb" # Ruby
    touch ".ai-session/$feature_id/artifacts/src/__tests__/unit.test.js" # Nested
    
    # Mock test discovery
    mock_command "claude" "mock_claude() {
        # Fresh discovery should find all test patterns
        echo '{
            \"status\": \"success\",
            \"discovered\": {
                \"python\": [\"test_main.py\"],
                \"go\": [\"main_test.go\"],
                \"javascript\": [\"main.test.js\", \"src/__tests__/unit.test.js\"],
                \"typescript\": [\"main.spec.ts\"],
                \"ruby\": [\"tests/integration_test.rb\"]
            },
            \"total_files\": 6
        }'
    }"
    
    # Run discovery
    output=$(./scripts/verify.sh "$feature_id" --discover-only)
    
    # Verify comprehensive discovery
    assert_contains "$output" "Discovering tests" "Should show discovery mode"
    assert_contains "$output" "6" "Should find all test files"
    assert_contains "$output" "python" "Should identify Python tests"
    assert_contains "$output" "go" "Should identify Go tests"
    assert_contains "$output" "javascript" "Should identify JS tests"
    assert_contains "$output" "typescript" "Should identify TS tests"
    assert_contains "$output" "ruby" "Should identify Ruby tests"
    
    unmock_command "claude"
}

test_verify_framework_autodetection() {
    setup_test_scripts
    
    # Initialize session
    feature_id="verify-auto-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Create package files for framework detection
    mkdir -p ".ai-session/$feature_id/artifacts"
    
    # Node.js project
    cat > ".ai-session/$feature_id/artifacts/package.json" <<'EOF'
{
  "name": "test-project",
  "scripts": {
    "test": "jest"
  },
  "devDependencies": {
    "jest": "^27.0.0"
  }
}
EOF
    
    # Python project
    cat > ".ai-session/$feature_id/artifacts/requirements.txt" <<'EOF'
pytest==7.0.0
pytest-cov==3.0.0
EOF
    
    # Go module
    cat > ".ai-session/$feature_id/artifacts/go.mod" <<'EOF'
module example.com/project

go 1.19
EOF
    
    # Mock auto-detection
    mock_command "claude" "mock_claude() {
        echo '{
            \"status\": \"success\",
            \"auto_detected\": {
                \"javascript\": {\"framework\": \"jest\", \"config\": \"package.json\"},
                \"python\": {\"framework\": \"pytest\", \"config\": \"requirements.txt\"},
                \"go\": {\"framework\": \"go test\", \"config\": \"go.mod\"}
            }
        }'
    }"
    
    # Run verify with auto-detection
    output=$(./scripts/verify.sh "$feature_id" --auto)
    
    # Verify framework detection
    assert_contains "$output" "Auto-detecting" "Should show auto-detection"
    assert_contains "$output" "jest" "Should detect Jest from package.json"
    assert_contains "$output" "pytest" "Should detect pytest from requirements"
    assert_contains "$output" "go test" "Should detect Go testing"
    
    unmock_command "claude"
}

test_verify_custom_test_commands() {
    setup_test_scripts
    
    # Initialize session
    feature_id="verify-custom-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Create makefile with test targets
    cat > ".ai-session/$feature_id/artifacts/Makefile" <<'EOF'
test-unit:
	go test ./...

test-integration:
	go test -tags=integration ./...

test-e2e:
	npm run test:e2e

test-all: test-unit test-integration test-e2e
EOF
    
    # Mock custom command execution
    mock_command "claude" "mock_claude() {
        if [[ \"\${ARGUMENTS}\" == *\"make test-unit\"* ]]; then
            echo '{\"command\": \"make test-unit\", \"status\": \"success\", \"tests\": 25}'
        elif [[ \"\${ARGUMENTS}\" == *\"make test-integration\"* ]]; then
            echo '{\"command\": \"make test-integration\", \"status\": \"success\", \"tests\": 10}'
        elif [[ \"\${ARGUMENTS}\" == *\"custom:\"* ]]; then
            echo '{\"custom_command\": true, \"status\": \"success\"}'
        else
            echo '{\"status\": \"success\"}'
        fi
    }"
    
    # Test custom commands
    output=$(./scripts/verify.sh "$feature_id" --custom "make test-unit")
    assert_contains "$output" "make test-unit" "Should run custom command"
    
    output=$(./scripts/verify.sh "$feature_id" --custom "make test-integration")
    assert_contains "$output" "test-integration" "Should run integration tests"
    
    unmock_command "claude"
}

test_verify_test_filtering() {
    setup_test_scripts
    
    # Initialize session
    feature_id="verify-filter-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Create test files with patterns
    mkdir -p ".ai-session/$feature_id/artifacts"
    touch ".ai-session/$feature_id/artifacts/auth_test.go"
    touch ".ai-session/$feature_id/artifacts/user_test.go"
    touch ".ai-session/$feature_id/artifacts/admin_test.go"
    touch ".ai-session/$feature_id/artifacts/test_auth.py"
    touch ".ai-session/$feature_id/artifacts/test_user.py"
    
    # Mock filtered verification
    mock_command "claude" "mock_claude() {
        if [[ \"\${ARGUMENTS}\" == *\"--filter auth\"* ]]; then
            echo '{\"filtered\": \"auth\", \"tests_run\": [\"auth_test.go\", \"test_auth.py\"]}'
        elif [[ \"\${ARGUMENTS}\" == *\"--filter user\"* ]]; then
            echo '{\"filtered\": \"user\", \"tests_run\": [\"user_test.go\", \"test_user.py\"]}'
        elif [[ \"\${ARGUMENTS}\" == *\"--exclude admin\"* ]]; then
            echo '{\"excluded\": \"admin\", \"tests_run\": [\"auth_test.go\", \"user_test.go\", \"test_auth.py\", \"test_user.py\"]}'
        else
            echo '{\"status\": \"success\"}'
        fi
    }"
    
    # Test filtering
    output=$(./scripts/verify.sh "$feature_id" --filter auth)
    assert_contains "$output" "auth_test.go" "Should run auth tests"
    assert_not_contains "$output" "user_test" "Should not run user tests"
    
    # Test exclusion
    output=$(./scripts/verify.sh "$feature_id" --exclude admin)
    assert_not_contains "$output" "admin_test" "Should exclude admin tests"
    
    unmock_command "claude"
}

test_verify_parallel_framework_execution() {
    setup_test_scripts
    
    # Initialize session
    feature_id="verify-parallel-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Create tests for multiple frameworks
    mkdir -p ".ai-session/$feature_id/artifacts"
    echo "func TestGo(t *testing.T) {}" > ".ai-session/$feature_id/artifacts/main_test.go"
    echo "def test_python(): pass" > ".ai-session/$feature_id/artifacts/test_main.py"
    echo "test('js', () => {});" > ".ai-session/$feature_id/artifacts/main.test.js"
    
    # Track parallel execution
    parallel_log="/tmp/verify_parallel_$(date +%s).log"
    
    # Mock parallel execution
    mock_command "claude" "mock_claude() {
        # Log execution with timestamp
        echo \"\$(date +%s%N) \${ARGUMENTS}\" >> \"$parallel_log\"
        
        # Simulate test execution time
        sleep 0.1
        
        if [[ \"\${ARGUMENTS}\" == *\"test.go\"* ]]; then
            echo '{\"framework\": \"go\", \"parallel\": true}'
        elif [[ \"\${ARGUMENTS}\" == *\"test_\"* ]]; then
            echo '{\"framework\": \"python\", \"parallel\": true}'
        elif [[ \"\${ARGUMENTS}\" == *\"test.js\"* ]]; then
            echo '{\"framework\": \"jest\", \"parallel\": true}'
        else
            echo '{\"status\": \"success\"}'
        fi
    }"
    
    # Run verify with parallel flag
    : > "$parallel_log"
    output=$(./scripts/verify.sh "$feature_id" --parallel)
    
    # Check for parallel execution
    execution_count=$(wc -l < "$parallel_log")
    assert_less_than "2" "$execution_count" "Should have multiple executions"
    
    # Verify timing indicates parallel execution
    if [[ -s "$parallel_log" ]]; then
        first_time=$(head -n1 "$parallel_log" | cut -d' ' -f1)
        last_time=$(tail -n1 "$parallel_log" | cut -d' ' -f1)
        duration=$(( (last_time - first_time) / 1000000 )) # Convert to ms
        
        # With 0.1s sleep per test, serial would take ~300ms, parallel should be ~100ms
        assert_less_than "$duration" "200" "Should execute in parallel"
    fi
    
    # Cleanup
    rm -f "$parallel_log"
    unmock_command "claude"
}

test_verify_ci_integration_mode() {
    setup_test_scripts
    
    # Initialize session
    feature_id="verify-ci-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Set CI environment variables
    export CI=true
    export GITHUB_ACTIONS=true
    export GITHUB_RUN_ID="123456"
    
    # Create test files
    mkdir -p ".ai-session/$feature_id/artifacts"
    echo "func TestCI(t *testing.T) {}" > ".ai-session/$feature_id/artifacts/ci_test.go"
    
    # Mock CI mode verification
    mock_command "claude" "mock_claude() {
        # Should detect CI environment
        echo '{
            \"ci_mode\": true,
            \"ci_provider\": \"github_actions\",
            \"output_format\": \"junit\",
            \"status\": \"success\"
        }'
    }"
    
    # Run verify in CI mode
    output=$(./scripts/verify.sh "$feature_id" --ci)
    
    # Verify CI mode behavior
    assert_contains "$output" "CI mode" "Should indicate CI mode"
    assert_contains "$output" "junit" "Should use CI-friendly output"
    
    # Should create test results file
    assert_exists ".ai-session/$feature_id/artifacts/test-results.xml" "Should create test results"
    
    # Cleanup
    unset CI GITHUB_ACTIONS GITHUB_RUN_ID
    unmock_command "claude"
}

test_verify_watch_mode_context() {
    setup_test_scripts
    
    # Initialize session
    feature_id="verify-watch-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Create test file
    mkdir -p ".ai-session/$feature_id/artifacts"
    echo "func TestWatch(t *testing.T) {}" > ".ai-session/$feature_id/artifacts/watch_test.go"
    
    # Mock watch mode
    watch_count=0
    mock_command "claude" "mock_claude() {
        # Each watch iteration should be fresh
        watch_count=\$((watch_count + 1))
        echo '{\"watch_iteration\": '\$watch_count', \"fresh_context\": true}'
    }"
    
    # Simulate watch mode (would normally loop)
    export WATCH_MODE=true
    
    # Run verify multiple times (simulating file changes)
    for i in {1..3}; do
        # Simulate file change
        touch ".ai-session/$feature_id/artifacts/watch_test.go"
        
        output=$(./scripts/verify.sh "$feature_id" --watch-once)
        assert_contains "$output" "fresh_context" "Each watch should be fresh"
        assert_contains "$output" "\"watch_iteration\": $i" "Should track iterations"
        
        sleep 0.1
    done
    
    unset WATCH_MODE
    unmock_command "claude"
}

# Run all tests
echo "Testing verify fresh context across frameworks..."
run_test_scenario "Verify Go tests fresh" test_verify_go_tests_fresh
run_test_scenario "Verify Python tests fresh" test_verify_python_tests_fresh
run_test_scenario "Verify JavaScript tests fresh" test_verify_javascript_tests_fresh
run_test_scenario "Verify mixed frameworks isolation" test_verify_mixed_frameworks_isolation
run_test_scenario "Verify framework specific options" test_verify_framework_specific_options
run_test_scenario "Verify test discovery fresh" test_verify_test_discovery_fresh
run_test_scenario "Verify framework autodetection" test_verify_framework_autodetection
run_test_scenario "Verify custom test commands" test_verify_custom_test_commands
run_test_scenario "Verify test filtering" test_verify_test_filtering
run_test_scenario "Verify parallel framework execution" test_verify_parallel_framework_execution
run_test_scenario "Verify CI integration mode" test_verify_ci_integration_mode
run_test_scenario "Verify watch mode context" test_verify_watch_mode_context