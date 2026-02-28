#!/bin/bash
# Test suite for executable permissions in sandbox
# Tests that binaries can be executed, including through symlinks

set -e

echo "=== Executable Permissions Test Suite ==="
echo

PASS=0
FAIL=0

inc_pass() { PASS=$((PASS + 1)); }
inc_fail() { FAIL=$((FAIL + 1)); }

# Use isolated config dir
setup_config() {
    TEST_CONFIG=$(mktemp -d)
    mkdir -p "$TEST_CONFIG/sandbash/projects"
    export XDG_CONFIG_HOME="$TEST_CONFIG"
}

teardown_config() {
    rm -rf "$TEST_CONFIG"
    unset XDG_CONFIG_HOME
}

# Setup: Create a test directory with a shim script
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

# Find real python3 binary (not shim or stub)
PYTHON_PATH=""
for path in /opt/homebrew/bin/python3 /usr/local/bin/python3 /Library/Frameworks/Python.framework/Versions/*/bin/python3; do
    if [ -x "$path" ]; then
        # Follow symlinks to get the real binary
        real_path=$(readlink -f "$path" 2>/dev/null || realpath "$path" 2>/dev/null || echo "$path")
        # Verify it's a real binary, not an xcode-select stub
        if "$real_path" --version >/dev/null 2>&1; then
            PYTHON_PATH="$real_path"
            break
        fi
    fi
done

if [ -z "$PYTHON_PATH" ]; then
    echo "✗ Could not find a real Python3 binary (not shim or stub)"
    exit 1
fi

# Create a shim script that executes the real python
cat > "$TEST_DIR/python_shim" <<EOF
#!/bin/bash
exec "$PYTHON_PATH" "\$@"
EOF
chmod +x "$TEST_DIR/python_shim"

# Also create a symlink to test symlink resolution
ln -s "$PYTHON_PATH" "$TEST_DIR/python_symlink"

echo "Created shim: $TEST_DIR/python_shim -> $PYTHON_PATH"
echo "Created symlink: $TEST_DIR/python_symlink -> $PYTHON_PATH"

# Test 1: Execute Python directly
echo "Test 1: Execute Python directly (baseline)"
if python3 -c "print('hello')" >/dev/null 2>&1; then
    echo "  ✓ PASS: Python executes outside sandbox"
    inc_pass
else
    echo "  ✗ FAIL: Python doesn't execute (baseline failed)"
    inc_fail
fi
echo

# Test 2: Execute Python through shim script in sandbox
echo "Test 2: Execute Python through shim script in sandbox"
setup_config
OUTPUT=$(./sandbash "$TEST_DIR/python_shim" -c "print('hello')" 2>&1) || true
teardown_config

if echo "$OUTPUT" | grep -q "hello"; then
    echo "  ✓ PASS: Python executed through shim"
    inc_pass
else
    echo "  ✗ FAIL: Python shim execution failed"
    echo "    Output: $OUTPUT"
    inc_fail
fi
echo

# Test 3: Execute Python through symlink in sandbox
echo "Test 3: Execute Python through symlink in sandbox"
setup_config
OUTPUT=$(./sandbash "$TEST_DIR/python_symlink" -c "print('hello')" 2>&1) || true
teardown_config

if echo "$OUTPUT" | grep -q "hello"; then
    echo "  ✓ PASS: Python executed through symlink"
    inc_pass
else
    echo "  ✗ FAIL: Python symlink execution failed"
    echo "    Output: $OUTPUT"
    inc_fail
fi
echo

# Test 4: Check symlink metadata is readable
echo "Test 4: Check symlink metadata is readable"
setup_config
OUTPUT=$(./sandbash readlink "$TEST_DIR/python_symlink" 2>&1) || true
teardown_config

if echo "$OUTPUT" | grep -q "$PYTHON_PATH"; then
    echo "  ✓ PASS: Symlink metadata readable"
    inc_pass
else
    echo "  ✗ FAIL: Symlink metadata not readable"
    echo "    Output: $OUTPUT"
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
