#!/bin/bash
# Test contract acknowledgment verification

set -euo pipefail

# Source test utilities if available
if [[ -f "test/test-utils.sh" ]]; then
    source test/test-utils.sh
else
    # Basic assertions
    assert_equals() {
        if [[ "$1" != "$2" ]]; then
            echo "FAIL: Expected '$2' but got '$1'"
            return 1
        fi
    }
    
    assert_contains() {
        if [[ "$1" != *"$2"* ]]; then
            echo "FAIL: Expected to find '$2' in output"
            return 1
        fi
    }
fi

# Test configuration
TEST_DIR="/tmp/test-contract-$$"
SCRIPT="scripts/verify-contract-acknowledgment.sh"

# Setup
setup() {
    mkdir -p "$TEST_DIR"
    cd "$TEST_DIR"
    
    # Create mock contract file
    mkdir -p docs
    cp "$OLDPWD/docs/session-state-spec.md" docs/
    
    # Copy verification script
    mkdir -p scripts
    cp "$OLDPWD/$SCRIPT" scripts/
}

# Cleanup
cleanup() {
    cd "$OLDPWD"
    rm -rf "$TEST_DIR"
}

# Test 1: Verify fails when no acknowledgment exists
test_no_acknowledgment() {
    echo "Test 1: Verify fails without acknowledgment"
    
    local output=$(scripts/verify-contract-acknowledgment.sh verify 2>&1)
    local exit_code=$?
    
    assert_equals "$exit_code" "1"
    assert_contains "$output" "No contract acknowledgment found"
    
    echo "PASS: Correctly fails when acknowledgment missing"
}

# Test 2: Create acknowledgment succeeds
test_create_acknowledgment() {
    echo "Test 2: Create acknowledgment"
    
    local output=$(scripts/verify-contract-acknowledgment.sh create "test-agent" 2>&1)
    local exit_code=$?
    
    assert_equals "$exit_code" "0"
    assert_contains "$output" "Contract acknowledgment created"
    
    # Verify file was created
    if [[ ! -f ".ai-session/contract-acknowledgment.md" ]]; then
        echo "FAIL: Acknowledgment file not created"
        return 1
    fi
    
    # Check content
    local content=$(cat .ai-session/contract-acknowledgment.md)
    assert_contains "$content" "Agent: test-agent"
    assert_contains "$content" "Contract Version: 1.0"
    assert_contains "$content" "Checksum:"
    
    echo "PASS: Acknowledgment created successfully"
}

# Test 3: Verify succeeds with valid acknowledgment
test_verify_valid() {
    echo "Test 3: Verify with valid acknowledgment"
    
    # Create acknowledgment first
    scripts/verify-contract-acknowledgment.sh create "test-agent" >/dev/null 2>&1
    
    # Now verify
    local output=$(scripts/verify-contract-acknowledgment.sh verify 2>&1)
    local exit_code=$?
    
    assert_equals "$exit_code" "0"
    assert_contains "$output" "Valid contract acknowledgment found"
    assert_contains "$output" "Checksum verified"
    
    echo "PASS: Verification succeeds with valid acknowledgment"
}

# Test 4: Verify detects contract changes
test_contract_change_detection() {
    echo "Test 4: Detect contract changes"
    
    # Create acknowledgment
    scripts/verify-contract-acknowledgment.sh create "test-agent" >/dev/null 2>&1
    
    # Modify contract (simulate change)
    echo "# Modified" >> docs/session-state-spec.md
    
    # Verify should now warn
    local output=$(scripts/verify-contract-acknowledgment.sh verify 2>&1)
    local exit_code=$?
    
    assert_equals "$exit_code" "1"
    assert_contains "$output" "Contract has changed since acknowledgment"
    assert_contains "$output" "Re-acknowledgment required"
    
    echo "PASS: Contract changes detected correctly"
}

# Test 5: Summary command works
test_summary_command() {
    echo "Test 5: Summary command"
    
    local output=$(scripts/verify-contract-acknowledgment.sh summary 2>&1)
    local exit_code=$?
    
    assert_equals "$exit_code" "0"
    assert_contains "$output" "Contract Summary"
    assert_contains "$output" "Version: 1.0"
    assert_contains "$output" "Key requirements"
    
    echo "PASS: Summary command works"
}

# Run tests
main() {
    echo "Running contract acknowledgment tests..."
    echo ""
    
    setup
    
    local failed=0
    
    # Run each test
    for test in test_no_acknowledgment test_create_acknowledgment test_verify_valid test_contract_change_detection test_summary_command; do
        if ! $test; then
            ((failed++))
        fi
        echo ""
    done
    
    cleanup
    
    # Summary
    if [[ $failed -eq 0 ]]; then
        echo "All tests passed!"
        exit 0
    else
        echo "$failed test(s) failed"
        exit 1
    fi
}

# Handle being sourced vs executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi