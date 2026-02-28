#!/bin/bash
# Test suite for --allow-signal behavior
# Tests that signal permissions are correctly applied by the sandbox

set -e

echo "=== Allow-Signal Test Suite ==="
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

# Test 1: Self-signaling works without --allow-signal
echo "Test 1: Self-signaling works without --allow-signal"
setup_config
if ./sandbash bash -c 'kill -0 $$ && echo ok' 2>/dev/null | grep -q 'ok'; then
    echo "  ✓ PASS: kill -0 self succeeds without --allow-signal"
    inc_pass
else
    echo "  ✗ FAIL: kill -0 self should succeed without --allow-signal"
    inc_fail
fi
teardown_config
echo

# Test 2: Signaling external process denied without --allow-signal
echo "Test 2: Signaling external process denied without --allow-signal"
setup_config
# Start a background sleep process outside the sandbox
sleep 300 &
EXT_PID=$!
if ./sandbash bash -c "kill -0 $EXT_PID" 2>/dev/null; then
    echo "  ✗ FAIL: kill -0 external PID should be denied without --allow-signal"
    inc_fail
else
    echo "  ✓ PASS: kill -0 external PID denied without --allow-signal"
    inc_pass
fi
kill $EXT_PID 2>/dev/null || true
wait $EXT_PID 2>/dev/null || true
teardown_config
echo

# Test 3: Signaling external process succeeds with --allow-signal
echo "Test 3: Signaling external process succeeds with --allow-signal"
setup_config
sleep 300 &
EXT_PID=$!
if ./sandbash --allow-signal bash -c "kill -0 $EXT_PID" 2>/dev/null; then
    echo "  ✓ PASS: kill -0 external PID succeeds with --allow-signal"
    inc_pass
else
    echo "  ✗ FAIL: kill -0 external PID should succeed with --allow-signal"
    inc_fail
fi
kill $EXT_PID 2>/dev/null || true
wait $EXT_PID 2>/dev/null || true
teardown_config
echo

# Test 4: Self-signaling still works with --allow-signal
echo "Test 4: Self-signaling works with --allow-signal"
setup_config
if ./sandbash --allow-signal bash -c 'kill -0 $$ && echo ok' 2>/dev/null | grep -q 'ok'; then
    echo "  ✓ PASS: kill -0 self succeeds with --allow-signal"
    inc_pass
else
    echo "  ✗ FAIL: kill -0 self should succeed with --allow-signal"
    inc_fail
fi
teardown_config
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
