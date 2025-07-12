#!/bin/bash
# Review-architecture command - Analyze system architecture with Gemini (fallback to Opus)

set -euo pipefail

# Configuration
SESSION_ROOT="${SESSION_ROOT:-.ai-session}"
DATE_FORMAT="+%Y-%m-%dT%H:%M:%SZ"
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

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

# Parse options
full_context=false
focus_area=""
compare_mode=false
compare_dirs=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --full-context)
            full_context=true
            shift
            ;;
        --focus)
            focus_area="$2"
            shift 2
            ;;
        --compare)
            compare_mode=true
            compare_dirs+=("$2")
            compare_dirs+=("$3")
            shift 3
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# Load session state
state_file="$session_dir/state.yaml"
feature_description=""
if [[ -f "$state_file" ]]; then
    feature_description=$(grep "description:" "$state_file" | sed 's/.*description: //' | sed 's/"//g' || true)
fi

# Function to discover architecture files
discover_architecture_files() {
    local arch_files=()
    local arch_dirs=("docs" "architecture" "design" "doc" "Documentation")
    local arch_patterns=("*.md" "*.txt" "*.yaml" "*.yml" "*.json")
    
    # Look for architecture-related directories
    for dir in "${arch_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            for pattern in "${arch_patterns[@]}"; do
                while IFS= read -r file; do
                    if [[ -f "$file" ]]; then
                        arch_files+=("$file")
                    fi
                done < <(find "$dir" -name "$pattern" -type f 2>/dev/null || true)
            done
        fi
    done
    
    # Look for specific architecture files in root
    local root_files=("README.md" "ARCHITECTURE.md" "DESIGN.md" "architecture.md" "design.md")
    for file in "${root_files[@]}"; do
        if [[ -f "$file" ]]; then
            arch_files+=("$file")
        fi
    done
    
    # Look for configuration files that define architecture
    local config_files=("Dockerfile" "docker-compose.yml" "docker-compose.yaml" ".env.example" "package.json" "go.mod" "pom.xml")
    for file in "${config_files[@]}"; do
        if [[ -f "$file" ]]; then
            arch_files+=("$file")
        fi
    done
    
    printf '%s\n' "${arch_files[@]}" | sort -u
}

# Function to log command to history
log_command() {
    local command="$1"
    local model_used="$2"
    local status="$3"
    local start_time="$4"
    local end_time="$5"
    local error_msg="${6:-}"
    local fallback="${7:-false}"
    local architecture_type="${8:-}"
    local components_count="${9:-0}"
    
    # Calculate duration
    local duration_ms=0
    if [[ -n "$start_time" ]] && [[ -n "$end_time" ]]; then
        duration_ms=$(( (end_time - start_time) / 1000000 ))
    fi
    
    # Get agent ID
    local agent="${AGENT_ID:-unknown}"
    
    # Create history entry
    local history_entry="{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\""
    history_entry="$history_entry,\"command\":\"$command\""
    history_entry="$history_entry,\"arguments\":\"\""
    history_entry="$history_entry,\"model\":\"$model_used\""
    history_entry="$history_entry,\"agent\":\"$agent\""
    history_entry="$history_entry,\"status\":\"$status\""
    history_entry="$history_entry,\"duration_ms\":$duration_ms"
    history_entry="$history_entry,\"feature_id\":\"$feature_id\""
    
    if [[ "$fallback" == "true" ]]; then
        history_entry="$history_entry,\"fallback\":true"
    fi
    
    if [[ -n "$feature_description" ]]; then
        history_entry="$history_entry,\"feature_context\":\"$feature_description\""
    fi
    
    # Add architecture context
    if [[ "$status" == "success" ]]; then
        history_entry="$history_entry,\"architecture_context\":{"
        
        # Get directories analyzed
        local dirs_analyzed=$(find . -type d -name "docs" -o -name "architecture" -o -name "design" 2>/dev/null | head -5 | tr '\n' ',' | sed 's/,$//')
        history_entry="$history_entry\"directories_analyzed\":[$(echo "$dirs_analyzed" | awk -F, '{for(i=1;i<=NF;i++) if($i) printf "\"%s\"%s", $i, (i<NF?",":"")}')]"
        
        if [[ -n "$architecture_type" ]]; then
            history_entry="$history_entry,\"architecture_type\":\"$architecture_type\""
        fi
        
        if [[ "$components_count" -gt 0 ]]; then
            history_entry="$history_entry,\"components_count\":$components_count"
        fi
        
        history_entry="$history_entry}"
    fi
    
    if [[ -n "$error_msg" ]]; then
        local error_type="unknown_error"
        if [[ "$error_msg" == *"unavailable"* ]]; then
            error_type="model_error"
        fi
        history_entry="$history_entry,\"error\":\"$error_msg\""
        history_entry="$history_entry,\"error_type\":\"$error_type\""
        history_entry="$history_entry,\"retry_possible\":true"
    fi
    
    # Add artifacts reference if review saved
    if [[ "$status" == "success" ]] && [[ -n "${artifact_path:-}" ]]; then
        history_entry="$history_entry,\"artifacts\":[{\"type\":\"architecture-review\",\"path\":\"$artifact_path\"}]"
    fi
    
    history_entry="$history_entry}"
    
    echo "$history_entry" >> "$session_dir/history.jsonl"
}

