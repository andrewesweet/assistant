#!/bin/bash
# Discover all valid command files (debug version - includes test files)

set -euo pipefail

# Configuration
COMMANDS_DIR=".claude/commands"

# Function to check if file is a valid command
is_valid_command() {
    local file="$1"
    
    # Skip non-.md files
    [[ "$file" == *.md ]] || return 1
    
    # Skip special files (but allow test.md)
    local basename=$(basename "$file")
    [[ "$basename" =~ ^(README|\..*) ]] && return 1
    
    # Check for YAML front matter
    grep -q "^---$" "$file" 2>/dev/null || return 1
    
    # Check for description field
    grep -q "^description:" "$file" 2>/dev/null || return 1
    
    return 0
}

# Function to get relative command path
get_command_path() {
    local file="$1"
    local rel_path="${file#$COMMANDS_DIR/}"
    echo "${rel_path%.md}"
}

# Main execution
main() {
    # Check if commands directory exists
    if [[ ! -d "$COMMANDS_DIR" ]]; then
        echo "Error: Commands directory not found: $COMMANDS_DIR" >&2
        exit 1
    fi
    
    # Find all .md files
    while IFS= read -r file; do
        if is_valid_command "$file"; then
            get_command_path "$file"
        fi
    done < <(find "$COMMANDS_DIR" -name "*.md" -type f 2>/dev/null | sort)
}

# Run main
main "$@"