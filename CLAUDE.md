# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

NixOS system configuration using Flakes and Home Manager. Modular architecture with NVIDIA graphics support, GNOME desktop, comprehensive development environment, and V2Ray proxy service.

## Commands

### Unified Management Script (`nix.sh`)

All primary operations are handled through the unified `nix.sh` script:

```bash
# Quick rebuild (default command)
./nix.sh

# Full system setup wizard
./nix.sh setup

# Test configuration
./nix.sh test

# Update flake inputs
./nix.sh update

# Clean old generations
./nix.sh clean

# Rollback to previous generation
./nix.sh rollback

# Setup SOPS encryption
./nix.sh sops

# Show help
./nix.sh help

# Command-specific help
./nix.sh rebuild --help
```

### Rebuild Operations

```bash
# Quick rebuild with auto-staging
./nix.sh rebuild

# Test configuration without switching
./nix.sh rebuild test

# Update and rebuild
./nix.sh rebuild -u

# Dry run (preview changes)
./nix.sh rebuild -n

# Verbose output with trace
./nix.sh rebuild -v

# Build for boot only
./nix.sh rebuild boot
```

### Setup Workflow

```bash
# Interactive setup for new system
./nix.sh setup

# Quick setup (auto-yes to all)
./nix.sh setup -q

# Only SOPS setup
./nix.sh setup --skip-hardware --skip-test --skip-build

# Only hardware configuration
./nix.sh setup --skip-sops --skip-test --skip-build
```

### Testing & Validation

```bash
# Run all tests
./nix.sh test

# Run specific tests
./nix.sh test syntax flake

# Quick validation with fail-fast
./nix.sh test -f

# Generate JSON report
./nix.sh test --format json > report.json

# Available tests: syntax, flake, build, modules, secrets, hardware, security
```

### V2Ray Configuration

```bash
# Configure V2Ray from VLESS URL
./configure-v2ray.sh 'vless://UUID@server:port?pbk=...&sid=...'

# Dry run to preview
./configure-v2ray.sh -n 'vless://...'

# Force overwrite existing
./configure-v2ray.sh -f 'vless://...'
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

The configuration follows a strict modular architecture:

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
│   ├── security/           # Firewall, SOPS
│   └── system/             # Performance optimizations
├── users/semyenov/         # Home Manager user configuration
├── secrets/                # SOPS-encrypted secrets
└── scripts/lib/common.sh   # Shared bash library
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

- `v2ray-sops.nix` requires `sops.nix` to be loaded
- `backup.nix` requires valid paths and services to backup
- `monitoring.nix` depends on network configuration
- V2Ray service is disabled by default (enable with `services.v2ray.enable = true;`)

## First-Time Setup

### Prerequisites

1. **Generate hardware configuration**:
   ```bash
   sudo nixos-generate-config --dir hosts/nixos/
   ```

2. **Setup SOPS encryption**:
   ```bash
   ./nix.sh sops
   ```

3. **Configure V2Ray** (optional):
   ```bash
   ./configure-v2ray.sh 'vless://YOUR_URL_HERE'
   ```

4. **Build and switch**:
   ```bash
   ./nix.sh rebuild
   ```

### Automated Setup

```bash
# Full interactive setup
./nix.sh setup

# Quick setup (auto-yes)
./nix.sh setup -q
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

### Testing Changes

Always test before applying:
```bash
# Validate syntax and configuration
./nix.sh test

# Test build without switching
./nix.sh rebuild test

# Apply if successful
./nix.sh rebuild
```

## Common Pitfalls

1. **Flake not updating**: Run `git add .` before rebuild - flakes only see staged/committed files
2. **SOPS decryption fails**: Ensure age key exists at `~/.config/sops/age/keys.txt`
3. **Hardware config missing**: Must generate with `nixos-generate-config --dir hosts/nixos/`
4. **Service failures**: Check with `systemctl status <service>` and `journalctl -xeu <service>`
5. **Disk space issues**: Run `./nix.sh clean` to remove old generations
6. **Home Manager conflicts**: Creates `.backup` files when configs conflict with existing files

## Troubleshooting

```bash
# System logs
journalctl -xe
journalctl -u v2ray.service  # Service-specific

# Build errors with trace
./nix.sh rebuild -v

# Home Manager errors
home-manager switch --flake .#semyenov --show-trace

# Check generation differences
nix profile diff-closures --profile /nix/var/nix/profiles/system

# Garbage collection
./nix.sh clean

# Store optimization
nix-store --optimise
```

## Script Library (`scripts/lib/common.sh`)

The common library provides extensive utilities for all scripts:

### Logging Functions
- `log_debug`, `log_info`, `log_warn`, `log_error`, `log_critical`
- `print_success`, `print_warning`, `print_error`, `print_info`, `print_step`
- `print_header` - Section headers
- `spinner` - Progress spinner for long operations
- `progress_bar` - Progress bar for batch operations

### Utility Functions
- `command_exists` - Check if command is available
- `is_root`, `require_root`, `require_non_root` - Permission checks
- `confirm` - Interactive confirmations
- `retry_with_backoff` - Retry failed operations
- `create_temp_file`, `create_temp_dir` - Temporary file management
- `acquire_lock`, `release_lock` - Script locking
- `backup_file` - Create timestamped backups
- `check_requirements` - Verify required commands
- `parse_options` - Standard option parsing

### Error Handling
- `setup_error_handling` - Enable comprehensive error trapping
- `error_handler` - Automatic stack traces on errors
- `cleanup_on_exit` - Cleanup temporary files and locks

All scripts should source this library for consistent behavior and user experience.