#!/bin/bash
# Validate command file structure and metadata

set -euo pipefail

# Configuration
REQUIRED_FIELDS=("description")
OPTIONAL_FIELDS=("category" "model_preference" "requires_context" "timeout_seconds" "max_retries")
VALID_CATEGORIES=("planning" "development" "review" "testing" "ai" "utility")
VALID_MODELS=("gemini" "opus" "sonnet")

# Allow override of command directory for testing
COMMAND_DIR="${COMMAND_DIR:-.claude/commands}"

# Function to validate YAML front matter
validate_yaml_front_matter() {
    local file="$1"
    local has_errors=false
    
    # Check for YAML front matter markers
    if ! grep -q "^---$" "$file"; then
        echo "Error: Missing metadata section in $file"
        echo "  Expected: YAML front matter between --- markers"
        return 1
    fi
    
    # Extract YAML front matter
    local yaml_content=$(awk '/^---$/{f++} f==1{print} /^---$/ && f==2{exit}' "$file")
    
    # Check for required fields
    for field in "${REQUIRED_FIELDS[@]}"; do
        if ! echo "$yaml_content" | grep -q "^$field:"; then
            echo "Error: Missing required field '$field' in $file"
            has_errors=true
        fi
    done
    
    # Validate category if present
    local category=$(echo "$yaml_content" | awk '/^category:/{gsub(/^category: */, ""); gsub(/"/, ""); print}')
    if [[ -n "$category" ]]; then
        local valid=false
        for valid_cat in "${VALID_CATEGORIES[@]}"; do
            if [[ "$category" == "$valid_cat" ]]; then
                valid=true
                break
            fi
        done
        if [[ "$valid" == "false" ]]; then
            echo "Warning: Invalid category '$category' in $file"
            echo "  Valid categories: ${VALID_CATEGORIES[*]}"
        fi
    else
        echo "Warning: Missing category in $file"
    fi
    
    # Validate model_preference if present
    local model=$(echo "$yaml_content" | awk '/^model_preference:/{gsub(/^model_preference: */, ""); gsub(/"/, ""); print}')
    if [[ -n "$model" ]]; then
        local valid=false
        for valid_model in "${VALID_MODELS[@]}"; do
            if [[ "$model" == "$valid_model" ]]; then
                valid=true
                break
            fi
        done
        if [[ "$valid" == "false" ]]; then
            echo "Error: Invalid model_preference '$model' in $file"
            echo "  Valid models: ${VALID_MODELS[*]}"
            has_errors=true
        fi
    fi
    
    # Check for unknown fields
    while IFS= read -r line; do
        if [[ "$line" =~ ^[a-zA-Z_]+: ]]; then
            local field=$(echo "$line" | cut -d: -f1)
            local known=false
            
            # Check against required and optional fields
            for known_field in "${REQUIRED_FIELDS[@]}" "${OPTIONAL_FIELDS[@]}"; do
                if [[ "$field" == "$known_field" ]]; then
                    known=true
                    break
                fi
            done
            
            if [[ "$known" == "false" ]] && [[ "$field" != "---" ]]; then
                echo "Warning: Unknown field '$field' in $file"
            fi
        fi
    done <<< "$yaml_content"
    
    if [[ "$has_errors" == "true" ]]; then
        return 1
    fi
    
    return 0
}

# Function to validate command content
validate_command_content() {
    local file="$1"
    
    # Check file is not empty
    if [[ ! -s "$file" ]]; then
        echo "Error: Command file is empty: $file"
        return 1
    fi
    
    # Check for content after YAML front matter
    local has_content=$(awk '/^---$/{f++} f==2{found=1} f==2 && NF{has_content=1; exit} END{print has_content+0}' "$file")
    if [[ "$has_content" -eq 0 ]]; then
        echo "Warning: No content after metadata in $file"
    fi
    
    return 0
}

# Main validation function
validate_command() {
    local file="$1"
    local overall_status=0
    
    echo "Validating: $file"
    
    # Validate YAML front matter
    if ! validate_yaml_front_matter "$file"; then
        overall_status=1
    fi
    
    # Validate content
    if ! validate_command_content "$file"; then
        overall_status=1
    fi
    
    if [[ $overall_status -eq 0 ]]; then
        echo "  ✓ Valid"
    else
        echo "  ✗ Invalid"
    fi
    
    return $overall_status
}

# Main execution
main() {
    local files=("$@")
    local total=0
    local passed=0
    local failed=0
    
    # If no files specified, validate all
    if [[ ${#files[@]} -eq 0 ]]; then
        while IFS= read -r file; do
            files+=("$file")
        done < <(find "$COMMAND_DIR" -name "*.md" -type f 2>/dev/null | grep -v README)
    fi
    
    # Validate each file
    for file in "${files[@]}"; do
        if [[ -f "$file" ]]; then
            ((total++))
            if validate_command "$file"; then
                ((passed++))
            else
                ((failed++))
            fi
            echo ""
        else
            echo "Error: File not found: $file"
        fi
    done
    
    # Summary
    echo "Validation Summary:"
    echo "  Total: $total"
    echo "  Passed: $passed"
    echo "  Failed: $failed"
    
    if [[ $failed -gt 0 ]]; then
        exit 1
    fi
}

# Run validation
main "$@"