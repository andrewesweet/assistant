---
name: escalate
description: Escalate from current AI to another AI with context preservation
category: ai
---

# Escalate Command

## Usage
```
/ai/escalate <target-ai> [options]
```

## Description
Escalate from your current AI assistant to another AI with full context preservation. This command allows seamless handoff between AI models while maintaining conversation history and context.

## Target AI Options
- `claude` - Escalate to Claude
- `gemini` - Escalate to Gemini  
- `opus` - Escalate to Claude Opus

## Options
- `--prompt` - Additional prompt to include with escalation
- `--context` - Include session context (default: true)
- `--summary` - Summarize context before escalation

## Examples
```bash
# Escalate to Claude with current context
/ai/escalate claude

# Escalate to Gemini with additional prompt
/ai/escalate gemini --prompt "Focus on performance optimization"

# Escalate without context
/ai/escalate opus --context=false
```

## Notes
- Context includes conversation history and active session state
- Large contexts may be summarized to fit token limits
- Original AI session remains available for reference