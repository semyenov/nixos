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

### Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/yourusername/nixos-config.git
   cd nixos-config
   ```

2. **Run automated setup**:
   ```bash
   ./nix.sh setup
   ```

   Or for quick setup (auto-yes):
   ```bash
   ./nix.sh setup -q
   ```

3. **Rebuild system**:
   ```bash
   ./nix.sh rebuild
   ```

## Usage

### Daily Operations

```bash
# Rebuild system (default command)
./nix.sh

# Update flake inputs
./nix.sh update

# Clean old generations
./nix.sh clean

# Rollback to previous
./nix.sh rollback

# Test configuration
./nix.sh test
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
./configure-v2ray.sh 'vless://...'

# Enable in configuration
# Edit hosts/nixos/configuration.nix:
# services.v2ray.enable = true;

# Rebuild
./nix.sh rebuild
```

## Project Structure

```
.
├── flake.nix              # Flake configuration
├── hosts/
│   └── nixos/            # Host-specific configuration
├── modules/              # Modular NixOS configuration
│   ├── core/            # Boot, kernel, Nix settings
│   ├── desktop/         # Desktop environment
│   ├── development/     # Development tools
│   ├── hardware/        # Hardware configuration
│   ├── security/        # Security settings
│   ├── services/        # System services
│   └── system/          # System optimizations
├── users/
│   └── semyenov/        # User home configuration
├── secrets/             # SOPS-encrypted secrets
├── shells.nix           # Development shells
├── nix.sh              # Management script
└── configure-v2ray.sh   # V2Ray setup helper
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
./nix.sh sops

# Edit secrets
sops secrets/v2ray.yaml

# Create new secrets
sops secrets/new-service.yaml
```

See [secrets/README.md](secrets/README.md) for detailed information.

## Troubleshooting

### Common Issues

1. **Hardware configuration missing**:
   ```bash
   sudo nixos-generate-config --dir hosts/nixos/
   ```

2. **Flake not updating**:
   ```bash
   git add .
   ./nix.sh rebuild
   ```

3. **SOPS decryption fails**:
   ```bash
   ./nix.sh sops
   ```

4. **Disk space issues**:
   ```bash
   ./nix.sh clean
   ```

### Debug Commands

```bash
# Check logs
journalctl -xe

# Service status
systemctl status service-name

# Build with trace
./nix.sh rebuild -v

# Test configuration
./nix.sh test
```

## Documentation

- [CLAUDE.md](CLAUDE.md) - Detailed documentation for Claude AI
- [secrets/README.md](secrets/README.md) - Secrets management guide
- `./nix.sh help` - Command help
- `./nix.sh [command] --help` - Command-specific help

## Contributing

1. Fork the repository
2. Create a feature branch
3. Test your changes: `./nix.sh test`
4. Submit a pull request

## License

MIT License - See LICENSE file for details

## Acknowledgments

- [NixOS](https://nixos.org/)
- [Home Manager](https://github.com/nix-community/home-manager)
- [SOPS](https://github.com/mozilla/sops)
- [sops-nix](https://github.com/Mic92/sops-nix)