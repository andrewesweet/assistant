---
name: review-architecture
description: Perform comprehensive system architecture review
category: review
---

# Review Architecture Command

You are performing a comprehensive architecture review. Gemini is preferred for this task due to its superior ability to analyze large codebases and understand system-wide patterns.

## Context
- Feature: {{description}}
- Session ID: {{feature_id}}
{{#if full_context}}
- Full codebase context enabled (-a flag)
{{/if}}

## Your Task
{{#if compare_mode}}
### Architecture Comparison
Compare the architectures in:
- Current: {{compare_current}}
- Proposed: {{compare_proposed}}

Focus on:
1. Key architectural differences
2. Migration path and challenges
3. Risk assessment
4. Transition recommendations
5. Compatibility considerations
{{else}}
### Architecture Review
Analyze the system architecture focusing on:
{{#if focus_area}}
{{#if (eq focus_area "security")}}
1. **Security Architecture**
   - Threat modeling and attack surfaces
   - Authentication and authorization design
   - Data protection and encryption strategies
   - Network security and isolation
   - Compliance and security best practices
{{/if}}
{{#if (eq focus_area "performance")}}
1. **Performance Architecture**
   - Bottlenecks and optimization opportunities
   - Caching strategies and implementations
   - Database design and query optimization
   - Resource utilization patterns
   - Scalability under load
{{/if}}
{{#if (eq focus_area "scalability")}}
1. **Scalability Architecture**
   - Horizontal vs vertical scaling capabilities
   - Load balancing and distribution strategies
   - State management and clustering
   - Database scaling patterns
   - Microservices readiness
{{/if}}
{{else}}
1. **Overall Architecture Quality**
   - Design patterns and best practices
   - Component coupling and cohesion
   - Technology choices and trade-offs
   - Scalability and performance readiness
   - Security architecture
   - Maintainability and evolvability
{{/if}}
{{/if}}

## Architecture Discovery
{{#if architecture_files}}
Found architecture documentation in:
{{#each architecture_files}}
- {{this}}
{{/each}}
{{else}}
No explicit architecture documentation found. Analyze the codebase structure to infer:
- Directory organization
- Component boundaries
- Technology stack
- Integration patterns
- Deployment architecture
{{/if}}

## Output Format
Provide your review as a structured JSON response:
```json
{
    "status": "success",
    "review": {
        "summary": "High-level architecture overview",
        "architecture_type": "monolithic|microservices|serverless|hybrid|other",
        "components_identified": 5,
        "patterns_found": ["Repository Pattern", "CQRS", "Event Sourcing"],
        "technology_stack": ["Go", "PostgreSQL", "Redis", "Docker"],
        "strengths": [
            "Clear separation of concerns",
            "Scalable design",
            "Good use of caching"
        ],
        "weaknesses": [
            "Missing monitoring strategy",
            "No disaster recovery plan",
            "Tight coupling in service layer"
        ],
        "recommendations": [
            "Implement observability layer",
            "Document failure scenarios",
            "Consider service mesh for microservices"
        ],
        "diagram": "graph TD\n    A[Client] --> B[API Gateway]\n    B --> C[Service Layer]\n    C --> D[Data Layer]"
    }
}
```

## Review Guidelines
1. **Holistic View**: Consider the entire system, not just individual components
2. **Trade-offs**: Acknowledge architectural trade-offs and their implications
3. **Evolution**: Consider how the architecture can evolve with changing requirements
4. **Best Practices**: Compare against industry standards and patterns
5. **Actionable**: Provide specific, implementable recommendations
6. **Visual**: Include architecture diagrams where helpful (Mermaid format)

{{#if using_gemini}}
You're using Gemini with its large context window. Take advantage of this to:
- Analyze the entire codebase structure
- Identify cross-cutting concerns
- Detect architectural drift
- Find inconsistencies across components
{{else}}
Fallback to Opus: Focus on the provided architecture files and high-level analysis.
{{/if}}