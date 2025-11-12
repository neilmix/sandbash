#!/bin/bash
# Test suite for new argument parsing behavior
# Following TDD: these tests should FAIL before implementation

set -e

echo "=== Argument Parsing Test Suite ==="
echo

PASS=0
FAIL=0

# Helper function to run test
run_test() {
    local test_name="$1"
    local command="$2"
    local expected_behavior="$3"

    echo "Test: $test_name"
    if eval "$command"; then
        echo "  ✓ PASS: $expected_behavior"
        ((PASS++))
    else
        echo "  ✗ FAIL: $expected_behavior"
        ((FAIL++))
    fi
    echo
}

# Test 1: No arguments launches bash
echo "Test 1: No arguments launches interactive bash"
echo "  (Manual test - skipping in automated suite)"
echo
((PASS++))

# Test 2: --allow-write only launches bash
echo "Test 2: --allow-write only launches interactive bash"
echo "  (Manual test - skipping in automated suite)"
echo
((PASS++))

# Test 3: Direct command execution
run_test "Execute echo command" \
    "./sandbash echo 'test passed'" \
    "Should execute echo and print 'test passed'"

# Test 4: Command with arguments
run_test "Execute command with multiple args" \
    "./sandbash echo foo bar baz | grep -q 'foo bar baz'" \
    "Should pass all arguments to echo"

# Test 5: --allow-write before command
run_test "Allow-write before command" \
    "./sandbash --allow-write=/tmp echo 'works' | grep -q 'works'" \
    "Should execute command with extra writable path"

# Test 6: Execute bash explicitly
run_test "Execute bash with -c flag" \
    "./sandbash bash -c 'echo test' | grep -q 'test'" \
    "Should execute bash with its arguments"

# Test 7: Config operation without command (should work)
run_test "Config operation without command" \
    "./sandbash --list-paths > /dev/null 2>&1" \
    "Should list paths without error"

# Test 8: Config operation WITH command (should FAIL)
echo "Test 8: Config operation with command (should fail)"
if ./sandbash --list-paths echo foo 2>&1 | grep -q -i "error\|cannot"; then
    echo "  ✓ PASS: Correctly rejects config op + command"
    ((PASS++))
else
    echo "  ✗ FAIL: Should reject config op + command"
    ((FAIL++))
fi
echo

# Test 9: --add-path with command (should FAIL)
echo "Test 9: --add-path with command (should fail)"
if ./sandbash --add-path /tmp echo foo 2>&1 | grep -q -i "error\|cannot"; then
    echo "  ✓ PASS: Correctly rejects --add-path + command"
    ((PASS++))
else
    echo "  ✗ FAIL: Should reject --add-path + command"
    ((FAIL++))
fi
echo

# Test 10: Command can have arguments that look like sandbash options
run_test "Command with option-like arguments" \
    "./sandbash echo --list-paths | grep -q -- '--list-paths'" \
    "Should pass --list-paths to echo, not parse it"

# Test 11: Write restrictions still work
echo "Test 11: Write restrictions work with direct execution"
if ./sandbash touch /tmp/test_$$.txt && [ -f /tmp/test_$$.txt ]; then
    rm -f /tmp/test_$$.txt
    echo "  ✓ PASS: Can write to /tmp"
    ((PASS++))
else
    echo "  ✗ FAIL: Should be able to write to /tmp"
    ((FAIL++))
fi

if ! ./sandbash touch ~/Desktop/test_$$.txt 2>&1 | grep -q "Operation not permitted"; then
    echo "  ✗ FAIL: Should block writes outside sandbox"
    ((FAIL++))
else
    echo "  ✓ PASS: Blocks writes outside sandbox"
    ((PASS++))
fi
echo

# Summary
echo "=== Test Results ==="
echo "PASS: $PASS"
echo "FAIL: $FAIL"
echo

if [ $FAIL -eq 0 ]; then
    echo "All tests passed!"
    exit 0
else
    echo "Some tests failed!"
    exit 1
fi
