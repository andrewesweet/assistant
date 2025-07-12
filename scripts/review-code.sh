#!/bin/bash
# Review-code command - Perform deep code analysis using Opus model

set -euo pipefail

# Configuration
SESSION_ROOT="${SESSION_ROOT:-.ai-session}"
DATE_FORMAT="+%Y-%m-%dT%H:%M:%SZ"
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# Get feature ID
if [[ $# -lt 1 ]]; then
    echo "Error: Feature ID required" >&2
    echo "Usage: $0 <feature-id> <file1> [file2...] [options]" >&2
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

# Parse files and options
files=()
focus_area=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --focus)
            focus_area="$2"
            shift 2
            ;;
        *)
            # Check if file exists
            if [[ -f "$1" ]]; then
                files+=("$1")
            else
                echo "Error: File not found: $1" >&2
                exit 1
            fi
            shift
            ;;
    esac
done

if [[ ${#files[@]} -eq 0 ]]; then
    echo "Error: At least one file required for review" >&2
    exit 1
fi

# Load session state
state_file="$session_dir/state.yaml"
feature_description=""
if [[ -f "$state_file" ]]; then
    feature_description=$(grep "description:" "$state_file" | sed 's/.*description: //' | sed 's/"//g' || true)
fi

# Function to get file metadata
get_file_metadata() {
    local file="$1"
    local size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo "0")
    local lines=$(wc -l < "$file")
    echo "{\"path\":\"$file\",\"size_bytes\":$size,\"lines\":$lines}"
}

# Function to log command to history
log_command() {
    local command="$1"
    local model_used="$2"
    local status="$3"
    local start_time="$4"
    local end_time="$5"
    local error_msg="${6:-}"
    local findings_count="${7:-0}"
    local critical_findings="${8:-0}"
    
    # Calculate duration
    local duration_ms=0
    if [[ -n "$start_time" ]] && [[ -n "$end_time" ]]; then
        duration_ms=$(( (end_time - start_time) / 1000000 ))
    fi
    
    # Build files array for JSON
    local files_json="["
    local first=true
    for f in "${files[@]}"; do
        if [[ "$first" == "true" ]]; then
            first=false
        else
            files_json="$files_json,"
        fi
        files_json="$files_json\"$f\""
    done
    files_json="$files_json]"
    
    # Get agent ID
    local agent="${AGENT_ID:-unknown}"
    
    # Create history entry
    local history_entry="{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\""
    history_entry="$history_entry,\"command\":\"$command\""
    history_entry="$history_entry,\"arguments\":\"${files[*]}\""
    history_entry="$history_entry,\"model\":\"$model_used\""
    history_entry="$history_entry,\"agent\":\"$agent\""
    history_entry="$history_entry,\"status\":\"$status\""
    history_entry="$history_entry,\"duration_ms\":$duration_ms"
    history_entry="$history_entry,\"feature_id\":\"$feature_id\""
    
    if [[ -n "$feature_description" ]]; then
        history_entry="$history_entry,\"feature_context\":\"$feature_description\""
    fi
    
    # Add review context
    history_entry="$history_entry,\"review_context\":{"
    history_entry="$history_entry\"files_reviewed\":$files_json"
    history_entry="$history_entry,\"file_count\":${#files[@]}"
    
    # Add file metadata
    local total_size=0
    local total_lines=0
    for f in "${files[@]}"; do
        local size=$(stat -c%s "$f" 2>/dev/null || stat -f%z "$f" 2>/dev/null || echo "0")
        local lines=$(wc -l < "$f")
        total_size=$((total_size + size))
        total_lines=$((total_lines + lines))
    done
    history_entry="$history_entry,\"file_size_bytes\":$total_size"
    history_entry="$history_entry,\"lines_reviewed\":$total_lines"
    
    if [[ "$status" == "success" ]]; then
        history_entry="$history_entry,\"findings_count\":$findings_count"
        history_entry="$history_entry,\"critical_findings\":$critical_findings"
    fi
    
    history_entry="$history_entry}"
    
    if [[ -n "$error_msg" ]]; then
        local error_type="unknown_error"
        if [[ "$error_msg" == *"Rate limit"* ]] || [[ "$error_msg" == *"unavailable"* ]]; then
            error_type="model_error"
        fi
        history_entry="$history_entry,\"error\":\"$error_msg\""
        history_entry="$history_entry,\"error_type\":\"$error_type\""
        history_entry="$history_entry,\"retry_possible\":true"
    fi
    
    # Add artifacts reference if review saved
    if [[ "$status" == "success" ]] && [[ -n "${artifact_path:-}" ]]; then
        history_entry="$history_entry,\"artifacts\":[{\"type\":\"review\",\"path\":\"$artifact_path\"}]"
    fi
    
    history_entry="$history_entry}"
    
    echo "$history_entry" >> "$session_dir/history.jsonl"
}

# Function to build review prompt
build_review_prompt() {
    local prompt="Code Review Request

Feature Context: ${feature_description:-No description provided}

Files to review:
"
    
    # Add file contents
    for file in "${files[@]}"; do
        prompt="$prompt
=== File: $file ===
$(cat "$file")
"
    done
    
    prompt="$prompt

Please perform a comprehensive code review focusing on:
1. Code quality and best practices
2. Potential bugs and edge cases
3. Security vulnerabilities
4. Performance considerations
5. Maintainability and readability
6. Test coverage suggestions
7. Documentation completeness"
    
    # Add focus area if specified
    if [[ -n "$focus_area" ]]; then
        prompt="$prompt

Special focus area: $focus_area"
    fi
    
    # Add security emphasis for auth-related code
    if grep -q -i "auth\|password\|secret\|token\|credential" <<< "${files[*]}" 2>/dev/null; then
        prompt="$prompt

IMPORTANT: This code appears to handle authentication or sensitive data.
Please pay special attention to security best practices and potential vulnerabilities."
    fi
    
    prompt="$prompt

Format your response as a structured JSON with:
{
    \"status\": \"success\",
    \"review\": {
        \"summary\": \"Brief overview\",
        \"findings\": [
            {
                \"severity\": \"critical|major|minor|suggestion\",
                \"file\": \"filename\",
                \"line\": line_number,
                \"issue\": \"Description of the issue\",
                \"recommendation\": \"How to fix it\"
            }
        ],
        \"recommendations\": [\"General recommendations\"],
        \"security_assessment\": \"Security review if applicable\",
        \"performance_notes\": \"Performance observations\"
    }
}"
    
    echo "$prompt"
}

