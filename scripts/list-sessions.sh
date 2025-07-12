#!/bin/bash
# List active sessions

set -euo pipefail

SESSION_ROOT="${SESSION_ROOT:-.ai-session}"

# Parse options
show_active=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --active)
            show_active=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# List sessions
if [[ -d "$SESSION_ROOT" ]]; then
    for session_dir in "$SESSION_ROOT"/*; do
        if [[ -d "$session_dir" && -f "$session_dir/state.yaml" ]]; then
            basename "$session_dir"
        fi
    done
fi