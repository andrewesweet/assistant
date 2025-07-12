#!/bin/bash
# Initialize a new AI orchestrator session

set -euo pipefail

# Configuration
SESSION_ROOT="${SESSION_ROOT:-.ai-session}"
DATE_FORMAT="+%Y-%m-%dT%H:%M:%SZ"

# Function to validate feature ID format
validate_feature_id() {
    local feature_id="$1"
    
    # Check if empty
    if [[ -z "$feature_id" ]]; then
        echo "Error: Invalid feature ID - cannot be empty"
        return 1
    fi
    
    # Check format: lowercase letters, numbers, and hyphens only
    if ! [[ "$feature_id" =~ ^[a-z0-9-]+$ ]]; then
        echo "Error: Invalid feature ID format: $feature_id"
        echo "  Feature ID must contain only lowercase letters, numbers, and hyphens"
        return 1
    fi
    
    # Check doesn't start or end with hyphen
    if [[ "$feature_id" =~ ^- ]] || [[ "$feature_id" =~ -$ ]]; then
        echo "Error: Invalid feature ID - cannot start or end with hyphen"
        return 1
    fi
    
    return 0
}

# Function to create session directory structure
create_session_structure() {
    local feature_id="$1"
    local session_dir="$SESSION_ROOT/$feature_id"
    
    # Check if session already exists
    if [[ -d "$session_dir" ]]; then
        echo "Error: Session already exists: $feature_id" >&2
        return 1
    fi
    
    # Create directories
    mkdir -p "$session_dir/artifacts"
    
    # Create initial state.yaml
    cat > "$session_dir/state.yaml" <<EOF
version: "1.0"
feature_id: "$feature_id"
current_state:
  active_task: null
  model_in_use: "sonnet"
  started_at: "$(date -u "$DATE_FORMAT")"
  last_updated: "$(date -u "$DATE_FORMAT")"
EOF
    
    # Create empty history log
    touch "$session_dir/history.jsonl"
    
    # Create initial implementation plan
    local description="${2:-AI Orchestrator Feature}"
    cat > "$session_dir/implementation-plan.yaml" <<EOF
feature:
  id: "$feature_id"
  name: "$description"
  description: "$description"
  created_at: "$(date -u "$DATE_FORMAT")"
  
phases: []
EOF
    
    return 0
}

# Function to add session to active features
add_to_active_features() {
    local feature_id="$1"
    local active_file="$SESSION_ROOT/active-features.yaml"
    
    # Create active features file if doesn't exist
    if [[ ! -f "$active_file" ]]; then
        cat > "$active_file" <<EOF
active_features: []
EOF
    fi
    
    # Add new feature (append to YAML array)
    # Using a temporary file for atomic update
    local temp_file=$(mktemp)
    
    # Read existing content and add new feature
    if [[ -f "$active_file" ]]; then
        awk -v feature="$feature_id" -v date="$(date -u "$DATE_FORMAT")" '
        /^active_features:/ {
            print $0
            print "  - feature_id: \"" feature "\""
            print "    started_at: \"" date "\""
            print "    last_active: \"" date "\""
            print "    status: \"active\""
            next
        }
        { print }
        ' "$active_file" > "$temp_file"
    fi
    
    # Atomic move
    mv "$temp_file" "$active_file"
    
    return 0
}

# Function to create session README if needed
create_session_readme() {
    local readme="$SESSION_ROOT/README.md"
    
    if [[ ! -f "$readme" ]]; then
        cat > "$readme" <<'EOF'
# AI Orchestrator Session Directory

This directory contains active and historical AI orchestrator sessions.

## Structure

```
.ai-session/
├── active-features.yaml     # List of all active features
├── {feature-id}/           # Per-feature session directory
│   ├── state.yaml          # Current session state
│   ├── implementation-plan.yaml  # Feature implementation plan
│   ├── history.jsonl       # Command execution history
│   └── artifacts/          # Generated artifacts
└── README.md              # This file
```

## Session Management

- Initialize new session: `scripts/init-session.sh <feature-id>`
- List active sessions: `scripts/list-sessions.sh`
- Update session state: `scripts/update-session-state.sh <feature-id> [options]`
- Clean up old sessions: `scripts/cleanup-sessions.sh`

## Data Formats

See `docs/session-state-spec.md` for detailed specifications.
EOF
    fi
}

# Main execution
main() {
    # Parse arguments
    if [[ $# -lt 1 ]]; then
        echo "Usage: $0 <feature-id> [description]"
        echo "Example: $0 ai-orchestrator-2025-01-09 \"AI Orchestrator Core\""
        exit 1
    fi
    
    local feature_id="$1"
    local description="${2:-}"
    
    # Validate feature ID
    if ! validate_feature_id "$feature_id"; then
        exit 1
    fi
    
    # Create session root if needed
    mkdir -p "$SESSION_ROOT"
    
    # Create session structure
    echo "Initializing session: $feature_id"
    if ! create_session_structure "$feature_id" "$description"; then
        exit 1
    fi
    
    # Add to active features
    if ! add_to_active_features "$feature_id"; then
        echo "Warning: Failed to add to active features list"
    fi
    
    # Create README if needed
    create_session_readme
    
    echo "Session initialized successfully:"
    echo "  Directory: $SESSION_ROOT/$feature_id"
    echo "  Status: active"
    
    return 0
}

# Run main
main "$@"