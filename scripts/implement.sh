#!/bin/bash
# Implement command - Execute tasks with ATDD/TDD enforcement

set -euo pipefail

# Configuration
SESSION_ROOT="${SESSION_ROOT:-.ai-session}"
DATE_FORMAT="+%Y-%m-%dT%H:%M:%SZ"
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
USE_SESSIONS="${USE_SESSIONS:-true}"

# Get feature ID
if [[ $# -lt 1 ]]; then
    echo "Error: Feature ID required" >&2
    echo "Usage: $0 <feature-id> [options]" >&2
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

# Check if implementation plan exists
plan_file="$session_dir/implementation-plan.yaml"
if [[ ! -f "$plan_file" ]]; then
    echo "Error: No implementation plan found" >&2
    echo "Run 'plan' command first to create an implementation plan" >&2
    exit 1
fi

# Parse options
task_id=""
model="sonnet"  # Default to Sonnet for implementation
no_tests=false
check_coverage=false
tdd=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --task)
            task_id="$2"
            shift 2
            ;;
        --model)
            model="$2"
            shift 2
            ;;
        --no-tests)
            no_tests=true
            shift
            ;;
        --check-coverage)
            check_coverage=true
            shift
            ;;
        --tdd)
            tdd=true
            shift
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

if [[ -z "$task_id" ]]; then
    echo "Error: Task ID required (--task <task-id>)" >&2
    exit 1
fi

# Function to log command to history
log_command() {
    local command="$1"
    local model_used="$2"
    local status="$3"
    local start_time="$4"
    local end_time="$5"
    local error_msg="${6:-}"
    local task_status="${7:-}"
    
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
    history_entry="$history_entry,\"arguments\":\"--task $task_id\""
    history_entry="$history_entry,\"model\":\"$model_used\""
    history_entry="$history_entry,\"agent\":\"$agent\""
    history_entry="$history_entry,\"status\":\"$status\""
    history_entry="$history_entry,\"duration_ms\":$duration_ms"
    history_entry="$history_entry,\"feature_id\":\"$feature_id\""
    history_entry="$history_entry,\"task_id\":\"$task_id\""
    
    if [[ -n "$error_msg" ]]; then
        history_entry="$history_entry,\"error\":\"$error_msg\""
    fi
    
    if [[ -n "$task_status" ]]; then
        history_entry="$history_entry,\"task_status\":\"$task_status\""
    fi
    
    if [[ "$no_tests" == "false" ]]; then
        history_entry="$history_entry,\"atdd_enforced\":true"
    fi
    
    # Add session state
    local active_task=$(grep "active_task:" "$session_dir/state.yaml" | sed 's/active_task: //' | sed 's/"//g' || true)
    if [[ -n "$active_task" ]]; then
        history_entry="$history_entry,\"session_state\":{\"active_task\":\"$active_task\"}"
    fi
    
    # Add session info if enabled
    if [[ "$USE_SESSIONS" == "true" ]]; then
        history_entry="$history_entry,\"session_enabled\":true"
        history_entry="$history_entry,\"session_name\":\"implement-$feature_id\""
    fi
    
    history_entry="$history_entry}"
    
    echo "$history_entry" >> "$session_dir/history.jsonl"
}

# Function to check for existing tests
check_existing_tests() {
    local test_marker="$session_dir/artifacts/.tests_written"
    
    if [[ -f "$test_marker" ]]; then
        echo "Tests already written for this task"
        return 0
    else
        echo "No tests found - will write tests first (ATDD)"
        return 1
    fi
}

# Function to update task status in plan
update_task_status() {
    local new_status="$1"
    local temp_file="/tmp/plan_update_$$"
    
    # Update task status in implementation plan
    awk -v task="$task_id" -v status="$new_status" '
        /task_id: "/ {
            if ($0 ~ "\"" task "\"") {
                in_task = 1
            } else {
                in_task = 0
            }
        }
        /status:/ && in_task {
            sub(/status: "[^"]*"/, "status: \"" status "\"")
        }
        { print }
    ' "$plan_file" > "$temp_file"
    
    mv "$temp_file" "$plan_file"
}

