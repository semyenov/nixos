# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

NixOS system configuration using Flakes and Home Manager. Modular architecture with NVIDIA graphics support, GNOME desktop, comprehensive development environment, and V2Ray proxy service.

## Commands

### Task Runner (Primary Method)

The project uses [go-task](https://taskfile.dev) for automation. Install: `nix-shell -p go-task` or add to configuration.

```bash
# Show all available tasks
task --list-all

# Common operations
task rebuild          # Rebuild and switch configuration
task test            # Run all tests (flake, format, unit)
task update          # Update flake inputs
task clean           # Clean old generations
task format          # Format all Nix files
task rollback        # Rollback to previous generation

# Quick aliases
task r               # Rebuild (alias)
task t               # Test (alias)
task u               # Update (alias)
task c               # Clean (alias)

# Testing commands
task test:flake      # Validate flake configuration
task test:flake:current  # Validate for current system only
task test:format     # Check Nix formatting
task test:unit       # Run unit tests
task test:vm         # Run VM integration tests
task test:vm:single TEST=backup  # Run specific VM test

# Alternative test runners
./scripts/run-unit-tests.sh  # Detailed unit test output with coverage
./scripts/run-vm-tests.sh     # Run VM tests directly

# Rebuild variants
task rebuild MODE=test    # Test without switching
task rebuild MODE=boot    # Set as boot default
task rebuild MODE=dry     # Dry run
task rebuild TRACE=true   # Rebuild with trace

# System management
task status          # Show git and system status
task info            # Show system information
task commit MSG="..." # Commit changes with message

# Setup operations
task setup:init              # Full initial setup
task setup:hardware          # Generate hardware config
task setup:sops              # Setup SOPS encryption
```

### Taskfile.yml Key Behaviors

**Important**: The `rebuild` task automatically runs `git add -A` before rebuilding. This ensures flakes see all changes (flakes only see staged/committed files).

**Task Parameters**:
- `MODE`: Controls rebuild behavior (switch/test/boot/dry)
- `TRACE`: Enables detailed error traces when true
- `TEST`: Specifies which VM test to run
- `INPUT`: Specifies which flake input to update
- `KEEP`: Number of generations to keep when cleaning
- `DAYS`: Days threshold for garbage collection
- `TYPE`: Development shell type to enter

**Global Variables**:
- `FLAKE_PATH`: Path to flake (defaults to current directory)
- `HOSTNAME`: System hostname (defaults to "nixos")
- `FLAKE_REF`: Computed as `${FLAKE_PATH}#${HOSTNAME}`

**Environment**: Sets `NIXOS_OZONE_WL=1` for Wayland support

### Development Shells

```bash
# Enter specific development environment
nix develop .#nixos    # NixOS configuration development
nix develop .#web      # Web development (Node.js, TypeScript, Bun, Deno)
nix develop .#systems  # Systems programming (Rust, Go, C/C++)
nix develop .#ops      # DevOps & Data Science (Python, Docker, K8s)
nix develop .#mobile   # Mobile & Security (Flutter, Android, security tools)

# Alternative using task command
task shell TYPE=web    # Enter web development shell
```

## Architecture

### Module Organization

The configuration follows a strict modular architecture with centralized configuration:

```
flake.nix                    # Entry point, defines nixosConfigurations and devShells
├── lib/
│   ├── config.nix          # Central configuration (ports, defaults, magic numbers)
│   ├── module-utils.nix    # Helper functions for creating module options
│   └── validators.nix      # Type validators and conflict detection
├── profiles/
│   ├── base.nix            # Shared base configuration
│   ├── workstation.nix     # Development-focused configuration
│   ├── server.nix          # Production server configuration
│   └── minimal.nix         # Lightweight configuration
├── hosts/nixos/             
│   ├── configuration.nix    # Host-specific: locale, users, system packages
│   └── hardware-configuration.nix  # Generated hardware config (not in git)
├── modules/
│   ├── core/               # Boot, kernel, Nix settings (loaded first)
│   ├── hardware/           # NVIDIA drivers, auto-detection
│   ├── desktop/            # GNOME environment
│   ├── services/           
│   │   ├── network/        # V2Ray, networking services
│   │   └── system/         # Backup, monitoring services
│   ├── development/        # Dev tools and languages
│   ├── security/           # Firewall, SOPS, hardening
│   └── system/             
│       ├── optimization.nix # Compatibility layer for performance modules
│       ├── performance/    # ZRAM, kernel tuning, filesystem
│       └── maintenance/    # Auto-updates, monitoring
├── users/semyenov/         # Home Manager user configuration
├── secrets/                # SOPS-encrypted secrets
├── tests/
│   ├── vm/                # VM integration tests
│   ├── unit/               # Unit tests for utilities
│   └── lib/                # Test helper functions
├── scripts/
│   ├── run-unit-tests.sh   # Unit test runner
│   └── run-vm-tests.sh     # VM test runner
└── shells.nix              # Development shell definitions
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

### Central Configuration (lib/config.nix)

All hardcoded values are centralized:
- Network ports (SSH: 22, HTTP: 80, HTTPS: 443, dev ports)
- Security settings (rate limits, fail2ban attempts)
- Performance defaults (ZRAM percentage, swappiness)
- Backup settings (default repository, retention)
- System limits (file descriptors, processes)

### Module Utilities (lib/module-utils.nix)

Helper functions for consistent module creation:
- `mkServiceEnableOption` - Standard service enable option
- `mkPortOption` - Port configuration with validation
- `mkPercentageOption` - Percentage values (0-100)
- `mkScheduleOption` - Systemd timer schedules
- Custom types: `networkConfig`, `serviceConfig`, `cronSchedule`, `cidr`, `domain`

### Service Dependencies

- `v2ray-secrets.nix` requires `sops.nix` to be loaded
- `backup.nix` requires valid paths and services to backup
- `monitoring.nix` depends on network configuration
- V2Ray service is disabled by default (enable with `services.v2rayWithSecrets.enable = true;`)

## Testing Infrastructure

### Unit Tests
Located in `tests/unit/`, run with `task test:unit`:
- `module-utils.nix` - Tests for module utility functions
- `validators.nix` - Tests for validation system
- Uses `nix-instantiate --eval` for evaluation
- Alternative runner: `./scripts/run-unit-tests.sh` for detailed output

### VM Tests
Located in `tests/vm/`, run with `task test:vm`:
- `backup.nix` - Tests backup service functionality
- `firewall.nix` - Tests firewall rules and fail2ban
- `monitoring.nix` - Tests Prometheus, Grafana, and alerts
- `performance.nix` - Tests kernel, ZRAM, and filesystem optimizations
- `v2ray-secrets.nix` - Tests V2Ray service with SOPS secrets

### Test Utilities
`tests/lib/test-utils.nix` provides common VM configuration and helper functions.

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
```

## Adding/Modifying Configuration

### System-wide Changes

1. **System packages**: Edit `hosts/nixos/configuration.nix`
2. **User packages**: Edit `users/semyenov/home.nix`
3. **New module**: Create in `modules/` appropriate subdirectory
4. **Enable services**: Add to host configuration:
   ```nix
   services.v2rayWithSecrets.enable = true;
   services.backup.enable = true;
   services.monitoring.enable = true;
   ```

### Using Configuration Profiles

Apply pre-configured profiles in `hosts/nixos/configuration.nix`:
```nix
imports = [
  ../../profiles/workstation.nix  # For development machines
  # OR
  ../../profiles/server.nix        # For production servers
  # OR
  ../../profiles/minimal.nix       # For resource-constrained systems
];
```

## Common Pitfalls

1. **Flake not updating**: Run `git add .` before rebuild - flakes only see staged/committed files
2. **SOPS decryption fails**: Ensure age key exists at `~/.config/sops/age/keys.txt`
3. **Hardware config missing**: Must generate with `task setup:hardware`
4. **Service failures**: Check with `systemctl status <service>` and `journalctl -xeu <service>`
5. **Disk space issues**: Run `task clean` to remove old generations
6. **Home Manager conflicts**: Creates `.backup` files when configs conflict with existing files
7. **Module import errors**: Check module is imported in host configuration
8. **Type errors**: Use module-utils.nix helpers for consistent option types

## Testing Scripts

The repository includes test runner scripts in `scripts/`:

- **run-unit-tests.sh**: Runs unit tests with detailed output and test counts
- **run-vm-tests.sh**: Executes VM integration tests

These scripts provide colored output and detailed test results.