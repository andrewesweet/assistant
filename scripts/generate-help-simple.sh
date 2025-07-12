#!/bin/bash
# Simple help generator - lists all commands with descriptions

set -euo pipefail

# Configuration
COMMAND_DIR="${COMMAND_DIR:-.claude/commands}"

# Function to extract description from markdown
extract_description() {
    local file="$1"
    # Extract description from YAML front matter
    if grep -q "^---" "$file"; then
        # Has YAML front matter
        awk '/^---/{count++; next} count==1 && /^description:/ {gsub(/^description: *|"/, ""); print; exit}' "$file"
    fi
}

# Function to get command path from file path
get_command_path() {
    local file="$1"
    local cmd_path="${file#$COMMAND_DIR/}"
    cmd_path="${cmd_path%.md}"
    echo "/$cmd_path"
}

# Main function
main() {
    local with_categories=false
    
    # Parse arguments
    if [[ "${1:-}" == "--with-categories" ]]; then
        with_categories=true
    fi
    
    echo "Available Commands:"
    echo "=================="
    echo
    
    if [[ "$with_categories" == "true" ]]; then
        # Group by category
        declare -A categories
        
        # Collect commands by category
        while IFS= read -r file; do
            if [[ -f "$file" ]] && [[ "$file" == *.md ]]; then
                desc=$(extract_description "$file")
                if [[ -n "$desc" ]]; then
                    cmd_path=$(get_command_path "$file")
                    # Extract category
                    category=$(awk '/^---/{count++; next} count==1 && /^category:/ {gsub(/^category: *|"/, ""); print; exit}' "$file")
                    category="${category:-uncategorized}"
                    
                    # Capitalize first letter
                    category_display="$(echo "${category:0:1}" | tr '[:lower:]' '[:upper:]')${category:1}"
                    
                    # Append to category
                    if [[ -z "${categories[$category_display]:-}" ]]; then
                        categories[$category_display]="$cmd_path - $desc"
                    else
                        categories[$category_display]+=$'\n'"$cmd_path - $desc"
                    fi
                fi
            fi
        done < <(find "$COMMAND_DIR" -type f -name "*.md" 2>/dev/null)
        
        # Display by category
        for category in "${!categories[@]}"; do
            echo "$category:"
            echo "${categories[$category]}" | sort
            echo
        done
    else
        # Simple alphabetical list
        while IFS= read -r file; do
            if [[ -f "$file" ]] && [[ "$file" == *.md ]]; then
                desc=$(extract_description "$file")
                if [[ -n "$desc" ]]; then
                    cmd_path=$(get_command_path "$file")
                    echo "$cmd_path - $desc"
                fi
            fi
        done < <(find "$COMMAND_DIR" -type f -name "*.md" 2>/dev/null | sort)
    fi
}

# Run main
main "$@"