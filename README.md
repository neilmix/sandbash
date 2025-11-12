# sandbash

A sandboxed bash launcher for macOS that restricts filesystem write access to designated directories.

## Purpose

`sandbash` enables safe AI-assisted development by launching bash in a sandboxed environment where only specific directories are writable. All other filesystem locations remain readable but protected from modification.

## Features

- **Filesystem sandboxing**: Current directory is writable, everything else is read-only by default
- **Three-tier configuration**: Global config, per-directory config, and command-line flags
- **Easy config management**: Built-in commands to add, remove, and edit writable paths
- **Transparent operation**: Works like normal bash with all standard features
- **Subprocess inheritance**: All child processes automatically inherit sandbox restrictions

## Quick Start

```bash
# Build and install
make
sudo make install

# Launch sandboxed bash in current directory
sandbash

# Add a writable path for this directory
sandbash --add-path /tmp

# Launch with temporary writable path
sandbash --allow-write=~/Downloads
```

## Documentation

- [Installation Guide](docs/INSTALL.md)
- [Design Document](docs/plans/2025-11-12-sandbash-design.md)

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
