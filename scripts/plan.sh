#!/bin/bash
# Plan command - Create implementation plans using AI models

set -euo pipefail

# Configuration
DATE_FORMAT="+%Y-%m-%dT%H:%M:%SZ"
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# Source AI assistant configuration
source "$SCRIPT_DIR/ai-config.sh"

USE_SESSIONS="${USE_SESSIONS:-true}"

# Get feature ID
if [[ $# -lt 1 ]]; then
    echo "Error: Feature ID required" >&2
    echo "Usage: $0 <feature-id> [options] <prompt>" >&2
    exit 1
fi

feature_id="$1"
shift

# Check if session exists
session_dir="$SESSION_ROOT/$feature_id"
if [[ ! -d "$session_dir" ]]; then
    echo "Error: Session not found: $feature_id" >&2
    echo "Run 'init-session.sh $feature_id' first" >&2
    exit 1
fi

# Parse options
full_context=false
model="gemini"  # Default to Gemini for planning
retry=false
timeout=""
prompt=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --full-context)
            full_context=true
            shift
            ;;
        --model)
            model="$2"
            shift 2
            ;;
        --retry)
            retry=true
            shift
            ;;
        --timeout)
            timeout="$2"
            shift 2
            ;;
        *)
            # Remaining args are the prompt
            prompt="$*"
            break
            ;;
    esac
done

if [[ -z "$prompt" ]]; then
    echo "Error: Planning prompt required" >&2
    exit 1
fi

# Load session state
state_file="$session_dir/state.yaml"
active_task=""
if [[ -f "$state_file" ]]; then
    active_task=$(grep "active_task:" "$state_file" | sed 's/.*active_task: //' | sed 's/"//g' || true)
fi

# Load implementation plan if exists to get description
description=""
if [[ -f "$session_dir/implementation-plan.yaml" ]]; then
    description=$(grep "description:" "$session_dir/implementation-plan.yaml" | head -1 | sed 's/.*description: //' | sed 's/"//g' || true)
fi

# Construct planning prompt
planning_prompt="Feature: $description

Current request: $prompt

Please create a comprehensive implementation plan following ATDD/TDD methodology. The plan should include:
1. Clear phases with specific tasks
2. Test requirements for each task
3. Acceptance criteria
4. Task dependencies
5. Agent assignments

Format the response as a structured JSON with phases, tasks, and test requirements."

if [[ -n "$active_task" ]]; then
    planning_prompt="$planning_prompt

Note: Currently working on task: $active_task"
fi

# Function to update session todo
update_session_todo() {
    local status="${1:-completed}"
    
    if [[ -f "$SCRIPT_DIR/track-session-todo.sh" ]] && [[ -n "$session_todo_id" ]]; then
        # Get session cost if available
        local session_cost=""
        local session_tokens=""
        if [[ -f "$SCRIPT_DIR/ai-session.sh" ]]; then
            # Extract cost and tokens from session
            local session_info=$("$SCRIPT_DIR/ai-session.sh" show "plan-$feature_id" 2>/dev/null || true)
            session_cost=$(echo "$session_info" | grep -oP 'Cost: \$\K[0-9.]+' || echo "0")
            session_tokens=$(echo "$session_info" | grep -oP 'Total: \K[0-9]+' || echo "0")
        fi
        
        "$SCRIPT_DIR/track-session-todo.sh" end "plan-$feature_id" "$session_todo_id" "$session_cost" "$session_tokens" "$status"
    fi
}

# Function to log command to history
log_command() {
    local command="$1"
    local model_used="$2"
    local status="$3"
    local start_time="$4"
    local end_time="$5"
    local error_msg="${6:-}"
    local arguments="$prompt"
    
    # Calculate duration
    local duration_ms=0
    if [[ -n "$start_time" ]] && [[ -n "$end_time" ]]; then
        duration_ms=$(( (end_time - start_time) ))
    fi
    
    # Get agent ID
    local agent="${AGENT_ID:-unknown}"
    
    # Create history entry
    local history_entry="{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\""
    history_entry="$history_entry,\"command\":\"$command\""
    history_entry="$history_entry,\"arguments\":\"$arguments\""
    history_entry="$history_entry,\"model\":\"$model_used\""
    history_entry="$history_entry,\"agent\":\"$agent\""
    history_entry="$history_entry,\"status\":\"$status\""
    history_entry="$history_entry,\"duration_ms\":$duration_ms"
    history_entry="$history_entry,\"feature_id\":\"$feature_id\""
    
    if [[ -n "$error_msg" ]]; then
        history_entry="$history_entry,\"error\":\"$error_msg\""
    fi
    
    if [[ "$full_context" == "true" ]]; then
        history_entry="$history_entry,\"full_context\":true"
    fi
    
    # Add session info if enabled
    if [[ "$USE_SESSIONS" == "true" ]]; then
        history_entry="$history_entry,\"session_enabled\":true"
        history_entry="$history_entry,\"session_name\":\"plan-$feature_id\""
    fi
    
    history_entry="$history_entry}"
    
    echo "$history_entry" >> "$session_dir/history.jsonl"
}

