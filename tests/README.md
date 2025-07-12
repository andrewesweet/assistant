# AI Orchestrator Test Suite

This directory contains the test infrastructure for the AI Orchestrator system.

## Quick Start

```bash
# Run basic test harness
./test-command.sh

# Run with verbose output
./test-command.sh -v

# Run specific test (once implemented)
./test-command.sh -t test_session_creation
```

## Directory Structure

```
test/
├── test-command.sh      # Core test harness with utilities
├── scenarios/          # Test scenarios organized by feature
├── fixtures/           # Test data and mock responses
├── utils/             # Additional test utilities
└── README.md          # This file
```

## Test Harness Features

The `test-command.sh` script provides:

### Assertion Functions
- `assert_equals` - Compare values
- `assert_contains` - Check for substrings
- `assert_exists` - Verify file/directory existence
- `assert_json_valid` - Validate JSON structure
- `assert_yaml_valid` - Validate YAML structure
- And many more...

### Mock Utilities
- `mock_command` - Create command mocks
- `unmock_command` - Remove mocks

### Session Utilities
- `create_test_session` - Set up test sessions
- `cleanup_test_sessions` - Clean up after tests

### Test Execution
- `run_test_scenario` - Execute individual test scenarios
- `measure_time` - Performance benchmarking

## Writing Tests

1. Create test files in `scenarios/` following the naming convention
2. Source the test harness at the beginning
3. Use assertion functions to verify behavior
4. Always clean up test artifacts

Example test structure:
```bash
#!/bin/bash
source "$(dirname "$0")/../test-command.sh"

test_my_feature() {
    # Arrange
    create_test_session "test-feature"
    
    # Act
    local result=$(run_command ".claude/commands/mycommand.md" "arg1")
    
    # Assert
    assert_contains "$result" "expected output"
    assert_exists ".ai-session/test-feature/state.yaml"
}

# Run the test
run_test_scenario "My Feature Test" test_my_feature
```

## Running Tests

### Individual Tests
```bash
./scenarios/test_help_basic.sh
```

### All Tests (once Makefile is updated)
```bash
make test-all
```

### With Coverage
```bash
make test-coverage
```

## Test Categories

- **Unit Tests**: Test individual functions
- **Integration Tests**: Test command interactions
- **End-to-End Tests**: Test complete workflows

## Environment Variables

- `TEST_VERBOSE=1` - Enable verbose output
- `TEST_USER=username` - Override test user
- `TEST_ENV=true` - Automatically set in test environment

## Best Practices

1. Each test should be independent
2. Always use test harness utilities
3. Clean up all test artifacts
4. Mock external dependencies
5. Test both success and failure paths

## Troubleshooting

If tests fail:
1. Check verbose output with `-v` flag
2. Verify test environment setup
3. Check for leftover test artifacts
4. Review assertion failure messages

For more details, see `docs/testing-standards.md`.