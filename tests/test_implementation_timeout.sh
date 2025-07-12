#!/bin/bash
# Test that implementation timeout is sufficient

set -euo pipefail

echo "Testing implementation timeout increase..."
echo ""

# Create a test prompt that simulates a complex task
complex_prompt="Task: Complex Implementation Test

Please analyze this complex implementation requirement:
1. Create a comprehensive solution
2. Consider multiple edge cases
3. Implement error handling
4. Add detailed comments
5. Follow best practices

This is a test to ensure the timeout is sufficient for complex tasks."

# Test with the new 180s timeout
echo "Testing complex prompt with 180s timeout..."
start_time=$(date +%s)

if timeout 200 scripts/ai-command-wrapper.sh claude 180 -p "$complex_prompt" > /tmp/timeout_test.out 2>&1; then
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    echo "SUCCESS: Completed in ${duration}s"
    echo "Response length: $(wc -c < /tmp/timeout_test.out) bytes"
    
    if [[ $duration -gt 60 ]]; then
        echo "✓ This would have failed with the old 60s timeout!"
    fi
else
    exit_code=$?
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    if [[ $exit_code -eq 124 ]]; then
        echo "FAILED: Timed out after ${duration}s"
        echo "Even 180s wasn't enough - may need further increase"
    else
        echo "FAILED: Exit code $exit_code after ${duration}s"
    fi
fi

echo ""
echo "Timeout Analysis:"
echo "- Old timeout: 60s (too short)"
echo "- New timeout: 180s (3 minutes)"
echo "- Safety margin: 3x the observed simple task time (45s)"

rm -f /tmp/timeout_test.out