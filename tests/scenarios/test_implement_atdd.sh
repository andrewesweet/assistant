#!/bin/bash
# Test: Implement command enforces ATDD (tests first)
# Feature: AI Orchestrator Implementation Commands
# Scenario: Implementation follows ATDD/TDD methodology with tests written first

set -euo pipefail

# Set project root if not already set
if [[ -z "${PROJECT_ROOT:-}" ]]; then
    PROJECT_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
    export PROJECT_ROOT
fi

# Source test harness and utilities
source "$(dirname "$0")/../test-command.sh"
source "$(dirname "$0")/../utils/test_setup.sh"

test_implement_enforces_test_first() {
    setup_test_scripts
    
    # Initialize session with a task
    feature_id="impl-atdd-test-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Create implementation plan with task
    cat > ".ai-session/$feature_id/implementation-plan.yaml" <<EOF
feature:
  id: "$feature_id"
  name: "Test Feature"
phases:
  - phase_id: "phase-1"
    name: "Implementation"
    tasks:
      - task_id: "impl-auth"
        description: "Implement authentication"
        agent: "agent-1"
        status: "pending"
        test_requirements:
          - "Unit tests for auth logic"
          - "Integration tests for API"
EOF
    
    # Mock claude to verify ATDD enforcement
    test_first_enforced=0
    mock_command "claude" "mock_claude() {
        # Check if prompt includes test-first requirements
        if [[ \"\$*\" == *\"write tests first\"* ]] || [[ \"\$*\" == *\"ATDD\"* ]]; then
            test_first_enforced=1
        fi
        echo '{\"status\": \"success\", \"tests_written\": true}'
    }"
    
    # Execute implement command
    ./scripts/implement.sh "$feature_id" --task "impl-auth"
    
    # Verify ATDD enforcement
    assert_equals "1" "$test_first_enforced" "Implementation should enforce test-first approach"
    
    # Verify history logs ATDD compliance
    history_entry=$(tail -n1 ".ai-session/$feature_id/history.jsonl")
    assert_contains "$history_entry" '"command":"implement"' "History should record implement command"
    assert_contains "$history_entry" '"atdd_enforced":true' "History should note ATDD enforcement"
    
    unmock_command "claude"
}

test_implement_checks_existing_tests() {
    setup_test_scripts
    
    # Initialize session
    feature_id="impl-check-tests-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Create task that requires tests
    cat > ".ai-session/$feature_id/implementation-plan.yaml" <<EOF
feature:
  id: "$feature_id"
  name: "Test Feature"
phases:
  - phase_id: "phase-1"
    tasks:
      - task_id: "add-validation"
        description: "Add input validation"
        status: "pending"
        test_files:
          - "test/validation_test.go"
          - "test/integration_test.go"
EOF
    
    # Mock checking for test files
    test_check_performed=0
    mock_command "claude" "mock_claude() {
        # Verify prompt includes test file checking
        if [[ \"\$*\" == *\"validation_test.go\"* ]]; then
            test_check_performed=1
        fi
        echo '{\"status\": \"success\", \"existing_tests_found\": false}'
    }"
    
    # Execute implement
    output=$(./scripts/implement.sh "$feature_id" --task "add-validation" 2>&1)
    
    # Verify test checking
    assert_equals "1" "$test_check_performed" "Should check for existing tests"
    assert_contains "$output" "Checking for existing tests" "Should notify about test check"
    assert_contains "$output" "No tests found" "Should report test status"
    assert_contains "$output" "Writing tests first" "Should indicate test-first approach"
    
    unmock_command "claude"
}

test_implement_with_existing_tests() {
    setup_test_scripts
    
    # Initialize session
    feature_id="impl-existing-tests-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Create task
    cat > ".ai-session/$feature_id/implementation-plan.yaml" <<EOF
feature:
  id: "$feature_id"
  name: "Test Feature"
phases:
  - phase_id: "phase-1"
    tasks:
      - task_id: "refactor-service"
        description: "Refactor user service"
        status: "in_progress"
        test_status: "written"
        test_files:
          - "test/user_service_test.go"
EOF
    
    # Create marker for existing tests
    mkdir -p ".ai-session/$feature_id/artifacts"
    echo "TESTS_EXIST" > ".ai-session/$feature_id/artifacts/.tests_written"
    
    # Mock claude to verify different flow
    implementation_allowed=0
    mock_command "claude" "mock_claude() {
        # Check if implementation is allowed after tests
        if [[ \"\$*\" == *\"implement\"* ]] && [[ \"\$*\" != *\"write tests first\"* ]]; then
            implementation_allowed=1
        fi
        echo '{\"status\": \"success\", \"implementation_complete\": true}'
    }"
    
    # Execute implement
    output=$(./scripts/implement.sh "$feature_id" --task "refactor-service" 2>&1)
    
    # Verify implementation allowed with existing tests
    assert_equals "1" "$implementation_allowed" "Should allow implementation with existing tests"
    assert_contains "$output" "Tests already written" "Should acknowledge existing tests"
    assert_contains "$output" "Proceeding with implementation" "Should proceed to implement"
    
    unmock_command "claude"
}

test_implement_generates_test_artifacts() {
    setup_test_scripts
    
    # Initialize session
    feature_id="impl-test-artifacts-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Create task requiring specific test types
    cat > ".ai-session/$feature_id/implementation-plan.yaml" <<EOF
feature:
  id: "$feature_id"
  name: "API Feature"
phases:
  - phase_id: "phase-1"
    tasks:
      - task_id: "create-endpoint"
        description: "Create REST endpoint"
        status: "pending"
        test_types:
          - "unit"
          - "integration"
          - "contract"
EOF
    
    # Mock claude to simulate test generation
    mock_command "claude" "mock_claude() {
        # First call writes tests
        if [[ \"\$*\" == *\"write tests\"* ]]; then
            mkdir -p test
            echo 'func TestEndpoint(t *testing.T) {}' > test/endpoint_test.go
            echo 'func TestIntegration(t *testing.T) {}' > test/integration_test.go
            echo '{\"status\": \"success\", \"tests_generated\": [\"endpoint_test.go\", \"integration_test.go\"]}'
        else
            echo '{\"status\": \"success\"}'
        fi
    }"
    
    # Execute implement
    ./scripts/implement.sh "$feature_id" --task "create-endpoint"
    
    # Verify test artifacts created
    assert_exists "test/endpoint_test.go" "Unit test should be created"
    assert_exists "test/integration_test.go" "Integration test should be created"
    
    # Verify test files tracked in task
    task_status=$(cat ".ai-session/$feature_id/implementation-plan.yaml")
    assert_contains "$task_status" "endpoint_test.go" "Test files should be tracked"
    
    unmock_command "claude"
}

test_implement_validates_test_coverage() {
    setup_test_scripts
    
    # Initialize session
    feature_id="impl-coverage-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Create task with coverage requirements
    cat > ".ai-session/$feature_id/implementation-plan.yaml" <<EOF
feature:
  id: "$feature_id"
  name: "High Coverage Feature"
phases:
  - phase_id: "phase-1"
    tasks:
      - task_id: "critical-logic"
        description: "Implement critical business logic"
        status: "pending"
        coverage_requirement: 90
        acceptance_criteria:
          - "All edge cases tested"
          - "Error paths covered"
          - "Happy path scenarios"
EOF
    
    # Mock test execution and coverage
    mock_command "claude" "mock_claude() {
        if [[ \"\$*\" == *\"run tests\"* ]]; then
            echo '{\"status\": \"success\", \"coverage\": 85, \"message\": \"Coverage below requirement\"}'
            return 1
        fi
        echo '{\"status\": \"success\"}'
    }"
    
    # Execute implement
    set +e
    output=$(./scripts/implement.sh "$feature_id" --task "critical-logic" --check-coverage 2>&1)
    exit_code=$?
    set -e
    
    # Verify coverage validation
    assert_not_equals "0" "$exit_code" "Should fail with insufficient coverage"
    assert_contains "$output" "Coverage: 85%" "Should report coverage"
    assert_contains "$output" "Required: 90%" "Should show requirement"
    assert_contains "$output" "below requirement" "Should indicate coverage issue"
    
    unmock_command "claude"
}

test_implement_bdd_scenario_generation() {
    setup_test_scripts
    
    # Initialize session
    feature_id="impl-bdd-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Create task with BDD requirements
    cat > ".ai-session/$feature_id/implementation-plan.yaml" <<EOF
feature:
  id: "$feature_id"
  name: "BDD Feature"
phases:
  - phase_id: "phase-1"
    tasks:
      - task_id: "user-registration"
        description: "User registration flow"
        status: "pending"
        test_approach: "BDD"
        scenarios:
          - "User registers with valid data"
          - "User registers with existing email"
          - "User registers with invalid data"
EOF
    
    # Mock BDD scenario generation
    bdd_generated=0
    mock_command "claude" "mock_claude() {
        if [[ \"\$*\" == *\"Gherkin\"* ]] || [[ \"\$*\" == *\"Given When Then\"* ]]; then
            bdd_generated=1
            # Create feature file
            mkdir -p features
            cat > features/user_registration.feature <<'FEATURE'
Feature: User Registration
  Scenario: Valid registration
    Given a new user
    When they register with valid data
    Then account should be created
FEATURE
        fi
        echo '{\"status\": \"success\", \"scenarios_generated\": 3}'
    }"
    
    # Execute implement
    ./scripts/implement.sh "$feature_id" --task "user-registration"
    
    # Verify BDD scenarios created
    assert_equals "1" "$bdd_generated" "Should generate BDD scenarios"
    assert_exists "features/user_registration.feature" "Feature file should be created"
    assert_file_contains "features/user_registration.feature" "Given" "Should use Gherkin syntax"
    
    unmock_command "claude"
}

test_implement_red_green_refactor_cycle() {
    setup_test_scripts
    
    # Initialize session
    feature_id="impl-tdd-cycle-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Create TDD task
    cat > ".ai-session/$feature_id/implementation-plan.yaml" <<EOF
feature:
  id: "$feature_id"
  name: "TDD Feature"
phases:
  - phase_id: "phase-1"
    tasks:
      - task_id: "calculator"
        description: "Calculator with TDD"
        status: "pending"
        methodology: "TDD"
EOF
    
    # Track TDD cycle
    cycle_phase=""
    mock_command "claude" "mock_claude() {
        if [[ \"\$*\" == *\"failing test\"* ]]; then
            cycle_phase=\"red\"
            echo '{\"status\": \"success\", \"phase\": \"red\", \"tests_failing\": true}'
        elif [[ \"\$*\" == *\"make test pass\"* ]]; then
            cycle_phase=\"green\"
            echo '{\"status\": \"success\", \"phase\": \"green\", \"tests_passing\": true}'
        elif [[ \"\$*\" == *\"refactor\"* ]]; then
            cycle_phase=\"refactor\"
            echo '{\"status\": \"success\", \"phase\": \"refactor\", \"code_improved\": true}'
        fi
    }"
    
    # Execute implement with TDD flag
    output=$(./scripts/implement.sh "$feature_id" --task "calculator" --tdd 2>&1)
    
    # Verify TDD cycle followed
    assert_contains "$output" "RED phase" "Should start with red phase"
    assert_contains "$output" "GREEN phase" "Should proceed to green phase"
    assert_contains "$output" "REFACTOR phase" "Should complete with refactor"
    
    # Verify cycle recorded in history
    history_content=$(cat ".ai-session/$feature_id/history.jsonl")
    assert_contains "$history_content" '"phase":"red"' "History should record red phase"
    assert_contains "$history_content" '"phase":"green"' "History should record green phase"
    assert_contains "$history_content" '"phase":"refactor"' "History should record refactor phase"
    
    unmock_command "claude"
}

test_implement_blocks_without_plan() {
    setup_test_scripts
    
    # Initialize session without implementation plan
    feature_id="impl-no-plan-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Remove implementation plan
    rm -f ".ai-session/$feature_id/implementation-plan.yaml"
    
    # Attempt to implement
    set +e
    output=$(./scripts/implement.sh "$feature_id" --task "some-task" 2>&1)
    exit_code=$?
    set -e
    
    # Verify implementation blocked
    assert_not_equals "0" "$exit_code" "Should fail without implementation plan"
    assert_contains "$output" "No implementation plan found" "Should explain the issue"
    assert_contains "$output" "Run 'plan' command first" "Should suggest next step"
}

test_implement_task_status_transitions() {
    setup_test_scripts
    
    # Initialize session with task
    feature_id="impl-status-$(date +%Y-%m-%d)"
    ./scripts/init-session.sh "$feature_id"
    
    # Create task in pending state
    cat > ".ai-session/$feature_id/implementation-plan.yaml" <<EOF
feature:
  id: "$feature_id"
phases:
  - phase_id: "phase-1"
    tasks:
      - task_id: "feature-x"
        description: "Implement feature X"
        status: "pending"
EOF
    
    # Mock implementation stages
    mock_command "claude" "mock_claude() {
        echo '{\"status\": \"success\"}'
    }"
    
    # Execute implement
    ./scripts/implement.sh "$feature_id" --task "feature-x"
    
    # Verify status transitions
    plan_content=$(cat ".ai-session/$feature_id/implementation-plan.yaml")
    
    # Task should transition through states
    history_content=$(cat ".ai-session/$feature_id/history.jsonl")
    assert_contains "$history_content" '"task_status":"in_progress"' "Should mark task in progress"
    assert_contains "$history_content" '"task_status":"completed"' "Should mark task completed"
    
    # Final state should be completed
    assert_contains "$plan_content" 'status: "completed"' "Task should be completed"
    
    unmock_command "claude"
}

# Run all tests
echo "Testing implement command ATDD enforcement..."
run_test_scenario "Implement enforces test-first" test_implement_enforces_test_first
run_test_scenario "Implement checks existing tests" test_implement_checks_existing_tests
run_test_scenario "Implement with existing tests" test_implement_with_existing_tests
run_test_scenario "Implement generates test artifacts" test_implement_generates_test_artifacts
run_test_scenario "Implement validates coverage" test_implement_validates_test_coverage
run_test_scenario "Implement BDD scenarios" test_implement_bdd_scenario_generation
run_test_scenario "Implement TDD cycle" test_implement_red_green_refactor_cycle
run_test_scenario "Implement blocks without plan" test_implement_blocks_without_plan
run_test_scenario "Implement task transitions" test_implement_task_status_transitions