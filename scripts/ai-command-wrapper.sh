#!/bin/bash
# AI Command Wrapper - Robust execution with timeout and error handling
# Enhanced with session management support for Claude

set -euo pipefail

# Configuration
DEFAULT_TIMEOUT=180  # 3 minutes default
DEBUG=${DEBUG:-false}
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
SESSION_DIR="${SESSION_DIR:-$HOME/.ai-sessions}"
MAX_SESSION_NAME_LENGTH=100

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Usage function
usage() {
    echo "Usage: $0 <command> <timeout> [args...]"
    echo ""
    echo "Execute AI commands with timeout and error handling"
    echo ""
    echo "Arguments:"
    echo "  command     AI command to execute (gemini, claude)"
    echo "  timeout     Timeout in seconds (default: $DEFAULT_TIMEOUT)"
    echo "  args        Additional arguments to pass to the command"
    echo ""
    echo "Session Management Options (Claude only):"
    echo "  --session-name NAME   Create or resume a named session"
    echo "  --json                Output in JSON format"
    echo "  -c, --continue        Continue the last conversation"
    echo "  -r, --resume ID       Resume a specific session by ID"
    echo ""
    echo "Environment Variables:"
    echo "  DEBUG=true            Enable verbose debugging output"
    echo "  SESSION_DIR=path      Override session storage directory (default: ~/.ai-sessions)"
    echo ""
    echo "Examples:"
    echo "  $0 gemini 60 -p \"Hello\""
    echo "  $0 claude 120 --model opus -p \"Analyze this code\""
    echo "  $0 claude 60 --session-name myproject -p \"Start new session\""
    echo "  $0 claude 60 --json --session-name myproject -p \"Get JSON response\""
    exit 1
}

