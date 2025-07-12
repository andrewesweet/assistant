---
name: history
description: Show AI command history and analyze patterns
category: ai
---

# History Command

## Usage
```
/ai/history <feature-id> [options]
```

## Description
Display and analyze the command history for an AI session. Shows what commands were executed, which models were used, and provides insights into the development workflow.

## Options
- `--limit N` - Show last N commands (default: 20)
- `--model MODEL` - Filter by specific model (gemini, claude, opus)
- `--command CMD` - Filter by command type (plan, implement, review, etc.)
- `--json` - Output in JSON format for processing
- `--stats` - Show statistics and patterns

## Examples
```bash
# Show recent history
/ai/history current-feature-2025-01-10

# Show last 50 commands
/ai/history feature-id --limit 50

# Filter by model
/ai/history feature-id --model gemini

# Get statistics
/ai/history feature-id --stats

# Export as JSON
/ai/history feature-id --json > history.json
```

## Output Includes
- Timestamp of each command
- Command type and arguments
- Model used
- Success/failure status
- Duration
- Error messages (if any)

## Notes
- History is stored in `.ai-session/<feature-id>/history.jsonl`
- Each line is a valid JSON object
- History is append-only for audit trail