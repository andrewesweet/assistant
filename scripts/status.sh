#!/bin/bash
# AI Orchestrator - Status Command
# Displays comprehensive session information including active tasks,
# model usage, history, and performance metrics

set -euo pipefail

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source AI assistant configuration
source "$SCRIPT_DIR/ai-config.sh"

PROJECT_ROOT="$(get_project_root)"

# Common utilities will be sourced as needed

# Default values
FEATURE_ID=""
JSON_OUTPUT=false
ALL_SESSIONS=false

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Usage function
usage() {
    echo "Usage: $0 [feature-id] [options]"
    echo ""
    echo "Display comprehensive session status and metrics"
    echo ""
    echo "Options:"
    echo "  --json              Output in JSON format"
    echo "  --all               Show all sessions (when no feature-id)"
    echo "  -h, --help          Show this help message"
    echo ""
    echo "If no feature-id is provided, shows all active sessions"
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        --all)
            ALL_SESSIONS=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            if [[ -z "$FEATURE_ID" ]]; then
                FEATURE_ID="$1"
            else
                echo "Error: Unknown argument: $1"
                usage
            fi
            shift
            ;;
    esac
done

# Function to calculate duration
calculate_duration() {
    local start_time="$1"
    local end_time="${2:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"
    
    # Convert to epoch seconds
    local start_epoch=$(date -d "$start_time" +%s 2>/dev/null || echo "0")
    local end_epoch=$(date -d "$end_time" +%s 2>/dev/null || date +%s)
    
    local duration=$((end_epoch - start_epoch))
    
    if [[ $duration -lt 60 ]]; then
        echo "${duration} seconds"
    elif [[ $duration -lt 3600 ]]; then
        echo "$((duration / 60)) minutes"
    elif [[ $duration -lt 86400 ]]; then
        echo "$((duration / 3600)) hours"
    else
        echo "$((duration / 86400)) days"
    fi
}

