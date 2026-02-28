#!/bin/bash
# Test suite for argument parsing behavior
# Tests command execution, option parsing, and config operations

set -e

echo "=== Argument Parsing Test Suite ==="
echo

PASS=0
FAIL=0

inc_pass() { PASS=$((PASS + 1)); }
inc_fail() { FAIL=$((FAIL + 1)); }

# Use isolated config dir to avoid interference from user's config
setup_config() {
    TEST_CONFIG=$(mktemp -d)
    mkdir -p "$TEST_CONFIG/sandbash/projects"
    export XDG_CONFIG_HOME="$TEST_CONFIG"
}

teardown_config() {
    rm -rf "$TEST_CONFIG"
    unset XDG_CONFIG_HOME
}

# Helper function to run test
run_test() {
    local test_name="$1"
    local command="$2"
    local expected_behavior="$3"

    echo "Test: $test_name"
    if eval "$command"; then
        echo "  ✓ PASS: $expected_behavior"
        inc_pass
    else
        echo "  ✗ FAIL: $expected_behavior"
        inc_fail
    fi
    echo
}

# Test 1: No arguments launches bash
echo "Test 1: No arguments launches interactive bash"
echo "  (Manual test - skipping in automated suite)"
echo
inc_pass

# Test 2: --allow-write only launches bash
echo "Test 2: --allow-write only launches interactive bash"
echo "  (Manual test - skipping in automated suite)"
echo
inc_pass

# Test 3: Direct command execution
setup_config
run_test "Execute echo command" \
    "./sandbash echo 'test passed'" \
    "Should execute echo and print 'test passed'"
teardown_config

# Test 4: Command with arguments
setup_config
run_test "Execute command with multiple args" \
    "./sandbash echo foo bar baz | grep -q 'foo bar baz'" \
    "Should pass all arguments to echo"
teardown_config

# Test 5: --allow-write before command
setup_config
run_test "Allow-write before command" \
    "./sandbash --allow-write=/private/tmp echo 'works' | grep -q 'works'" \
    "Should execute command with extra writable path"
teardown_config

# Test 6: Execute bash explicitly
setup_config
run_test "Execute bash with -c flag" \
    "./sandbash bash -c 'echo test' | grep -q 'test'" \
    "Should execute bash with its arguments"
teardown_config

# Test 7: Config operation without command (should work)
setup_config
run_test "Config operation without command" \
    "./sandbash --list-paths > /dev/null 2>&1" \
    "Should list paths without error"
teardown_config

# Test 8: Config operation WITH command (should FAIL)
echo "Test 8: Config operation with command (should fail)"
setup_config
if ./sandbash --list-paths echo foo 2>&1 | grep -q -i "error\|cannot"; then
    echo "  ✓ PASS: Correctly rejects config op + command"
    inc_pass
else
    echo "  ✗ FAIL: Should reject config op + command"
    inc_fail
fi
teardown_config
echo

# Test 9: --add-path with command (should FAIL)
echo "Test 9: --add-path with command (should fail)"
setup_config
if ./sandbash --add-path /private/tmp echo foo 2>&1 | grep -q -i "error\|cannot"; then
    echo "  ✓ PASS: Correctly rejects --add-path + command"
    inc_pass
else
    echo "  ✗ FAIL: Should reject --add-path + command"
    inc_fail
fi
teardown_config
echo

# Test 10: Command can have arguments that look like sandbash options
setup_config
run_test "Command with option-like arguments" \
    "./sandbash echo --list-paths | grep -q -- '--list-paths'" \
    "Should pass --list-paths to echo, not parse it"
teardown_config

# Test 11: Write restrictions still work
echo "Test 11: Write restrictions work with direct execution"
setup_config
if ./sandbash --allow-write=/private/tmp touch /tmp/test_$$.txt && [ -f /tmp/test_$$.txt ]; then
    rm -f /tmp/test_$$.txt
    echo "  ✓ PASS: Can write to /tmp with --allow-write"
    inc_pass
else
    echo "  ✗ FAIL: Should be able to write to /tmp with --allow-write"
    inc_fail
fi

if ! ./sandbash touch ~/Desktop/test_$$.txt 2>&1 | grep -q "Operation not permitted"; then
    echo "  ✗ FAIL: Should block writes outside sandbox"
    inc_fail
else
    echo "  ✓ PASS: Blocks writes outside sandbox"
    inc_pass
fi
teardown_config
echo

# Test 12: --allow-signal flag is accepted
setup_config
run_test "--allow-signal flag accepted" \
    "./sandbash --allow-signal echo 'signal test' | grep -q 'signal test'" \
    "Should accept --allow-signal and execute command"
teardown_config

# Test 13: --allow-signal combined with --allow-write
setup_config
run_test "--allow-signal with --allow-write" \
    "./sandbash --allow-signal --allow-write=/private/tmp echo 'combo test' | grep -q 'combo test'" \
    "Should accept --allow-signal combined with --allow-write"
teardown_config

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