# Function to execute AI model
execute_model() {
    local model_name="$1"
    local model_args=""
    
    # Track timing
    local start_time=$(date +%s%N)
    
    # Build model command
    if [[ "$model_name" == "gemini" ]]; then
        local cmd_args=()
        cmd_args+=("gemini" "300")
        
        if [[ "$full_context" == "true" ]]; then
            cmd_args+=("-a")
        fi
        
        # Add session support if enabled
        if [[ "$USE_SESSIONS" == "true" ]]; then
            local session_name="plan-$feature_id"
            cmd_args+=("--session-name" "$session_name")
        fi
        
        cmd_args+=("-p" "$planning_prompt")
        
        local output
        local exit_code
        
        # Execute with error capture using wrapper
        if output=$("$SCRIPT_DIR/ai-command-wrapper.sh" "${cmd_args[@]}" 2>&1); then
            exit_code=0
        else
            exit_code=$?
        fi
        
        local end_time=$(date +%s%N)
        
        if [[ $exit_code -eq 0 ]]; then
            # Log success
            log_command "plan" "$model_name" "success" "$start_time" "$end_time"
            
            # Update model in use
            "$SCRIPT_DIR/update-session-state.sh" "$feature_id" --model="$model_name"
            
            # Process and save plan
            echo "$output" | process_plan_output
            
            return 0
        else
            # Log failure
            log_command "plan" "$model_name" "failure" "$start_time" "$end_time" "$output"
            return $exit_code
        fi
        
    elif [[ "$model_name" == "opus" ]]; then
        local cmd_args=()
        cmd_args+=("claude" "300" "--model" "opus")
        
        # Add session support if enabled
        if [[ "$USE_SESSIONS" == "true" ]]; then
            local session_name="plan-$feature_id"
            cmd_args+=("--session-name" "$session_name")
        fi
        
        cmd_args+=("-p" "$planning_prompt")
        
        local output
        local exit_code
        
        # Execute with error capture using wrapper
        if output=$("$SCRIPT_DIR/ai-command-wrapper.sh" "${cmd_args[@]}" 2>&1); then
            exit_code=0
        else
            exit_code=$?
        fi
        
        local end_time=$(date +%s%N)
        
        if [[ $exit_code -eq 0 ]]; then
            # Log success
            log_command "plan" "$model_name" "success" "$start_time" "$end_time"
            
            # Update model in use
            "$SCRIPT_DIR/update-session-state.sh" "$feature_id" --model="$model_name"
            
            # Process and save plan
            echo "$output" | process_plan_output
            
            return 0
        else
            # Log failure
            log_command "plan" "$model_name" "failure" "$start_time" "$end_time" "$output"
            return $exit_code
        fi
    fi
}

# Function to process plan output and save to YAML
process_plan_output() {
    local plan_file="$session_dir/implementation-plan.yaml"
    local temp_file="/tmp/plan_$$"
    
    # Read all input
    local output=$(cat)
    
    # Try to extract JSON from output
    local json_plan=""
    if echo "$output" | grep -q '"phases"'; then
        # Extract JSON object
        json_plan=$(echo "$output" | grep -o '{.*}' | tail -1)
    fi
    
    # Convert to YAML format
    cat > "$temp_file" <<EOF
feature:
  id: "$feature_id"
  name: "$(echo "$description" | sed 's/"//g')"
  created_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  
EOF
    
    if [[ -n "$json_plan" ]]; then
        # Parse JSON and convert to YAML (simplified for this implementation)
        echo "$json_plan" | jq -r '
            "phases:",
            (.phases[]? | 
                "  - phase_id: \"" + .phase_id + "\"",
                "    name: \"" + .name + "\"",
                "    tasks:",
                (.tasks[]? |
                    "      - task_id: \"" + .task_id + "\"",
                    "        description: \"" + .description + "\"",
                    "        agent: \"" + .agent + "\"",
                    "        status: \"" + .status + "\""
                )
            )
        ' >> "$temp_file" 2>/dev/null || {
            # Fallback: just save the output as-is
            echo "# Generated plan:" >> "$temp_file"
            echo "$output" >> "$temp_file"
        }
    else
        # Save raw output
        echo "# Generated plan:" >> "$temp_file"
        echo "$output" >> "$temp_file"
    fi
    
    # Move to final location
    mv "$temp_file" "$plan_file"
    
    echo "Plan saved to: $plan_file"
}

