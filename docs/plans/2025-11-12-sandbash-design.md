# sandbash Design Document

**Date:** 2025-11-12
**Status:** Design approved, ready for implementation

## Overview

`sandbash` is a command-line tool for macOS that launches a sandboxed bash shell where the current directory is fully writable, but all filesystem locations outside the current directory are read-only unless explicitly allowed via configuration.

## Purpose

Enable safe AI-assisted development with Claude Code by restricting filesystem write access to intended project directories only. The primary security concern is preventing accidental or malicious file modifications outside the project scope.

## Requirements

### Core Functionality
- Launch bash in a sandboxed environment from the current directory
- Current directory is fully writable (recursively)
- All other filesystem locations are readable but not writable
- Write attempts outside allowed paths fail with standard permission errors (EPERM)
- Sandboxing automatically inherits to all subprocess and child processes
- Network and other system resources remain unrestricted (only filesystem writes are sandboxed)

### Security Constraints
- Can only be invoked from within the user's home directory (subdirectories of `$HOME`)
- Configuration files must be stored outside any potentially sandboxed directory
- Per-directory configurations cannot be modified by sandboxed processes

### Configuration
- Three-tier configuration system:
  1. Global config applies to all sandbash invocations
  2. Per-directory config applies only when invoked from specific directory
  3. Command-line flags add temporary writable paths
- Configuration files use XDG Base Directory specification
- Simple file format: one path per line, comments supported with `#`

## Architecture

### Components

1. **CLI Frontend**
   - Parses command-line arguments
   - Loads and merges configuration from multiple sources
   - Validates current directory is under `$HOME`
   - Handles config management commands (`--add-path`, `--remove-path`, `--edit`, `--list-paths`)

2. **Configuration Manager**
   - Loads global config from `~/.config/sandbash/config`
   - Computes hash of current working directory
   - Loads per-directory config from `~/.config/sandbash/projects/<hash>`
   - Merges all paths (global + per-directory + command-line)
   - Normalizes paths (absolute, tilde expansion, validation)

3. **Sandbox Profile Generator**
   - Generates macOS sandbox profile using TinyScheme language
   - Allows read access to entire filesystem
   - Denies write access by default
   - Allows write access to current directory (recursive)
   - Allows write access to each configured path (recursive)

4. **Bash Launcher**
   - Calls `sandbox_init()` with generated profile
   - Executes `execve()` to replace process with bash
   - Preserves environment and passes through bash arguments

### Implementation Technology

- **Language:** C (required for macOS Sandbox API access)
- **Sandboxing:** macOS Sandbox API (`sandbox_init()` with TinyScheme profiles)
- **Why this approach:** Kernel-level enforcement, no external dependencies, inherits to all children automatically

## Configuration System

### File Locations

All configuration stored in XDG-compliant locations outside any sandboxed directory:

- **Global config:** `~/.config/sandbash/config`
- **Per-directory configs:** `~/.config/sandbash/projects/<hash-of-directory-path>`

### Configuration File Format

Dead simple format with just paths and comments:

```
# This is a comment
# One path per line

/tmp
~/Downloads
/Users/nmix/projects/other-project
```

No sections, no key-value pairs, no options. Just paths.

### Configuration Loading

1. Load global config (if exists)
2. Hash current working directory (e.g., SHA256 of absolute path)
3. Load per-directory config for this hash (if exists)
4. Parse `--allow-write` command-line flags
5. Merge all paths into union set
6. Current directory is implicitly writable (always added)
7. Normalize all paths to absolute form

### Path Resolution