# Function to build architecture review prompt
build_architecture_prompt() {
    local prompt="Architecture Review Request

Feature Context: ${feature_description:-No description provided}

"
    
    if [[ "$compare_mode" == "true" ]]; then
        prompt="${prompt}Please compare the following architectures:

=== Current Architecture (${compare_dirs[0]}) ===
"
        if [[ -d "${compare_dirs[0]}" ]]; then
            for file in $(find "${compare_dirs[0]}" -name "*.md" -o -name "*.yaml" -o -name "*.yml" | head -10); do
                prompt="$prompt
File: $file
$(cat "$file" | head -100)
"
            done
        fi
        
        prompt="$prompt

=== Proposed Architecture (${compare_dirs[1]}) ===
"
        if [[ -d "${compare_dirs[1]}" ]]; then
            for file in $(find "${compare_dirs[1]}" -name "*.md" -o -name "*.yaml" -o -name "*.yml" | head -10); do
                prompt="$prompt
File: $file
$(cat "$file" | head -100)
"
            done
        fi
        
        prompt="$prompt

Please compare these architectures and provide:
1. Key differences and changes
2. Migration path and challenges
3. Risk assessment
4. Recommendations for the transition"
    else
        # Standard architecture review
        local arch_files=($(discover_architecture_files))
        
        if [[ ${#arch_files[@]} -eq 0 ]]; then
            echo "Warning: No architecture files found in standard locations" >&2
            prompt="${prompt}No explicit architecture documentation found. Please analyze the codebase structure and infer the architecture.

"
        else
            prompt="${prompt}Architecture files found:
"
            for file in "${arch_files[@]:0:10}"; do  # Limit to first 10 files
                prompt="$prompt
=== File: $file ===
$(cat "$file" | head -200)
"
            done
        fi
        
        prompt="$prompt

Please perform a comprehensive architecture review focusing on:"
        
        if [[ -n "$focus_area" ]]; then
            case "$focus_area" in
                security)
                    prompt="$prompt
1. Security architecture and threat model
2. Authentication and authorization design
3. Data protection and encryption
4. Network security and isolation
5. Vulnerability assessment and security best practices"
                    ;;
                performance)
                    prompt="$prompt
1. Performance bottlenecks and optimization opportunities
2. Scalability limitations and solutions
3. Caching strategies
4. Database and query optimization
5. Resource utilization and efficiency"
                    ;;
                scalability)
                    prompt="$prompt
1. Horizontal and vertical scaling capabilities
2. Load balancing and distribution
3. State management and clustering
4. Database scaling patterns
5. Microservices readiness"
                    ;;
                *)
                    prompt="$prompt
