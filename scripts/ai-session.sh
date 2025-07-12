#!/bin/bash
# AI Session Management Tool
# Provides utilities for managing Claude AI sessions

set -euo pipefail

# Configuration
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
SESSION_DIR="${SESSION_DIR:-$HOME/.ai-sessions}"
DEFAULT_OLDER_THAN_DAYS=30

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Usage function
usage() {
    echo "AI Session Management Tool"
    echo
    echo "Usage: $0 <command> [options]"
    echo
    echo "Commands:"
    echo "  list [--active] [--sort <field>]"
    echo "      List all sessions or only active ones (last 30 days)"
    echo "      Sort by: name, date, tokens, cost (default: date)"
    echo
    echo "  show <session-name>"
    echo "      Show detailed information about a specific session"
    echo
    echo "  clean --older-than <days> [--dry-run] [--force]"
    echo "      Remove sessions older than specified days"
    echo "      --dry-run: Show what would be removed without deleting"
    echo "      --force: Skip confirmation prompt"
    echo
    echo "  stats [--session <name>]"
    echo "      Show usage statistics for all sessions or a specific one"
    echo
    echo "  export [--output <file>] [--active]"
    echo "      Export session data to JSON file"
    echo
    echo "  help"
    echo "      Show this help message"
    echo
    echo "Environment Variables:"
    echo "  SESSION_DIR    Override session directory (default: ~/.ai-sessions)"
    echo
    echo "Examples:"
    echo "  $0 list --active"
    echo "  $0 show my-project"
    echo "  $0 clean --older-than 30 --dry-run"
    echo "  $0 stats --session my-project"
    echo "  $0 export --output sessions.json"
    exit "${1:-0}"
}

# Ensure session directory exists
ensure_session_dir() {
    if [[ ! -d "$SESSION_DIR" ]]; then
        mkdir -p "$SESSION_DIR"
        chmod 700 "$SESSION_DIR"
    fi
}

