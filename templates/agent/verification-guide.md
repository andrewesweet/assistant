# AI Orchestrator Verification Guide

## Overview

The verification system provides independent, context-free test execution to ensure accurate and unbiased test results. Each verification run operates with a fresh agent instance, maintaining complete isolation from session state and history.

## Key Principles

### 1. Fresh Context Guarantee
- Every verification run starts with zero knowledge
- No access to previous command outputs or session state
- Unique agent ID generated for each run
- Complete isolation from implementation context

### 2. Framework Agnostic
- Automatic detection of test frameworks
- Support for multiple languages and test runners
- Configurable for custom test commands
- Parallel execution across different frameworks

### 3. Comprehensive Reporting
- Detailed test results with pass/fail/skip counts
- Coverage metrics when enabled
- Performance timing information
- Structured output for CI/CD integration

## Usage Examples

### Basic Verification
```bash
# Run all tests for a feature
./scripts/verify.sh my-feature

# Run only unit tests
./scripts/verify.sh my-feature --unit

# Run integration tests
./scripts/verify.sh my-feature --integration
```

### Framework-Specific Testing
```bash
# Run Go tests with race detection
./scripts/verify.sh my-feature --go --race

# Run Python tests with coverage
./scripts/verify.sh my-feature --python --coverage

# Run JavaScript tests
./scripts/verify.sh my-feature --javascript
```

### Advanced Options
```bash
# Filter tests by pattern
./scripts/verify.sh my-feature --filter "auth"

# Exclude certain tests
./scripts/verify.sh my-feature --exclude "slow"

# Run tests in parallel
./scripts/verify.sh my-feature --parallel

# Custom test command
./scripts/verify.sh my-feature --custom "make test-special"

# CI mode with structured output
./scripts/verify.sh my-feature --ci

# JSON output for automation
./scripts/verify.sh my-feature --json
```

### Test Discovery
```bash
# Discover tests without running them
./scripts/verify.sh my-feature --discover-only

# Auto-detect framework from config files
./scripts/verify.sh my-feature --auto
```

## Framework Detection

The verification system automatically detects test frameworks based on:

### Configuration Files
- `package.json` → Jest, Mocha (JavaScript)
- `requirements.txt` → pytest, unittest (Python)
- `go.mod` → go test (Go)
- `Gemfile` → RSpec (Ruby)

### File Patterns
- `*_test.go` → Go tests
- `test_*.py`, `*_test.py` → Python tests
- `*.test.js`, `*.spec.js` → JavaScript tests
- `*_spec.rb`, `*_test.rb` → Ruby tests

## Output Formats

### Standard Output
```
Verification Results
Agent ID: verify-1234567890-5678-abcd
Framework: go
Status: success

Tests:
  Total: 25
  Passed: 24
  Failed: 1
  Skipped: 0
  Coverage: 85.3%

Duration: 1234ms
```

### JSON Output
```json
{
    "status": "success",
    "framework": "go",
    "tests": {
        "total": 25,
        "passed": 24,
        "failed": 1,
        "skipped": 0
    },
    "coverage": "85.3%",
    "duration_ms": 1234,
    "agent_id": "verify-1234567890-5678-abcd"
}
```

### CI Mode
Generates JUnit XML format test results in:
``.ai-session/<feature-id>/artifacts/test-results.xml`

## Best Practices

### 1. Test Organization
- Keep tests close to implementation code
- Use standard naming conventions for auto-detection
- Include test configuration files in artifacts

### 2. Performance
- Use `--parallel` for faster execution with multiple test suites
- Filter tests when debugging specific issues
- Cache dependencies outside the verification scope

### 3. Debugging
- Use `--verbose` for detailed output
- Check discovered tests with `--discover-only`
- Review agent ID in logs for tracking specific runs

### 4. CI/CD Integration
```yaml
# Example GitHub Actions workflow
- name: Verify Tests
  run: ./scripts/verify.sh ${{ env.FEATURE_ID }} --ci --parallel
  
- name: Upload Test Results
  uses: actions/upload-artifact@v3
  with:
    name: test-results
    path: .ai-session/*/artifacts/test-results.xml
```

## Troubleshooting

### No Tests Found
- Check artifact directory exists
- Verify test file naming conventions
- Use `--discover-only` to see what's being searched
- Ensure tests are included in session artifacts

### Framework Not Detected
- Add configuration files (package.json, requirements.txt, etc.)
- Use explicit framework flags (--go, --python, etc.)
- Check for typos in test file names

### Tests Failing in Verify but Passing Locally
- Remember verify runs with fresh context
- Check for hidden dependencies on session state
- Ensure all test fixtures are self-contained
- Verify environment variables are not leaking

### Concurrent Execution Issues
- Each verify run has unique agent ID
- Parallel runs are fully isolated
- Check for shared resources (ports, files)
- Use proper test cleanup

## Architecture

### Isolation Mechanism
1. Generate unique agent ID per run
2. Create fresh environment variables
3. No access to session state files
4. Independent process execution
5. Clean working directory

### Execution Flow
1. Parse command arguments
2. Validate session exists
3. Generate agent ID
4. Discover test files
5. Detect frameworks
6. Create verification prompt
7. Execute tests via AI agent
8. Parse and format results
9. Log to history with fresh context marker
10. Generate CI artifacts if requested

## Security Considerations

- No session state access prevents data leakage
- Fresh context prevents prompt injection from history
- Isolated execution prevents cross-contamination
- Unique IDs enable audit trails

## Future Enhancements

- Watch mode for continuous testing
- Test impact analysis
- Distributed test execution
- Test flakiness detection
- Historical trend analysis