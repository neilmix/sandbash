#!/bin/bash
# Test suite for config error handling
# Verifies that invalid/missing paths in config cause hard errors

set -e

echo "=== Config Error Handling Test Suite ==="
echo

PASS=0
FAIL=0

inc_pass() { PASS=$((PASS + 1)); }
inc_fail() { FAIL=$((FAIL + 1)); }

# Use isolated config dir for each test
setup_config() {
    TEST_CONFIG=$(mktemp -d)
    mkdir -p "$TEST_CONFIG/sandbash/projects"
    export XDG_CONFIG_HOME="$TEST_CONFIG"
}

teardown_config() {
    rm -rf "$TEST_CONFIG"
    unset XDG_CONFIG_HOME
}

# Test 1: Nonexistent absolute path in global config
echo "Test 1: Nonexistent absolute path in global config"
setup_config
echo "+ /nonexistent/path/abc123" > "$TEST_CONFIG/sandbash/config"
if OUTPUT=$(./sandbash --list-paths 2>&1); then
    echo "  ✗ FAIL: Should have exited with error"
    inc_fail
else
    if echo "$OUTPUT" | grep -q "Error: Directory not found.*nonexistent"; then
        echo "  ✓ PASS: Errors on nonexistent absolute path"
        inc_pass
    else
        echo "  ✗ FAIL: Wrong error message: $OUTPUT"
        inc_fail
    fi
fi
teardown_config
echo

# Test 2: Nonexistent tilde path in global config
echo "Test 2: Nonexistent tilde path in global config"
setup_config
echo "+ ~/nonexistent_dir_xyz789" > "$TEST_CONFIG/sandbash/config"
if OUTPUT=$(./sandbash --list-paths 2>&1); then
    echo "  ✗ FAIL: Should have exited with error"
    inc_fail
else
    if echo "$OUTPUT" | grep -q "Error: Directory not found"; then
        echo "  ✓ PASS: Errors on nonexistent tilde path"
        inc_pass
    else
        echo "  ✗ FAIL: Wrong error message: $OUTPUT"
        inc_fail
    fi
fi
teardown_config
echo

# Test 3: Nonexistent path in local (per-directory) config
echo "Test 3: Nonexistent path in local config"
setup_config
# Get the project hash by running list-paths first
HASH=$(./sandbash --list-paths 2>/dev/null | grep "Per-directory" | grep -oE '[a-f0-9]{16}')
echo "+ /does/not/exist" > "$TEST_CONFIG/sandbash/projects/$HASH"
if OUTPUT=$(./sandbash --list-paths 2>&1); then
    echo "  ✗ FAIL: Should have exited with error"
    inc_fail
else
    if echo "$OUTPUT" | grep -q "Error:.*load local configuration"; then
        echo "  ✓ PASS: Errors on nonexistent path in local config"
        inc_pass
    else
        echo "  ✗ FAIL: Wrong error message: $OUTPUT"
        inc_fail
    fi
fi
teardown_config
echo

# Test 4: Valid path in global config still works (use canonical path, not symlink)
echo "Test 4: Valid path in global config succeeds"
setup_config
echo "+ /private/tmp" > "$TEST_CONFIG/sandbash/config"
if OUTPUT=$(./sandbash --list-paths 2>&1); then
    if echo "$OUTPUT" | grep -q "/private/tmp"; then
        echo "  ✓ PASS: Valid path loads successfully"
        inc_pass
    else
        echo "  ✗ FAIL: Valid path not in output: $OUTPUT"
        inc_fail
    fi
else
    echo "  ✗ FAIL: Should have succeeded with valid path"
    inc_fail
fi
teardown_config
echo

# Test 5: Empty config file is fine
echo "Test 5: Empty config file succeeds"
setup_config
touch "$TEST_CONFIG/sandbash/config"
if ./sandbash --list-paths > /dev/null 2>&1; then
    echo "  ✓ PASS: Empty config works"
    inc_pass
else
    echo "  ✗ FAIL: Empty config should not error"
    inc_fail
fi
teardown_config
echo

