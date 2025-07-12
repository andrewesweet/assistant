# AI Development Assistant

A comprehensive AI orchestrator for software development workflows, providing intelligent model routing, session management, and test-first development enforcement.

## Overview

The AI Development Assistant enhances your development workflow by:
- **Intelligent Model Routing**: Automatically selects the optimal AI model (Gemini, Claude, Opus) for each task
- **Session Management**: Maintains context across commands with 40% token savings
- **Test-First Development**: Enforces TDD/ATDD methodology throughout the development cycle
- **Multi-Feature Support**: Manage multiple features simultaneously with isolated sessions
- **Command History**: Full audit trail of all AI interactions

## Features

### 🧠 Intelligent AI Model Selection
- **Gemini**: Best for planning, architecture, and full codebase analysis (1M token context)
- **Claude Sonnet**: Optimal for code implementation and execution (200k context)
- **Opus**: Superior for complex problem-solving and planning (200k context)
- Automatic fallback mechanisms ensure reliability

### 💾 Session Management
- Persistent context across commands
- 40% average token savings through session continuity
- Isolated sessions for different features
- Automatic session cleanup and management

### 🧪 Test-First Development
- Enforces writing tests before implementation
- Generates test requirements for all tasks
- Validates test coverage before marking tasks complete
- Supports BDD/Gherkin scenarios

### 📊 Comprehensive Tracking
- Command history with full audit trail
- Cost tracking per session and task
- Token usage analytics
- Performance metrics

## Installation

### Prerequisites
- Claude Code CLI installed ([docs](https://docs.anthropic.com/en/docs/claude-code))
- Gemini CLI (optional but recommended)
- Bash 4.0+
- Git

### Installation Methods

#### Method 1: Symlink Setup (Recommended)

This method symlinks files from your git repository, making updates easier:

1. Clone the repository:
```bash
git clone https://github.com/andrewesweet/assistant.git ~/assistant
cd ~/assistant
```

2. Run the symlink setup:
```bash
./setup-symlinks.sh
```

3. Reload your shell configuration:
```bash
source ~/.bashrc  # or ~/.zshrc
```

4. Verify installation:
```bash
status
```

**Benefits of symlinks:**
- Easy updates with `git pull`
- No file duplication
- Changes immediately reflected
- Simple uninstall (just remove symlinks)

#### Method 2: Copy Installation

If you prefer copying files instead of symlinks:

```bash
cd ~/assistant
./install.sh
```

## Usage

### Starting a New Feature

```bash
# Initialize a new feature session
init-session "my-awesome-feature"

# Create an implementation plan
plan my-awesome-feature "Build a user authentication system with OAuth support"

# View the generated plan
status my-awesome-feature
```

### Implementing Tasks

```bash
# Implement a specific task from the plan
implement my-awesome-feature --task T1.1

# The AI will:
# 1. Write tests first (enforced)
# 2. Implement the feature
# 3. Verify tests pass
# 4. Update session state
```

### Managing Sessions

```bash
# List all active sessions
ai-session list

# View session details
ai-session show my-awesome-feature

# Switch between features
switch-feature another-feature

# View session statistics
ai-session stats
```

### Code Reviews

```bash
# Review code changes
review-code my-awesome-feature

# Architectural review
review-architecture my-awesome-feature
```

### Verification

```bash
# Run verification workflow
verify my-awesome-feature

# Checks:
# - All tests pass
# - Code quality standards met
# - Documentation updated
# - No pending tasks
```

## Available Commands

| Command | Description |
|---------|-------------|
| `init-session` | Start a new development session |
| `plan` | Create an AI-powered implementation plan |
| `implement` | Execute tasks with TDD enforcement |
| `verify` | Run comprehensive verification |
| `status` | View session and task status |
| `review-code` | Get AI code review |
| `review-architecture` | Perform architectural review |
| `ai-session` | Manage sessions (list, show, clean) |
| `escalate` | Switch AI models with context |
| `history` | View command history |
| `switch-feature` | Change active feature context |

## Slash Commands

When using Claude Code interactively, these slash commands are available:
- `/plan` - Create implementation plans
- `/implement` - Execute tasks
- `/verify` - Run verification
- `/status` - Check progress
- `/review-code` - Code review
- `/review-architecture` - Architecture review
- `/ai/escalate` - Model escalation
- `/ai/history` - Command history
- `/ai/switch-feature` - Switch features

## Configuration

### Environment Variables

```bash
# Session directory (default: ~/.ai-sessions)
export AI_SESSION_DIR="$HOME/.ai-sessions"

# Enable/disable sessions (default: true)
export USE_SESSIONS=true

# AI Assistant home directory
export AI_ASSISTANT_HOME="$HOME/assistant"
```

### Claude Code Settings

The installation automatically configures:
- User-level commands in `~/.claude/commands/`
- AI assistant instructions in `~/.claude/CLAUDE.md`
- Environment settings in `~/.claude/settings.json`

## Architecture

### Session Structure

```
~/.ai-sessions/
├── my-feature/
│   ├── implementation-plan.yaml
│   ├── session-state.json
│   ├── command-history.log
│   └── logs/
├── another-feature/
│   └── ...
└── sessions.json
```

### Model Routing Logic

1. **Planning Tasks** → Gemini (superior planning capabilities)
2. **Implementation** → Claude Sonnet (efficient coding)
3. **Complex Analysis** → Opus (when needed)
4. **Reviews** → Model selected based on scope

### TDD Enforcement

The system enforces test-first development by:
1. Requiring test files before implementation
2. Validating test coverage
3. Running tests automatically
4. Blocking task completion if tests fail

## Contributing

1. Fork the repository
2. Create a feature branch
3. Follow TDD methodology (enforced!)
4. Submit a pull request

## Testing

Run the test suite:
```bash
cd ~/assistant/tests
./run-ai-orchestrator-tests.sh
```

## Troubleshooting

### Commands Not Found
```bash
# Ensure PATH is updated
source ~/.bashrc
echo $PATH | grep -q "$HOME/bin" || echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
```

### Session Issues
```bash
# Clean old sessions
ai-session clean --older-than 30

# Reset session state
rm -rf ~/.ai-sessions/feature-name
```

### Permission Errors
```bash
# Fix script permissions
chmod +x ~/assistant/scripts/*.sh
chmod +x ~/bin/*
```

## License

MIT License - see LICENSE file for details.

## Support

- Documentation: See `docs/` directory
- Issues: [GitHub Issues](https://github.com/andrewesweet/assistant/issues)
- AI Orchestrator Guide: `docs/AI_ORCHESTRATOR_GUIDE.md`
- Session Management Guide: `docs/AI_SESSION_MANAGEMENT_GUIDE.md`

## Acknowledgments

Originally developed as part of the nomad-driver-milo project, the AI Development Assistant has been extracted and enhanced as a standalone tool for general software development workflows.