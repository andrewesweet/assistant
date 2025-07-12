#!/bin/bash
# AI Assistant Configuration
# This file sets up paths and environment for the AI assistant scripts

# Get the absolute path to the AI assistant installation
export AI_ASSISTANT_HOME="${AI_ASSISTANT_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# Script directories
export AI_ASSISTANT_SCRIPTS="${AI_ASSISTANT_HOME}/scripts"
export AI_ASSISTANT_TEMPLATES="${AI_ASSISTANT_HOME}/templates"
export AI_ASSISTANT_DOCS="${AI_ASSISTANT_HOME}/docs"

# Session directory (user-specific)
export AI_SESSION_DIR="${AI_SESSION_DIR:-$HOME/.ai-sessions}"
export SESSION_DIR="$AI_SESSION_DIR"
export SESSION_ROOT="$AI_SESSION_DIR"

# Ensure session directory exists
mkdir -p "$AI_SESSION_DIR"

# Add scripts to PATH if not already there
if [[ ":$PATH:" != *":$AI_ASSISTANT_SCRIPTS:"* ]]; then
    export PATH="$AI_ASSISTANT_SCRIPTS:$PATH"
fi

# Function to get project root (current working directory)
get_project_root() {
    pwd
}

# Export for use in other scripts
export -f get_project_root