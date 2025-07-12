# AI Orchestrator Test Suite Documentation

## Overview

The AI Orchestrator test suite provides comprehensive testing for the AI session management functionality introduced in the nomad-driver-milo project. This test suite ensures reliable operation of session management, file locking, and integration with the Claude and Gemini AI tools.

## Test Structure

### Test Categories

The test suite is organized into the following categories:

1. **Session Management** - Core session functionality and file locking
   - `test_ai_command_wrapper_sessions.sh` - Session creation, resumption, JSON output
   - `test_session_file_locking.sh` - Concurrent access and race condition prevention

2. **Core Scripts** - AI command wrapper functionality
   - `test_wrapper_claude_support.sh` - Claude integration
   - `test_wrapper_claude_timeout_isolated.sh` - Timeout handling

3. **Init & Setup** - Session initialization
   - `test_init_session.sh` - Session initialization workflow
   - `test_concurrent_sessions.sh` - Multiple concurrent sessions

4. **Planning** - AI planning workflows
   - `test_plan_gemini_routing.sh` - Gemini model routing
   - `test_plan_opus_fallback.sh` - Opus fallback scenarios

5. **Implementation** - ATDD/TDD implementation workflows
   - `test_implement_atdd.sh` - Test-driven development
   - `test_implement_model_routing.sh` - Model selection
   - `test_implement_history.sh` - History tracking

6. **Review & Verify** - Code review and verification
   - `test_review_code_routing.sh` - Code review routing
   - `test_review_architecture_fallback.sh` - Architecture reviews
   - `test_verify_fresh_context.sh` - Context isolation

7. **Status & History** - Session tracking
   - `test_status_display.sh` - Status command
   - `test_review_history_logging.sh` - History logging

8. **Session Cleanup** - Maintenance operations
   - `test_session_cleanup.sh` - Session cleanup utilities

## Running Tests

### Run All Tests
```bash
make test-ai-orchestrator
```

### Run Specific Category
```bash
./test/run-ai-orchestrator-tests.sh --category "Session Management"
```

### List Available Categories
```bash
./test/run-ai-orchestrator-tests.sh --list
```

### CI Integration
Tests are automatically run in GitHub Actions as part of the build workflow.

## Test Framework

### Prerequisites
- `jq` - JSON processing
- `flock` - File locking support
- `timeout` - Command timeout utility
- Bash 4.0+

### Test Harness
Tests use the common test harness from `test-command.sh` which provides:
- Assertion functions (`assert_equals`, `assert_contains`, etc.)
- Color-coded output
- Consistent error handling

### Mock Components
- Mock `claude` command for isolated testing
- Configurable responses and exit codes
- Session ID simulation

## Key Test Scenarios

### Session Name Sanitization
- Valid characters (alphanumeric, dash, underscore)
- Path traversal prevention (`../`, `./`)
- Special character handling
- Length limitations (100 chars max)
- Unicode handling

### File Locking
- Concurrent write protection
- Shared read access
- Lock timeout (5 seconds)
- Race condition prevention
- Metadata integrity

### Error Handling
- API failures
- Empty responses
- Invalid JSON
- Network timeouts
- Lock acquisition failures

### Backward Compatibility
- Existing scripts continue to work
- Non-session usage unchanged
- Optional session features

## Security Considerations

### File Permissions
- Session directory: 700 (owner only)
- Metadata files: 600 (owner read/write)
- Lock files managed by flock

### Input Validation
- Session names sanitized
- Path traversal blocked
- Command injection prevented

## Performance

### Benchmarks
- Session operations: < 100ms
- Concurrent reads: No blocking
- Lock timeout: 5 seconds max
- File operations: Optimized with flock

## Troubleshooting

### Common Issues

1. **Missing jq**
   ```bash
   sudo apt-get install jq
   ```

2. **Lock timeout failures**
   - Check for stale lock files
   - Verify flock availability
   - Increase timeout if needed

3. **Permission errors**
   - Check ~/.ai-sessions permissions
   - Ensure user has write access

### Debug Mode
```bash
DEBUG=true ./test/run-ai-orchestrator-tests.sh
```

## Future Enhancements

1. **Performance Tests**
   - Load testing with many sessions
   - Memory usage profiling
   - Large metadata handling

2. **Integration Tests**
   - End-to-end workflows
   - Multi-user scenarios
   - Network failure simulation

3. **Security Tests**
   - Penetration testing
   - Input fuzzing
   - Permission escalation checks

## Contributing

When adding new tests:
1. Place in appropriate category
2. Follow naming convention: `test_feature_aspect.sh`
3. Use test harness assertions
4. Document test purpose
5. Add to test runner categories
6. Ensure CI compatibility