# AI Orchestrator Binding Contracts

## Overview

This document serves as the central registry for all binding contracts in the AI Orchestrator system. These contracts define critical interfaces and behaviors that all agents must adhere to.

## Active Contracts

### 1. Session State Specification

**Location**: `docs/session-state-spec.md`  
**Version**: 1.0  
**Status**: BINDING  
**Purpose**: Defines the structure and management of session state for all orchestrator operations

**Key Requirements**:
- All session data must be stored in `.ai-session/{feature-id}/`
- State updates must be atomic
- History logs use JSON lines format
- Valid models: `gemini`, `opus`, `sonnet`

**Verification**:
```bash
# Verify contract acknowledgment
./scripts/verify-contract-acknowledgment.sh verify

# Create acknowledgment for new agent
./scripts/verify-contract-acknowledgment.sh create "agent-name"

# Show contract summary
./scripts/verify-contract-acknowledgment.sh summary
```

## Contract Management Process

### Adding New Contracts

1. Create contract document in `docs/` with clear version and status
2. Add entry to this CONTRACTS.md file
3. Create verification mechanism if applicable
4. Require acknowledgment from all affected agents

### Modifying Contracts

1. **Non-breaking changes**: Update version (e.g., 1.0 → 1.1)
2. **Breaking changes**: Major version bump (e.g., 1.0 → 2.0)
3. All changes require:
   - Human review and approval
   - Migration plan for breaking changes
   - Re-acknowledgment from all agents

### Contract Acknowledgment

All agents working with binding contracts must:

1. Read and understand the contract
2. Create acknowledgment file using verification script
3. Adhere to all contract requirements
4. Re-acknowledge when contracts change

## Compliance Monitoring

### Automated Checks

- Pre-commit hooks verify contract compliance
- CI/CD pipelines validate session state format
- Periodic audits ensure ongoing compliance

### Manual Review

- Code reviews must verify contract adherence
- Architecture reviews check for contract violations
- Regular audits of session state integrity

## Contract Violations

### Severity Levels

1. **Critical**: Corrupts session state or breaks system
2. **Major**: Violates contract but system continues
3. **Minor**: Deviates from best practices

### Response Process

1. **Detection**: Automated or manual discovery
2. **Assessment**: Determine severity and impact
3. **Remediation**: Fix violation and prevent recurrence
4. **Documentation**: Record violation and resolution

## Historical Contracts

(None yet - all contracts currently active)

## References

- Session State Specification: `docs/session-state-spec.md`
- Verification Script: `scripts/verify-contract-acknowledgment.sh`
- Test Suite: `test/test_contract_acknowledgment.sh`

---

**Note**: This document is part of the AI Orchestrator's governance framework. All changes require approval from the project maintainer.