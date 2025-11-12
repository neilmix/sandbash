#!/bin/bash

set -e

echo "=== sandbash Manual Test Suite ==="
echo
echo "Note: This suite focuses on interactive testing."
echo "For automated argument parsing tests, run: ./test/test_argument_parsing.sh"
echo

# Test 1: Help message
echo "Test 1: Help message"
./sandbash --help
echo "✓ Help message displayed"
echo

# Test 2: List paths (should be empty initially)
echo "Test 2: List paths"
./sandbash --list-paths
echo "✓ List paths command works"
echo

# Test 3: Add path
echo "Test 3: Add path"
./sandbash --add-path /tmp
echo "✓ Added /tmp to config"
echo

# Test 4: List paths (should show /tmp)
echo "Test 4: List paths after add"
./sandbash --list-paths | grep "/tmp"
echo "✓ Path appears in config"
echo

# Test 5: Launch sandbash and test write restrictions
echo "Test 5: Launch sandbash interactively"
echo "  Commands to run manually:"
echo "    1. touch test_file.txt    # Should succeed"
echo "    2. touch ~/Desktop/test_file.txt  # Should fail"
echo "    3. touch /tmp/test_file.txt  # Should succeed (we added /tmp)"
echo "    4. exit"
echo
echo "Press Enter to launch sandbash..."
read
./sandbash

# Test 6: Remove path
echo "Test 6: Remove path"
./sandbash --remove-path /tmp
echo "✓ Removed /tmp from config"
echo

# Test 7: List paths (should not show /tmp)
echo "Test 7: List paths after remove"
./sandbash --list-paths
echo "✓ Path removed from config"
echo

echo "=== All tests completed ==="