1. Overall architecture quality
2. Design patterns and best practices
3. Component coupling and cohesion
4. Scalability and performance
5. Security considerations"
                    ;;
            esac
        else
            prompt="$prompt
1. Overall architecture quality and patterns
2. Component design and interactions
3. Scalability and performance considerations
4. Security architecture
5. Technology choices and trade-offs
6. Areas for improvement"
        fi
    fi
    
    prompt="$prompt

Format your response as a structured JSON with:
{
    \"status\": \"success\",
    \"review\": {
        \"summary\": \"Brief architecture overview\",
        \"architecture_type\": \"monolithic|microservices|serverless|hybrid\",
        \"components_identified\": number,
        \"patterns_found\": [\"Pattern names\"],
        \"technology_stack\": [\"Technologies used\"],
        \"strengths\": [\"Architecture strengths\"],
        \"weaknesses\": [\"Architecture weaknesses\"],
        \"recommendations\": [\"Improvement recommendations\"],
        \"diagram\": \"Optional architecture diagram in mermaid format\"
    }
}"
    
    echo "$prompt"
}

# Function to save review artifact
save_review_artifact() {
    local review_output="$1"
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local artifact_dir="$session_dir/artifacts"
    local artifact_file="$artifact_dir/review-architecture-${timestamp}-${RANDOM}.json"
    
    mkdir -p "$artifact_dir"
    echo "$review_output" > "$artifact_file"
    echo "$artifact_file"
}

# Function to execute architecture review with model
execute_review_with_model() {
    local model_name="$1"
    local is_fallback="${2:-false}"
    
    # Build review prompt
    local review_prompt=$(build_architecture_prompt)
    
    # Track timing
    local start_time=$(date +%s%N)
    
    # Update state to show model in use
    "$SCRIPT_DIR/update-session-state.sh" "$feature_id" --model="$model_name"
    
    # Execute review
    local output
    local exit_code
    
    echo "Performing architecture review with $model_name model..."
    
    if [[ "$model_name" == "gemini" ]]; then
        local gemini_args=""
        if [[ "$full_context" == "true" ]]; then
            gemini_args="-a"
        fi
        
        if output=$(gemini $gemini_args -p "$review_prompt" 2>&1); then
            exit_code=0
        else
            exit_code=$?
        fi
    elif [[ "$model_name" == "opus" ]]; then
        if output=$(claude --model opus -p "$review_prompt" 2>&1); then
            exit_code=0
        else
            exit_code=$?
        fi
    fi
    
    local end_time=$(date +%s%N)
    
    if [[ $exit_code -eq 0 ]]; then
        # Extract architecture metadata
        local architecture_type=""
        local components_count=0
        
        if echo "$output" | grep -q '"architecture_type"'; then
            architecture_type=$(echo "$output" | grep -o '"architecture_type":\s*"[^"]*"' | cut -d'"' -f4 || echo "")
            components_count=$(echo "$output" | grep -o '"components_identified":\s*[0-9]*' | grep -o '[0-9]*' || echo "0")
        fi
        
        # Save review artifact
        artifact_path=$(save_review_artifact "$output")
        
        # Log success
        log_command "review-architecture" "$model_name" "success" "$start_time" "$end_time" "" "$is_fallback" "$architecture_type" "$components_count"
        
        # Display review
        echo "$output"
        
        return 0
    else
        # Log failure
        log_command "review-architecture" "$model_name" "failure" "$start_time" "$end_time" "$output" "$is_fallback"
        return $exit_code
    fi
}

# Main execution
main() {
    # Try Gemini first (preferred for architecture review)
    if execute_review_with_model "gemini" "false"; then
        exit 0
    fi
    
    # Fallback to Opus
    echo "Gemini unavailable, falling back to Opus..."
    if execute_review_with_model "opus" "true"; then
        exit 0
    fi
    
    # Both models failed
    echo "Error: All models failed to perform architecture review" >&2
    exit 1
}

# Execute main logic
main