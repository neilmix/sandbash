# Test Results

Date: 2025-11-12

## Automated Tests

All command-line operations tested:
- ✓ Help message
- ✓ List paths
- ✓ Add path
- ✓ Remove path
- ✓ Edit (requires manual EDITOR test)

## Manual Sandbox Tests

Test sandboxing by running:

1. Launch sandbox: `./sandbash`
2. Test write in current directory: `touch test_file.txt` (should succeed)
3. Test write outside: `touch ~/Desktop/test.txt` (should fail with permission denied)
4. Add writable path: exit and run `./sandbash --add-path /tmp`
5. Launch again: `./sandbash`
6. Test write to allowed path: `touch /tmp/test.txt` (should succeed)

## Subprocess Inheritance Test

```bash
./sandbash -c "bash -c 'touch ~/Desktop/test.txt'"
```

Should fail with permission denied, confirming sandbox inherits to children.

## Known Issues

- May require code signing on some macOS versions
- Private API usage may trigger warnings
