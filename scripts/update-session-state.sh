#!/bin/bash
# Update session state with atomic file operations

set -euo pipefail

# Configuration
SESSION_ROOT="${SESSION_ROOT:-.ai-session}"
DATE_FORMAT="+%Y-%m-%dT%H:%M:%SZ"
LOCK_TIMEOUT=5

# Safe mktemp function
safe_mktemp() {
    if command -v mktemp >/dev/null 2>&1; then
        mktemp "$@"
    else
        local temp="/tmp/tmp.$$.$RANDOM"
        touch "$temp"
        echo "$temp"
    fi
}

# Portable sed replacement
safe_sed() {
    local pattern="$1"
    local file="$2"
    local temp_file=$(safe_mktemp)
    
    sed "$pattern" "$file" > "$temp_file"
    mv "$temp_file" "$file"
}

# Function to acquire lock with timeout
acquire_lock() {
    local lockfile="$1"
    local timeout="$2"
    local elapsed=0
    
    while ! (set -C; echo $$ > "$lockfile") 2>/dev/null; do
        if [[ $elapsed -ge $timeout ]]; then
            echo "Error: Failed to acquire lock after ${timeout}s"
            return 1
        fi
        sleep 0.1
        ((elapsed++))
    done
    
    return 0
}

# Function to release lock
release_lock() {
    local lockfile="$1"
    rm -f "$lockfile"
}

# Function to update state file
update_state() {
    local session_dir="$1"
    local updates=("${@:2}")
    local state_file="$session_dir/state.yaml"
    local lockfile="$session_dir/.state.lock"
    local temp_file=$(safe_mktemp)
    
    # Acquire lock
    if ! acquire_lock "$lockfile" "$LOCK_TIMEOUT"; then
        rm -f "$temp_file"
        return 1
    fi
    
    # Ensure cleanup on exit
    trap "release_lock '$lockfile'; rm -f '$temp_file'" EXIT
    
    # Read current state
    if [[ ! -f "$state_file" ]]; then
        echo "Error: State file not found: $state_file"
        return 1
    fi
    
    cp "$state_file" "$temp_file"
    
    # Apply updates
    for update in "${updates[@]}"; do
        case "$update" in
            --task=*)
                local task="${update#--task=}"
                safe_sed "s/^  active_task:.*/  active_task: \"$task\"/" "$temp_file"
                ;;
            --model=*)
                local model="${update#--model=}"
                safe_sed "s/^  model_in_use:.*/  model_in_use: \"$model\"/" "$temp_file"
                ;;
            --status=*)
                local status="${update#--status=}"
                # Add status field if not exists
                if ! grep -q "status:" "$temp_file"; then
                    # Create temp file for complex sed
                    local temp2=$(safe_mktemp)
                    awk -v status="$status" '
                        /feature_id:/ { print; print "  status: \"" status "\""; next }
                        { print }
                    ' "$temp_file" > "$temp2"
                    mv "$temp2" "$temp_file"
                else
                    safe_sed "s/status:.*/status: \"$status\"/" "$temp_file"
                fi
                ;;
            --sleep=*)
                # For testing lock contention
                local sleep_time="${update#--sleep=}"
                sleep "$sleep_time"
                ;;
        esac
    done
    
    # Update last_updated timestamp
    safe_sed "s/^  last_updated:.*/  last_updated: \"$(date -u "$DATE_FORMAT")\"/" "$temp_file"
    
    # Atomic replace
    mv "$temp_file" "$state_file"
    
    # Cleanup
    release_lock "$lockfile"
    trap - EXIT
    
    return 0
}

# Function to update active features
update_active_features() {
    local feature_id="$1"
    local active_file="$SESSION_ROOT/active-features.yaml"
    local temp_file=$(safe_mktemp)
    
    if [[ ! -f "$active_file" ]]; then
        echo "Warning: Active features file not found"
        return 1
    fi
    
    # Update last_active timestamp
    awk -v feature="$feature_id" -v date="$(date -u "$DATE_FORMAT")" '
    /feature_id: "'"$feature_id"'"/ {
        found=1
    }
    found && /last_active:/ {
        sub(/last_active:.*/, "last_active: \"" date "\"")
        found=0
    }
    { print }
    ' "$active_file" > "$temp_file"
    
    mv "$temp_file" "$active_file"
    return 0
}

# Main execution
main() {
    if [[ $# -lt 1 ]]; then
        echo "Usage: $0 <feature-id> [options]"
        echo "Options:"
        echo "  --task=<task-id>     Update active task"
        echo "  --model=<model>      Update model in use (gemini|opus|sonnet)"
        echo "  --status=<status>    Update session status"
        echo "Example: $0 ai-orchestrator-2025-01-09 --task=implement-core --model=gemini"
        exit 1
    fi
    
    local feature_id="$1"
    shift
    local session_dir="$SESSION_ROOT/$feature_id"
    
    # Check session exists
    if [[ ! -d "$session_dir" ]]; then
        echo "Error: Session not found: $feature_id"
        exit 1
    fi
    
    # Update state
    if update_state "$session_dir" "$@"; then
        echo "Session state updated: $feature_id"
        
        # Update active features timestamp
        update_active_features "$feature_id"
    else
        echo "Error: Failed to update session state"
        exit 1
    fi
}

# Run main
main "$@"