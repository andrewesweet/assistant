#!/bin/bash
# Escalation command - Escalate from current AI to another AI

set -euo pipefail

# Script information
SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SESSION_ROOT="${SESSION_ROOT:-.ai-session}"

# Usage function
usage() {
    echo "Usage: $SCRIPT_NAME <target-ai> [options]"
    echo ""
    echo "Escalate from current AI to another AI with context preservation"
    echo ""
    echo "Target AI:"
    echo "  claude     Escalate to Claude"
    echo "  gemini     Escalate to Gemini"
    echo "  opus       Escalate to Claude Opus"
    echo ""
    echo "Options:"
    echo "  --prompt TEXT    Additional prompt to include"
    echo "  --context BOOL   Include session context (default: true)"
    echo "  --feature ID     Feature/session ID (default: current)"
    echo "  -h, --help       Show this help message"
    exit 0
}

# Default values
target_ai=""
additional_prompt=""
include_context=true
feature_id=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            ;;
        --prompt)
            additional_prompt="$2"
            shift 2
            ;;
        --context)
            include_context="$2"
            shift 2
            ;;
        --feature)
            feature_id="$2"
            shift 2
            ;;
        claude|gemini|opus)
            target_ai="$1"
            shift
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            ;;
    esac
done

# Validate target AI
if [[ -z "$target_ai" ]]; then
    echo "Error: Target AI required" >&2
    usage
fi

# Find active feature if not specified
if [[ -z "$feature_id" ]]; then
    if [[ -f "$SESSION_ROOT/active-features.yaml" ]]; then
        # Get the most recent active feature
        feature_id=$(grep "^  - " "$SESSION_ROOT/active-features.yaml" | tail -1 | sed 's/^  - //')
    fi
    
    if [[ -z "$feature_id" ]]; then
        echo "Error: No active feature found. Specify with --feature" >&2
        exit 1
    fi
fi

# Verify session exists
session_dir="$SESSION_ROOT/$feature_id"
if [[ ! -d "$session_dir" ]]; then
    echo "Error: Session not found: $feature_id" >&2
    exit 1
fi

# Build escalation prompt
echo "Escalating to $target_ai..."

escalation_prompt="I need to escalate this conversation to $target_ai."

# Add context if requested
if [[ "$include_context" == "true" ]]; then
    echo "Gathering session context..."
    
    # Add session info
    if [[ -f "$session_dir/state.yaml" ]]; then
        escalation_prompt="$escalation_prompt

Current Session: $feature_id"
        
        # Get active task if any
        active_task=$(grep "active_task:" "$session_dir/state.yaml" | sed 's/.*active_task: *//' | tr -d '"')
        if [[ -n "$active_task" && "$active_task" != "null" ]]; then
            escalation_prompt="$escalation_prompt
Active Task: $active_task"
        fi
    fi
    
    # Add recent history
    if [[ -f "$session_dir/history.jsonl" ]]; then
        recent_commands=$(tail -5 "$session_dir/history.jsonl" | jq -r '.command + " " + .arguments' 2>/dev/null | sed 's/^/  - /')
        if [[ -n "$recent_commands" ]]; then
            escalation_prompt="$escalation_prompt

Recent Commands:
$recent_commands"
        fi
    fi
    
    # Add implementation plan summary if exists
    if [[ -f "$session_dir/implementation-plan.yaml" ]]; then
        escalation_prompt="$escalation_prompt

Note: Implementation plan exists for this session."
    fi
fi

# Add additional prompt if provided
if [[ -n "$additional_prompt" ]]; then
    escalation_prompt="$escalation_prompt

Additional Context: $additional_prompt"
fi

# Execute escalation based on target
case $target_ai in
    claude)
        echo "Launching Claude with context..."
        claude -p "$escalation_prompt"
        ;;
    gemini)
        echo "Launching Gemini with context..."
        gemini -p "$escalation_prompt"
        ;;
    opus)
        echo "Launching Claude Opus with context..."
        claude --model opus -p "$escalation_prompt"
        ;;
    *)
        echo "Error: Unknown target AI: $target_ai" >&2
        exit 1
        ;;
esac

echo "Escalation complete."