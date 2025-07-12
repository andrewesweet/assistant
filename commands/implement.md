---
description: Implement tasks following ATDD/TDD methodology
category: development
---

# Implement Command

Execute implementation tasks with enforced test-first development practices.

## Usage

```
/implement --task <task-id> [options]
```

## Required Arguments

- `--task <task-id>` - The ID of the task to implement from your plan

## Options

- `--model <model>` - AI model to use (default: sonnet, alternatives: opus)
- `--tdd` - Run full TDD red-green-refactor cycle
- `--check-coverage` - Validate test coverage meets requirements
- `--no-tests` - Skip test enforcement (testing only, not recommended)

## Description

The implement command executes tasks from your implementation plan while enforcing ATDD/TDD practices:

1. **Checks for existing tests** - Verifies if tests already exist
2. **Writes tests first** - Enforces test-first development
3. **Implements solution** - Creates code to make tests pass
4. **Validates coverage** - Ensures adequate test coverage
5. **Updates task status** - Tracks progress in the plan

## ATDD/TDD Workflow

### Standard ATDD Flow (default)
1. Check if tests exist for the task
2. If not, write comprehensive tests first
3. Implement code to make tests pass
4. Mark task as completed

### Full TDD Cycle (--tdd flag)
1. **RED**: Write failing tests
2. **GREEN**: Implement minimal code to pass
3. **REFACTOR**: Improve code quality

## Examples

### Basic Implementation
```
/implement --task auth-service
```

### With Specific Model
```
/implement --task user-validation --model opus
```

### Full TDD Cycle
```
/implement --task calculator --tdd
```

### Check Coverage
```
/implement --task critical-logic --check-coverage
```

## Test Requirements

The command enforces different test types based on the task:
- **Unit Tests**: Core logic testing
- **Integration Tests**: Component interaction
- **Contract Tests**: API contracts
- **BDD Scenarios**: User behavior tests

## Task Management

Tasks progress through states:
1. `pending` → Initial state
2. `in_progress` → Currently being implemented
3. `completed` → Successfully implemented

## Best Practices

1. **Never skip tests**: Always write tests first
2. **Small iterations**: Implement one test at a time
3. **Clear test names**: Tests should describe behavior
4. **Edge cases**: Include error and boundary conditions
5. **Refactor regularly**: Keep code clean and maintainable

## Model Selection

- **Sonnet** (default):
  - Optimized for coding tasks
  - Fast and efficient
  - Excellent for implementation
  - 200k context window

- **Opus**:
  - Better for complex logic
  - Superior problem-solving
  - Use for challenging tasks
  - 200k context window

## Coverage Requirements

When using `--check-coverage`, the command validates:
- Minimum coverage thresholds (defined in plan)
- All acceptance criteria covered
- Edge cases tested
- Error paths validated

## Session Integration

The command:
- Requires an active session with a plan
- Updates task status automatically
- Logs all activities to history
- Maintains test artifacts

## Error Handling

Common errors and solutions:
- **No plan found**: Run `/plan` first
- **Task not found**: Check task ID in plan
- **Tests failed**: Fix tests before proceeding
- **Coverage too low**: Add more test cases