# Get session age in days
get_session_age_days() {
    local session_path="$1"
    local metadata_file="$session_path/metadata.json"
    
    if [[ ! -f "$metadata_file" ]]; then
        echo "999"  # Very old if no metadata
        return
    fi
    
    local last_used=""
    if command -v jq >/dev/null 2>&1; then
        last_used=$(jq -r '.last_used // .created_at // empty' "$metadata_file" 2>/dev/null || echo "")
    else
        # Fallback: grep for last_used or created_at
        last_used=$(grep -o '"last_used"[[:space:]]*:[[:space:]]*"[^"]*"' "$metadata_file" 2>/dev/null | cut -d'"' -f4 || echo "")
        if [[ -z "$last_used" ]]; then
            last_used=$(grep -o '"created_at"[[:space:]]*:[[:space:]]*"[^"]*"' "$metadata_file" 2>/dev/null | cut -d'"' -f4 || echo "")
        fi
    fi
    
    if [[ -z "$last_used" ]]; then
        echo "999"
        return
    fi
    
    # Convert to epoch and calculate days
    local last_used_epoch=$(date -d "$last_used" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$last_used" +%s 2>/dev/null || echo "0")
    local current_epoch=$(date +%s)
    
    if [[ "$last_used_epoch" -eq 0 ]]; then
        echo "999"
    else
        echo $(( (current_epoch - last_used_epoch) / 86400 ))
    fi
}

# Get session info
get_session_info() {
    local session_path="$1"
    local metadata_file="$session_path/metadata.json"
    
    if [[ ! -f "$metadata_file" ]]; then
        echo "No metadata"
        return
    fi
    
    if command -v jq >/dev/null 2>&1; then
        local session_id=$(jq -r '.session_id // "none"' "$metadata_file" 2>/dev/null || echo "none")
        local created_at=$(jq -r '.created_at // "unknown"' "$metadata_file" 2>/dev/null || echo "unknown")
        local last_used=$(jq -r '.last_used // .created_at // "unknown"' "$metadata_file" 2>/dev/null || echo "unknown")
        local total_input=0
        local total_output=0
        local total_cost=0
        
        # Sum up token usage from interactions
        if jq -e '.interactions' "$metadata_file" >/dev/null 2>&1; then
            total_input=$(jq '[.interactions[].tokens.input // 0] | add' "$metadata_file" 2>/dev/null || echo "0")
            total_output=$(jq '[.interactions[].tokens.output // 0] | add' "$metadata_file" 2>/dev/null || echo "0")
            total_cost=$(jq '[.interactions[].cost // 0] | add' "$metadata_file" 2>/dev/null || echo "0")
        fi
        
        echo "ID: $session_id | Created: $created_at | Last used: $last_used | Tokens: $total_input/$total_output | Cost: \$$total_cost"
    else
        # Fallback without jq
        echo "Metadata exists (install jq for details)"
    fi
}

# List sessions command
cmd_list() {
    ensure_session_dir
    
    local active_only=false
    local sort_field="date"
    
    # Parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --active)
                active_only=true
                shift
                ;;
            --sort)
                shift
                sort_field="${1:-date}"
                shift
                ;;
            *)
                echo "Unknown option: $1"
                usage 1
                ;;
        esac
    done
    
    echo -e "${BLUE}AI Sessions${NC}"
    echo "Directory: $SESSION_DIR"
    echo
    
    local count=0
    local active_count=0
    
    # Create temporary file for sorting
    local temp_list=$(mktemp)
    
    # Collect session data
    for session_dir in "$SESSION_DIR"/*; do
        if [[ ! -d "$session_dir" ]]; then
            continue
        fi
        
        local session_name=$(basename "$session_dir")
        local age_days=$(get_session_age_days "$session_dir")
        
        ((count++))
        
        if [[ "$age_days" -lt 30 ]]; then
            ((active_count++))
        fi
        
        if [[ "$active_only" == true ]] && [[ "$age_days" -ge 30 ]]; then
            continue
        fi
        
        local info=$(get_session_info "$session_dir")
        
        # Format for sorting
        echo "${age_days}|${session_name}|${info}" >> "$temp_list"
    done
    
    # Sort and display
    if [[ -s "$temp_list" ]]; then
        # Sort based on field
        case "$sort_field" in
            name)
                sort -t'|' -k2 "$temp_list"
                ;;
            date|*)
                sort -n -t'|' -k1 "$temp_list"
                ;;
        esac | while IFS='|' read -r age name info; do
            if [[ "$age" -lt 7 ]]; then
                echo -e "${GREEN}● ${name}${NC} (${age}d ago)"
            elif [[ "$age" -lt 30 ]]; then
                echo -e "${YELLOW}● ${name}${NC} (${age}d ago)"
            else
                echo -e "${RED}● ${name}${NC} (${age}d ago)"
            fi
            echo "  $info"
            echo
        done
    else
        echo "No sessions found."
    fi
    
    rm -f "$temp_list"
    
    echo
    echo "Total sessions: $count (Active: $active_count)"
}

# Show session command
cmd_show() {
    if [[ $# -lt 1 ]]; then
        echo -e "${RED}Error:${NC} Show command requires a session name"
        usage 1
    fi
    
    local session_name="$1"
    local session_path="$SESSION_DIR/$session_name"
    
    if [[ ! -d "$session_path" ]]; then
        echo -e "${RED}Error:${NC} Session not found: $session_name"
        exit 1
    fi
    
    local metadata_file="$session_path/metadata.json"
    
    if [[ ! -f "$metadata_file" ]]; then
        echo -e "${RED}Error:${NC} No metadata found for session: $session_name"
        exit 1
    fi
    
    echo -e "${BLUE}Session: $session_name${NC}"
    echo "Path: $session_path"
    echo
    
    if command -v jq >/dev/null 2>&1; then
        # Extract detailed information
        local session_id=$(jq -r '.session_id // "none"' "$metadata_file")
        local created_at=$(jq -r '.created_at // "unknown"' "$metadata_file")
        local last_used=$(jq -r '.last_used // "unknown"' "$metadata_file")
        local command=$(jq -r '.command // "unknown"' "$metadata_file")
        
        echo "ID: $session_id"
        echo "Command: $command"
        echo "Created: $created_at"
        echo "Last used: $last_used"
        echo
        
        # Token usage
        if jq -e '.interactions' "$metadata_file" >/dev/null 2>&1; then
            local total_input=$(jq '[.interactions[].tokens.input // 0] | add' "$metadata_file")
            local total_output=$(jq '[.interactions[].tokens.output // 0] | add' "$metadata_file")
            local interaction_count=$(jq '.interactions | length' "$metadata_file")
            
            echo "Interactions: $interaction_count"
            echo "Tokens:"
            echo "  Input: $total_input"
            echo "  Output: $total_output"
            echo "  Total: $((total_input + total_output))"
            
            # Cost calculation (example rates)
            local input_cost=$(echo "scale=4; $total_input * 0.003 / 1000" | bc 2>/dev/null || echo "0")
            local output_cost=$(echo "scale=4; $total_output * 0.015 / 1000" | bc 2>/dev/null || echo "0")
            local total_cost=$(echo "scale=4; $input_cost + $output_cost" | bc 2>/dev/null || echo "0")
            
            echo
            echo "Estimated Cost: \$$total_cost"
        fi
        
        # Show recent interactions
        echo
        echo "Recent Interactions:"
        jq -r '.interactions[-3:] | reverse | .[] | "  [\(.timestamp)] \(.model // "unknown") - \(.tokens.input // 0)/\(.tokens.output // 0) tokens"' "$metadata_file" 2>/dev/null || echo "  No interaction data"
        
    else
        # Fallback: show raw content
        echo "Raw metadata:"
        cat "$metadata_file"
    fi
}

# Clean sessions command
cmd_clean() {
    ensure_session_dir
    
    local older_than_days=""
    local dry_run=false
    local force=false
    
    # Parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --older-than)
                shift
                older_than_days="${1:-$DEFAULT_OLDER_THAN_DAYS}"
                shift
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            --force)
                force=true
                shift
                ;;
            *)
                echo "Unknown option: $1"
                usage 1
                ;;
        esac
    done
    
    if [[ -z "$older_than_days" ]]; then
        echo -e "${RED}Error:${NC} --older-than <days> is required"
        usage 1
    fi
    
    echo -e "${BLUE}Cleaning sessions older than $older_than_days days${NC}"
    if [[ "$dry_run" == true ]]; then
        echo "(DRY RUN - no changes will be made)"
    fi
    echo
    
    local to_remove=()
    local total_size=0
    
    # Find sessions to remove
    for session_dir in "$SESSION_DIR"/*; do
        if [[ ! -d "$session_dir" ]]; then
            continue
        fi
        
        local session_name=$(basename "$session_dir")
        local age_days=$(get_session_age_days "$session_dir")
        
        if [[ "$age_days" -ge "$older_than_days" ]]; then
            to_remove+=("$session_name")
            local size=$(du -sh "$session_dir" 2>/dev/null | cut -f1)
            echo "  - $session_name (${age_days}d old, $size)"
        fi
    done
    
    if [[ ${#to_remove[@]} -eq 0 ]]; then
        echo "No sessions to remove."
        return 0
    fi
    
    echo
    if [[ "$dry_run" == true ]]; then
        echo "Would remove: ${#to_remove[@]} sessions"
    else
        # Confirm unless forced
        if [[ "$force" != true ]]; then
            echo -n "Remove ${#to_remove[@]} sessions? [y/N] "
            read -r response
            if [[ ! "$response" =~ ^[Yy]$ ]]; then
                echo "Cancelled."
                return 0
            fi
        fi
        
        # Remove sessions
        echo "Removing sessions..."
        for session in "${to_remove[@]}"; do
            rm -rf "$SESSION_DIR/$session"
            echo -e "  ${GREEN}✓${NC} Removed: $session"
        done
        
        echo
        echo "Removed: ${#to_remove[@]} sessions"
    fi
}

# Stats command
cmd_stats() {
    ensure_session_dir
    
    local specific_session=""
    
    # Parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --session)
                shift
                specific_session="$1"
                shift
                ;;
            *)
                echo "Unknown option: $1"
                usage 1
                ;;
        esac
    done
    
    if [[ -n "$specific_session" ]]; then
        # Stats for specific session
        cmd_show "$specific_session"
        return
    fi
    
    # Overall stats
    echo -e "${BLUE}AI Session Statistics${NC}"
    echo
    
    local total_sessions=0
    local active_sessions=0
    local total_input_tokens=0
    local total_output_tokens=0
    local total_interactions=0
    local total_cost=0
    
    for session_dir in "$SESSION_DIR"/*; do
        if [[ ! -d "$session_dir" ]]; then
            continue
        fi
        
        ((total_sessions++))
        
        local age_days=$(get_session_age_days "$session_dir")
        if [[ "$age_days" -lt 30 ]]; then
            ((active_sessions++))
        fi
        
        local metadata_file="$session_dir/metadata.json"
        if [[ -f "$metadata_file" ]] && command -v jq >/dev/null 2>&1; then
            # Sum up tokens
            local input=$(jq '[.interactions[].tokens.input // 0] | add' "$metadata_file" 2>/dev/null || echo "0")
            local output=$(jq '[.interactions[].tokens.output // 0] | add' "$metadata_file" 2>/dev/null || echo "0")
            local interactions=$(jq '.interactions | length' "$metadata_file" 2>/dev/null || echo "0")
            
            total_input_tokens=$((total_input_tokens + input))
            total_output_tokens=$((total_output_tokens + output))
            total_interactions=$((total_interactions + interactions))
        fi
    done
    
    # Calculate costs (example rates)
    if command -v bc >/dev/null 2>&1; then
        local input_cost=$(echo "scale=4; $total_input_tokens * 0.003 / 1000" | bc)
        local output_cost=$(echo "scale=4; $total_output_tokens * 0.015 / 1000" | bc)
        total_cost=$(echo "scale=2; $input_cost + $output_cost" | bc)
    fi
    
    echo "Total sessions: $total_sessions"
    echo "Active sessions: $active_sessions (last 30 days)"
    echo
    echo "Total interactions: $total_interactions"
    echo "Total tokens used:"
    echo "  Input: $total_input_tokens"
    echo "  Output: $total_output_tokens"
    echo "  Total: $((total_input_tokens + total_output_tokens))"
    echo
    echo "Estimated total cost: \$$total_cost"
    
    # Show most active sessions
    echo
    echo "Most active sessions:"
    local temp_active=$(mktemp)
    
    for session_dir in "$SESSION_DIR"/*; do
        if [[ ! -d "$session_dir" ]]; then
            continue
        fi
        
        local session_name=$(basename "$session_dir")
        local metadata_file="$session_dir/metadata.json"
        
        if [[ -f "$metadata_file" ]] && command -v jq >/dev/null 2>&1; then
            local interactions=$(jq '.interactions | length' "$metadata_file" 2>/dev/null || echo "0")
            echo "$interactions|$session_name" >> "$temp_active"
        fi
    done
    
    sort -rn "$temp_active" | head -5 | while IFS='|' read -r count name; do
        if [[ "$count" -gt 0 ]]; then
            echo "  - $name ($count interactions)"
        fi
    done
    
    rm -f "$temp_active"
}

# Export command
cmd_export() {
    ensure_session_dir
    
    local output_file=""
    local active_only=false
    
    # Parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --output)
                shift
                output_file="$1"
                shift
                ;;
            --active)
                active_only=true
                shift
                ;;
            *)
                echo "Unknown option: $1"
                usage 1
                ;;
        esac
    done
    
    if [[ -z "$output_file" ]]; then
        output_file="sessions-export-$(date +%Y%m%d-%H%M%S).json"
    fi
    
    echo -e "${BLUE}Exporting sessions to: $output_file${NC}"
    
    # Check for jq
    if ! command -v jq >/dev/null 2>&1; then
        echo -e "${RED}Error:${NC} jq is required for export functionality"
        exit 1
    fi
    
    # Build JSON array
    echo "[" > "$output_file"
    
    local first=true
    for session_dir in "$SESSION_DIR"/*; do
        if [[ ! -d "$session_dir" ]]; then
            continue
        fi
        
        local session_name=$(basename "$session_dir")
        local age_days=$(get_session_age_days "$session_dir")
        
        if [[ "$active_only" == true ]] && [[ "$age_days" -ge 30 ]]; then
            continue
        fi
        
        local metadata_file="$session_dir/metadata.json"
        if [[ -f "$metadata_file" ]]; then
            if [[ "$first" != true ]]; then
                echo "," >> "$output_file"
            fi
            first=false
            
            # Add session name to metadata and append
            jq --arg name "$session_name" '. + {session_name: $name}' "$metadata_file" >> "$output_file"
        fi
    done
    
    echo "]" >> "$output_file"
    
    # Validate and pretty-print
    if jq . "$output_file" > "${output_file}.tmp" 2>/dev/null; then
        mv "${output_file}.tmp" "$output_file"
        echo -e "${GREEN}✓${NC} Export complete"
        
        # Show summary
        local count=$(jq '. | length' "$output_file")
        echo "Exported $count sessions"
    else
        echo -e "${RED}Error:${NC} Failed to create valid JSON export"
        rm -f "$output_file" "${output_file}.tmp"
        exit 1
    fi
}

# Main command dispatch
main() {
    if [[ $# -lt 1 ]]; then
        usage 0
    fi
    
    local command="$1"
    shift
    
    case "$command" in
        list)
            cmd_list "$@"
            ;;
        show)
            cmd_show "$@"
            ;;
        clean)
            cmd_clean "$@"
            ;;
        stats)
            cmd_stats "$@"
            ;;
        export)
            cmd_export "$@"
            ;;
        help|--help|-h)
            usage 0
            ;;
        *)
            echo -e "${RED}Error:${NC} Unknown command: $command"
            echo
            usage 1
            ;;
    esac
}

# Execute main if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi