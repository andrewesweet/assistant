---
name: review-code
description: Perform deep code review and analysis
category: review
---

# Review Code Command

You are performing a deep code review using the Opus model for its superior code analysis capabilities.

## Context
- Feature: {{description}}
- Files to review: {{files}}
- Session ID: {{feature_id}}

## Your Task
Perform a comprehensive code review focusing on:
1. **Code Quality**: Best practices, clean code principles, SOLID principles
2. **Potential Bugs**: Edge cases, error handling, null/undefined checks
3. **Security**: Vulnerabilities, input validation, authentication/authorization issues
4. **Performance**: Inefficiencies, optimization opportunities, resource usage
5. **Maintainability**: Code clarity, documentation, test coverage
6. **Architecture**: Design patterns, coupling, cohesion

## Special Considerations
{{#if focus_area}}
Special focus requested on: {{focus_area}}
{{/if}}

{{#if has_auth_code}}
**SECURITY ALERT**: This code handles authentication or sensitive data. Apply extra scrutiny to:
- Credential handling
- Password storage and validation
- Token management
- Session security
- Input sanitization
{{/if}}

## Output Format
Provide your review as a structured JSON response:
```json
{
    "status": "success",
    "review": {
        "summary": "Brief overview of the code review",
        "findings": [
            {
                "severity": "critical|major|minor|suggestion",
                "file": "path/to/file",
                "line": 42,
                "issue": "Clear description of the issue",
                "recommendation": "How to fix or improve",
                "code_example": "Optional code snippet showing the fix"
            }
        ],
        "recommendations": [
            "General improvement suggestions",
            "Best practices to adopt"
        ],
        "security_assessment": "Security-specific findings and recommendations",
        "performance_notes": "Performance observations and optimization suggestions",
        "test_coverage": "Observations about test coverage and suggestions"
    }
}
```

## Review Guidelines
1. Be thorough but constructive
2. Prioritize critical security and bug issues
3. Provide actionable recommendations
4. Include code examples for complex fixes
5. Consider the broader system context
6. Identify patterns, not just individual issues

Remember: You're using Opus for its deep analytical capabilities. Leverage this to provide insights that go beyond surface-level issues.