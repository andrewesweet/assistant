#!/bin/bash
# Test multiline prompts with claude

set -euo pipefail

echo "Testing multiline prompt handling..."

# Test with escaped newlines
echo "Test 1: Escaped newlines"
prompt="Task: Test Task\nPlease write a simple test."
time scripts/ai-command-wrapper.sh claude 30 -p "$prompt" 2>&1 | grep -E "(SUCCESS|ERROR|timeout|Task)" | head -5

echo ""
echo "Test 2: Single line version"
prompt="Task: Test Task - Please write a simple test."
time scripts/ai-command-wrapper.sh claude 30 -p "$prompt" 2>&1 | grep -E "(SUCCESS|ERROR|timeout|Task)" | head -5

echo ""
echo "Test 3: Using printf to format"
prompt=$(printf "Task: Test Task\nPlease write a simple test.")
time scripts/ai-command-wrapper.sh claude 30 -p "$prompt" 2>&1 | grep -E "(SUCCESS|ERROR|timeout|Task)" | head -5