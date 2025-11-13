#!/bin/bash
# Test suite for sandbox profile string escaping
# Tests that special characters in paths are properly escaped

set -e

echo "=== Sandbox Profile Escaping Test Suite ==="
echo

PASS=0
FAIL=0

# Test helper program that uses the escaping function
cat > test_escape_helper.c <<'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Function to test - should escape quotes and backslashes
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

# Try to compile and link with sandbox.o
echo "Compiling test helper..."
if ! clang -o test_escape_helper test_escape_helper.c src/sandbox.o src/config.o src/utils.o -framework Security -framework CoreFoundation 2>&1 | grep -v "Undefined symbols"; then
    echo "✗ EXPECTED FAILURE: escape_sandbox_string() function doesn't exist yet"
    echo
    rm -f test_escape_helper test_escape_helper.c
    exit 1
fi

echo "✓ Test helper compiled"
echo

# Test 1: Escape double quotes
echo "Test 1: Escape double quotes in path"
INPUT='/tmp/test"path'
EXPECTED='/tmp/test\"path'
ACTUAL=$(./test_escape_helper "$INPUT")

if [ "$ACTUAL" = "$EXPECTED" ]; then
    echo "  ✓ PASS: Double quote escaped correctly"
    ((PASS++))
else
    echo "  ✗ FAIL: Double quote not escaped"
    echo "    Input:    $INPUT"
    echo "    Expected: $EXPECTED"
    echo "    Actual:   $ACTUAL"
    ((FAIL++))
fi
echo

# Test 2: Escape backslashes
echo "Test 2: Escape backslashes in path"
INPUT='/tmp/test\path'
EXPECTED='/tmp/test\\path'
ACTUAL=$(./test_escape_helper "$INPUT")

if [ "$ACTUAL" = "$EXPECTED" ]; then
    echo "  ✓ PASS: Backslash escaped correctly"
    ((PASS++))
else
    echo "  ✗ FAIL: Backslash not escaped"
    echo "    Input:    $INPUT"
    echo "    Expected: $EXPECTED"
    echo "    Actual:   $ACTUAL"
    ((FAIL++))
fi
echo

# Test 3: Escape both quotes and backslashes
echo "Test 3: Escape both quotes and backslashes"
INPUT='/tmp/test\"path'
EXPECTED='/tmp/test\\\"path'
ACTUAL=$(./test_escape_helper "$INPUT")

if [ "$ACTUAL" = "$EXPECTED" ]; then
    echo "  ✓ PASS: Both characters escaped correctly"
    ((PASS++))
else
    echo "  ✗ FAIL: Not all characters escaped"
    echo "    Input:    $INPUT"
    echo "    Expected: $EXPECTED"
    echo "    Actual:   $ACTUAL"
    ((FAIL++))
fi
echo

# Test 4: No escaping needed for normal paths
echo "Test 4: Normal path unchanged"
INPUT='/tmp/normal/path'
EXPECTED='/tmp/normal/path'
ACTUAL=$(./test_escape_helper "$INPUT")

if [ "$ACTUAL" = "$EXPECTED" ]; then
    echo "  ✓ PASS: Normal path unchanged"
    ((PASS++))
else
    echo "  ✗ FAIL: Normal path was modified"
    echo "    Input:    $INPUT"
    echo "    Expected: $EXPECTED"
    echo "    Actual:   $ACTUAL"
    ((FAIL++))
fi
echo

# Cleanup
rm -f test_escape_helper test_escape_helper.c

# Summary
echo "==================================="
echo "Results: $PASS passed, $FAIL failed"
echo "==================================="

if [ $FAIL -gt 0 ]; then
    exit 1
fi

exit 0