# Test 6: Every non-blank line must begin with "+ " or "- ". Comments, bare
# paths, and a prefix without its separating space are all rejected.
echo "Test 6: Lines without a \"+ \" or \"- \" prefix are rejected"
for BAD in "# just a comment" "/private/tmp" "+/private/tmp" "-/private/tmp" "+" "* /private/tmp"; do
    setup_config
    printf '%s\n' "$BAD" > "$TEST_CONFIG/sandbash/config"
    if OUTPUT=$(./sandbash --list-paths 2>&1); then
        echo "  ✗ FAIL: Should have rejected line: $BAD"
        inc_fail
    elif echo "$OUTPUT" | grep -q 'Error: Invalid config line 1'; then
        echo "  ✓ PASS: Rejects line: $BAD"
        inc_pass
    else
        echo "  ✗ FAIL: Wrong error message for '$BAD': $OUTPUT"
        inc_fail
    fi
    teardown_config
done
echo

# Test 6b: Whitespace-only lines are ignored
echo "Test 6b: Blank and whitespace-only lines are ignored"
setup_config
printf '\n   \n\t\n+ /private/tmp\n\n' > "$TEST_CONFIG/sandbash/config"
if OUTPUT=$(./sandbash --list-paths 2>&1) && echo "$OUTPUT" | grep -q "+ /private/tmp"; then
    echo "  ✓ PASS: Whitespace-only lines ignored"
    inc_pass
else
    echo "  ✗ FAIL: Whitespace-only lines should be ignored: $OUTPUT"
    inc_fail
fi
teardown_config
echo

# Test 7: Valid path with trailing slash is accepted (not a false symlink)
echo "Test 7: Valid path with trailing slash is accepted"
setup_config
echo "+ /private/tmp/" > "$TEST_CONFIG/sandbash/config"
if OUTPUT=$(./sandbash --list-paths 2>&1); then
    if echo "$OUTPUT" | grep -q "/private/tmp"; then
        echo "  ✓ PASS: Trailing-slash path loads successfully"
        inc_pass
    else
        echo "  ✗ FAIL: Path not in output: $OUTPUT"
        inc_fail
    fi
else
    echo "  ✗ FAIL: Should have succeeded (trailing slash caused false symlink rejection): $OUTPUT"
    inc_fail
fi
teardown_config
echo

# Test 8: Symlinked path in global config is rejected
echo "Test 8: Symlinked path /tmp is rejected (symlink to /private/tmp)"
setup_config
echo "+ /tmp" > "$TEST_CONFIG/sandbash/config"
if OUTPUT=$(./sandbash --list-paths 2>&1); then
    echo "  ✗ FAIL: Should have exited with error for symlinked path"
    inc_fail
else
    if echo "$OUTPUT" | grep -q "symlink" && echo "$OUTPUT" | grep -q "/private/tmp"; then
        echo "  ✓ PASS: Rejects symlinked path with helpful message"
        inc_pass
    else
        echo "  ✗ FAIL: Wrong error message (expected symlink warning with resolved path): $OUTPUT"
        inc_fail
    fi
fi
teardown_config
echo

# Test 9: Symlinked path in local config is rejected
echo "Test 9: Symlinked path in local (per-directory) config is rejected"
setup_config
HASH=$(./sandbash --list-paths 2>/dev/null | grep "Per-directory" | grep -oE '[a-f0-9]{16}')
echo "+ /tmp" > "$TEST_CONFIG/sandbash/projects/$HASH"
if OUTPUT=$(./sandbash --list-paths 2>&1); then
    echo "  ✗ FAIL: Should have exited with error for symlinked path in local config"
    inc_fail
else
    if echo "$OUTPUT" | grep -q "symlink" && echo "$OUTPUT" | grep -q "/private/tmp"; then
        echo "  ✓ PASS: Rejects symlinked path in local config"
        inc_pass
    else
        echo "  ✗ FAIL: Wrong error message: $OUTPUT"
        inc_fail
    fi
fi
teardown_config
echo

# Test 10: Custom symlink to a directory is rejected
echo "Test 10: Custom symlink to directory is rejected"
setup_config
REAL_DIR=$(mktemp -d)
LINK_DIR=$(mktemp -d)
rmdir "$LINK_DIR"
ln -s "$REAL_DIR" "$LINK_DIR"
echo "+ $LINK_DIR" > "$TEST_CONFIG/sandbash/config"
if OUTPUT=$(./sandbash --list-paths 2>&1); then
    echo "  ✗ FAIL: Should have exited with error for symlinked path"
    inc_fail