- Convert relative paths to absolute
- Expand `~` to `$HOME`
- Remove trailing slashes
- Validate paths exist (warn if not, but don't fail)
- Writable permissions apply recursively to all subdirectories

## Sandbox Profile

The generated sandbox profile follows this template:

```scheme
(version 1)
(deny default)

; Allow basic process operations
(allow process*)
(allow sysctl-read)
(allow mach-lookup)

; Allow network access (unrestricted)
(allow network*)

; Allow reading entire filesystem
(allow file-read*)

; Deny all write operations by default
(deny file-write*)

; Allow writes to current directory
(allow file-write* (subpath "/full/path/to/current/directory"))

; Allow writes to each configured path
(allow file-write* (subpath "/tmp"))
(allow file-write* (subpath "/Users/nmix/Downloads"))
; ... one rule per writable path
```

## Command-Line Interface

### Sandbox Execution

```bash
# Interactive bash (no command specified)
sandbash

# Execute command directly in sandbox
sandbash npm install
sandbash echo "hello world"
sandbash ./script.sh

# Execute with temporary writable paths
sandbash --allow-write=/tmp touch /tmp/test.txt

# Explicitly execute bash with arguments
sandbash bash -c "npm install"
```

**Argument parsing rules:**
- All arguments before the command are sandbash options (--allow-write, etc.)
- First non-option argument is the command to execute
- All subsequent arguments are passed to the command
- Configuration operations (--add-path, --list-paths, etc.) cannot be combined with command execution

### Configuration Management

These commands operate on configs without entering sandbox:

```bash
# Add path to per-directory config
sandbash --add-path /some/path

# Remove path from per-directory config
sandbash --remove-path /some/path

# Edit per-directory config in $EDITOR
sandbash --edit

# Show all writable paths for current directory
sandbash --list-paths
```

Output format for `--list-paths`:
```
Current directory: /Users/nmix/projects/myapp (always writable)

Global paths (from ~/.config/sandbash/config):
  /tmp
  /Users/nmix/Downloads

Per-directory paths (from ~/.config/sandbash/projects/a1b2c3d4...):
  /Users/nmix/projects/other-project

Command-line paths:
  (none)
```

## Execution Flow

### Startup Sequence

1. Parse command-line arguments
2. Check if operation is config management (`--add-path`, `--remove-path`, `--edit`, `--list-paths`)
   - If yes: perform config operation and exit (no sandbox)
   - If no: continue to sandbox setup
3. Verify current directory is under `$HOME`
   - If not: print error and exit
4. Load global config from `~/.config/sandbash/config`
5. Compute hash of current working directory
6. Load per-directory config from `~/.config/sandbash/projects/<hash>`
7. Parse `--allow-write` flags from command-line
8. Merge all writable paths (global + per-directory + command-line + current directory)
9. Normalize and validate all paths
10. Generate sandbox profile string with all writable paths
11. Call `sandbox_init()` with profile
    - If fails: print clear error message and exit
12. Call `execve()` to replace process with bash
13. Bash runs in sandboxed environment
14. All child processes automatically inherit sandbox

### Error Handling

**Invalid current directory:**
```
Error: sandbash must be invoked from within your home directory
Current directory: /usr/local/bin
Home directory: /Users/nmix
```

**Config file parse error:**
```
Error: Failed to parse config file
File: ~/.config/sandbash/config
Line 5: Invalid path format
```

**Sandbox initialization failure:**
```
Error: Failed to initialize sandbox
Reason: [error from sandbox_init()]
```

**Write to restricted path:**
- No special handling
- Bash receives standard `EPERM` error
- Appears as: `bash: /etc/hosts: Permission denied`
- Same behavior as any permission error

## Security Model

### Threat Model

**Primary threat:** AI-generated or untrusted code attempting to modify files outside the intended project directory.

**Protected against:**
- Accidental writes to system directories
- Malicious writes to home directory files outside project
- Modification of configs (stored outside sandbox)
- Privilege escalation via config tampering

**Not protected against:**
- Network-based attacks (network unrestricted)
- Reading sensitive files (entire filesystem readable)
- Resource exhaustion (memory, CPU, disk space in allowed directories)
- Sandbox escape vulnerabilities in macOS itself

### Design Decisions for Security

1. **No local config in working directory:** Prevents sandboxed process from granting itself more permissions
2. **Home directory restriction:** Prevents sandboxing system directories where broader access might be needed
3. **Hash-based per-directory configs:** Configs identified by directory path hash, not by in-directory file
4. **Immutable sandbox:** Profile set once at startup via `execve()`, cannot be modified after
5. **No interactive approval:** Avoids complexity and maintains strict immutability

## Implementation Notes

### Directory Hash Algorithm

Use SHA256 of absolute directory path (without trailing slash):

```c
// Pseudocode
canonical_path = realpath(getcwd())
hash = sha256(canonical_path)
config_path = "~/.config/sandbash/projects/" + hash[:16]  // First 16 hex chars
```

### Config Management Commands

For `--add-path` and `--remove-path`:
1. Load existing per-directory config
2. Parse into list of paths
3. Add/remove specified path
4. Write back to file
5. Display confirmation with config file path

For `--edit`:
1. Determine per-directory config path
2. Create directory and empty file if doesn't exist
3. Launch `$EDITOR` (default to `vi`)
4. Wait for editor to exit

For `--list-paths`:
1. Go through normal config loading
2. Track source of each path (global/per-directory/command-line)
3. Display organized by source
4. Show config file paths

### Bash Integration

Pass through all bash arguments after processing sandbash-specific flags:

```c
// If user runs: sandbash --allow-write=/tmp -c "echo hello"
// We process: --allow-write=/tmp
// We pass to bash: -c "echo hello"
```

Environment variables preserved (inherit from parent).

## Future Enhancements (Not in MVP)

- `--global` flag for config commands to modify global config instead of per-directory
- Shell alias/wrapper detection and warnings
- Dry-run mode to show what would be sandboxed without actually sandboxing
- Integration with shell prompts (show indicator when in sandbox)
- Support for other shells (zsh, fish)
- Config file includes/imports
- Path wildcards or patterns
- Per-path write vs. create vs. delete granularity

## Testing Strategy

### Manual Testing Scenarios

1. **Basic sandboxing:**
   - Run `sandbash` in test directory
   - Verify can create files in current directory
   - Verify cannot write to `~/Desktop` or other locations
   - Verify can read files everywhere

2. **Configuration:**
   - Add path with `--add-path`
   - Verify new path is writable in sandbox
   - Remove path with `--remove-path`
   - Verify path is no longer writable

3. **Subprocess inheritance:**
   - Launch script that spawns child processes
   - Verify children also cannot write to restricted paths

4. **Error cases:**
   - Try running from `/tmp` (outside home)
   - Try with invalid paths in config
   - Verify clear error messages

### Security Testing

1. Attempt to modify config file from within sandbox (should fail)
2. Attempt to escape sandbox using various techniques
3. Verify `sandbox_init()` is actually being called
4. Check that all syscalls go through sandbox

## Open Questions

None - design complete and approved.
