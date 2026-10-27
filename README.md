# sandbash

A command sandboxing tool for macOS that restricts filesystem write access to designated directories.

## Purpose

`sandbash` enables safe AI-assisted development by executing commands in a sandboxed environment where only specific directories or files are writable. All other filesystem locations remain readable but protected from modification, except paths explicitly denied in config, which are neither readable nor writable.

## Features

- **Filesystem sandboxing**: Current directory is writable, everything else is read-only by default, and denied paths are unreadable
- **Direct command execution**: Run any command in a sandbox, not just bash
- **Three-tier configuration**: Global config, per-directory config, and command-line flags
- **Easy config management**: Built-in commands to add, remove, and edit writable paths for the local directory
- **Subprocess inheritance**: All child processes automatically inherit sandbox restrictions

sanbash uses deprecated APIs that Apple uses privately for its own first-party tools. Caveat emptor.

## Requirements

- macOS 10.10 or later
- Xcode Command Line Tools (for clang)
- Must be invoked from within your home directory

## Installation

Install Xcode Command Line Tools if not already present:
```bash
xcode-select --install
```

Build and install:
```bash
make
sudo make install
```

This installs `sandbash` to `/usr/local/bin/`.

Verify installation:
```bash
# Should print usage
sandbash --help

# Should show current directory
sandbash --list-paths
```

### Uninstalling

```bash
sudo make uninstall
```

## Usage

```bash
# Launch interactive shell in current directory
# Uses your $SHELL (or /bin/bash if not set)
sandbash

# Execute a command in sandbox
sandbash npm install
sandbash echo "hello world"

# Execute with temporary writable path
sandbash --allow-write=/private/tmp touch /tmp/test.txt

# Explicitly run a specific shell with arguments
sandbash bash -c "echo test"
sandbash zsh -c "echo test"

# Add a writable path for this directory
sandbash --add-path /private/tmp

# List configured paths
sandbash --list-paths
```

## Configuration

Configuration files are stored in `~/.config/sandbash/` following the XDG Base Directory specification:

- Global config: `~/.config/sandbash/config`
- Per-directory configs: `~/.config/sandbash/projects/<hash>`

Each non-blank line begins with `+ ` or `- ` followed by a file or directory path:

- `+ PATH` makes the path writable.
- `- PATH` denies the path: it can be neither read nor written, even inside a writable path such as the current directory. Its ancestor directories cannot be renamed or removed, since that would move the denied content to an unprotected path.

Any other line, including comments, is a hard error. Wildcards are not supported.

Create a global config:
```bash
mkdir -p ~/.config/sandbash
cat > ~/.config/sandbash/config <<EOF
+ /private/tmp
+ ~/Downloads
- ~/.ssh
EOF
```

**Note:** Symlinked paths are rejected — use canonical paths instead. For example, `/tmp` is a symlink to `/private/tmp` on macOS, so use `/private/tmp`. sandbash will show the resolved path in the error message if you use a symlink by mistake.

Example config for Claude Code (enables `--dangerously-skip-permissions`):
```
+ ~/.claude
+ ~/.claude.json
```

**Shell Selection:** When launched without arguments, sandbash automatically uses your preferred shell from the `$SHELL` environment variable. If `$SHELL` isn't set or points to a non-existent shell, it falls back to `/bin/bash`.

## Security Model

**Protected against:**
- Accidental writes to system directories
- Malicious writes to files outside project scope
- Config tampering (configs stored outside sandbox)
- Signal delivery to processes outside the sandbox (your editor, shell, and
  other sandbash sessions are unreachable)

**Not protected against:**
- Network-based attacks (network unrestricted)
- Reading sensitive files not listed as `- ` denied paths (filesystem is
  readable by default)
- Denied content leaking through processes outside the sandbox (e.g.
  Spotlight via `mdfind`/`mdls`, `osascript` driving Terminal) or through
  pre-existing hard links located outside the denied path
- Resource exhaustion
- Signal delivery within the sandbox — processes started inside a sandbash
  session can signal each other, so a command can kill dev servers and test
  runners it started
- Interference with SysV shared memory and semaphores owned by the same user
  (SysV message queues remain denied)

**Known Limitations:**
- **Most setuid/setgid binaries cannot be executed** - macOS denies a
  sandboxed process from exec'ing a setuid/setgid binary unless the profile
  grants a `(with no-sandbox)` exception, which runs that child *unconfined*.
  The profile grants exactly one such exception, scoped to the literal path
  `/bin/ps`, because third-party scripts commonly depend on it and `ps` is
  read-only and spawns nothing (so an unconfined `ps` cannot write files or
  leak confinement to descendants). Other setuid tools remain unrunnable:
  - `/usr/bin/top` - Real-time process viewer
  - `/usr/bin/sudo`, `/usr/bin/su` - Privilege escalation
  - `/usr/bin/crontab` - Job scheduling
  - `/usr/sbin/traceroute` - Network diagnostics

  Non-setuid alternatives (like `ls`, `grep`, `whoami`, `uname`, `pgrep`,
  etc.) work normally.

## Troubleshooting

### "must be invoked from within your home directory"

`sandbash` enforces that you can only run it from subdirectories of your home directory. Navigate to your home directory or a project within it.

### "Path contains a symlink on line N: /dev/fd/1"

Appears when redirecting output to a file (`sandbash cmd > out.txt`) if your config lists `/dev/fd/1` or `/dev/fd/2`. With a pipe or terminal those resolve to the tty, but with a file redirect they resolve to a symlink pointing at the target file, which the symlink check rejects. Pipe instead (`sandbash cmd | cat > out.txt`), or drop the `/dev/fd/*` entries from your config.

## License

See [LICENSE](LICENSE)

## Contributing

This is a personal tool project. Issues and pull requests are welcome.