# Function to save review artifact
save_review_artifact() {
    local review_output="$1"
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local artifact_dir="$session_dir/artifacts"
    local artifact_file="$artifact_dir/review-code-${timestamp}-${RANDOM}.json"
    
    mkdir -p "$artifact_dir"
    echo "$review_output" > "$artifact_file"
    echo "$artifact_file"
}

# Function to execute code review
execute_review() {
    local model_name="opus"  # Always use Opus for deep code analysis
    
    # Build review prompt
    local review_prompt=$(build_review_prompt)
    
    # Track timing
    local start_time=$(date +%s%N)
    
    # Update state to show model in use
    "$SCRIPT_DIR/update-session-state.sh" "$feature_id" --model="$model_name"
    
    # Execute review with Opus
    local output
    local exit_code
    
    echo "Performing code review with Opus model..."
    
    if output=$(claude --model opus -p "$review_prompt" 2>&1); then
        exit_code=0
    else
        exit_code=$?
    fi
    
    local end_time=$(date +%s%N)
    
    if [[ $exit_code -eq 0 ]]; then
        # Process review output
        local findings_count=0
        local critical_findings=0
        
        # Try to extract findings count from JSON
        if echo "$output" | grep -q '"findings"'; then
            findings_count=$(echo "$output" | grep -o '"severity"' | wc -l || echo "0")
            critical_findings=$(echo "$output" | grep -o '"severity":\s*"critical"' | wc -l || echo "0")
        fi
        
        # Save review artifact
        artifact_path=$(save_review_artifact "$output")
        
        # Log success
        log_command "review-code" "$model_name" "success" "$start_time" "$end_time" "" "$findings_count" "$critical_findings"
        
        # Display review
        echo "$output"
        
        return 0
    else
        # Log failure
        log_command "review-code" "$model_name" "failure" "$start_time" "$end_time" "$output"
        echo "Error: $output" >&2
        return $exit_code
    fi
}

# Main execution
main() {
    # Execute review
    if ! execute_review; then
        echo "Error: Code review failed" >&2
        exit 1
    fi
}

# Execute main logic
main