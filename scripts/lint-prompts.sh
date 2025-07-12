#!/bin/bash
# Lint command prompt files for structure and content

set -euo pipefail

# Configuration
REQUIRED_FIELDS=("description")
VALID_CATEGORIES=("planning" "development" "review" "testing" "ai" "utility")
VALID_MODELS=("gemini" "opus" "sonnet")
VALID_TEMPLATE_VARS=("USER" "ARGUMENTS" "CURRENT_DATE" "CURRENT_TIME" "CURRENT_DATETIME" "PWD" "HOME" "FEATURE_ID" "SESSION_PATH" "MODEL")
MAX_PROMPT_LENGTH=10000
SECURITY_CHECK=false

# Allow override of command directory for testing
COMMAND_DIR="${COMMAND_DIR:-.claude/commands}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Parse arguments
while [[ $# -gt 0 ]]; do
    if [[ "$1" == "--security" ]]; then
        SECURITY_CHECK=true
        shift
    else
        break
    fi
done

# Counters
TOTAL_FILES=0
PASSED_FILES=0
FAILED_FILES=0

# Function to extract YAML front matter
extract_yaml() {
    local file="$1"
    awk '/^---$/{f++} f==1{print} /^---$/ && f==2{exit}' "$file"
}

# Function to lint YAML syntax
lint_yaml_syntax() {
    local file="$1"
    local yaml_content="$2"
    
    # Basic YAML syntax checks
    if ! echo "$yaml_content" | grep -q "^---$"; then
        echo -e "${RED}Error:${NC} Missing metadata section in $file"
        return 1
    fi
    
    # Check for proper indentation (no tabs)
    if echo "$yaml_content" | grep -q $'\t'; then
        echo -e "${RED}Error:${NC} Invalid YAML syntax in $file - contains tabs"
        return 1
    fi
    
    # Check for missing colons in key-value pairs
    if echo "$yaml_content" | grep -E "^[a-zA-Z_]+ [^:]" | grep -v "^---"; then
        echo -e "${RED}Error:${NC} Invalid YAML syntax in $file - missing colon in key-value pair"
        return 1
    fi
    
    return 0
}

# Function to lint required fields
lint_required_fields() {
    local file="$1"
    local yaml_content="$2"
    local has_errors=false
    
    for field in "${REQUIRED_FIELDS[@]}"; do
        if ! echo "$yaml_content" | grep -q "^$field:"; then
            echo -e "${RED}Error:${NC} Missing required field: $field in $file"
            has_errors=true
        fi
    done
    
    if [[ "$has_errors" == "true" ]]; then
        return 1
    fi
    return 0
}

# Function to lint category
lint_category() {
    local file="$1"
    local yaml_content="$2"
    
    local category=$(echo "$yaml_content" | awk '/^category:/{gsub(/^category: */, ""); gsub(/"/, ""); print}')
    
    if [[ -z "$category" ]]; then
        echo -e "${YELLOW}Warning:${NC} Missing category in $file"
        return 0
    fi
    
    # Check if category is valid
    local valid=false
    for valid_cat in "${VALID_CATEGORIES[@]}"; do
        if [[ "$category" == "$valid_cat" ]]; then
            valid=true
            break
        fi
    done
    
    if [[ "$valid" == "false" ]]; then
        echo -e "${RED}Error:${NC} Invalid category: $category in $file"
        echo "  Valid categories: ${VALID_CATEGORIES[*]}"
        return 1
    fi
    
    return 0
}

# Function to lint model preference
lint_model_preference() {
    local file="$1"
    local yaml_content="$2"
    
    local model=$(echo "$yaml_content" | awk '/^model_preference:/{gsub(/^model_preference: */, ""); gsub(/"/, ""); print}')
    
    if [[ -z "$model" ]]; then
        return 0  # Model preference is optional
    fi
    
    # Check if model is valid
    local valid=false
    for valid_model in "${VALID_MODELS[@]}"; do
        if [[ "$model" == "$valid_model" ]]; then
            valid=true
            break
        fi
    done
    
    if [[ "$valid" == "false" ]]; then
        echo -e "${RED}Error:${NC} Invalid model_preference: $model in $file"
        echo "  Valid models: ${VALID_MODELS[*]}"
        return 1
    fi
    
    return 0
}

# Function to lint template variables
lint_template_variables() {
    local file="$1"
    local content="$2"
    local has_errors=false
    
    # Find all template variables
    while IFS= read -r var; do
        local valid=false
        for valid_var in "${VALID_TEMPLATE_VARS[@]}"; do
            if [[ "$var" == "$valid_var" ]]; then
                valid=true
                break
            fi
        done
        
        if [[ "$valid" == "false" ]]; then
            echo -e "${RED}Error:${NC} Undefined variable: $var in $file"
            has_errors=true
        fi
    done < <(echo "$content" | grep -o '{{[A-Z_]*}}' | sed 's/[{}]//g' | sort -u)
    
    if [[ "$has_errors" == "true" ]]; then
        return 1
    fi
    return 0
}

# Function to check dangerous patterns
lint_security() {
    local file="$1"
    local content="$2"
    
    # Dangerous patterns to check
    local dangerous_patterns=(
        '\$\('
        '`.*`'
        'eval '
        ' \| *sh'
        ' \| *bash'
        'rm -rf'
        'curl.*\|.*sh'
        'wget.*\|.*sh'
    )
    
    for pattern in "${dangerous_patterns[@]}"; do
        if echo "$content" | grep -E "$pattern" >/dev/null 2>&1; then
            echo -e "${YELLOW}Security warning:${NC} Found dangerous pattern in $file"
            echo "  Pattern: $pattern"
        fi
    done
    
    return 0
}

# Function to check prompt length
lint_length() {
    local file="$1"
    local content="$2"
    
    local length=${#content}
    if [[ $length -gt $MAX_PROMPT_LENGTH ]]; then
        echo -e "${YELLOW}Warning:${NC} Prompt exceeds recommended length in $file"
        echo "  Length: $length characters (max: $MAX_PROMPT_LENGTH)"
    fi
    
    return 0
}

# Function to lint a single file
lint_file() {
    local file="$1"
    local errors=0
    
    # Check file exists
    if [[ ! -f "$file" ]]; then
        echo -e "${RED}Error:${NC} File not found: $file"
        return 1
    fi
    
    # Read file content
    local content=$(cat "$file")
    local yaml_content=$(extract_yaml "$file")
    
    # Run linters
    lint_yaml_syntax "$file" "$yaml_content" || ((errors++))
    lint_required_fields "$file" "$yaml_content" || ((errors++))
    lint_category "$file" "$yaml_content" || ((errors++))
    lint_model_preference "$file" "$yaml_content" || ((errors++))
    lint_template_variables "$file" "$content" || ((errors++))
    lint_length "$file" "$content"
    
    if [[ "$SECURITY_CHECK" == "true" ]]; then
        lint_security "$file" "$content"
    fi
    
    if [[ $errors -eq 0 ]]; then
        echo -e "${GREEN}PASS:${NC} $file"
        return 0
    else
        echo -e "${RED}FAIL:${NC} $file ($errors error(s))"
        return 1
    fi
}

# Main execution
main() {
    local files=("$@")
    
    # If no files specified, lint all command files
    if [[ ${#files[@]} -eq 0 ]]; then
        while IFS= read -r file; do
            files+=("$file")
        done < <(find "$COMMAND_DIR" -name "*.md" -type f 2>/dev/null | grep -v README | sort)
    fi
    
    # Lint each file
    for file in "${files[@]}"; do
        TOTAL_FILES=$((TOTAL_FILES + 1))
        if lint_file "$file"; then
            PASSED_FILES=$((PASSED_FILES + 1))
        else
            FAILED_FILES=$((FAILED_FILES + 1))
        fi
    done
    
    # Summary
    echo ""
    echo "Linting Summary:"
    echo "  Total: $TOTAL_FILES"
    echo "  Passed: $PASSED_FILES"
    echo "  Failed: $FAILED_FILES"
    
    if [[ $TOTAL_FILES -eq 0 ]]; then
        echo -e "${YELLOW}Warning:${NC} No files to lint"
        exit 0
    elif [[ $FAILED_FILES -eq 0 ]]; then
        echo -e "${GREEN}All files passed!${NC}"
        exit 0
    else
        echo -e "${RED}$FAILED_FILES file(s) failed linting${NC}"
        exit 1
    fi
}

# Run main
main "$@"