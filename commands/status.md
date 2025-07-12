---
name: status
description: Display comprehensive session status and metrics
category: utility
---

# AI Orchestrator - Status Command Prompt

You are assisting with displaying comprehensive session status and metrics for the AI Orchestrator system.

## Context

The status command provides users with a complete overview of their development sessions, including:
- Current active tasks and state
- Command history and statistics
- Model usage patterns
- Task progress tracking
- Performance metrics
- Session health indicators

## Status Information Categories

### 1. Session Overview
- Feature ID and description
- Current active task
- Model currently in use
- Session start time and duration
- Last update timestamp

### 2. Session Health
- **Active**: Recent activity within last hour
- **Idle**: No activity for 1-24 hours
- **Stale**: No activity for more than 24 hours
- Time since last activity

### 3. Command History
- Total commands executed
- Breakdown by command type (plan, implement, review, verify)
- Number of failures
- Recent activity log (last 5 commands)

### 4. Model Usage Statistics
- Count of commands per model (gemini, sonnet, opus)
- Model preference patterns
- Cost implications (if applicable)

### 5. Task Progress
- Total tasks in implementation plan
- Completed tasks count
- In-progress tasks
- Pending tasks
- Overall progress percentage

### 6. Artifacts Summary
- Total files created/modified
- Breakdown by file type (.go, .py, .js, .md, .sql, etc.)
- Directory structure summary

### 7. Performance Metrics
- Average command duration
- Total execution time
- Performance trends

## Display Formats

### Standard Output
Formatted, color-coded terminal output with:
- Clear section headers
- Visual separators
- Progress indicators
- Color coding for status (green=good, yellow=warning, red=error)

### JSON Output
Structured JSON for programmatic consumption:
```json
{
    "feature_id": "string",
    "description": "string",
    "active_task": "string",
    "model": "string",
    "started_at": "ISO 8601 timestamp",
    "last_updated": "ISO 8601 timestamp",
    "duration": "human-readable duration",
    "health_status": "Active|Idle|Stale",
    "commands": {
        "total": number,
        "by_type": {...},
        "failures": number
    },
    "model_usage": {...},
    "tasks": {...},
    "artifacts": {...},
    "performance": {...}
}
```

## Multiple Sessions

When no feature ID is provided, display:
- List of all active sessions
- Brief summary for each (ID, description, status)
- Instructions to view detailed status

## Error Handling

- Session not found: Clear error message with suggestions
- Corrupted state: Graceful degradation, show what's available
- Missing files: Continue with partial information

## Best Practices

1. **Performance**: Cache calculations where possible
2. **Accuracy**: Use precise timestamps and calculations
3. **Clarity**: Present information in order of importance
4. **Actionability**: Include next steps or recommendations

Remember: The status command is often the first thing users check to understand their project state, so clarity and accuracy are paramount.