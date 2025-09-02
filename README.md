# NixOS Configuration

A modular NixOS system configuration using Flakes, Home Manager, and SOPS for secrets management.

## Features

- 🚀 **NixOS 25.05** with Flakes
- 🏠 **Home Manager** for user configuration
- 🔐 **SOPS** for secrets management
- 🎮 **NVIDIA** graphics support
- 🖥️ **GNOME** desktop environment
- 🛠️ **Development Tools** - Multiple languages and environments
- 🌐 **V2Ray** proxy support
- 📦 **Docker** container support
- 🔧 **Modular** architecture

## Quick Start

### Prerequisites

- NixOS installed (or installing)
- Git installed
- Basic understanding of Nix
- [go-task](https://taskfile.dev) for task automation

### Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/yourusername/nixos-config.git
   cd nixos-config
   ```

2. **Install task runner** (recommended):
   ```bash
   nix-shell -p go-task
   # Or add to your system: add 'go-task' to environment.systemPackages
   ```

3. **Run automated setup**:
   ```bash
   task setup:init
   ```

4. **Rebuild system**:
   ```bash
   task rebuild
   ```

## Usage

### Daily Operations

```bash
# Show all available tasks
task --list-all

# Rebuild system
task rebuild          # or just 'task r'

# Test configuration
task test            # or 'task t'

# Update flake inputs
task update          # or 'task u'

# Clean old generations
task clean           # or 'task c'

# Rollback to previous
task rollback

# Show system info
task info
```

### Development Environments

```bash
# TypeScript/JavaScript
nix develop .#typescript

# Python
nix develop .#python

# Rust
nix develop .#rust

# Go
nix develop .#go

# See all available shells
nix flake show
```

### V2Ray Proxy Setup

```bash
# Configure from VLESS URL
task v2ray:config URL='vless://...'

# Check service status
task v2ray:status

# Test proxy connection
task v2ray:test

# View logs
task v2ray:logs

# Enable in configuration
# Edit hosts/nixos/configuration.nix:
# services.v2rayWithSecrets.enable = true;

# Rebuild
task rebuild
```

## Project Structure

```
.
├── flake.nix              # Flake configuration
├── Taskfile.yml           # Task automation (go-task)
├── tasks/                 # Modular task files
│   ├── setup.yml         # Setup tasks
│   ├── v2ray.yml         # V2Ray management
│   └── git.yml           # Git operations
├── hosts/
│   └── nixos/            # Host-specific configuration
├── modules/              # Modular NixOS configuration
│   ├── core/            # Boot, kernel, Nix settings
│   ├── desktop/         # Desktop environment
│   ├── development/     # Development tools (includes go-task)
│   ├── hardware/        # Hardware configuration
│   ├── security/        # Security settings
│   ├── services/        # System services
│   └── system/          # System optimizations
├── users/
│   └── semyenov/        # User home configuration
├── secrets/             # SOPS-encrypted secrets
└── shells.nix           # Development shells
```

## Configuration

### System Packages

Edit `hosts/nixos/configuration.nix`:
```nix
environment.systemPackages = with pkgs; [
  vim
  git
  firefox
];
```

### User Packages

Edit `users/semyenov/home.nix`:
```nix
home.packages = with pkgs; [
  vscode
  slack
  spotify
];
```

### Enable Services

In `hosts/nixos/configuration.nix`:
```nix
# Enable V2Ray proxy
services.v2ray.enable = true;

# Enable backup service
services.backup.enable = true;

# Enable monitoring
services.monitoring.enable = true;
```

## Secrets Management

Secrets are managed with SOPS and age encryption:

```bash
# Setup SOPS
task setup:sops

# Edit V2Ray secrets
task setup:sops:edit-v2ray

# Edit secrets directly
sops secrets/v2ray.yaml

# Create new secrets
sops secrets/new-service.yaml
```

See [secrets/README.md](secrets/README.md) for detailed information.

## Troubleshooting

### Common Issues

1. **Hardware configuration missing**:
   ```bash
   task setup:hardware
   # Or manually:
   sudo nixos-generate-config --dir hosts/nixos/
   ```

2. **Flake not updating** (uncommitted changes):
   ```bash
   task git:add-all       # Stage all changes
   task git:commit:rebuild  # Auto-commit for rebuild
   task rebuild
   ```

3. **SOPS decryption fails**:
   ```bash
   task setup:sops
   ```

4. **Disk space issues**:
   ```bash
   task clean
   # Or keep some generations:
   task clean:keep KEEP=5
   ```

### Debug Commands

```bash
# Check logs
journalctl -xe

# Service status
systemctl status service-name

# Build with detailed trace
task rebuild:trace

# Test configuration
task test

# Validate flake
task test:flake

# Check formatting
task test:format

# System information
task info
task info:generation
task info:kernel
```

## Documentation

- [CLAUDE.md](CLAUDE.md) - Detailed documentation for Claude AI
- [secrets/README.md](secrets/README.md) - Secrets management guide
- `task --list-all` - List all available tasks
- `task --summary <task-name>` - Show task details
- `task help` - General help

## Contributing

1. Fork the repository
2. Create a feature branch
3. Test your changes: `task test`
4. Submit a pull request

## License

MIT License - See LICENSE file for details

## Acknowledgments

- [NixOS](https://nixos.org/)
- [Home Manager](https://github.com/nix-community/home-manager)
- [SOPS](https://github.com/mozilla/sops)
- [sops-nix](https://github.com/Mic92/sops-nix)