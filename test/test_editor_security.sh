#!/bin/bash
# Test for command injection vulnerability in --edit
# Verifies that malicious $EDITOR values cannot execute arbitrary commands

set -e

echo "=== Editor Command Injection Security Test ==="
echo

# Create a marker file that would be created if injection succeeds
MARKER_FILE="/tmp/sandbash_test_injection_$$"
rm -f "$MARKER_FILE"

# Build sandbash
echo "Building sandbash..."
make clean && make || { echo "✗ Build failed"; exit 1; }
echo "✓ Build succeeded"
echo

# Test: Malicious $EDITOR should NOT execute arbitrary commands
echo "Test: Malicious EDITOR value should not execute commands"
echo "  Setting EDITOR='vi; touch $MARKER_FILE; #'"
echo "  (This would create $MARKER_FILE if injection is possible)"
echo

# Export malicious EDITOR and try to use --edit
export EDITOR="vi; touch $MARKER_FILE; #"

# Create a temp config dir for testing
TEST_CONFIG_DIR="/tmp/sandbash_test_config_$$"
mkdir -p "$TEST_CONFIG_DIR"
export XDG_CONFIG_HOME="$TEST_CONFIG_DIR"

# Try to run --edit (it will fail because vi can't run, but that's okay)
# The important thing is whether the injection command runs
timeout 2 ./sandbash --edit 2>&1 | head -5 || true

# Check if marker file was created (indicating successful injection)
if [ -f "$MARKER_FILE" ]; then
    echo "  ✗ FAIL: Command injection successful - arbitrary commands executed!"
    echo "  Marker file was created: $MARKER_FILE"
    rm -f "$MARKER_FILE"
    rm -rf "$TEST_CONFIG_DIR"
    exit 1
else
    echo "  ✓ PASS: Command injection prevented - no arbitrary execution"
fi

# Cleanup
rm -f "$MARKER_FILE"
rm -rf "$TEST_CONFIG_DIR"

echo
echo "==================================="
echo "Security test passed"
echo "==================================="
exit 0
