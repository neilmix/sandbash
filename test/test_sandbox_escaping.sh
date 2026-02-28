#!/bin/bash
# Test suite for sandbox profile string escaping
# Tests that special characters in paths are properly escaped

set -e

echo "=== Sandbox Profile Escaping Test Suite ==="
echo

PASS=0
FAIL=0

inc_pass() { PASS=$((PASS + 1)); }
inc_fail() { FAIL=$((FAIL + 1)); }

# Build test helper in a temp directory
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

cat > "$TEST_DIR/test_escape_helper.c" <<'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Function to test - defined in sandbox.o
char* escape_sandbox_string(const char* str);

int main(int argc, char* argv[]) {
    if (argc != 2) {
        fprintf(stderr, "Usage: %s <string_to_escape>\n", argv[0]);
        return 1;
    }

    char* escaped = escape_sandbox_string(argv[1]);
    if (!escaped) {
        fprintf(stderr, "Error: Failed to escape string\n");
        return 1;
    }

    printf("%s", escaped);
    free(escaped);
    return 0;
}
EOF

echo "Compiling test helper..."
if ! clang -o "$TEST_DIR/test_escape_helper" "$TEST_DIR/test_escape_helper.c" \
    src/sandbox.o src/config.o src/utils.o -framework Security 2>&1; then
    echo "✗ FAIL: Could not compile test helper"
    exit 1
fi
echo "✓ Test helper compiled"
echo

# Test 1: Escape double quotes
echo "Test 1: Escape double quotes in path"
INPUT='/tmp/test"path'
EXPECTED='/tmp/test\"path'
ACTUAL=$("$TEST_DIR/test_escape_helper" "$INPUT")

if [ "$ACTUAL" = "$EXPECTED" ]; then
    echo "  ✓ PASS: Double quote escaped correctly"
    inc_pass
else
    echo "  ✗ FAIL: Double quote not escaped"
    echo "    Input:    $INPUT"
    echo "    Expected: $EXPECTED"
    echo "    Actual:   $ACTUAL"
    inc_fail
fi
echo

# Test 2: Escape backslashes
echo "Test 2: Escape backslashes in path"
INPUT='/tmp/test\path'
EXPECTED='/tmp/test\\path'
ACTUAL=$("$TEST_DIR/test_escape_helper" "$INPUT")

if [ "$ACTUAL" = "$EXPECTED" ]; then
    echo "  ✓ PASS: Backslash escaped correctly"
    inc_pass
else
    echo "  ✗ FAIL: Backslash not escaped"
    echo "    Input:    $INPUT"
    echo "    Expected: $EXPECTED"
    echo "    Actual:   $ACTUAL"
    inc_fail
fi
echo

# Test 3: Escape both quotes and backslashes
echo "Test 3: Escape both quotes and backslashes"
INPUT='/tmp/test\"path'
EXPECTED='/tmp/test\\\"path'
ACTUAL=$("$TEST_DIR/test_escape_helper" "$INPUT")

if [ "$ACTUAL" = "$EXPECTED" ]; then
    echo "  ✓ PASS: Both characters escaped correctly"
    inc_pass
else
    echo "  ✗ FAIL: Not all characters escaped"
    echo "    Input:    $INPUT"
    echo "    Expected: $EXPECTED"
    echo "    Actual:   $ACTUAL"
    inc_fail
fi
echo

# Test 4: No escaping needed for normal paths
echo "Test 4: Normal path unchanged"
INPUT='/tmp/normal/path'
EXPECTED='/tmp/normal/path'
ACTUAL=$("$TEST_DIR/test_escape_helper" "$INPUT")

if [ "$ACTUAL" = "$EXPECTED" ]; then
    echo "  ✓ PASS: Normal path unchanged"
    inc_pass
else
    echo "  ✗ FAIL: Normal path was modified"
    echo "    Input:    $INPUT"
    echo "    Expected: $EXPECTED"
    echo "    Actual:   $ACTUAL"
    inc_fail
fi
echo

# Summary
echo "==================================="
echo "Results: $PASS passed, $FAIL failed"
echo "==================================="

if [ $FAIL -gt 0 ]; then
    exit 1
fi

exit 0
