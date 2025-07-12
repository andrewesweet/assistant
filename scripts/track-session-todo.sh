#!/bin/bash
# Track session lifecycle in TodoWrite system
# Integrates AI session management with task tracking

set -euo pipefail

# Configuration
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
SESSION_DIR="${SESSION_DIR:-$HOME/.ai-sessions}"

# Parse arguments
action="${1:-}"
session_name="${2:-}"
shift 2 || true

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to create todo for session start
track_session_start() {
    local session_name="$1"
    local feature_id="${2:-}"
    local task_id="${3:-}"
    local estimated_cost="${4:-0.10}"
    
    local todo_content="🤖 AI Session: $session_name"
    if [[ -n "$feature_id" ]]; then
        todo_content="$todo_content | Feature: $feature_id"
    fi
    if [[ -n "$task_id" ]]; then
        todo_content="$todo_content | Task: $task_id"
    fi
    todo_content="$todo_content | Est. cost: \$$estimated_cost"
    
    # Create todo item
    local todo_id="session-$(date +%s)"
    local todo_entry="{
        \"id\": \"$todo_id\",
        \"content\": \"$todo_content\",
        \"status\": \"in_progress\",
        \"priority\": \"medium\",
        \"metadata\": {
            \"type\": \"ai_session\",
            \"session_name\": \"$session_name\",
            \"feature_id\": \"$feature_id\",
            \"task_id\": \"$task_id\",
            \"start_time\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
            \"estimated_cost\": $estimated_cost
        }
    }"
    
    echo -e "${BLUE}[TodoWrite]${NC} Session started: $session_name"
    echo "$todo_entry" >> "${TODO_FILE:-/tmp/todos.jsonl}"
    
    # Return todo ID for later updates
    echo "$todo_id"
}

# Function to update todo for session end
track_session_end() {
    local session_name="$1"
    local todo_id="${2:-}"
    local actual_cost="${3:-}"
    local token_count="${4:-}"
    local status="${5:-completed}"
    
    if [[ -z "$todo_id" ]]; then
        # Try to find todo by session name
        todo_id=$(grep "\"session_name\": \"$session_name\"" "${TODO_FILE:-/tmp/todos.jsonl}" 2>/dev/null | tail -1 | jq -r '.id' || echo "")
    fi
    
    if [[ -z "$todo_id" ]]; then
        echo -e "${YELLOW}[TodoWrite]${NC} No todo found for session: $session_name"
        return
    fi
    
    # Get session summary if available
    local summary=""
    if [[ -f "$SCRIPT_DIR/ai-session.sh" ]]; then
        summary=$("$SCRIPT_DIR/ai-session.sh" show "$session_name" 2>/dev/null | grep -E "(Interactions:|Tokens:|Cost:)" | tr '\n' ' ' || echo "")
    fi
    
    # Update todo entry
    local update_entry="{
        \"id\": \"$todo_id\",
        \"action\": \"update\",
        \"status\": \"$status\",
        \"metadata\": {
            \"end_time\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
            \"actual_cost\": ${actual_cost:-0},
            \"total_tokens\": ${token_count:-0},
            \"summary\": \"$summary\"
        }
    }"
    
    echo -e "${GREEN}[TodoWrite]${NC} Session completed: $session_name"
    if [[ -n "$summary" ]]; then
        echo "  $summary"
    fi
    
    echo "$update_entry" >> "${TODO_FILE:-/tmp/todos.jsonl}"
}

# Function to track session error
track_session_error() {
    local session_name="$1"
    local todo_id="${2:-}"
    local error_msg="${3:-Unknown error}"
    
    track_session_end "$session_name" "$todo_id" "" "" "failed"
    
    # Log error details
    local error_entry="{
        \"id\": \"$todo_id-error\",
        \"content\": \"❌ Session error: $session_name - $error_msg\",
        \"status\": \"completed\",
        \"priority\": \"high\",
        \"metadata\": {
            \"type\": \"ai_session_error\",
            \"session_name\": \"$session_name\",
            \"error\": \"$error_msg\",
            \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"
        }
    }"
    
    echo "$error_entry" >> "${TODO_FILE:-/tmp/todos.jsonl}"
}

# Function to generate session report
generate_session_report() {
    local start_date="${1:-$(date -d '7 days ago' +%Y-%m-%d)}"
    local end_date="${2:-$(date +%Y-%m-%d)}"
    
    echo -e "${BLUE}AI Session Report${NC}"
    echo "Period: $start_date to $end_date"
    echo
    
    if [[ ! -f "${TODO_FILE:-/tmp/todos.jsonl}" ]]; then
        echo "No todo data found"
        return
    fi
    
    # Count sessions
    local total_sessions=$(grep '"type": "ai_session"' "${TODO_FILE:-/tmp/todos.jsonl}" | wc -l)
    local completed_sessions=$(grep '"type": "ai_session"' "${TODO_FILE:-/tmp/todos.jsonl}" | grep '"status": "completed"' | wc -l)
    local failed_sessions=$(grep '"type": "ai_session_error"' "${TODO_FILE:-/tmp/todos.jsonl}" | wc -l)
    
    echo "Total sessions: $total_sessions"
    echo "Completed: $completed_sessions"
    echo "Failed: $failed_sessions"
    echo
    
    # Calculate costs
    if command -v jq >/dev/null 2>&1; then
        local total_cost=$(grep '"type": "ai_session"' "${TODO_FILE:-/tmp/todos.jsonl}" | jq -s '[.[] | .metadata.actual_cost // 0] | add' 2>/dev/null || echo "0")
        echo "Total cost: \$$total_cost"
        
        # Top features by session count
        echo
        echo "Top features:"
        grep '"type": "ai_session"' "${TODO_FILE:-/tmp/todos.jsonl}" | \
            jq -r '.metadata.feature_id // "unknown"' | \
            sort | uniq -c | sort -rn | head -5
    fi
}

# Main command dispatch
case "$action" in
    start)
        track_session_start "$session_name" "$@"
        ;;
    end)
        track_session_end "$session_name" "$@"
        ;;
    error)
        track_session_error "$session_name" "$@"
        ;;
    report)
        generate_session_report "$session_name" "$@"
        ;;
    *)
        echo "Usage: $0 <action> <session-name> [args...]"
        echo
        echo "Actions:"
        echo "  start <session-name> [feature-id] [task-id] [est-cost]"
        echo "      Track session start in todo system"
        echo
        echo "  end <session-name> [todo-id] [actual-cost] [tokens] [status]"
        echo "      Update todo when session ends"
        echo
        echo "  error <session-name> [todo-id] [error-msg]"
        echo "      Track session error"
        echo
        echo "  report [start-date] [end-date]"
        echo "      Generate session usage report"
        echo
        echo "Environment:"
        echo "  TODO_FILE    Todo storage file (default: /tmp/todos.jsonl)"
        echo "  SESSION_DIR  AI sessions directory"
        exit 1
        ;;
esac