# Function to execute AI model for implementation
execute_implementation() {
    local phase="$1"  # "test" or "implement"
    local model_name="$2"
    
    # Build prompt based on phase
    local prompt=""
    if [[ "$phase" == "test" ]]; then
        prompt="Task: $task_id

Please write tests first following ATDD/TDD methodology. Include:
1. Unit tests for the core logic
2. Integration tests if applicable
3. Acceptance tests based on requirements
4. Clear test names that describe behavior
5. Edge cases and error conditions

Write comprehensive tests that will fail initially (red phase)."
    elif [[ "$phase" == "implement" ]]; then
        prompt="Task: $task_id

Now implement the code to make the tests pass (green phase). Focus on:
1. Making all tests pass
2. Clean, maintainable code
3. Following established patterns
4. Proper error handling
5. Clear documentation"
    elif [[ "$phase" == "refactor" ]]; then
        prompt="Task: $task_id

Refactor the implementation (refactor phase). Focus on:
1. Improving code structure
2. Removing duplication
3. Enhancing readability
4. Optimizing performance
5. Ensuring tests still pass"
    fi
    
    # Track timing
    local start_time=$(date +%s%N)
    
    # Build command arguments
    local cmd_args=()
    cmd_args+=("claude" "180")
    
    # Add session support if enabled
    if [[ "$USE_SESSIONS" == "true" ]]; then
        local session_name="implement-$feature_id"
        cmd_args+=("--session-name" "$session_name")
        
        # If this is not the first task, add continue flag
        if [[ -f "$session_dir/.session_active" ]]; then
            # Session already active, no need for explicit continue
            # The wrapper will handle it automatically
            :
        else
            # Mark session as active
            touch "$session_dir/.session_active"
        fi
    fi
    
    # Add model flag if needed
    if [[ "$model_name" == "opus" ]]; then
        cmd_args+=("--model" "opus")
    fi
    
    # Add prompt
    cmd_args+=("-p" "$prompt")
    
    # Execute with appropriate model
    local output
    local exit_code
    
    if output=$("$SCRIPT_DIR/ai-command-wrapper.sh" "${cmd_args[@]}" 2>&1); then
        exit_code=0
    else
        exit_code=$?
    fi
    
    local end_time=$(date +%s%N)
    
    if [[ $exit_code -eq 0 ]]; then
        # Log success
        if [[ "$phase" == "test" ]]; then
            log_command "implement" "$model_name" "success" "$start_time" "$end_time" "" "in_progress"
        elif [[ "$phase" == "implement" ]] || [[ "$phase" == "refactor" ]]; then
            log_command "implement" "$model_name" "success" "$start_time" "$end_time" "" "completed"
        fi
        
        # Process output
        if [[ "$phase" == "test" ]]; then
            echo "$output"
            # Mark tests as written
            mkdir -p "$session_dir/artifacts"
            echo "TESTS_WRITTEN" > "$session_dir/artifacts/.tests_written"
        else
            echo "$output"
        fi
        
        return 0
    else
        # Log failure
        log_command "implement" "$model_name" "failure" "$start_time" "$end_time" "$output"
        echo "Error: $output" >&2
        return $exit_code
    fi
}

# Function to run TDD cycle
run_tdd_cycle() {
    echo "=== Starting TDD Cycle ==="
    
    # RED phase - write failing tests
    echo "=== RED phase: Writing failing tests ==="
    if ! execute_implementation "test" "$model"; then
        echo "Error: Failed to write tests" >&2
        return 1
    fi
    
    # Log TDD phase
    echo "{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"command\":\"implement\",\"phase\":\"red\",\"task_id\":\"$task_id\"}" >> "$session_dir/history.jsonl"
    
    # GREEN phase - make tests pass
    echo "=== GREEN phase: Making tests pass ==="
    if ! execute_implementation "implement" "$model"; then
        echo "Error: Failed to implement solution" >&2
        return 1
    fi
    
    # Log TDD phase
    echo "{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"command\":\"implement\",\"phase\":\"green\",\"task_id\":\"$task_id\"}" >> "$session_dir/history.jsonl"
    
    # REFACTOR phase - improve code
    echo "=== REFACTOR phase: Improving code ==="
    if ! execute_implementation "refactor" "$model"; then
        echo "Error: Failed to refactor" >&2
        return 1
    fi
    
    # Log TDD phase
    echo "{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"command\":\"implement\",\"phase\":\"refactor\",\"task_id\":\"$task_id\"}" >> "$session_dir/history.jsonl"
    
    echo "=== TDD Cycle Complete ==="
}

