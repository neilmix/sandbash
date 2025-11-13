# sandbash

A command sandboxing tool for macOS that restricts filesystem write access to designated directories.

## Purpose

`sandbash` enables safe AI-assisted development by executing commands in a sandboxed environment where only specific directories are writable. All other filesystem locations remain readable but protected from modification.

## Features

- **Filesystem sandboxing**: Current directory is writable, everything else is read-only by default
- **Direct command execution**: Run any command in a sandbox, not just bash
- **Three-tier configuration**: Global config, per-directory config, and command-line flags
- **Easy config management**: Built-in commands to add, remove, and edit writable paths
- **Subprocess inheritance**: All child processes automatically inherit sandbox restrictions

This uses deprecated APIs that Apple uses privately for its own first-party tools. Caveat emptor.

## Quick Start

```bash
# Build and install
make
sudo make install

# Launch interactive shell in current directory
# Uses your $SHELL (or /bin/bash if not set)
sandbash

# Execute a command in sandbox
sandbash npm install
sandbash echo "hello world"

# Execute with temporary writable path
sandbash --allow-write=/tmp touch /tmp/test.txt

# Explicitly run a specific shell with arguments
sandbash bash -c "echo test"
sandbash zsh -c "echo test"

# Add a writable path for this directory
sandbash --add-path /tmp

# List configured paths
sandbash --list-paths
```

**Shell Selection:** When launched without arguments, sandbash automatically uses your preferred shell from the `$SHELL` environment variable. If `$SHELL` isn't set or points to a non-existent shell, it falls back to `/bin/bash`.

Global configuration is stored in ~/.config/sandbash/config

Here is an example config for claude code:
```
# enable claude code for --dangerously-skip-permissions
~/.claude
~/.claude.json
```

## Documentation

- [Installation Guide](docs/INSTALL.md)

## Requirements

- macOS 10.10 or later
- Xcode Command Line Tools (for clang)
- Must be invoked from within your home directory

## Security Model

**Protected against:**
- Accidental writes to system directories
- Malicious writes to files outside project scope
- Config tampering (configs stored outside sandbox)

**Not protected against:**
- Network-based attacks (network unrestricted)
- Reading sensitive files (filesystem is readable)
- Resource exhaustion

## License

See [LICENSE](LICENSE)

## Contributing

This is a personal tool project. Issues and pull requests are welcome.
