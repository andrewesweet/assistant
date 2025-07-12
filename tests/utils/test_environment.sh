#!/bin/bash
# Test environment setup utilities

# Set default environment variables
export COMMAND_DIR="${COMMAND_DIR:-.claude/commands}"
export SESSION_ROOT="${SESSION_ROOT:-.ai-session}"
export TEST_ENV=true

# Create safe mktemp function
safe_mktemp() {
    if command -v mktemp >/dev/null 2>&1; then
        mktemp "$@"
    else
        # Fallback for environments without mktemp
        local template="${1:-/tmp/tmp.XXXXXX}"
        local temp_file="${template}.$$.$RANDOM"
        touch "$temp_file"
        echo "$temp_file"
    fi
}

# Export for use in scripts
export -f safe_mktemp

# Setup test directories in current (temp) directory
setup_test_directories() {
    mkdir -p "$COMMAND_DIR"
    mkdir -p "$SESSION_ROOT"
    mkdir -p scripts
    mkdir -p .git/hooks
    mkdir -p bin  # For mock commands
}

# Copy project scripts to test environment
copy_project_scripts() {
    local project_root="${1:-$PROJECT_ROOT}"
    
    if [[ -d "$project_root/scripts" ]]; then
        cp -r "$project_root/scripts/"*.sh scripts/ 2>/dev/null || true
        chmod +x scripts/*.sh 2>/dev/null || true
    fi
}

# Copy project commands to test environment
copy_project_commands() {
    local project_root="${1:-$PROJECT_ROOT}"
    
    if [[ -d "$project_root/$COMMAND_DIR" ]]; then
        cp -r "$project_root/$COMMAND_DIR/"* "$COMMAND_DIR/" 2>/dev/null || true
    fi
}

# Full test environment setup
setup_complete_test_env() {
    local project_root="${1:-$PROJECT_ROOT}"
    
    setup_test_directories
    copy_project_scripts "$project_root"
    copy_project_commands "$project_root"
    
    # Initialize git if needed
    if [[ ! -d .git ]]; then
        git init --quiet
    fi
}

# Cleanup helper
cleanup_test_env() {
    # Only cleanup if we're in a test directory
    if [[ "$TEST_ENV" == "true" ]] && [[ "$PWD" == */tmp* ]]; then
        rm -rf "$COMMAND_DIR" "$SESSION_ROOT" scripts .git
    fi
}