# Main execution
main() {
    # Session todo tracking
    local session_todo_id=""
    
    # Update task status to in_progress
    update_task_status "in_progress"
    
    # Update session state
    "$SCRIPT_DIR/update-session-state.sh" "$feature_id" --task="$task_id"
    "$SCRIPT_DIR/update-session-state.sh" "$feature_id" --model="$model"
    
    # Log session start if enabled
    if [[ "$USE_SESSIONS" == "true" ]]; then
        echo "Session management: ENABLED"
        echo "Session name: implement-$feature_id"
        
        # Initialize session tracking
        mkdir -p "$session_dir"
        
        # Log session start in history
        echo "{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"event\":\"session_start\",\"session_name\":\"implement-$feature_id\",\"feature_id\":\"$feature_id\"}" >> "$session_dir/history.jsonl"
        
        # Track in TodoWrite if available
        if [[ -f "$SCRIPT_DIR/track-session-todo.sh" ]]; then
            session_todo_id=$("$SCRIPT_DIR/track-session-todo.sh" start "implement-$feature_id" "$feature_id" "$task_id" "0.20")
        fi
    else
        echo "Session management: DISABLED"
    fi
    
    if [[ "$no_tests" == "true" ]]; then
        # Skip test enforcement (for testing purposes)
        echo "Warning: Skipping test-first enforcement (--no-tests flag)"
        execute_implementation "implement" "$model"
    elif [[ "$tdd" == "true" ]]; then
        # Full TDD cycle
        run_tdd_cycle
    else
        # Standard ATDD approach
        echo "Checking for existing tests..."
        
        if ! check_existing_tests; then
            # Write tests first
            echo "Writing tests first (ATDD approach)..."
            if ! execute_implementation "test" "$model"; then
                echo "Error: Failed to write tests" >&2
                exit 1
            fi
        else
            echo "Tests already written"
        fi
        
        # Proceed with implementation
        echo "Proceeding with implementation..."
        if ! execute_implementation "implement" "$model"; then
            echo "Error: Failed to implement" >&2
            exit 1
        fi
    fi
    
    # Update task status to completed
    update_task_status "completed"
    
    # Log session end if enabled
    if [[ "$USE_SESSIONS" == "true" ]]; then
        echo "{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"event\":\"session_end\",\"session_name\":\"implement-$feature_id\",\"feature_id\":\"$feature_id\",\"task_id\":\"$task_id\"}" >> "$session_dir/history.jsonl"
        
        # Get session cost if available
        local session_cost=""
        local session_tokens=""
        if [[ -f "$SCRIPT_DIR/ai-session.sh" ]]; then
            # Extract cost and tokens from session
            local session_info=$("$SCRIPT_DIR/ai-session.sh" show "implement-$feature_id" 2>/dev/null || true)
            session_cost=$(echo "$session_info" | grep -oP 'Cost: \$\K[0-9.]+' || echo "0")
            session_tokens=$(echo "$session_info" | grep -oP 'Total: \K[0-9]+' || echo "0")
            
            echo
            echo "Session summary:"
            echo "$session_info" | grep -E "(Interactions:|Tokens:|Cost:)" | head -5 || true
        fi
        
        # Update TodoWrite if available
        if [[ -f "$SCRIPT_DIR/track-session-todo.sh" ]] && [[ -n "${session_todo_id:-}" ]]; then
            "$SCRIPT_DIR/track-session-todo.sh" end "implement-$feature_id" "$session_todo_id" "$session_cost" "$session_tokens" "completed"
        fi
    fi
    
    echo "Task $task_id completed successfully"
}

# Execute main logic
main