else
    if echo "$OUTPUT" | grep -q "symlink" && echo "$OUTPUT" | grep -q "$REAL_DIR"; then
        echo "  ✓ PASS: Rejects custom symlink with resolved path in message"
        inc_pass
    else
        echo "  ✗ FAIL: Wrong error message: $OUTPUT"
        inc_fail
    fi
fi
rm -f "$LINK_DIR"
rm -rf "$REAL_DIR"
teardown_config
echo

# Test 11: Symlinked path via --allow-write is rejected
echo "Test 11: Symlinked --allow-write path is rejected"
setup_config
if OUTPUT=$(./sandbash --allow-write=/tmp echo hello 2>&1); then
    echo "  ✗ FAIL: Should have exited with error for symlinked --allow-write path"
    inc_fail
else
    if echo "$OUTPUT" | grep -q "symlink" && echo "$OUTPUT" | grep -q "/private/tmp"; then
        echo "  ✓ PASS: Rejects symlinked --allow-write path"
        inc_pass
    else
        echo "  ✗ FAIL: Wrong error message: $OUTPUT"
        inc_fail
    fi
fi
teardown_config
echo

# Test 12: "- " lines load as denied paths and are listed as such
echo "Test 12: Deny lines load and are listed"
setup_config
DENY_DIR=$(cd "$(mktemp -d)" && pwd -P)
printf '+ /private/tmp\n- %s\n' "$DENY_DIR" > "$TEST_CONFIG/sandbash/config"
if OUTPUT=$(./sandbash --list-paths 2>&1) \
    && echo "$OUTPUT" | grep -qF "+ /private/tmp" \
    && echo "$OUTPUT" | grep -qF -- "- $DENY_DIR"; then
    echo "  ✓ PASS: Allow and deny paths listed"
    inc_pass
else
    echo "  ✗ FAIL: Expected '+ /private/tmp' and '- $DENY_DIR': $OUTPUT"
    inc_fail
fi
rm -rf "$DENY_DIR"
teardown_config
echo

# Test 13: Deny paths get the same strict validation as allow paths
echo "Test 13: Nonexistent and symlinked deny paths are rejected"
setup_config
echo "- /nonexistent/deny/abc123" > "$TEST_CONFIG/sandbash/config"
if OUTPUT=$(./sandbash --list-paths 2>&1); then
    echo "  ✗ FAIL: Should reject nonexistent deny path"
    inc_fail
elif echo "$OUTPUT" | grep -q "not found"; then
    echo "  ✓ PASS: Rejects nonexistent deny path"
    inc_pass
else
    echo "  ✗ FAIL: Wrong error message: $OUTPUT"
    inc_fail
fi
echo "- /tmp" > "$TEST_CONFIG/sandbash/config"
if OUTPUT=$(./sandbash --list-paths 2>&1); then
    echo "  ✗ FAIL: Should reject symlinked deny path"
    inc_fail
elif echo "$OUTPUT" | grep -q "symlink"; then
    echo "  ✓ PASS: Rejects symlinked deny path"
    inc_pass
else
    echo "  ✗ FAIL: Wrong error message: $OUTPUT"
    inc_fail
fi
teardown_config
echo

# Test 14: --add-path writes the "+ " format and preserves existing deny lines
echo "Test 14: --add-path writes '+ ' lines and keeps deny lines"
setup_config
HASH=$(./sandbash --list-paths 2>/dev/null | grep "Per-directory" | grep -oE '[a-f0-9]{16}')
DENY_DIR=$(cd "$(mktemp -d)" && pwd -P)
echo "- $DENY_DIR" > "$TEST_CONFIG/sandbash/projects/$HASH"
if ./sandbash --add-path /private/tmp > /dev/null 2>&1 \
    && grep -qxF "+ /private/tmp" "$TEST_CONFIG/sandbash/projects/$HASH" \
    && grep -qxF -- "- $DENY_DIR" "$TEST_CONFIG/sandbash/projects/$HASH" \
    && ./sandbash --list-paths > /dev/null 2>&1; then
    echo "  ✓ PASS: Saved config uses prefixes, keeps denies, and reloads"
    inc_pass
else
    echo "  ✗ FAIL: Saved config wrong:"
    cat "$TEST_CONFIG/sandbash/projects/$HASH"
    inc_fail
fi
rm -rf "$DENY_DIR"
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
