#!/bin/bash
# Test timeout functionality in isolation

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Testing ai-command-wrapper.sh timeout enforcement..."
echo ""

# Create isolated test environment
TEST_DIR="/tmp/wrapper-timeout-test-$$"
mkdir -p "$TEST_DIR/bin"
cd "$TEST_DIR"

# Copy the wrapper script
cp "$OLDPWD/scripts/ai-command-wrapper.sh" .

# Create a mock claude that sleeps and supports --help
cat > bin/claude << 'EOF'
#!/bin/bash
if [[ "$1" == "--help" ]]; then
    echo "Mock claude help"
    exit 0
fi
# For actual execution, sleep longer than timeout
sleep 10
echo "SHOULD_NOT_SEE_THIS"
EOF
chmod +x bin/claude

# Run test with isolated PATH
export PATH="$TEST_DIR/bin:$PATH"
export CLAUDE_CODE_SSE_PORT=""
export CLAUDECODE=""

echo -e "${YELLOW}Test:${NC} 2-second timeout should kill 10-second sleep"

# Measure execution time
start_time=$(date +%s)

# Run wrapper with 2 second timeout
set +e
output=$(./ai-command-wrapper.sh claude 2 -p "test prompt" 2>&1)
exit_code=$?
set -e

end_time=$(date +%s)
duration=$((end_time - start_time))

# Cleanup
cd "$OLDPWD"
rm -rf "$TEST_DIR"

# Check results
echo "Exit code: $exit_code"
echo "Duration: ${duration}s"
echo "Full output:"
echo "---"
echo "$output"
echo "---"

# Verify timeout worked
if [[ $exit_code -eq 124 ]] && [[ $duration -le 3 ]]; then
    echo -e "${GREEN}PASS:${NC} Timeout correctly enforced (exit code 124, duration ${duration}s)"
    exit 0
else
    echo -e "${RED}FAIL:${NC} Timeout not properly enforced"
    echo "  Expected: exit code 124, duration ≤3s"
    echo "  Actual: exit code $exit_code, duration ${duration}s"
    exit 1
fi