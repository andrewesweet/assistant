#!/bin/bash
# Cleanup sessions based on criteria

set -euo pipefail

SESSION_ROOT="${SESSION_ROOT:-.ai-session}"

# Default values
cleanup_completed=false
cleanup_stale=false
cleanup_empty=false
dry_run=false
archive=false
preserve_artifacts=false
pattern=""
force=false
days=7

# Parse options
while [[ $# -gt 0 ]]; do
    case $1 in
        --completed)
            cleanup_completed=true
            shift
            ;;
        --stale)
            cleanup_stale=true
            shift
            ;;
        --empty)
            cleanup_empty=true
            shift
            ;;
        --dry-run)
            dry_run=true
            shift
            ;;
        --archive)
            archive=true
            shift
            ;;
        --preserve-artifacts)
            preserve_artifacts=true
            shift
            ;;
        --pattern)
            pattern="$2"
            shift 2
            ;;
        --force)
            force=true
            shift
            ;;
        --days)
            days="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

# Function to check if session is completed
is_completed() {
    local session_dir="$1"
    if [[ -f "$session_dir/state.yaml" ]]; then
        grep -q 'status: "completed"' "$session_dir/state.yaml" 2>/dev/null || \
        grep -q 'status: "failed"' "$session_dir/state.yaml" 2>/dev/null
    else
        return 1
    fi
}

# Function to check if session is stale
is_stale() {
    local session_dir="$1"
    local days_limit="$2"
    
    if [[ -f "$session_dir/state.yaml" ]]; then
        # This is a simplified check - would need proper date parsing in real implementation
        return 1
    else
        return 1
    fi
}

# Function to check if session is empty
is_empty() {
    local session_dir="$1"
    
    # Check if artifacts directory is empty
    if [[ -d "$session_dir/artifacts" ]]; then
        if find "$session_dir/artifacts" -type f | head -1 | grep -q .; then
            return 1  # Not empty
        fi
    fi
    
    # Check if history is empty or minimal
    if [[ -f "$session_dir/history.jsonl" ]]; then
        if [[ $(wc -l < "$session_dir/history.jsonl") -gt 0 ]]; then
            return 1  # Has history
        fi
    fi
    
    return 0  # Is empty
}

# Function to remove session from active features
remove_from_active() {
    local feature_id="$1"
    local active_file="$SESSION_ROOT/active-features.yaml"
    
    if [[ -f "$active_file" ]]; then
        # Simple removal - would need proper YAML handling in real implementation
        grep -v "feature_id: \"$feature_id\"" "$active_file" > "$active_file.tmp" || true
        mv "$active_file.tmp" "$active_file"
    fi
}

# Main cleanup logic
if [[ -d "$SESSION_ROOT" ]]; then
    for session_dir in "$SESSION_ROOT"/*; do
        if [[ -d "$session_dir" && "$session_dir" != "$SESSION_ROOT/active-features.yaml" ]]; then
            session_name=$(basename "$session_dir")
            should_remove=false
            
            # Check if should remove based on criteria
            if [[ "$cleanup_completed" == "true" ]] && is_completed "$session_dir"; then
                should_remove=true
            fi
            
            if [[ "$cleanup_stale" == "true" ]] && is_stale "$session_dir" "$days"; then
                should_remove=true
            fi
            
            if [[ "$cleanup_empty" == "true" ]] && is_empty "$session_dir"; then
                should_remove=true
            fi
            
            if [[ -n "$pattern" ]] && [[ "$session_name" == $pattern ]]; then
                should_remove=true
            fi
            
            # Process removal
            if [[ "$should_remove" == "true" ]]; then
                if [[ "$dry_run" == "true" ]]; then
                    echo "Would remove: $session_name"
                else
                    # Archive if requested
                    if [[ "$archive" == "true" ]]; then
                        mkdir -p "$SESSION_ROOT-archive"
                        mv "$session_dir" "$SESSION_ROOT-archive/"
                    elif [[ "$preserve_artifacts" == "true" ]]; then
                        # Remove everything except artifacts
                        find "$session_dir" -type f -not -path "*/artifacts/*" -delete 2>/dev/null || true
                        find "$session_dir" -type d -empty -delete 2>/dev/null || true
                    else
                        # Full removal
                        rm -rf "$session_dir"
                    fi
                    
                    # Update active features
                    remove_from_active "$session_name"
                fi
            fi
        fi
    done
fi