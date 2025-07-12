#!/bin/bash
# Generate help content by discovering all commands

set -euo pipefail

# Configuration
COMMANDS_DIR="${COMMAND_DIR:-.claude/commands}"
SHOW_CATEGORIES=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --with-categories)
            SHOW_CATEGORIES=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Function to extract description from command file
get_description() {
    local file="$1"
    local desc=""
    
    # Extract description from YAML front matter
    if [[ -f "$file" ]]; then
        desc=$(awk '/^---$/{f=1; next} /^---$/{f=0} f && /^description:/{gsub(/^description: */, ""); gsub(/"/, ""); print}' "$file" | head -1)
    fi
    
    echo "${desc:-No description}"
}

# Function to extract category from command file
get_category() {
    local file="$1"
    local category=""
    
    if [[ -f "$file" ]]; then
        category=$(awk '/^---$/{f=1; next} /^---$/{f=0} f && /^category:/{gsub(/^category: */, ""); gsub(/"/, ""); print}' "$file" | head -1)
    fi
    
    echo "${category:-uncategorized}"
}

# Discover all command files
find_commands() {
    find "$COMMANDS_DIR" -name "*.md" -type f 2>/dev/null | \
        grep -v -E "(README|\.hidden|^\.|/\.)" | \
        grep -v -E "test-" | \
        sort
}

# Generate command list
generate_command_list() {
    local commands=()
    local categories=()
    
    while IFS= read -r file; do
        # Skip if file doesn't have valid YAML front matter
        if ! grep -q "^---$" "$file" 2>/dev/null; then
            continue
        fi
        
        # Get relative path and convert to command name
        local rel_path="${file#$COMMANDS_DIR/}"
        local cmd_name="/${rel_path%.md}"
        
        # Get description and category
        local desc=$(get_description "$file")
        local category=$(get_category "$file")
        
        # Store command info
        if [[ "$SHOW_CATEGORIES" == "true" ]]; then
            categories+=("$category|$cmd_name - $desc")
        else
            commands+=("$cmd_name - $desc")
        fi
    done < <(find_commands)
    
    # Output commands
    if [[ "$SHOW_CATEGORIES" == "true" ]]; then
        # Group by category
        local current_category=""
        printf '%s\n' "${categories[@]}" | sort | while IFS='|' read -r cat cmd; do
            if [[ "$cat" != "$current_category" ]]; then
                current_category="$cat"
                echo -e "\n${current_category^}:"
            fi
            echo "  $cmd"
        done
    else
        # Simple sorted list
        printf '%s\n' "${commands[@]}"
    fi
}

# Main execution
main() {
    # Check if commands directory exists
    if [[ ! -d "$COMMANDS_DIR" ]]; then
        echo "Error: Commands directory not found: $COMMANDS_DIR"
        exit 1
    fi
    
    # Generate and output help content
    if [[ -f "$COMMANDS_DIR/help.md" ]]; then
        # Read help template
        help_content=$(cat "$COMMANDS_DIR/help.md")
        
        # Generate commands list
        commands_list=$(generate_command_list)
        
        # Replace placeholder
        echo "${help_content//\{\{COMMANDS\}\}/$commands_list}"
    else
        # Fallback if no help template
        echo "Available Commands:"
        echo ""
        generate_command_list
    fi
}

# Run main function
main "$@"