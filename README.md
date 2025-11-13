# sandbash

A command sandboxing tool for macOS that restricts filesystem write access to designated directories.

## Purpose

`sandbash` enables safe AI-assisted development by executing commands in a sandboxed environment where only specific directories or files are writable. All other filesystem locations remain readable but protected from modification.

## Features

- **Filesystem sandboxing**: Current directory is writable, everything else is read-only by default
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
sandbash --allow-write=/tmp touch /tmp/test.txt

# Explicitly run a specific shell with arguments
sandbash bash -c "echo test"
sandbash zsh -c "echo test"

# Add a writable path for this directory
sandbash --add-path /tmp

# List configured paths
sandbash --list-paths
```

## Configuration

Configuration files are stored in `~/.config/sandbash/` following the XDG Base Directory specification:

- Global config: `~/.config/sandbash/config`
- Per-directory configs: `~/.config/sandbash/projects/<hash>`

Config format is a list of writable files and directories, one per line. Comment lines begin with `#`.

Create a global config:
```bash
mkdir -p ~/.config/sandbash
cat > ~/.config/sandbash/config <<EOF
# Global writable paths
/tmp
~/Downloads
EOF
```

Example config for Claude Code:
```
# Enable Claude Code for --dangerously-skip-permissions
~/.claude
~/.claude.json
```

**Shell Selection:** When launched without arguments, sandbash automatically uses your preferred shell from the `$SHELL` environment variable. If `$SHELL` isn't set or points to a non-existent shell, it falls back to `/bin/bash`.

## Security Model

**Protected against:**
- Accidental writes to system directories
- Malicious writes to files outside project scope
- Config tampering (configs stored outside sandbox)

**Not protected against:**
- Network-based attacks (network unrestricted)
- Reading sensitive files (filesystem is readable)
- Resource exhaustion

## Troubleshooting

### "must be invoked from within your home directory"

`sandbash` enforces that you can only run it from subdirectories of your home directory. Navigate to your home directory or a project within it.

## License

See [LICENSE](LICENSE)

## Contributing

This is a personal tool project. Issues and pull requests are welcome.