# Function to display single session status
display_session_status() {
    local feature_id="$1"
    local session_dir="$PROJECT_ROOT/.ai-session/$feature_id"
    
    if [[ ! -d "$session_dir" ]]; then
        if [[ $JSON_OUTPUT == true ]]; then
            echo '{"error": "Session not found", "feature_id": "'$feature_id'"}'
        else
            echo -e "${RED}Error:${NC} Session not found for feature: $feature_id"
        fi
        return 1
    fi
    
    # Read session info
    local description=""
    if [[ -f "$session_dir/implementation-plan.yaml" ]]; then
        description=$(grep "description:" "$session_dir/implementation-plan.yaml" 2>/dev/null | cut -d: -f2- | sed 's/^ *//;s/ *$//;s/^"//;s/"$//' || echo "")
    fi
    
    # Read state
    local active_task="none"
    local model_in_use="none"
    local started_at=""
    local last_updated=""
    
    if [[ -f "$session_dir/state.yaml" ]]; then
        active_task=$(grep "active_task:" "$session_dir/state.yaml" 2>/dev/null | cut -d: -f2- | sed 's/^ *//;s/ *$//;s/^"//;s/"$//' || echo "none")
        active_task=$(echo "$active_task" | tr -d '\n\r ')
        active_task=${active_task:-none}
        [[ "$active_task" == "null" ]] && active_task="none"
        model_in_use=$(grep "model_in_use:" "$session_dir/state.yaml" 2>/dev/null | cut -d: -f2- | sed 's/^ *//;s/ *$//;s/^"//;s/"$//' || echo "none")
        model_in_use=$(echo "$model_in_use" | tr -d '\n\r ')
        model_in_use=${model_in_use:-none}
        started_at=$(grep "started_at:" "$session_dir/state.yaml" 2>/dev/null | cut -d: -f2- | sed 's/^ *//;s/ *$//;s/^"//;s/"$//' || echo "")
        started_at=$(echo "$started_at" | tr -d '\n\r ')
        last_updated=$(grep "last_updated:" "$session_dir/state.yaml" 2>/dev/null | cut -d: -f2- | sed 's/^ *//;s/ *$//;s/^"//;s/"$//' || echo "")
        last_updated=$(echo "$last_updated" | tr -d '\n\r ')
    fi
    
    # Calculate duration
    local duration=""
    if [[ -n "$started_at" ]]; then
        duration=$(calculate_duration "$started_at" "$last_updated")
    fi
    
    # Process history for statistics
    local total_commands=0
    local plan_count=0
    local implement_count=0
    local review_count=0
    local verify_count=0
    local failures=0
    local gemini_count=0
    local sonnet_count=0
    local opus_count=0
    local total_duration_ms=0
    local recent_commands=()
    
    if [[ -f "$session_dir/history.jsonl" ]]; then
        # Count total commands
        total_commands=$(wc -l < "$session_dir/history.jsonl" | tr -d ' ')
        total_commands=${total_commands:-0}
        
        # Count by command type
        plan_count=$(grep -c '"command":"plan"' "$session_dir/history.jsonl" 2>/dev/null || echo "0")
        plan_count=$(echo "$plan_count" | tr -d '\n\r ')
        plan_count=${plan_count:-0}
        implement_count=$(grep -c '"command":"implement"' "$session_dir/history.jsonl" 2>/dev/null || echo "0")
        implement_count=$(echo "$implement_count" | tr -d '\n\r ')
        implement_count=${implement_count:-0}
        review_count=$(grep -c '"command":"review"' "$session_dir/history.jsonl" 2>/dev/null || echo "0")
        review_count=$(echo "$review_count" | tr -d '\n\r ')
        review_count=${review_count:-0}
        verify_count=$(grep -c '"command":"verify"' "$session_dir/history.jsonl" 2>/dev/null || echo "0")
        verify_count=$(echo "$verify_count" | tr -d '\n\r ')
        verify_count=${verify_count:-0}
        
        # Count failures
        failures=$(grep -c '"status":"failure"' "$session_dir/history.jsonl" 2>/dev/null || echo "0")
        failures=$(echo "$failures" | tr -d '\n\r ')
        failures=${failures:-0}
        
        # Model usage
        gemini_count=$(grep -c '"model":"gemini"' "$session_dir/history.jsonl" 2>/dev/null || echo "0")
        gemini_count=$(echo "$gemini_count" | tr -d '\n\r ')
        gemini_count=${gemini_count:-0}
        sonnet_count=$(grep -c '"model":"sonnet"' "$session_dir/history.jsonl" 2>/dev/null || echo "0")
        sonnet_count=$(echo "$sonnet_count" | tr -d '\n\r ')
        sonnet_count=${sonnet_count:-0}
        opus_count=$(grep -c '"model":"opus"' "$session_dir/history.jsonl" 2>/dev/null || echo "0")
        opus_count=$(echo "$opus_count" | tr -d '\n\r ')
        opus_count=${opus_count:-0}
        
        # Get recent commands (last 5)
        if command -v jq >/dev/null 2>&1; then
            mapfile -t recent_commands < <(tail -n 5 "$session_dir/history.jsonl" | jq -r '"\(.timestamp) - \(.command) (\(.status))"' 2>/dev/null)
            
            # Calculate total duration
            total_duration_ms=$(jq -s 'map(.duration_ms // 0) | add' "$session_dir/history.jsonl" 2>/dev/null || echo "0")
            total_duration_ms=$(echo "$total_duration_ms" | tr -d '\n\r ')
            [[ "$total_duration_ms" == "null" ]] && total_duration_ms="0"
            total_duration_ms=${total_duration_ms:-0}
        fi
    fi
    
    # Process implementation plan for task progress
    local completed_tasks=0
    local in_progress_tasks=0
    local pending_tasks=0
    local total_tasks=0
    
    if [[ -f "$session_dir/implementation-plan.yaml" ]]; then
        # Simple parsing for task counts
        completed_tasks=$(grep -c "status: \"completed\"" "$session_dir/implementation-plan.yaml" 2>/dev/null || echo "0")
        completed_tasks=$(echo "$completed_tasks" | tr -d '\n\r ')
        completed_tasks=${completed_tasks:-0}
        in_progress_tasks=$(grep -c "status: \"in_progress\"" "$session_dir/implementation-plan.yaml" 2>/dev/null || echo "0")
        in_progress_tasks=$(echo "$in_progress_tasks" | tr -d '\n\r ')
        in_progress_tasks=${in_progress_tasks:-0}
        pending_tasks=$(grep -c "status: \"pending\"" "$session_dir/implementation-plan.yaml" 2>/dev/null || echo "0")
        pending_tasks=$(echo "$pending_tasks" | tr -d '\n\r ')
        pending_tasks=${pending_tasks:-0}
        total_tasks=$((completed_tasks + in_progress_tasks + pending_tasks))
    fi
    
    # Count artifacts
    local total_files=0
    local go_files=0
    local py_files=0
    local js_files=0
    local md_files=0
    local sql_files=0
    
    if [[ -d "$session_dir/artifacts" ]]; then
        total_files=$(find "$session_dir/artifacts" -type f | wc -l)
        
        # Count by extension
        go_files=$(find "$session_dir/artifacts" -name "*.go" | wc -l)
        py_files=$(find "$session_dir/artifacts" -name "*.py" | wc -l)
        js_files=$(find "$session_dir/artifacts" -name "*.js" | wc -l)
        md_files=$(find "$session_dir/artifacts" -name "*.md" | wc -l)
        sql_files=$(find "$session_dir/artifacts" -name "*.sql" | wc -l)
    fi
    
    # Calculate session health
    local health_status="Active"
    local last_activity="unknown"
    if [[ -n "$last_updated" ]]; then
        local last_epoch=$(date -d "$last_updated" +%s 2>/dev/null || echo "0")
        local now_epoch=$(date +%s)
        local idle_time=$((now_epoch - last_epoch))
        
        if [[ $idle_time -lt 300 ]]; then
            last_activity="$(( idle_time / 60 )) minutes ago"
            health_status="Active"
        elif [[ $idle_time -lt 3600 ]]; then
            last_activity="$(( idle_time / 60 )) minutes ago"
            health_status="Active"
        elif [[ $idle_time -lt 86400 ]]; then
            last_activity="$(( idle_time / 3600 )) hours ago"
            health_status="Idle"
        else
            last_activity="$(( idle_time / 86400 )) days ago"
            health_status="Stale"
        fi
    fi
    
    # Output based on format
    if [[ $JSON_OUTPUT == true ]]; then
        cat <<EOF
{
    "feature_id": "$feature_id",
    "description": "$description",
    "active_task": "$active_task",
    "model": "$model_in_use",
    "started_at": "$started_at",
    "last_updated": "$last_updated",
    "duration": "$duration",
    "health_status": "$health_status",
    "last_activity": "$last_activity",
    "commands": {
        "total": $total_commands,
        "plan": $plan_count,
        "implement": $implement_count,
        "review": $review_count,
        "verify": $verify_count,
        "failures": $failures
    },
    "model_usage": {
        "gemini": $gemini_count,
        "sonnet": $sonnet_count,
        "opus": $opus_count
    },
    "tasks": {
        "total": $total_tasks,
        "completed": $completed_tasks,
        "in_progress": $in_progress_tasks,
        "pending": $pending_tasks,
        "progress_percent": $(( total_tasks > 0 ? completed_tasks * 100 / total_tasks : 0 ))
    },
    "artifacts": {
        "total_files": $total_files,
        "go": $go_files,
        "python": $py_files,
        "javascript": $js_files,
        "markdown": $md_files,
        "sql": $sql_files
    },
    "performance": {
        "total_duration_ms": $total_duration_ms,
        "avg_duration_ms": $(( total_commands > 0 ? total_duration_ms / total_commands : 0 ))
    }
}
EOF
    else
        # Display formatted output
        echo -e "\n${BLUE}═══════════════════════════════════════════════════════${NC}"
        echo -e "${CYAN}Feature: $feature_id${NC}"
        [[ -n "$description" ]] && echo -e "Description: $description"
        echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
        
        echo -e "\n${MAGENTA}Current State:${NC}"
        echo "  Active Task: $active_task"
        echo "  Model: $model_in_use"
        echo "  Started: $started_at"
        echo "  Duration: $duration"
        
        echo -e "\n${MAGENTA}Session Health:${NC}"
        if [[ "$health_status" == "Active" ]]; then
            echo -e "  Status: ${GREEN}$health_status${NC}"
        elif [[ "$health_status" == "Idle" ]]; then
            echo -e "  Status: ${YELLOW}$health_status${NC}"
        else
            echo -e "  Status: ${RED}$health_status${NC}"
        fi
        echo "  Last Activity: $last_activity"
        
        echo -e "\n${MAGENTA}Command History:${NC}"
        echo "  Total Commands: $total_commands"
        [[ $plan_count -gt 0 ]] && echo "    plan: $plan_count"
        [[ $implement_count -gt 0 ]] && echo "    implement: $implement_count"
        [[ $review_count -gt 0 ]] && echo "    review: $review_count"
        [[ $verify_count -gt 0 ]] && echo "    verify: $verify_count"
        if [[ $failures -gt 0 ]]; then
            echo -e "  ${RED}Failures: $failures${NC}"
        fi
        
        echo -e "\n${MAGENTA}Model Usage:${NC}"
        [[ $gemini_count -gt 0 ]] && echo "  gemini: $gemini_count"
        [[ $sonnet_count -gt 0 ]] && echo "  sonnet: $sonnet_count"
        [[ $opus_count -gt 0 ]] && echo "  opus: $opus_count"
        
        if [[ $total_tasks -gt 0 ]]; then
            echo -e "\n${MAGENTA}Task Progress:${NC}"
            echo "  Completed: $completed_tasks/$total_tasks"
            echo "  In Progress: $in_progress_tasks"
            echo "  Pending: $pending_tasks"
            local progress_percent=$(( completed_tasks * 100 / total_tasks ))
            echo -e "  Progress: ${GREEN}${progress_percent}%${NC}"
        fi
        
        if [[ $total_files -gt 0 ]]; then
            echo -e "\n${MAGENTA}Artifacts:${NC}"
            echo "  Total Files: $total_files"
            [[ $go_files -gt 0 ]] && echo "    .go: $go_files"
            [[ $py_files -gt 0 ]] && echo "    .py: $py_files"
            [[ $js_files -gt 0 ]] && echo "    .js: $js_files"
            [[ $md_files -gt 0 ]] && echo "    .md: $md_files"
            [[ $sql_files -gt 0 ]] && echo "    .sql: $sql_files"
        fi
        
        if [[ $total_duration_ms -gt 0 ]]; then
            echo -e "\n${MAGENTA}Performance:${NC}"
            local avg_duration=$(( total_duration_ms / total_commands ))
            echo "  Avg Duration: ${avg_duration}ms"
            echo "  Total Time: $(( total_duration_ms / 1000 ))s"
        fi
        
        if [[ ${#recent_commands[@]} -gt 0 ]]; then
            echo -e "\n${MAGENTA}Recent Activity:${NC}"
            for cmd in "${recent_commands[@]}"; do
                echo "  $cmd"
            done
        fi
        
        echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}\n"
    fi
}

# Function to display all sessions
display_all_sessions() {
    local active_features_file="$PROJECT_ROOT/.ai-session/active-features.yaml"
    
    if [[ ! -f "$active_features_file" ]]; then
        if [[ $JSON_OUTPUT == true ]]; then
            echo '{"error": "No active sessions found"}'
        else
            echo -e "${YELLOW}No active sessions found${NC}"
        fi
        return 0
    fi
    
    # Parse active features
    local features=()
    while IFS= read -r line; do
        if [[ "$line" =~ feature_id:[[:space:]]*(.+) ]]; then
            features+=("${BASH_REMATCH[1]}")
        fi
    done < "$active_features_file"
    
    if [[ ${#features[@]} -eq 0 ]]; then
        if [[ $JSON_OUTPUT == true ]]; then
            echo '{"sessions": []}'
        else
            echo -e "${YELLOW}No active sessions found${NC}"
        fi
        return 0
    fi
    
    if [[ $JSON_OUTPUT == true ]]; then
        echo '{"sessions": ['
        local first=true
        for feature in "${features[@]}"; do
            [[ $first == false ]] && echo ","
            display_session_status "$feature"
            first=false
        done
        echo ']}'
    else
        echo -e "\n${CYAN}Active Sessions:${NC}"
        echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
        
        for feature in "${features[@]}"; do
            # Get brief info for summary
            local session_dir="$PROJECT_ROOT/.ai-session/$feature"
            if [[ -d "$session_dir" ]]; then
                local description=""
                local status="active"
                local last_updated=""
                
                if [[ -f "$session_dir/session-info.yaml" ]]; then
                    description=$(grep "description:" "$session_dir/session-info.yaml" 2>/dev/null | cut -d: -f2- | sed 's/^ *//;s/ *$//' || echo "")
                fi
                
                if [[ -f "$active_features_file" ]]; then
                    # Extract status for this feature
                    local in_feature_block=false
                    while IFS= read -r line; do
                        if [[ "$line" =~ feature_id:[[:space:]]*$feature ]]; then
                            in_feature_block=true
                        elif [[ $in_feature_block == true ]] && [[ "$line" =~ status:[[:space:]]*(.+) ]]; then
                            status="${BASH_REMATCH[1]}"
                            break
                        elif [[ "$line" =~ ^[[:space:]]*- ]] && [[ $in_feature_block == true ]]; then
                            break
                        fi
                    done < "$active_features_file"
                fi
                
                echo ""
                echo -e "${GREEN}$feature${NC}"
                [[ -n "$description" ]] && echo "  $description"
                if [[ "$status" == "active" ]]; then
                    echo -e "  Status: ${GREEN}$status${NC}"
                else
                    echo -e "  Status: ${YELLOW}$status${NC}"
                fi
                echo "  Run: status $feature"
            fi
        done
        
        echo -e "\n${BLUE}═══════════════════════════════════════════════════════${NC}"
        echo -e "\nFor detailed status, run: ${CYAN}status <feature-id>${NC}\n"
    fi
}

# Main execution
if [[ -z "$FEATURE_ID" ]]; then
    # Show all sessions
    display_all_sessions
else
    # Show specific session
    display_session_status "$FEATURE_ID"
fi