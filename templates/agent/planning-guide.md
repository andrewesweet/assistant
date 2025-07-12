# AI Orchestrator Planning Guide

## Overview

The AI Orchestrator planning system enables structured, test-driven development through AI-powered planning and implementation commands. This guide covers best practices for creating effective implementation plans.

## Planning Philosophy

### Why Plan First?

1. **Clarity**: Clear understanding before coding
2. **Testability**: Design for testing from the start
3. **Collaboration**: Multiple agents can work from the same plan
4. **Traceability**: Full audit trail of decisions
5. **Quality**: Enforced ATDD/TDD practices

### Planning Principles

- **Break down complexity**: Divide features into phases and tasks
- **Test-first mindset**: Define test requirements upfront
- **Clear ownership**: Assign agents to specific tasks
- **Measurable outcomes**: Include acceptance criteria
- **Iterative approach**: Plans can evolve

## Using the Plan Command

### Basic Usage

```bash
./scripts/plan.sh <feature-id> "Description of what to build"
```

### Advanced Options

```bash
# Full codebase context
./scripts/plan.sh <feature-id> --full-context "Refactor entire system"

# Explicit model selection
./scripts/plan.sh <feature-id> --model opus "Complex architecture"

# With retry for reliability
./scripts/plan.sh <feature-id> --retry "Critical feature planning"
```

## Plan Structure

### Phases

Phases represent major stages of implementation:

```yaml
phases:
  - phase_id: "phase-1"
    name: "Foundation"
    description: "Set up core infrastructure"
    
  - phase_id: "phase-2"
    name: "Features"
    description: "Implement user-facing features"
    
  - phase_id: "phase-3"
    name: "Polish"
    description: "Optimization and refinement"
```

### Tasks

Tasks are specific, actionable items:

```yaml
tasks:
  - task_id: "auth-service"
    description: "Implement authentication service"
    phase_id: "phase-1"
    agent: "agent-1"
    status: "pending"
    test_requirements:
      - "Unit tests for token generation"
      - "Integration tests for login flow"
      - "Security tests for vulnerabilities"
    acceptance_criteria:
      - "Users can register with email"
      - "Passwords are securely hashed"
      - "Sessions expire after timeout"
```

### Test Requirements

Every task must define test requirements:

1. **Unit Tests**: Isolated component testing
2. **Integration Tests**: Component interaction
3. **Acceptance Tests**: User-facing behavior
4. **Performance Tests**: Speed and scalability
5. **Security Tests**: Vulnerability checks

## Effective Planning Strategies

### 1. Start with User Stories

Transform user stories into phases and tasks:

```
User Story: "As a user, I want to reset my password"

Breaks down to:
- Task: "password-reset-api" - Backend API endpoint
- Task: "password-reset-ui" - Frontend form
- Task: "password-reset-email" - Email service integration
```

### 2. Define Clear Boundaries

Each task should be:
- **Independent**: Can be implemented separately
- **Testable**: Clear success criteria
- **Sized appropriately**: 2-8 hours of work
- **Single responsibility**: One main purpose

### 3. Consider Dependencies

Order tasks logically:

```yaml
tasks:
  - task_id: "database-schema"
    description: "Create user tables"
    dependencies: []
    
  - task_id: "user-model"
    description: "Implement user model"
    dependencies: ["database-schema"]
    
  - task_id: "user-api"
    description: "Create user REST API"
    dependencies: ["user-model"]
```

### 4. Plan for Testing

Include specific test scenarios:

```yaml
test_scenarios:
  - scenario: "Valid user registration"
    given: "New user with valid email"
    when: "They submit registration form"
    then: "Account is created and welcome email sent"
    
  - scenario: "Duplicate email registration"
    given: "Email already exists in system"
    when: "User tries to register"
    then: "Error message displayed"
```

## Model Selection Strategy

### When to Use Gemini (Default)

- Complex architectural planning
- Full codebase analysis needed
- Breaking down large features
- Discovering hidden dependencies
- Long-term roadmap planning

### When to Use Opus (Fallback/Explicit)

- Gemini is unavailable
- Need different perspective
- Complex business logic planning
- Specific domain expertise needed

## Integration with Implementation

### From Plan to Code

1. **Create Plan**: Define what to build
2. **Select Task**: Choose specific task ID
3. **Implement**: Execute with ATDD enforcement
4. **Verify**: Ensure tests pass
5. **Review**: Check implementation quality

### Example Workflow

```bash
# 1. Initialize session
./scripts/init-session.sh auth-feature "User authentication system"

# 2. Create plan
./scripts/plan.sh auth-feature "Build secure login with 2FA"

# 3. Review generated plan
cat .ai-session/auth-feature/implementation-plan.yaml

# 4. Implement first task
./scripts/implement.sh auth-feature --task user-model

# 5. Continue with dependent tasks
./scripts/implement.sh auth-feature --task login-api
```

## Best Practices

### DO:
- ✅ Break features into testable chunks
- ✅ Define clear acceptance criteria
- ✅ Include error scenarios in tests
- ✅ Consider security from the start
- ✅ Plan for observability

### DON'T:
- ❌ Create overly complex tasks
- ❌ Skip test requirements
- ❌ Ignore dependencies
- ❌ Plan everything upfront
- ❌ Forget about deployment

## Troubleshooting

### Common Issues

1. **Plan too vague**
   - Solution: Add more specific requirements
   - Include concrete examples

2. **Tasks too large**
   - Solution: Break into subtasks
   - Aim for 2-8 hour chunks

3. **Missing test cases**
   - Solution: Think about edge cases
   - Include negative scenarios

4. **Circular dependencies**
   - Solution: Restructure task order
   - Extract shared components

## Advanced Planning Patterns

### 1. Spike-First Planning

For uncertain areas:
```yaml
phases:
  - phase_id: "spike"
    name: "Technical Investigation"
    tasks:
      - task_id: "spike-performance"
        description: "Investigate caching strategies"
        type: "spike"
        timeboxed: "4 hours"
```

### 2. Progressive Enhancement

Build incrementally:
```yaml
phases:
  - phase_id: "mvp"
    name: "Minimum Viable Product"
  - phase_id: "enhanced"
    name: "Enhanced Features"
  - phase_id: "optimized"
    name: "Performance Optimization"
```

### 3. Risk-First Planning

Address high-risk items early:
```yaml
tasks:
  - task_id: "auth-security"
    description: "Implement secure authentication"
    risk_level: "high"
    priority: 1
```

## Metrics and Tracking

Plans automatically track:
- Task completion rates
- Time estimates vs actual
- Test coverage achieved
- Model usage patterns
- Agent performance

## Conclusion

Effective planning is the foundation of successful AI-assisted development. By following these guidelines, you can create plans that lead to high-quality, well-tested implementations.