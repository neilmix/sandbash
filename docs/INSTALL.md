# Installation Guide

## Prerequisites

- macOS 10.10 or later
- Xcode Command Line Tools

Install Xcode Command Line Tools:
```bash
xcode-select --install
```

## Building from Source

1. Clone the repository:
```bash
git clone <repository-url>
cd sandbash
```

2. Build:
```bash
make
```

3. Install (requires sudo):
```bash
sudo make install
```

This installs `sandbash` to `/usr/local/bin/`.

## Uninstalling

```bash
sudo make uninstall
```

## Verification

After installation, verify it works:

```bash
# Should print usage
sandbash --help

# Should show current directory
sandbash --list-paths
```

## Configuration

Configuration files are stored in `~/.config/sandbash/` following the XDG Base Directory specification:

- Global config: `~/.config/sandbash/config`
- Per-directory configs: `~/.config/sandbash/projects/<hash>`

Create a global config:
```bash
mkdir -p ~/.config/sandbash
cat > ~/.config/sandbash/config <<EOF
# Global writable paths
/tmp
~/Downloads
EOF
```

Config format is a list of writeable files and directories one per line.
Comment lines begin with #

## Code Signing (Optional)

If you encounter sandbox initialization errors, the binary may need code signing:

```bash
codesign -s - sandbash
```

For production use, consider signing with a Developer ID certificate.

## Troubleshooting

### "sandbox initialization failed"

This may indicate:
1. The binary needs code signing (see above)
2. macOS security settings blocking execution
3. Invalid sandbox profile generation

### "must be invoked from within your home directory"

`sandbash` enforces that you can only run it from subdirectories of your home directory. Navigate to your home directory or a project within it.

### Config file not found

This is normal on first run. Use `--add-path` to create a per-directory config, or manually create `~/.config/sandbash/config`.
