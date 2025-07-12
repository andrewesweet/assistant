---
name: switch-feature
description: Switch between active AI sessions/features
category: ai
---

# Switch Feature Command

## Usage
```
/ai/switch-feature <feature-id>
```

## Description
Switch to a different active AI session or feature. This allows you to work on multiple features concurrently and switch between them seamlessly.

## Options
- `--list` - List all active sessions before switching
- `--status` - Show status of target session

## Examples
```bash
# Switch to a specific feature
/ai/switch-feature payment-integration-2025-01-10

# List sessions then switch
/ai/switch-feature --list
/ai/switch-feature feature-x-2025-01-10

# Check status before switching
/ai/switch-feature payment-api-2025-01-10 --status
```

## Notes
- Preserves state of current session before switching
- Restores full context of target session
- Session must be active to switch to it