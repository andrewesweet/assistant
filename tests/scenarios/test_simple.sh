#!/bin/bash
# Simple test to debug environment

set -euo pipefail

# Set project root
PROJECT_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
export PROJECT_ROOT

# Source test harness
source "$(dirname "$0")/../test-command.sh"
source "$(dirname "$0")/../utils/test_setup.sh"

test_environment() {
    echo "Current directory: $(pwd)"
    echo "PROJECT_ROOT: $PROJECT_ROOT"
    
    # Setup scripts
    setup_test_scripts
    
    echo "Scripts directory contents:"
    ls -la scripts/ || echo "No scripts directory"
    
    echo "Claude commands directory:"
    ls -la .claude/commands/ || echo "No commands directory"
}

# Run test
run_test_scenario "Environment check" test_environment