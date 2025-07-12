#!/bin/bash
# Verify that agents have acknowledged the binding contract

set -euo pipefail

# Configuration
CONTRACT_FILE="docs/session-state-spec.md"
ACKNOWLEDGMENT_FILE=".ai-session/contract-acknowledgment.md"
CONTRACT_VERSION="1.0"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Function to calculate contract checksum
calculate_checksum() {
    if [[ -f "$CONTRACT_FILE" ]]; then
        sha256sum "$CONTRACT_FILE" | cut -d' ' -f1
    else
        echo "ERROR: Contract file not found: $CONTRACT_FILE" >&2
        return 1
    fi
}

# Function to verify acknowledgment
verify_acknowledgment() {
    local agent_name="${1:-}"
    
    if [[ ! -f "$ACKNOWLEDGMENT_FILE" ]]; then
        echo -e "${RED}FAIL:${NC} No contract acknowledgment found at $ACKNOWLEDGMENT_FILE"
        return 1
    fi
    
    # Extract fields from acknowledgment
    local ack_version=$(grep "Contract Version:" "$ACKNOWLEDGMENT_FILE" | cut -d' ' -f3)
    local ack_checksum=$(grep "Checksum:" "$ACKNOWLEDGMENT_FILE" | cut -d' ' -f2)
    local ack_agent=$(grep "Agent:" "$ACKNOWLEDGMENT_FILE" | cut -d' ' -f2-)
    
    # Calculate current contract checksum
    local current_checksum=$(calculate_checksum)
    
    # Verify version
    if [[ "$ack_version" != "$CONTRACT_VERSION" ]]; then
        echo -e "${RED}FAIL:${NC} Wrong contract version"
        echo "  Expected: $CONTRACT_VERSION"
        echo "  Found: $ack_version"
        return 1
    fi
    
    # Verify checksum
    if [[ "$ack_checksum" != "$current_checksum" ]]; then
        echo -e "${YELLOW}WARNING:${NC} Contract has changed since acknowledgment"
        echo "  Original checksum: $ack_checksum"
        echo "  Current checksum: $current_checksum"
        echo "  Re-acknowledgment required"
        return 1
    fi
    
    # Verify agent name if provided
    if [[ -n "$agent_name" ]] && [[ "$ack_agent" != "$agent_name" ]]; then
        echo -e "${YELLOW}WARNING:${NC} Agent name mismatch"
        echo "  Expected: $agent_name"
        echo "  Found: $ack_agent"
    fi
    
    echo -e "${GREEN}PASS:${NC} Valid contract acknowledgment found"
    echo "  Agent: $ack_agent"
    echo "  Version: $ack_version"
    echo "  Checksum verified"
    return 0
}

# Function to create acknowledgment
create_acknowledgment() {
    local agent_name="${1:-AI-Agent}"
    local checksum=$(calculate_checksum)
    local date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    mkdir -p "$(dirname "$ACKNOWLEDGMENT_FILE")"
    
    cat > "$ACKNOWLEDGMENT_FILE" << EOF
# Contract Acknowledgment

Agent: $agent_name
Date: $date
Contract Version: $CONTRACT_VERSION
Checksum: $checksum

I acknowledge that I have read and will adhere to the Session State Specification v$CONTRACT_VERSION.
EOF
    
    echo -e "${GREEN}SUCCESS:${NC} Contract acknowledgment created"
    echo "  File: $ACKNOWLEDGMENT_FILE"
    echo "  Agent: $agent_name"
}

# Function to show contract summary
show_contract_summary() {
    echo -e "${YELLOW}Contract Summary:${NC}"
    echo "  Location: $CONTRACT_FILE"
    echo "  Version: $CONTRACT_VERSION"
    echo "  Checksum: $(calculate_checksum)"
    echo ""
    echo "Key requirements:"
    echo "  - Session state in .ai-session/{feature-id}/"
    echo "  - History log in JSON lines format"
    echo "  - Atomic state updates required"
    echo "  - Valid model values: gemini|opus|sonnet"
}

# Main execution
main() {
    local command="${1:-verify}"
    local agent_name="${2:-}"
    
    case "$command" in
        verify)
            verify_acknowledgment "$agent_name"
            ;;
        create)
            create_acknowledgment "$agent_name"
            ;;
        summary)
            show_contract_summary
            ;;
        *)
            echo "Usage: $0 [verify|create|summary] [agent-name]"
            echo ""
            echo "Commands:"
            echo "  verify [agent]  - Verify contract acknowledgment exists"
            echo "  create [agent]  - Create new contract acknowledgment"
            echo "  summary        - Show contract summary"
            exit 1
            ;;
    esac
}

main "$@"