# Debug logging function
debug_log() {
    if [[ "$DEBUG" == "true" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $*" >&2
    fi
}

# Error logging function
error_log() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# Warning logging function
warn_log() {
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

# Success logging function
success_log() {
    echo -e "${GREEN}[SUCCESS]${NC} $*" >&2
}

# Session management functions

# Sanitize session name to prevent path traversal and invalid characters
sanitize_session_name() {
    local name="$1"
    
    # Remove leading/trailing spaces
    name=$(echo "$name" | xargs)
    
    # Replace dangerous characters with underscores
    name=$(echo "$name" | sed 's/[^a-zA-Z0-9._-]/_/g')
    
    # Remove path traversal attempts
    name=$(echo "$name" | sed 's/\.\.//g' | sed 's/\///g')
    
    # Truncate if too long
    if [[ ${#name} -gt $MAX_SESSION_NAME_LENGTH ]]; then
        name="${name:0:$MAX_SESSION_NAME_LENGTH}"
    fi
    
    # Default to generated name if empty
    if [[ -z "$name" ]]; then
        name="session-$(date +%Y%m%d-%H%M%S)"
    fi
    
    echo "$name"
}

# Create session directory structure
create_session_directory() {
    local session_name="$1"
    local session_path="$SESSION_DIR/$session_name"
    
    # Create session directory with secure permissions
    if [[ ! -d "$SESSION_DIR" ]]; then
        mkdir -p "$SESSION_DIR"
        chmod 700 "$SESSION_DIR"
    fi
    
    if [[ ! -d "$session_path" ]]; then
        mkdir -p "$session_path"
        chmod 700 "$session_path"
    fi
    
    echo "$session_path"
}

# Store session metadata
store_session_metadata() {
    local session_path="$1"
    local session_id="${2:-}"
    local command="$3"
    local prompt="${4:-}"
    local response="${5:-}"
    local duration_ms="${6:-0}"
    local model="${7:-}"
    
    local metadata_file="$session_path/metadata.json"
    local lock_file="$session_path/.lock"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Use file locking to prevent race conditions
    exec 200>"$lock_file"
    if ! flock -w 5 200; then
        warn_log "Failed to acquire lock for session metadata update"
        return 1
    fi
    
    # Extract token usage from response if available
    local input_tokens=0
    local output_tokens=0
    local cost=0
    
    if [[ -n "$response" ]] && command -v jq >/dev/null 2>&1; then
        # Try to extract token info from JSON response
        if echo "$response" | jq -e '.usage' >/dev/null 2>&1; then
            input_tokens=$(echo "$response" | jq -r '.usage.input_tokens // 0' 2>/dev/null || echo "0")
            output_tokens=$(echo "$response" | jq -r '.usage.output_tokens // 0' 2>/dev/null || echo "0")
        fi
    fi
    
    # Estimate token counts if not provided (rough estimate)
    if [[ "$input_tokens" -eq 0 ]] && [[ -n "$prompt" ]]; then
        # Rough estimate: 1 token per 4 characters
        input_tokens=$(( ${#prompt} / 4 ))
    fi
    if [[ "$output_tokens" -eq 0 ]] && [[ -n "$response" ]]; then
        # Rough estimate: 1 token per 4 characters
        output_tokens=$(( ${#response} / 4 ))
    fi
    
    # Calculate cost based on model (example rates)
    case "$model" in
        *opus*)
            # Opus: $15/$75 per million tokens
            cost=$(echo "scale=6; ($input_tokens * 0.015 + $output_tokens * 0.075) / 1000" | bc 2>/dev/null || echo "0")
            ;;
        *sonnet*|*)
            # Sonnet: $3/$15 per million tokens (default)
            cost=$(echo "scale=6; ($input_tokens * 0.003 + $output_tokens * 0.015) / 1000" | bc 2>/dev/null || echo "0")
            ;;
    esac
    
    # Create interaction record
    local interaction=$(jq -n \
        --arg ts "$timestamp" \
        --arg model "$model" \
        --arg prompt "$prompt" \
        --argjson input "$input_tokens" \
        --argjson output "$output_tokens" \
        --argjson cost "$cost" \
        --argjson duration "$duration_ms" \
        '{
            timestamp: $ts,
            model: $model,
            prompt_preview: ($prompt | if length > 100 then .[:100] + "..." else . end),
            tokens: {
                input: $input,
                output: $output
            },
            cost: $cost,
            duration_ms: $duration
        }')
    
    # Create or update metadata
    if [[ -f "$metadata_file" ]]; then
        # Update existing metadata
        local temp_file=$(mktemp)
        if command -v jq >/dev/null 2>&1; then
            jq --arg ts "$timestamp" \
               --arg sid "$session_id" \
               --arg cmd "$command" \
               --argjson interaction "$interaction" \
               '. + {
                   last_used: $ts,
                   session_id: ($sid // .session_id),
                   command: $cmd,
                   interactions: ((.interactions // []) + [$interaction])
               }' \
               "$metadata_file" > "$temp_file"
            mv "$temp_file" "$metadata_file"
        else
            # Fallback without jq - just update timestamp in a simple way
            sed -i.bak "s/\"last_used\":\"[^\"]*\"/\"last_used\":\"$timestamp\"/" "$metadata_file"
        fi
    else
        # Create new metadata
        if command -v jq >/dev/null 2>&1; then
            jq -n \
                --arg ts "$timestamp" \
                --arg sid "$session_id" \
                --arg cmd "$command" \
                --arg name "$(basename "$session_path")" \
                --argjson interaction "$interaction" \
                '{
                    created_at: $ts,
                    last_used: $ts,
                    session_id: $sid,
                    command: $cmd,
                    session_name: $name,
                    interactions: [$interaction]
                }'> "$metadata_file"
        else
            cat > "$metadata_file" << EOF
{
    "created_at": "$timestamp",
    "last_used": "$timestamp",
    "session_id": "$session_id",
    "command": "$command",
    "session_name": "$(basename "$session_path")"
}
EOF
        fi
    fi
    
    chmod 600 "$metadata_file"
    
    # Release lock
    exec 200>&-
}

# Get session ID from metadata
get_session_id() {
    local session_path="$1"
    local metadata_file="$session_path/metadata.json"
    local lock_file="$session_path/.lock"
    
    if [[ -f "$metadata_file" ]]; then
        # Use shared lock for reading
        exec 201<"$lock_file"
        if ! flock -s -w 5 201; then
            warn_log "Failed to acquire lock for reading session metadata"
            return 1
        fi
        
        local result=""
        if command -v jq >/dev/null 2>&1; then
            result=$(jq -r '.session_id // empty' "$metadata_file")
        else
            # Fallback: grep for session_id
            result=$(grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' "$metadata_file" | cut -d'"' -f4 || true)
        fi
        
        # Release lock
        exec 201<&-
        
        echo "$result"
    fi
}

# Parse JSON response to extract session ID
extract_session_id_from_response() {
    local response="$1"
    
    if command -v jq >/dev/null 2>&1; then
        echo "$response" | jq -r '.session_id // empty' 2>/dev/null || true
    else
        # Fallback: try to extract session_id with grep
        echo "$response" | grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4 || true
    fi
}

# Pre-flight checks
preflight_checks() {
    local command="$1"
    
    debug_log "Starting pre-flight checks for command: $command"
    
    # Check if command exists
    if ! command -v "$command" >/dev/null 2>&1; then
        error_log "Command '$command' not found in PATH"
        error_log "Available AI commands: $(ls /home/sweeand/.npm-global/bin/ | grep -E '(gemini|claude)' | tr '\n' ' ')"
        return 1
    fi
    
    # Check if command is executable
    local cmd_path=$(which "$command")
    if [[ ! -x "$cmd_path" ]]; then
        error_log "Command '$command' at '$cmd_path' is not executable"
        return 1
    fi
    
    # Test basic command functionality
    debug_log "Testing command availability with --help"
    if ! timeout 10 "$command" --help >/dev/null 2>&1; then
        error_log "Command '$command' failed basic --help test"
        return 1
    fi
    
    success_log "Pre-flight checks passed for $command"
    return 0
}

# Validate output
validate_output() {
    local output="$1"
    local command="$2"
    
    debug_log "Validating output from $command"
    
    # Check for empty output
    if [[ -z "$output" ]]; then
        warn_log "Command '$command' produced empty output"
        return 1
    fi
    
    # Check for common error patterns
    if echo "$output" | grep -q "Error:"; then
        warn_log "Command '$command' output contains error message"
        return 1
    fi
    
    # Check minimum output length (more than just whitespace)
    # Claude might give very short responses, so be more lenient
    local min_length=10
    if [[ "$command" == "claude" ]]; then
        min_length=2  # Claude can give very short answers
    fi
    
    if [[ $(echo "$output" | wc -c) -lt $min_length ]]; then
        warn_log "Command '$command' output too short ($(echo "$output" | wc -c) chars, min: $min_length)"
        return 1
    fi
    
    success_log "Output validation passed for $command"
    return 0
}

# Execute command with timeout and monitoring
execute_command() {
    local command="$1"
    local timeout_duration="$2"
    shift 2
    local args=("$@")
    
    # Session management variables
    local session_name=""
    local json_output=false
    local processed_args=()
    local prompt=""
    local has_continue=false
    local has_resume=false
    local resume_id=""
    
    # Process arguments to extract session-related flags
    local i=0
    while [[ $i -lt ${#args[@]} ]]; do
        case "${args[$i]}" in
            --session-name)
                if [[ $((i + 1)) -lt ${#args[@]} ]]; then
                    session_name="${args[$((i + 1))]}"
                    ((i += 2))
                else
                    error_log "--session-name requires an argument"
                    return 1
                fi
                ;;
            --json)
                json_output=true
                ((i++))
                ;;
            -c|--continue)
                has_continue=true
                processed_args+=("${args[$i]}")
                ((i++))
                ;;
            -r|--resume)
                has_resume=true
                processed_args+=("${args[$i]}")
                if [[ $((i + 1)) -lt ${#args[@]} ]] && [[ ! "${args[$((i + 1))]}" =~ ^- ]]; then
                    resume_id="${args[$((i + 1))]}"
                    processed_args+=("$resume_id")
                    ((i += 2))
                else
                    ((i++))
                fi
                ;;
            -p|--prompt)
                processed_args+=("${args[$i]}")
                if [[ $((i + 1)) -lt ${#args[@]} ]]; then
                    prompt="${args[$((i + 1))]}"
                    processed_args+=("${args[$((i + 1))]}")
                    ((i += 2))
                else
                    ((i++))
                fi
                ;;
            *)
                processed_args+=("${args[$i]}")
                ((i++))
                ;;
        esac
    done
    
    # Handle session logic for Claude
    if [[ "$command" == "claude" ]] && [[ -n "$session_name" ]]; then
        session_name=$(sanitize_session_name "$session_name")
        local session_path=$(create_session_directory "$session_name")
        local existing_session_id=$(get_session_id "$session_path")
        
        debug_log "Session name: $session_name"
        debug_log "Session path: $session_path"
        debug_log "Existing session ID: $existing_session_id"
        
        # If we have an existing session and no explicit continue/resume flags
        if [[ -n "$existing_session_id" ]] && [[ "$has_continue" == "false" ]] && [[ "$has_resume" == "false" ]]; then
            # Add continue flag to maintain session
            processed_args=("-c" "${processed_args[@]}")
            debug_log "Adding -c flag to continue existing session"
        fi
        
        # Always add --print for reliable scripting
        if [[ ! " ${processed_args[*]} " =~ " --print " ]]; then
            processed_args+=("--print")
        fi
    fi
    
    debug_log "Executing: $command with timeout $timeout_duration seconds"
    debug_log "Processed arguments: ${processed_args[*]}"
    
    # Create temporary files for output capture
    stdout_file=$(mktemp)
    stderr_file=$(mktemp)
    exit_code_file=$(mktemp)
    
    # Cleanup function
    cleanup() {
        rm -f "$stdout_file" "$stderr_file" "$exit_code_file" 2>/dev/null || true
    }
    trap cleanup EXIT
    
    # Track timing
    local start_time=$(date +%s%N)
    
    # Execute command with timeout - special handling for different commands
    debug_log "Starting command execution..."
    if [[ "$command" == "claude" ]]; then
        # Claude requires special handling for timeout
        local cmd_output
        local exit_code
        
        # Initialize exit code file with default
        echo "0" > "$exit_code_file"
        
        # Use background process with timeout monitoring
        # Claude requires stdin to be closed to prevent hanging
        (
            "$command" "${processed_args[@]}" < /dev/null > "$stdout_file" 2> "$stderr_file"
            echo "$?" > "$exit_code_file"
        ) &
        local cmd_pid=$!
        
        # Monitor for timeout (check every 100ms)
        local elapsed_tenths=0
        local timeout_tenths=$((timeout_duration * 10))
        while [[ $elapsed_tenths -lt $timeout_tenths ]]; do
            if ! kill -0 $cmd_pid 2>/dev/null; then
                # Process finished
                break
            fi
            sleep 0.1
            elapsed_tenths=$((elapsed_tenths + 1))
        done
        
        # Check if still running (timeout)
        if kill -0 $cmd_pid 2>/dev/null; then
            # Timeout occurred
            kill -TERM $cmd_pid 2>/dev/null || true
            sleep 0.5
            kill -KILL $cmd_pid 2>/dev/null || true
            echo "124" > "$exit_code_file"
            warn_log "Claude command timed out after $timeout_duration seconds"
        fi
        
        # Wait for process to fully terminate
        wait $cmd_pid 2>/dev/null || true
    else
        # Other commands can use file redirection
        if timeout "$timeout_duration" "$command" "${processed_args[@]}" > "$stdout_file" 2> "$stderr_file"; then
            echo "0" > "$exit_code_file"
        else
            echo "$?" > "$exit_code_file"
        fi
    fi
    
    local end_time=$(date +%s%N)
    local duration=$(( (end_time - start_time) / 1000000 ))  # Convert to milliseconds
    
    # Read results
    local stdout_content=$(cat "$stdout_file")
    local stderr_content=$(cat "$stderr_file")
    local exit_code=$(cat "$exit_code_file")
    
    debug_log "Command completed with exit code: $exit_code"
    debug_log "Execution time: ${duration}ms"
    
    # Handle timeout
    if [[ $exit_code -eq 124 ]]; then
        error_log "Command '$command' timed out after $timeout_duration seconds"
        error_log "Consider increasing timeout or checking for hanging processes"
        return 124
    fi
    
    # Handle command failure
    if [[ $exit_code -ne 0 ]]; then
        error_log "Command '$command' failed with exit code: $exit_code"
        if [[ -n "$stderr_content" ]]; then
            error_log "Error output: $stderr_content"
        fi
        return $exit_code
    fi
    
    # Validate output
    if ! validate_output "$stdout_content" "$command"; then
        error_log "Output validation failed for command '$command'"
        if [[ -n "$stderr_content" ]]; then
            error_log "Error output: $stderr_content"
        fi
        return 1
    fi
    
    # Handle session metadata for Claude
    if [[ "$command" == "claude" ]] && [[ -n "$session_name" ]]; then
        local session_path="$SESSION_DIR/$session_name"
        
        # Extract session ID from response if available
        local new_session_id=$(extract_session_id_from_response "$stdout_content")
        if [[ -n "$new_session_id" ]]; then
            debug_log "Extracted session ID: $new_session_id"
        fi
        
        # Determine model from arguments
        local model="claude-3-sonnet"  # default
        for arg in "${processed_args[@]}"; do
            if [[ "$arg" == "--model" ]]; then
                model="claude-3-opus"
                break
            fi
        done
        
        # Store session metadata with analytics
        store_session_metadata "$session_path" "$new_session_id" "$command" "$prompt" "$stdout_content" "$duration" "$model"
    fi
    
    # Handle JSON output formatting
    if [[ "$json_output" == true ]] && [[ "$command" == "claude" ]]; then
        # If the output is already JSON, pass it through
        # If not, wrap it in a JSON structure
        if echo "$stdout_content" | jq . >/dev/null 2>&1; then
            # Already valid JSON
            echo "$stdout_content"
        else
            # Wrap in JSON structure
            local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
            local json_response=$(jq -n \
                --arg response "$stdout_content" \
                --arg timestamp "$timestamp" \
                --arg duration "${duration}ms" \
                --arg session "$session_name" \
                '{
                    response: $response,
                    timestamp: $timestamp,
                    duration: $duration,
                    session_name: $session
                }')
            echo "$json_response"
        fi
    else
        # Normal output
        echo "$stdout_content"
    fi
    
    success_log "Command '$command' executed successfully in ${duration}ms"
    return 0
}

# Main execution
main() {
    # Parse arguments
    if [[ $# -lt 2 ]]; then
        usage
    fi
    
    local command="$1"
    local timeout_duration="$2"
    shift 2
    local args=("$@")
    
    # Validate timeout
    if ! [[ "$timeout_duration" =~ ^[0-9]+$ ]]; then
        error_log "Invalid timeout value: $timeout_duration"
        usage
    fi
    
    debug_log "AI Command Wrapper starting..."
    debug_log "Command: $command"
    debug_log "Timeout: $timeout_duration seconds"
    debug_log "Environment: CLAUDECODE=$CLAUDECODE, CLAUDE_CODE_SSE_PORT=$CLAUDE_CODE_SSE_PORT"
    
    # Run pre-flight checks
    if ! preflight_checks "$command"; then
        error_log "Pre-flight checks failed for command: $command"
        return 1
    fi
    
    # Execute command
    if execute_command "$command" "$timeout_duration" "${args[@]}"; then
        debug_log "AI Command Wrapper completed successfully"
        return 0
    else
        local exit_code=$?
        error_log "AI Command Wrapper failed with exit code: $exit_code"
        return $exit_code
    fi
}

# Handle script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi