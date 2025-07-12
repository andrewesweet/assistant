# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) and Gemini Code Assist when working with the AI Development Assistant.

## AI Tool Usage

### AI Orchestrator

This AI Development Assistant provides a comprehensive orchestrator system for managing development workflows. See the [AI Orchestrator Usage Guide](docs/AI_ORCHESTRATOR_GUIDE.md) for detailed documentation on:
- Session management and multi-feature development
- Test-first development enforcement (TDD/ATDD)
- Optimal model routing (Gemini, Claude, Opus)
- Code and architecture review workflows
- AI escalation between models with context preservation
- Command history and audit trails
- **NEW**: AI Session Continuity - 40% token savings with persistent context (enabled by default)

#### AI Session Management (NEW!)

AI sessions are now enabled by default for significant token savings:

```bash
# Sessions are automatically enabled - AI maintains context across tasks!
implement my-feature --task T1.1
implement my-feature --task T1.2  # Continues same session

# Disable sessions if needed
USE_SESSIONS=false implement my-feature --task T1.1

# Manage sessions
ai-session list                    # List all sessions
ai-session show implement-my-feature  # Show details
ai-session stats                   # View usage stats
ai-session clean --older-than 30  # Clean old sessions
```

See the [AI Session Management Guide](docs/AI_SESSION_MANAGEMENT_GUIDE.md) for complete documentation.

### Gemini Integration

For Claude Code, the `gemini` command is available for complex analysis, planning, and debugging:

```bash
# Use Gemini 2.5 Pro (default model, 1M token context)
gemini -p "Your prompt here"

# Include all files in context for full codebase analysis
gemini -a -p "Analyze the entire codebase structure"

# Enable debug mode for troubleshooting
gemini -d -p "Debug this issue"
```

**When to use Gemini:**
- Full codebase analysis and understanding (tip: run gemini with the project root folder and use the -a flag for it to automatically ingest all files in the codebase into its context)
- Complex problem solving and planning
- Debugging intricate issues
- Architecture reviews
- Long-form analysis requiring large context
- Reviewing technical spike findings
- Epic and user story planning

**Gemini capabilities:**
- 1 million token context window (excellent for large codebases)
- Reads CLAUDE.md automatically for project context
- Superior at planning and problem-solving
- Can call Claude for additional opinions when needed

### Claude Integration

For Gemini, the `claude` command provides access to different Claude models:

```bash
# Use Sonnet 4 (default, excellent for coding)
claude -p "Your prompt here"

# Use Opus 4 for complex planning and problem-solving
claude --model opus -p "Your prompt here"

# Print mode for scripting/automation
claude -p "Your prompt here" --print
```

**Model Selection:**
- **Sonnet 4**: Best for coding execution, efficient, 200k context
- **Opus 4**: Superior for planning and complex problem-solving, more expensive, 200k context
- Both models are excellent, choose based on task complexity and cost considerations

**When to use Claude:**
- Code generation and editing
- Quick problem-solving
- Integration with existing workflows
- When you need a second opinion on Gemini's suggestions

### Context Management

**Important**: Each `claude -p` and `gemini -p` call starts with **empty context** - no memory of previous calls or conversations. Interactive Claude Code sessions maintain persistent context throughout the entire conversation.

**Context sharing limitations:**
- No built-in context sharing between separate command calls
- Each invocation is stateless and independent
- Manual context passing required (but hits token limits quickly)

### Best Practices

1. **For comprehensive analysis**: Run Gemini from the project root directory with full codebase context:
   ```bash
   cd /path/to/your-project
   gemini -a -p "Analyze the entire codebase and suggest improvements"
   ```

2. **Context-aware workflows:**
   - Use interactive Claude Code sessions for context-heavy work that builds on previous exchanges
   - Use `claude -p` or `gemini -p` for isolated, specific tasks that don't require conversation history
   - Consider copying relevant context manually when using one-off commands

3. **Optimal workflow patterns:**
   - **Planning**: Use Gemini with `-a` flag for comprehensive codebase analysis and planning
   - **Execution**: Use interactive Claude Code sessions to maintain context during implementation
   - **Isolated tasks**: Use `claude -p` or `gemini -p` for specific, standalone questions

4. **Model selection**: Choose the right model for the task (Sonnet for coding, Opus for planning)
5. **Cross-consultation**: Gemini can call Claude for additional perspectives
6. **Cost awareness**: Be mindful of Opus costs for routine tasks

### AI Orchestrator Quick Reference

Initialize and manage development sessions:
```bash
# Start new feature
init-session "feature-name-$(date +%Y-%m-%d)"

# Create implementation plan
plan feature-name-2025-01-10 "Feature description"

# Implement with TDD
implement feature-name-2025-01-10 --task T1.1

# Check status
status feature-name-2025-01-10

# Escalate between AI models
escalate gemini --prompt "Need system-wide perspective"
```

See the [AI Orchestrator Usage Guide](docs/AI_ORCHESTRATOR_GUIDE.md) for complete documentation.