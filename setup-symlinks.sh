#!/bin/bash
# Setup symlinks for AI Development Assistant
# This creates symlinks from ~/.claude to the assistant repository

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the directory of this script (the assistant repo)
ASSISTANT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}AI Development Assistant - Symlink Setup${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Ensure ~/.claude directory exists
mkdir -p ~/.claude

# Function to create symlink with backup
create_symlink() {
    local source="$1"
    local target="$2"
    local name="$3"
    
    if [[ -L "$target" ]]; then
        echo -e "${YELLOW}Symlink already exists: $name${NC}"
    elif [[ -e "$target" ]]; then
        echo -e "${YELLOW}Backing up existing $name to ${target}.backup${NC}"
        mv "$target" "${target}.backup"
        ln -s "$source" "$target"
        echo -e "${GREEN}Created symlink: $name${NC}"
    else
        ln -s "$source" "$target"
        echo -e "${GREEN}Created symlink: $name${NC}"
    fi
}

# 1. Symlink commands directory
echo -e "${YELLOW}Setting up command symlinks...${NC}"
if [[ -d ~/.claude/commands ]] && [[ ! -L ~/.claude/commands ]]; then
    # If commands directory exists and is not a symlink, handle each file
    mkdir -p ~/.claude/commands.backup
    if [[ -n "$(ls -A ~/.claude/commands 2>/dev/null)" ]]; then
        mv ~/.claude/commands/* ~/.claude/commands.backup/ 2>/dev/null || true
    fi
    rmdir ~/.claude/commands
fi

# Create commands directory symlink
create_symlink "$ASSISTANT_DIR/commands" ~/.claude/commands "commands directory"

# 2. Symlink CLAUDE.md
echo -e "\n${YELLOW}Setting up CLAUDE.md symlink...${NC}"
create_symlink "$ASSISTANT_DIR/CLAUDE.md" ~/.claude/CLAUDE.md "CLAUDE.md"

# 3. Create wrapper scripts in ~/bin
echo -e "\n${YELLOW}Creating command wrappers...${NC}"
mkdir -p ~/bin

# Check if ~/bin is in PATH
if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
    echo -e "${YELLOW}Note: ~/bin is not in your PATH${NC}"
    echo -e "Add this to your ~/.bashrc or ~/.zshrc:"
    echo -e '  export PATH="$HOME/bin:$PATH"'
fi

# Create wrapper functions
create_wrapper() {
    local cmd="$1"
    local script="${2:-$1}"
    local wrapper="$HOME/bin/$cmd"
    
    cat > "$wrapper" << EOF
#!/bin/bash
# AI Assistant wrapper for $cmd command
exec "$ASSISTANT_DIR/scripts/$script.sh" "\$@"
EOF
    chmod +x "$wrapper"
    echo -e "${GREEN}Created wrapper: $cmd${NC}"
}

# Create all wrappers
for cmd in plan implement verify status review-code review-architecture escalate history switch-feature ai-session init-session; do
    create_wrapper "$cmd"
done

# Create special named wrappers
create_wrapper "ai-escalate" "escalate"
create_wrapper "ai-history" "history"
create_wrapper "ai-switch" "switch-feature"

# 4. Update settings.json with AI assistant paths
echo -e "\n${YELLOW}Updating settings.json...${NC}"
SETTINGS_FILE="$HOME/.claude/settings.json"

if [[ -f "$SETTINGS_FILE" ]]; then
    echo -e "${YELLOW}Existing settings.json found${NC}"
    echo -e "Please manually add these environment variables to your settings.json:"
    echo '  "env": {'
    echo '    "AI_ASSISTANT_HOME": "'$ASSISTANT_DIR'",'
    echo '    "AI_ASSISTANT_SCRIPTS": "'$ASSISTANT_DIR'/scripts",'
    echo '    "AI_SESSION_DIR": "$HOME/.ai-sessions"'
    echo '  }'
else
    # Create new settings.json
    cat > "$SETTINGS_FILE" << EOF
{
  "env": {
    "AI_ASSISTANT_HOME": "$ASSISTANT_DIR",
    "AI_ASSISTANT_SCRIPTS": "$ASSISTANT_DIR/scripts",
    "AI_SESSION_DIR": "\${HOME}/.ai-sessions"
  }
}
EOF
    echo -e "${GREEN}Created settings.json${NC}"
fi

# 5. Create session directory
mkdir -p ~/.ai-sessions
echo -e "${GREEN}Created session directory${NC}"

echo -e "\n${GREEN}Setup complete!${NC}"
echo -e "\n${BLUE}Next steps:${NC}"
echo -e "1. Run: ${YELLOW}source ~/.bashrc${NC} (or restart your terminal)"
echo -e "2. Test with: ${YELLOW}status${NC}"
echo -e "3. Start using AI assistant commands!"
echo -e "\n${BLUE}All files are symlinked to:${NC} ${YELLOW}$ASSISTANT_DIR${NC}"
echo -e "${BLUE}To update, just git pull in the assistant repository${NC}"