# Main execution logic with fallback
main() {
    local retry_count=0
    local max_retries=3
    local session_todo_id=""
    
    # Log session start if enabled
    if [[ "$USE_SESSIONS" == "true" ]]; then
        echo "Session management: ENABLED"
        echo "Session name: plan-$feature_id"
        
        # Log session start in history
        echo "{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"event\":\"session_start\",\"session_name\":\"plan-$feature_id\",\"feature_id\":\"$feature_id\"}" >> "$session_dir/history.jsonl"
        
        # Track in TodoWrite if available
        if [[ -f "$SCRIPT_DIR/track-session-todo.sh" ]]; then
            session_todo_id=$("$SCRIPT_DIR/track-session-todo.sh" start "plan-$feature_id" "$feature_id" "" "0.50")
        fi
    fi
    
    # Try primary model (Gemini by default)
    if [[ "$model" == "opus" ]]; then
        # User explicitly requested Opus, skip Gemini
        echo "Using Opus model for planning..."
        execute_model "opus"
        local result=$?
        
        # Log session end if enabled
        if [[ "$USE_SESSIONS" == "true" ]]; then
            echo "{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"event\":\"session_end\",\"session_name\":\"plan-$feature_id\",\"feature_id\":\"$feature_id\"}" >> "$session_dir/history.jsonl"
            
            # Update TodoWrite if available
            update_session_todo "completed"
        fi
        
        exit $result
    fi
    
    # Try Gemini first
    echo "Creating plan with Gemini..."
    
    if [[ "$retry" == "true" ]]; then
        # Retry logic for Gemini
        while [[ $retry_count -lt $max_retries ]]; do
            if execute_model "gemini"; then
                # Log session end if enabled
                if [[ "$USE_SESSIONS" == "true" ]]; then
                    echo "{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"event\":\"session_end\",\"session_name\":\"plan-$feature_id\",\"feature_id\":\"$feature_id\"}" >> "$session_dir/history.jsonl"
                    update_session_todo "completed"
                fi
                exit 0
            fi
            
            ((retry_count++))
            if [[ $retry_count -lt $max_retries ]]; then
                echo "Retrying Gemini (attempt $((retry_count + 1))/$max_retries)..."
                sleep 1
            fi
        done
    else
        # Single attempt
        if execute_model "gemini"; then
            # Log session end if enabled
            if [[ "$USE_SESSIONS" == "true" ]]; then
                echo "{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"event\":\"session_end\",\"session_name\":\"plan-$feature_id\",\"feature_id\":\"$feature_id\"}" >> "$session_dir/history.jsonl"
                update_session_todo "completed"
            fi
            exit 0
        fi
    fi
    
    # Fallback to Opus
    echo "Gemini unavailable, falling back to Opus..."
    echo "Using Opus model for planning..."
    
    if execute_model "opus"; then
        # Log session end if enabled
        if [[ "$USE_SESSIONS" == "true" ]]; then
            echo "{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"event\":\"session_end\",\"session_name\":\"plan-$feature_id\",\"feature_id\":\"$feature_id\"}" >> "$session_dir/history.jsonl"
            update_session_todo "completed"
        fi
        exit 0
    fi
    
    # Both models failed
    # Log session end even on failure
    if [[ "$USE_SESSIONS" == "true" ]]; then
        echo "{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"event\":\"session_end\",\"session_name\":\"plan-$feature_id\",\"feature_id\":\"$feature_id\",\"status\":\"failed\"}" >> "$session_dir/history.jsonl"
        update_session_todo "failed"
    fi
    echo "Error: All models failed to generate plan" >&2
    exit 1
}

# Execute main logic
main