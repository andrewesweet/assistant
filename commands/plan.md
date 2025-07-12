---
description: Create implementation plan using AI planning models
category: planning
---

# Plan Command

Create a comprehensive implementation plan for your feature using advanced AI planning capabilities.

## Usage

```
/plan [options] <description>
```

## Options

- `--full-context` - Include full codebase context in planning (uses `-a` flag with Gemini)
- `--model <model>` - Specify model to use (default: gemini, fallback: opus)
- `--retry` - Enable retry logic for transient failures
- `--timeout <ms>` - Set execution timeout in milliseconds

## Description

The plan command creates detailed implementation plans following ATDD/TDD methodology. It automatically:

1. **Routes to Gemini by default** - Leverages Gemini's superior planning capabilities
2. **Falls back to Opus** - Automatically switches to Opus if Gemini is unavailable
3. **Generates structured plans** - Creates phases, tasks, and test requirements
4. **Enforces ATDD** - Ensures test-first development approach
5. **Tracks in history** - Logs all planning activities for audit trail

## Examples

### Basic Planning
```
/plan "Create user authentication system"
```

### Full Codebase Analysis
```
/plan --full-context "Refactor the entire data access layer"
```

### Explicit Model Selection
```
/plan --model opus "Design microservices architecture"
```

### With Retry Logic
```
/plan --retry "Plan API versioning strategy"
```

## Output

The command generates an implementation plan with:
- **Phases**: Major implementation stages
- **Tasks**: Specific work items with IDs
- **Test Requirements**: Required tests for each task
- **Agent Assignments**: Which agent should handle each task
- **Dependencies**: Task relationships and order

## Planning Best Practices

1. **Be Specific**: Provide clear, detailed descriptions of what you want to build
2. **Include Context**: Mention existing systems, constraints, and requirements
3. **Think in Phases**: Break complex features into manageable phases
4. **Consider Testing**: Think about testability from the planning stage
5. **Define Success**: Include acceptance criteria in your description

## Integration with Other Commands

After planning, use:
- `/implement --task <task-id>` to execute specific tasks
- `/status` to view plan progress
- `/review-plan` to get feedback on the plan

## Model Selection

- **Gemini** (default): 
  - Best for complex planning tasks
  - Excellent at breaking down large features
  - Superior context handling with `-a` flag
  - 1M token context window

- **Opus** (fallback):
  - Used when Gemini is unavailable
  - Excellent planning capabilities
  - Good for architectural decisions
  - 200k token context window

## Session Management

Plans are stored in the session directory:
- `.ai-session/<feature-id>/implementation-plan.yaml`
- Automatically versioned and tracked
- Can be manually edited if needed