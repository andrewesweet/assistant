# AI Orchestrator Usage Guide

## Table of Contents
- [Overview](#overview)
- [Quick Start](#quick-start)
- [Core Commands](#core-commands)
  - [Session Management](#session-management)
  - [Planning](#planning)
  - [Implementation](#implementation)
  - [Code Review](#code-review)
  - [Architecture Review](#architecture-review)
  - [Verification](#verification)
  - [Status Monitoring](#status-monitoring)
- [AI Namespace Commands](#ai-namespace-commands)
  - [Escalation](#escalation)
  - [Session Switching](#session-switching)
  - [History Analysis](#history-analysis)
- [Workflows](#workflows)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## Overview

The AI Orchestrator is a comprehensive system for managing AI-assisted development workflows. It enforces test-first development (TDD/ATDD), provides multi-model AI coordination, and maintains detailed session tracking.

### Key Features
- **Test-First Development**: Enforces writing tests before implementation
- **Multi-Model Support**: Optimized routing between Gemini, Claude, and Opus
- **Session Management**: Track multiple features concurrently
- **Context Preservation**: Maintain state across commands and sessions
- **AI Session Continuity**: Preserve AI context across multiple interactions (40% token savings)
- **Audit Trail**: Complete history logging with metadata
- **TodoWrite Integration**: Automatic task tracking for AI sessions

## Quick Start

### 1. Initialize a New Feature Session
```bash
# Create a new session for your feature
./scripts/init-session.sh "payment-api-2025-01-10"

# Output:
# Initializing session: payment-api-2025-01-10
# Session initialized successfully:
#   Directory: .ai-session/payment-api-2025-01-10
#   Status: active
```

### 2. Create an Implementation Plan
```bash
# Generate a comprehensive plan using Gemini
./scripts/plan.sh payment-api-2025-01-10 "Add payment processing API with Stripe integration"

# With full codebase context (slower but more comprehensive)
./scripts/plan.sh payment-api-2025-01-10 "Add payment processing API" --full-context
```

### 3. Implement with TDD
```bash
# Implement a specific task (tests required first)
./scripts/implement.sh payment-api-2025-01-10 --task T1.1

# AI sessions are enabled by default (40% token savings)
./scripts/implement.sh payment-api-2025-01-10 --task T1.1

# Skip test enforcement (not recommended)
./scripts/implement.sh payment-api-2025-01-10 --task T1.1 --no-tests
```

### 4. Check Status
```bash
# View comprehensive session status
./scripts/status.sh payment-api-2025-01-10

# View all active sessions
./scripts/status.sh --all
```

## AI Session Management (NEW!)

The orchestrator now supports persistent AI sessions that maintain context across multiple interactions, providing significant token savings and improved consistency.

### Sessions Enabled by Default

Starting with version 1.1.0, AI sessions are enabled by default for all commands. No configuration needed!

```bash
# Sessions are automatically used
./scripts/implement.sh feature --task T1
./scripts/plan.sh feature "Create a plan"

# Disable for single command if needed
USE_SESSIONS=false ./scripts/implement.sh feature --task T1

# Disable globally
export USE_SESSIONS=false

# Check current setting
echo $USE_SESSIONS
```

### Benefits
- **40% Token Reduction**: Reuse context across tasks
- **Better Consistency**: AI remembers previous discussions
- **Cost Tracking**: Monitor usage per session
- **TodoWrite Integration**: Automatic task tracking

### Session Commands

```bash
# List all AI sessions
./scripts/ai-session.sh list

# Show session details with costs
./scripts/ai-session.sh show implement-feature-name

# View statistics
./scripts/ai-session.sh stats

# Clean old sessions
./scripts/ai-session.sh clean --older-than 30

# Export session data
./scripts/ai-session.sh export --output backup.json
```

### How It Works
- Sessions automatically created per feature
- Named as: `<command>-<feature-id>` (e.g., `implement-auth-service`)
- Context preserved between commands
- Secure storage in `~/.ai-sessions/`

See the [AI Session Management Guide](AI_SESSION_MANAGEMENT_GUIDE.md) for detailed documentation.

## Core Commands

### Session Management

#### Initialize Session
```bash
./scripts/init-session.sh <feature-id>
```
- Creates new session directory structure
- Initializes state tracking
- Updates active features list

**Example:**
```bash
./scripts/init-session.sh "user-auth-2025-01-10"
```

#### List Sessions
```bash
./scripts/list-sessions.sh [options]

# List active sessions only
./scripts/list-sessions.sh --active

# Include archived sessions
./scripts/list-sessions.sh --all
```

#### Clean Up Sessions
```bash
# Archive completed session
./scripts/cleanup-sessions.sh user-auth-2025-01-10

# Clean up all inactive sessions
./scripts/cleanup-sessions.sh --all --inactive
```

### Planning

The plan command uses Gemini for comprehensive system-wide planning:

```bash
./scripts/plan.sh <feature-id> "<description>" [options]

Options:
  --full-context    Include entire codebase context
  --model           Override default model (gemini)
```

**Examples:**
```bash
# Basic planning
./scripts/plan.sh api-v2-2025-01-10 "Migrate API to v2 with GraphQL"

# Comprehensive planning with full context
./scripts/plan.sh api-v2-2025-01-10 "Migrate API to v2" --full-context

# Force specific model
./scripts/plan.sh api-v2-2025-01-10 "Simple CRUD API" --model opus
```

**Output**: Creates `implementation-plan.yaml` with:
- Phased approach
- Task breakdown
- Test requirements
- Dependencies
- Agent assignments

### Implementation

Enforces test-first development methodology:

```bash
./scripts/implement.sh <feature-id> [options]

Options:
  --task         Specific task ID from plan
  --model        Choose model (sonnet/opus)
  --no-tests     Skip test enforcement (not recommended)
  --tdd          Full TDD cycle support
```

**Examples:**
```bash
# Implement specific task (requires tests)
./scripts/implement.sh payment-api-2025-01-10 --task T2.3

# Use Opus for complex implementation
./scripts/implement.sh payment-api-2025-01-10 --task T3.1 --model opus

# Full TDD cycle
./scripts/implement.sh payment-api-2025-01-10 --task T1.1 --tdd
```

### Code Review

Deep code analysis using Opus model:

```bash
./scripts/review-code.sh <feature-id> <file1> [file2 ...] [options]

Options:
  --security     Focus on security issues
  --performance  Focus on performance
```

**Examples:**
```bash
# Review single file
./scripts/review-code.sh feature-x-2025-01-10 src/payment.js

# Review multiple files
./scripts/review-code.sh feature-x-2025-01-10 src/*.js tests/*.test.js

# Security-focused review
./scripts/review-code.sh auth-2025-01-10 src/auth.js --security
```

### Architecture Review

System-wide architecture analysis using Gemini:

```bash
./scripts/review-architecture.sh <feature-id> [options]

Options:
  --focus        Area to focus on (security/performance/scalability)
  --compare      Compare with previous architecture
```

**Examples:**
```bash
# Basic architecture review
./scripts/review-architecture.sh microservices-2025-01-10

# Performance-focused review
./scripts/review-architecture.sh api-optimization-2025-01-10 --focus performance

# Compare architectures
./scripts/review-architecture.sh v2-migration-2025-01-10 --compare v1
```

### Verification

Independent verification with fresh context:

```bash
./scripts/verify.sh <feature-id> [options]

Options:
  --unit          Run unit tests only
  --integration   Run integration tests only
  --acceptance    Run acceptance tests only
  --all           Run all tests (default)
```

**Examples:**
```bash
# Run all tests
./scripts/verify.sh payment-api-2025-01-10

# Unit tests only
./scripts/verify.sh payment-api-2025-01-10 --unit

# Specific test framework
./scripts/verify.sh payment-api-2025-01-10 --go
```

### Status Monitoring

Comprehensive session status display:

```bash
./scripts/status.sh [feature-id] [options]

Options:
  --json         Output in JSON format
  --all          Show all sessions
```

**Examples:**
```bash
# Specific session status
./scripts/status.sh payment-api-2025-01-10

# All active sessions
./scripts/status.sh --all

# JSON output for processing
./scripts/status.sh payment-api-2025-01-10 --json
```

**Status includes:**
- Current task and progress
- Model usage statistics
- Command history summary
- Performance metrics
- Session health indicators

## AI Namespace Commands

### Escalation

Seamlessly hand off between AI models with context:

```bash
./scripts/escalate.sh <target-ai> [options]

Target AI:
  claude     Standard Claude model
  gemini     Gemini model
  opus       Claude Opus model

Options:
  --prompt TEXT    Additional context
  --context BOOL   Include session context (default: true)
  --feature ID     Specific feature (default: current)
```

**Examples:**
```bash
# Basic escalation to Gemini
./scripts/escalate.sh gemini

# Escalate with additional context
./scripts/escalate.sh claude --prompt "Focus on performance optimization"

# Escalate without session context
./scripts/escalate.sh opus --context false

# Escalate specific feature
./scripts/escalate.sh gemini --feature payment-api-2025-01-10
```

**Context includes:**
- Current session information
- Active task details
- Recent command history
- Implementation plan reference

### Session Switching

Switch between active features (placeholder - not fully implemented):

```bash
./scripts/switch-feature.sh <feature-id>

Options:
  --list         List all active sessions
  --status       Show target session status
```

**Examples:**
```bash
# Switch to different feature
./scripts/switch-feature.sh auth-system-2025-01-10

# List then switch
./scripts/switch-feature.sh --list
./scripts/switch-feature.sh payment-api-2025-01-10
```

### History Analysis

Analyze command history (placeholder - not fully implemented):

```bash
./scripts/history.sh <feature-id> [options]

Options:
  --limit N      Show last N commands
  --model MODEL  Filter by model
  --command CMD  Filter by command type
  --json         JSON output
  --stats        Show statistics
```

**Examples:**
```bash
# Recent history
./scripts/history.sh payment-api-2025-01-10

# Filter by model
./scripts/history.sh payment-api-2025-01-10 --model gemini

# Get statistics
./scripts/history.sh payment-api-2025-01-10 --stats
```

## Workflows

### Complete Feature Development Workflow

1. **Initialize Session**
   ```bash
   ./scripts/init-session.sh "new-feature-2025-01-10"
   ```

2. **Create Plan**
   ```bash
   ./scripts/plan.sh new-feature-2025-01-10 "Implement user notifications system"
   ```

3. **Review Plan**
   ```bash
   cat .ai-session/new-feature-2025-01-10/implementation-plan.yaml
   ```

4. **Implement Tasks** (following TDD)
   ```bash
   # For each task in the plan
   ./scripts/implement.sh new-feature-2025-01-10 --task T1.1
   ./scripts/implement.sh new-feature-2025-01-10 --task T1.2
   ```

5. **Review Code**
   ```bash
   ./scripts/review-code.sh new-feature-2025-01-10 src/notifications/*.js
   ```

6. **Verify Implementation**
   ```bash
   ./scripts/verify.sh new-feature-2025-01-10
   ```

7. **Review Architecture**
   ```bash
   ./scripts/review-architecture.sh new-feature-2025-01-10
   ```

### Multi-Model Workflow

```bash
# Start with Gemini for planning
./scripts/plan.sh feature-2025-01-10 "Complex distributed system"

# Escalate to Opus for complex architecture decisions
./scripts/escalate.sh opus --prompt "Need deep analysis of distributed consensus"

# Return to implementation with Sonnet
./scripts/implement.sh feature-2025-01-10 --task T2.1

# Escalate to Gemini for system-wide perspective
./scripts/escalate.sh gemini --prompt "Review overall system design"
```

## Best Practices

### 1. Always Start with a Plan
```bash
# Good: Create plan first
./scripts/plan.sh feature-2025-01-10 "Description"

# Bad: Jump to implementation
./scripts/implement.sh feature-2025-01-10  # No plan!
```

### 2. Follow Test-First Development
```bash
# Good: Let TDD guide implementation
./scripts/implement.sh feature-2025-01-10 --task T1.1

# Avoid: Skipping tests
./scripts/implement.sh feature-2025-01-10 --task T1.1 --no-tests
```

### 3. Use Appropriate Models
- **Gemini**: Planning, architecture review, system-wide analysis
- **Claude/Sonnet**: Implementation, quick tasks
- **Opus**: Complex code review, difficult problems

### 4. Maintain Clean Sessions
```bash
# Regularly clean up completed features
./scripts/cleanup-sessions.sh completed-feature-2025-01-01

# Check status before switching
./scripts/status.sh --all
```

### 5. Leverage Context in Escalations
```bash
# Include relevant context when escalating
./scripts/escalate.sh opus --prompt "Focus on the authentication security model"
```

## Troubleshooting

### Common Issues

#### 1. Command Hangs
- **Symptom**: Command doesn't complete
- **Solution**: Commands have built-in timeouts. If hanging persists, check system resources

#### 2. Empty Plan Generation
- **Symptom**: Plan file exists but has no content
- **Solution**: Retry with explicit model selection or check API availability

#### 3. Session Not Found
- **Symptom**: "Session not found" error
- **Solution**: 
  ```bash
  # Check if session exists
  ls -la .ai-session/
  
  # Initialize if needed
  ./scripts/init-session.sh "feature-id"
  ```

#### 4. Model Unavailable
- **Symptom**: Model routing fails
- **Solution**: Orchestrator has automatic fallbacks. Check logs for details

### Debug Mode

Enable debug output for any command:
```bash
DEBUG=true ./scripts/plan.sh feature-2025-01-10 "Description"
```

### Log Locations
- Session logs: `.ai-session/<feature-id>/history.jsonl`
- Command artifacts: `.ai-session/<feature-id>/artifacts/`
- State file: `.ai-session/<feature-id>/state.yaml`

## Advanced Usage

### Custom Model Routing
```bash
# Force specific model for planning
./scripts/plan.sh feature-2025-01-10 "Description" --model opus

# Use environment variable
FORCE_MODEL=gemini ./scripts/implement.sh feature-2025-01-10
```

### Batch Operations
```bash
# Review multiple files
find src -name "*.js" -exec ./scripts/review-code.sh feature-2025-01-10 {} +

# Verify all active sessions
for session in $(./scripts/list-sessions.sh --active); do
  ./scripts/verify.sh "$session"
done
```

### Integration with CI/CD
```bash
# In CI pipeline
./scripts/init-session.sh "ci-build-$(date +%Y%m%d%H%M%S)"
./scripts/verify.sh "ci-build-*" --all
./scripts/cleanup-sessions.sh "ci-build-*"
```

## Summary

The AI Orchestrator provides a comprehensive framework for AI-assisted development with:
- Enforced best practices (TDD/ATDD)
- Optimal model routing
- Session management
- Context preservation
- Complete audit trails

Use this guide to leverage the full power of multi-model AI development while maintaining code quality and development discipline.