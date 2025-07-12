#!/bin/bash
# AI Assistant Installation Script
# Sets up the AI assistant for system-wide use

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the directory of this script
INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}AI Development Assistant Installation${NC}"
echo -e "${BLUE}=====================================${NC}\n"

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command -v claude &> /dev/null; then
    echo -e "${RED}Error: Claude Code CLI not found${NC}"
    echo "Please install Claude Code first: https://docs.anthropic.com/en/docs/claude-code"
    exit 1
fi

if ! command -v gemini &> /dev/null && ! command -v gemini-cli &> /dev/null; then
    echo -e "${YELLOW}Warning: Gemini CLI not found${NC}"
    echo "Some features may be limited without Gemini"
fi

# Create bin directory in user home if it doesn't exist
BIN_DIR="$HOME/bin"
mkdir -p "$BIN_DIR"

# Check if bin directory is in PATH
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    echo -e "${YELLOW}Adding $BIN_DIR to PATH...${NC}"
    
    # Determine shell configuration file
    if [[ -f "$HOME/.bashrc" ]]; then
        SHELL_RC="$HOME/.bashrc"
    elif [[ -f "$HOME/.zshrc" ]]; then
        SHELL_RC="$HOME/.zshrc"
    else
        SHELL_RC="$HOME/.profile"
    fi
    
    # Add to PATH
    echo "" >> "$SHELL_RC"
    echo "# AI Assistant PATH" >> "$SHELL_RC"
    echo 'export PATH="$HOME/bin:$PATH"' >> "$SHELL_RC"
    echo -e "${GREEN}Added to $SHELL_RC${NC}"
    echo -e "${YELLOW}Please run: source $SHELL_RC${NC}"
fi

# Create wrapper commands
echo -e "\n${YELLOW}Creating command wrappers...${NC}"

# Main AI assistant commands
COMMANDS=(
    "plan"
    "implement"
    "verify"
    "status"
    "review-code"
    "review-architecture"
    "escalate"
    "history"
    "switch-feature"
    "ai-session"
    "init-session"
)

for cmd in "${COMMANDS[@]}"; do
    WRAPPER="$BIN_DIR/$cmd"
    cat > "$WRAPPER" << EOF
#!/bin/bash
# AI Assistant wrapper for $cmd command
exec "$INSTALL_DIR/scripts/$cmd.sh" "\$@"
EOF
    chmod +x "$WRAPPER"
    echo -e "${GREEN}Created: $cmd${NC}"
done

# Create special wrappers for commands with different script names
cat > "$BIN_DIR/ai-escalate" << 'EOF'
#!/bin/bash
# AI Assistant wrapper for escalate command
exec "$HOME/assistant/scripts/escalate.sh" "$@"
EOF
chmod +x "$BIN_DIR/ai-escalate"

cat > "$BIN_DIR/ai-history" << 'EOF'
#!/bin/bash
# AI Assistant wrapper for history command
exec "$HOME/assistant/scripts/history.sh" "$@"
EOF
chmod +x "$BIN_DIR/ai-history"

cat > "$BIN_DIR/ai-switch" << 'EOF'
#!/bin/bash
# AI Assistant wrapper for switch-feature command
exec "$HOME/assistant/scripts/switch-feature.sh" "$@"
EOF
chmod +x "$BIN_DIR/ai-switch"

# Set up Claude configuration
echo -e "\n${YELLOW}Setting up Claude configuration...${NC}"

# Ensure Claude directories exist
mkdir -p "$HOME/.claude/commands"

# Copy/update commands
if [[ -d "$INSTALL_DIR/commands" ]]; then
    cp -r "$INSTALL_DIR/commands/"* "$HOME/.claude/commands/"
    echo -e "${GREEN}Updated Claude slash commands${NC}"
fi

# Copy/update CLAUDE.md
if [[ -f "$INSTALL_DIR/CLAUDE.md" ]]; then
    if [[ -f "$HOME/.claude/CLAUDE.md" ]]; then
        echo -e "${YELLOW}Existing CLAUDE.md found. Creating backup...${NC}"
        cp "$HOME/.claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md.backup"
    fi
    cp "$INSTALL_DIR/CLAUDE.md" "$HOME/.claude/"
    echo -e "${GREEN}Updated CLAUDE.md${NC}"
fi

# Update settings.json
SETTINGS_FILE="$HOME/.claude/settings.json"
if [[ -f "$SETTINGS_FILE" ]]; then
    echo -e "${YELLOW}Existing settings.json found. Please manually merge AI assistant settings.${NC}"
    echo -e "AI assistant environment variables needed:"
    echo '  "AI_ASSISTANT_HOME": "'$INSTALL_DIR'",'
    echo '  "AI_ASSISTANT_SCRIPTS": "'$INSTALL_DIR'/scripts",'
    echo '  "AI_SESSION_DIR": "$HOME/.ai-sessions"'
else
    cat > "$SETTINGS_FILE" << EOF
{
  "env": {
    "AI_ASSISTANT_HOME": "$INSTALL_DIR",
    "AI_ASSISTANT_SCRIPTS": "$INSTALL_DIR/scripts",
    "AI_SESSION_DIR": "\${HOME}/.ai-sessions",
    "PATH": "\${HOME}/bin:\${PATH}"
  }
}
EOF
    echo -e "${GREEN}Created settings.json${NC}"
fi

# Create session directory
mkdir -p "$HOME/.ai-sessions"
echo -e "${GREEN}Created session directory${NC}"

echo -e "\n${GREEN}Installation complete!${NC}"
echo -e "\n${BLUE}Next steps:${NC}"
echo -e "1. Run: ${YELLOW}source $SHELL_RC${NC} (or restart your terminal)"
echo -e "2. Test with: ${YELLOW}status${NC}"
echo -e "3. Start a new feature: ${YELLOW}init-session my-feature${NC}"
echo -e "\n${BLUE}Available commands:${NC}"
for cmd in "${COMMANDS[@]}"; do
    echo -e "  - ${GREEN}$cmd${NC}"
done
echo -e "\n${BLUE}Documentation:${NC}"
echo -e "  - Main guide: ${YELLOW}$INSTALL_DIR/docs/AI_ORCHESTRATOR_GUIDE.md${NC}"
echo -e "  - Session guide: ${YELLOW}$INSTALL_DIR/docs/AI_SESSION_MANAGEMENT_GUIDE.md${NC}"