#!/bin/bash
# Log command execution to session history

set -euo pipefail

SESSION_ROOT="${SESSION_ROOT:-.ai-session}"

# Get arguments
feature_id="$1"
shift

# Default values
command=""
model="sonnet"
status="success"

# Parse options
while [[ $# -gt 0 ]]; do
    case $1 in
        --command)
            command="$2"
            shift 2
            ;;
        --model)
            model="$2"
            shift 2
            ;;
        --status)
            status="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

# Create log entry
history_file="$SESSION_ROOT/$feature_id/history.jsonl"
timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Append to history
echo "{\"timestamp\": \"$timestamp\", \"command\": \"$command\", \"model\": \"$model\", \"status\": \"$status\"}" >> "$history_file"