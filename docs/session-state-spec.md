# Session State Specification (BINDING CONTRACT)

**Version**: 1.0  
**Status**: BINDING - Changes require approval  
**Date**: 2025-01-09

## Overview

This document defines the binding contract for session state management in the AI Orchestrator system. All agents must adhere to this specification when reading or writing session state.

## Session Structure

```yaml
session_structure:
  feature_id: "string (format: {slug}-{date})"
  implementation_plan: "path to YAML file"
  history_log: "path to JSON lines file"
  current_state:
    active_task: "task ID or null"
    model_in_use: "gemini|opus|sonnet"
    started_at: "ISO 8601 timestamp"
    last_updated: "ISO 8601 timestamp"
```

## Directory Layout

```
.ai-session/
├── active-features.yaml           # List of active features
├── {feature-id}/                  # Per-feature directory
│   ├── implementation-plan.yaml   # Feature implementation plan
│   ├── history.jsonl             # Command history log
│   ├── state.yaml                # Current session state
│   └── artifacts/                # Generated artifacts
└── README.md                     # Session documentation
```

## Data Formats

### Feature ID Format
- Pattern: `{feature-slug}-{YYYY-MM-DD}`
- Example: `ai-orchestrator-2025-01-09`
- Slug: lowercase, hyphen-separated
- Date: ISO 8601 date format

### Implementation Plan Schema
```yaml
feature:
  id: "feature-id"
  name: "Human-readable feature name"
  description: "Feature description"
  created_at: "ISO 8601 timestamp"
  
phases:
  - phase_id: "string"
    name: "Phase name"
    tasks:
      - task_id: "string"
        description: "Task description"
        agent: "assigned agent identifier"
        status: "pending|in_progress|completed|blocked"
        started_at: "ISO 8601 timestamp or null"
        completed_at: "ISO 8601 timestamp or null"
        artifacts: ["list of generated files"]
```

### History Log Format (JSON Lines)
Each line is a JSON object:
```json
{
  "timestamp": "ISO 8601 timestamp",
  "command": "command name",
  "arguments": "command arguments",
  "model": "gemini|opus|sonnet",
  "agent": "agent identifier",
  "task_id": "current task ID or null",
  "status": "success|failure",
  "duration_ms": 1234,
  "error": "error message if status=failure"
}
```

### Active Features Format
```yaml
active_features:
  - feature_id: "ai-orchestrator-2025-01-09"
    started_at: "2025-01-09T10:00:00Z"
    last_active: "2025-01-09T15:30:00Z"
    status: "active|paused|completed"
```

## State Management Rules

### Creating a Session
1. Generate unique feature ID
2. Create feature directory
3. Initialize implementation plan
4. Create empty history log
5. Initialize state.yaml
6. Add to active-features.yaml

### Updating State
1. All state changes must be atomic
2. Update last_updated timestamp
3. Append to history log (never modify existing entries)
4. State transitions must be valid

### Session Cleanup
1. Mark feature as completed in active-features.yaml
2. Archive or preserve session data
3. Never delete active session data

## Concurrency Handling

### Locking Strategy
- File-based locking for state.yaml updates
- Append-only for history.jsonl (no locks needed)
- Read locks for implementation-plan.yaml

### Conflict Resolution
- Last-write-wins for state updates
- Merge conflicts in active-features.yaml must be resolved manually
- History logs are immutable

## Validation Requirements

### On Session Creation
- Validate feature ID format
- Ensure no duplicate feature IDs
- Verify directory creation permissions

### On State Update
- Validate against schema
- Ensure timestamps are monotonic
- Verify model values are valid

### On Read
- Handle missing files gracefully
- Validate data format
- Report corruption or inconsistencies

## Error Handling

### Required Error Information
```yaml
error_context:
  operation: "create|read|update|delete"
  file: "affected file path"
  feature_id: "feature ID if applicable"
  timestamp: "when error occurred"
  details: "specific error message"
```

### Recovery Procedures
1. Corrupted state: Restore from history log
2. Missing files: Recreate from specification
3. Lock conflicts: Exponential backoff retry

## Backward Compatibility

### Version Detection
- Check for `version` field in state.yaml
- Assume v1.0 if missing
- Migration path required for version changes

### Migration Strategy
- Never modify existing data in-place
- Create new format alongside old
- Provide migration tools

## Contract Acknowledgment

All agents implementing this specification must create an acknowledgment file at `.ai-session/contract-acknowledgment.md` containing:

```markdown
# Contract Acknowledgment

Agent: [Agent Name/ID]
Date: [ISO 8601 Date]
Contract Version: 1.0
Checksum: [SHA256 of this specification]

I acknowledge that I have read and will adhere to the Session State Specification v1.0.
```

## Change Management

### Modification Process
1. Propose changes via PR
2. Human review and approval required
3. Version bump required
4. All agents must re-acknowledge

### Breaking Changes
- Require major version bump
- Migration plan required
- Deprecation period of at least 1 phase

## Appendix: Example Files

### Example state.yaml
```yaml
version: "1.0"
feature_id: "ai-orchestrator-2025-01-09"
current_state:
  active_task: "impl-core-commands"
  model_in_use: "opus"
  started_at: "2025-01-09T10:00:00Z"
  last_updated: "2025-01-09T15:30:45Z"
```

### Example history.jsonl entry
```json
{"timestamp":"2025-01-09T10:00:00Z","command":"plan","arguments":"Create AI orchestrator","model":"gemini","agent":"agent-1","task_id":null,"status":"success","duration_ms":5234}
```

---

**END OF BINDING CONTRACT**