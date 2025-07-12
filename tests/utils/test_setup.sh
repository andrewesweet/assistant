#!/bin/bash
# Test setup utilities

# Source environment helpers
source "$(dirname "${BASH_SOURCE[0]}")/test_environment.sh"

# Get the project root directory
get_project_root() {
    if [[ -n "${PROJECT_ROOT:-}" ]]; then
        echo "$PROJECT_ROOT"
    else
        local script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
        cd "$script_dir/../.." && pwd
    fi
}

# Copy scripts to test environment
setup_test_scripts() {
    local project_root=$(get_project_root)
    
    # Source test environment utilities
    source "$project_root/test/utils/test_environment.sh"
    
    # Setup complete test environment
    setup_complete_test_env "$project_root"
}

# Setup complete test environment
setup_full_test_env() {
    setup_test_scripts
    
    # Create other necessary directories
    mkdir -p .ai-session
    mkdir -p .git/hooks
    
    # Initialize git if needed (for pre-commit tests)
    if [[ ! -d .git ]]; then
        git init --quiet
    fi
}