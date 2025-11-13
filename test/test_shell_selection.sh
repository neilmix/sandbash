#!/bin/bash
# Test suite for shell selection behavior
# Tests that sandbash uses $SHELL environment variable with fallback to /bin/bash
#
# NOTE: These are manual tests for the interactive shell mode.
# To test properly, run sandbash interactively and check which shell launches:
#
# Test 1: Normal case - should use your current $SHELL
#   $ sandbash
#   (check the prompt/shell features match your normal shell)
#
# Test 2: Custom SHELL - should use the specified shell
#   $ SHELL=/bin/sh sandbash
#   (should get /bin/sh)
#
# Test 3: Empty SHELL - should fallback to /bin/bash
#   $ SHELL= sandbash
#   (should get /bin/bash)
#
# Test 4: Invalid SHELL - should fallback to /bin/bash
#   $ SHELL=/nonexistent sandbash
#   (should get /bin/bash)
#
# Test 5: Direct command execution - should work regardless of SHELL
#   $ sandbash echo "test"
#   (should execute echo successfully)

echo "=== Shell Selection Manual Test Guide ==="
echo
echo "This feature must be tested manually by running sandbash interactively."
echo "See comments in this file for test scenarios."
echo
echo "Quick verification:"
echo "  1. Run: sandbash"
echo "  2. Check if your default shell (\$SHELL=$SHELL) launches"
echo "  3. Exit and try: SHELL=/bin/sh sandbash"
echo "  4. Verify /bin/sh launches instead"
echo
