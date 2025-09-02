# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

NixOS system configuration using Flakes and Home Manager. Modular architecture with NVIDIA graphics support, GNOME desktop, comprehensive development environment, and V2Ray proxy service.

## Commands

### Task Runner

The project uses [go-task](https://taskfile.dev) for automation. Install: `nix-shell -p go-task` or add to configuration.

```bash
# Show all available tasks
task --list-all

# Common operations
task rebuild          # Rebuild and switch configuration
task test            # Test configuration
task update          # Update flake inputs
task clean           # Clean old generations
task setup:init      # Initial system setup
task rollback        # Rollback to previous generation

# Quick aliases
task r               # Rebuild (alias)
task t               # Test (alias)
task u               # Update (alias)
task c               # Clean (alias)

# Specific operations
task rebuild:test    # Test without switching
task rebuild:boot    # Set as boot default
task rebuild:trace   # Rebuild with trace
task update:input INPUT=nixpkgs  # Update specific input
task clean:keep KEEP=5           # Keep N generations

# V2Ray management
task v2ray:config URL="vless://..."  # Configure from URL
task v2ray:status                    # Check service status
task v2ray:test                      # Test proxy connection

# Setup operations
task setup:hardware            # Generate hardware config
task setup:sops               # Setup SOPS encryption
task setup:validate           # Validate setup

# Git operations
task git:status              # Show git status
task git:commit MSG="..."    # Commit changes
task git:commit:rebuild      # Auto-commit for rebuild

# Task help
task --summary <task-name>   # Show task details
```

### Rebuild Operations

```bash
# Quick rebuild
task rebuild

# Test configuration without switching
task rebuild:test

# Build for boot only
task rebuild:boot

# Rebuild with trace
task rebuild:trace

# Dry run
task rebuild:dry
```

### Testing & Validation

```bash
# Run all tests
task test

# Validate flake configuration
task test:flake

# Check all systems
task test:flake:all

# Check formatting
task test:format
```

### V2Ray Configuration

```bash
# Configure V2Ray from VLESS URL
task v2ray:config URL='vless://UUID@server:port?pbk=...&sid=...'

# Check service status
task v2ray:status

# Test proxy connection
task v2ray:test

# View logs
task v2ray:logs
```

### Development Shells

```bash
# Enter specific development environment
nix develop .#typescript  # TypeScript/JavaScript
nix develop .#python      # Python
nix develop .#rust        # Rust
nix develop .#go          # Go
nix develop .#cpp         # C/C++
nix develop .#devops      # DevOps tools
nix develop .#database    # Database tools
nix develop .#datascience # Data Science
nix develop .#mobile      # Mobile development
nix develop .#security    # Security testing

# Default development shell
nix develop
```

### Manual Commands (Fallback)

```bash
# Direct nixos-rebuild
sudo nixos-rebuild switch --flake .#nixos

# Flake operations
nix flake update
nix flake check
nix flake show
nix flake metadata

# Home Manager
home-manager switch --flake .#semyenov

# System info
nixos-version
nix-env --list-generations --profile /nix/var/nix/profiles/system
```

## Architecture

### Module Organization

The configuration follows a strict modular architecture with 2025 best practices:

```
flake.nix                    # Entry point, defines nixosConfigurations and devShells
├── hosts/nixos/             
│   ├── configuration.nix    # Host-specific: locale, users, system packages
│   └── hardware-configuration.nix  # Generated hardware config (not in git)
├── modules/
│   ├── core/               # Boot, kernel, Nix settings (loaded first)
│   ├── hardware/           # NVIDIA drivers, auto-detection
│   ├── desktop/            # GNOME environment
│   ├── services/           # System services
│   ├── development/        # Dev tools and languages
│   ├── security/           # Firewall, SOPS, hardening profiles
│   └── system/             # System-level configuration
│       ├── optimization.nix # Compatibility layer for new modules
│       ├── performance/    # Modular performance optimization
│       │   ├── zram.nix   # ZRAM with swappiness=180
│       │   ├── kernel.nix # Kernel profiles (balanced/performance/low-latency)
│       │   └── filesystem.nix # Filesystem optimizations
│       └── maintenance/    # System maintenance
│           └── auto-update.nix # Auto-updates, monitoring, GC
├── users/semyenov/         # Home Manager user configuration
└── secrets/                # SOPS-encrypted secrets
```

### Module Loading Order

1. **Core modules** (`core/nix.nix`, `core/boot.nix`) - Base system configuration
2. **Hardware modules** - Hardware detection and drivers
3. **Service modules** - System services (networking must load before dependent services)
4. **Desktop modules** - Desktop environment
5. **Development modules** - Development tools
6. **User configuration** - Home Manager (loads last)

### Key Configuration Points

- **Flake Inputs**: nixpkgs (25.05), home-manager (25.05), sops-nix, nixos-hardware
- **State Version**: 25.05 (DO NOT change without migration)
- **User**: semyenov with sudo, docker, network access
- **Shell**: ZSH with Starship prompt
- **Development**: Node.js 22, TypeScript, Bun, Deno, multiple package managers

### Service Dependencies

- `v2ray-secrets.nix` requires `sops.nix` to be loaded
- `backup.nix` requires valid paths and services to backup
- `monitoring.nix` depends on network configuration
- V2Ray service is disabled by default (enable with `services.v2ray.enable = true;`)
- Performance modules can be used independently or together
- Security hardening may conflict with some services (start with "minimal" profile)

## First-Time Setup

### Prerequisites

1. **Generate hardware configuration**:
   ```bash
   sudo nixos-generate-config --dir hosts/nixos/
   ```

2. **Setup SOPS encryption**:
   ```bash
   task setup:sops
   ```

3. **Configure V2Ray** (optional):
   ```bash
   task v2ray:config URL='vless://YOUR_URL_HERE'
   ```

4. **Build and switch**:
   ```bash
   task rebuild
   ```

### Automated Setup

```bash
# Full interactive setup
task setup:init
```

## Working with Secrets

### SOPS Configuration

The repository uses SOPS with age keys for secret management:

1. **Age key location**: `~/.config/sops/age/keys.txt`
2. **Configuration**: `.sops.yaml` defines encryption rules
3. **Secret files**: `secrets/*.yaml` are encrypted at rest

### V2Ray Secrets

V2Ray configuration expects these SOPS-encrypted fields:
- `v2ray/server_address`: Target server
- `v2ray/server_port`: Server port
- `v2ray/user_id`: VLESS UUID
- `v2ray/public_key`: Reality public key
- `v2ray/short_id`: Reality short ID

### Managing Secrets

```bash
# Edit encrypted secrets
sops secrets/v2ray.yaml

# Create new secret from template
cp secrets/v2ray.yaml.example secrets/v2ray.yaml
sops -e -i secrets/v2ray.yaml

# Verify SOPS setup
grep age1 .sops.yaml
```

## Adding/Modifying Configuration

### System-wide Changes

1. **System packages**: Edit `hosts/nixos/configuration.nix`
2. **User packages**: Edit `users/semyenov/home.nix`
3. **New module**: Create in `modules/`, add to `flake.nix` imports
4. **Enable services**: Add to host configuration:
   ```nix
   services.v2ray.enable = true;
   services.backup.enable = true;
   services.monitoring.enable = true;
   ```

5. **Performance tuning** (2025 best practices):
   ```nix
   performance.kernel.profile = "performance";
   performance.zram.memoryPercent = 75;
   performance.filesystem.tmpfsSize = "16G";
   ```

6. **Security hardening** (opt-in):
   ```nix
   security.hardening.enable = true;
   security.hardening.profile = "standard";  # or "hardened" for stronger security
   ```

7. **Auto-updates** (opt-in):
   ```nix
   system.maintenance.autoUpdate.enable = true;
   system.maintenance.autoUpdate.allowReboot = true;
   ```

### Testing Changes

Always test before applying:
```bash
# Validate syntax and configuration
task test

# Test build without switching
task rebuild:test

# Apply if successful
task rebuild
```

## Common Pitfalls

1. **Flake not updating**: Run `git add .` before rebuild - flakes only see staged/committed files
2. **SOPS decryption fails**: Ensure age key exists at `~/.config/sops/age/keys.txt`
3. **Hardware config missing**: Must generate with `nixos-generate-config --dir hosts/nixos/`
4. **Service failures**: Check with `systemctl status <service>` and `journalctl -xeu <service>`
5. **Disk space issues**: Run `task clean` to remove old generations
6. **Home Manager conflicts**: Creates `.backup` files when configs conflict with existing files

## Troubleshooting

```bash
# System logs
journalctl -xe
journalctl -u v2ray.service  # Service-specific

# Build errors with trace
task rebuild:trace

# Home Manager errors
home-manager switch --flake .#semyenov --show-trace

# Check generation differences
nix profile diff-closures --profile /nix/var/nix/profiles/system

# Garbage collection
task clean

# Store optimization
nix-store --optimise
```

