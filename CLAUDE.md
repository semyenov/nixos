# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

NixOS system configuration using Flakes and Home Manager. Modular architecture with NVIDIA graphics support, GNOME desktop, comprehensive development environment, and V2Ray proxy service. The codebase follows 2025 best practices with centralized configuration, reusable utilities, comprehensive testing, and configuration profiles.

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

# Rebuild variants
task rebuild:test    # Test without switching
task rebuild:boot    # Set as boot default
task rebuild:trace   # Rebuild with trace
task rebuild:dry     # Dry run

# Specific operations
task update:input INPUT=nixpkgs  # Update specific input
task clean:keep KEEP=5           # Keep N generations
task info                        # Show system information

# V2Ray management
task v2ray:config URL="vless://..."  # Configure from URL
task v2ray:status                    # Check service status
task v2ray:test                      # Test proxy connection

# Setup operations
task setup:init              # Full initial setup
task setup:hardware          # Generate hardware config
task setup:sops              # Setup SOPS encryption
task setup:validate          # Validate setup

# Git operations
task git:status              # Show git status
task git:commit MSG="..."    # Commit changes
task git:commit:rebuild      # Auto-commit for rebuild
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

The configuration follows a strict modular architecture with centralized configuration:

```
flake.nix                    # Entry point, defines nixosConfigurations and devShells
├── lib/
│   ├── config.nix          # Central configuration (ports, defaults, magic numbers)
│   ├── module-utils.nix    # Helper functions for creating module options
│   └── validators.nix      # Type validators and conflict detection
├── profiles/
│   ├── workstation.nix     # Development-focused configuration
│   ├── server.nix          # Production server configuration
│   └── minimal.nix         # Lightweight configuration
├── hosts/nixos/             
│   ├── configuration.nix    # Host-specific: locale, users, system packages
│   └── hardware-configuration.nix  # Generated hardware config (not in git)
├── modules/
│   ├── core/               # Boot, kernel, Nix settings (loaded first)
│   │   └── index.nix       # Module index for auto-import
│   ├── hardware/           # NVIDIA drivers, auto-detection
│   │   └── index.nix       
│   ├── desktop/            # GNOME environment
│   │   └── index.nix       
│   ├── services/           
│   │   ├── index.nix       
│   │   ├── network/        # V2Ray, networking services
│   │   └── system/         # Backup, monitoring services
│   ├── development/        # Dev tools and languages
│   │   └── index.nix       
│   ├── security/           # Firewall, SOPS, hardening
│   │   └── index.nix       
│   └── system/             
│       ├── index.nix       
│       ├── optimization.nix # Compatibility layer
│       ├── performance/    # ZRAM, kernel tuning, filesystem
│       └── maintenance/    # Auto-updates, monitoring
├── users/semyenov/         # Home Manager user configuration
├── secrets/                # SOPS-encrypted secrets
├── tests/
│   ├── vm/                # VM integration tests
│   ├── unit/               # Unit tests for utilities
│   └── lib/                # Test helper functions
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
- Validators: `isEmail`, `isIPv4`, `isValidPort`, `isSystemdTimer`

### Service Dependencies

- `v2ray-sops.nix` requires `sops.nix` to be loaded
- `backup.nix` requires valid paths and services to backup
- `monitoring.nix` depends on network configuration
- V2Ray service is disabled by default (enable with `services.v2ray.enable = true;`)

## Testing Infrastructure

### Unit Tests
Located in `tests/unit/`, run with `task test:unit`:
- `module-utils.nix` - Tests for module utility functions
- `validators.nix` - Tests for validation system (service dependencies, paths, memory sizes)
- Uses `nix-instantiate --eval` for evaluation
- Alternative runner: `./scripts/run-unit-tests.sh` for detailed output

### VM Tests
Located in `tests/vm/`, run with `task test:vm`:
- `backup.nix` - Tests backup service functionality
- `firewall.nix` - Tests firewall rules and fail2ban
- `monitoring.nix` - Tests Prometheus, Grafana, and alerts
- `performance.nix` - Tests kernel, ZRAM, and filesystem optimizations
- Uses NixOS VM testing framework

### Test Utilities
`tests/lib/test-utils.nix` provides:
- Common VM configuration for faster tests
- Helper functions for test patterns
- Standardized test environment

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
3. **New module**: Create in `modules/`, add to appropriate subdirectory index
4. **Enable services**: Add to host configuration:
   ```nix
   services.v2ray.enable = true;
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

### Testing Changes

Always test before applying:
```bash
# Run all tests
task test

# Validate configuration
task test:flake

# Check formatting
task test:format

# Run unit tests
task test:unit

# Test build without switching
task rebuild:test

# Apply if successful
task rebuild
```

## Common Pitfalls

1. **Flake not updating**: Run `git add .` before rebuild - flakes only see staged/committed files
2. **SOPS decryption fails**: Ensure age key exists at `~/.config/sops/age/keys.txt`
3. **Hardware config missing**: Must generate with `task setup:hardware`
4. **Service failures**: Check with `systemctl status <service>` and `journalctl -xeu <service>`
5. **Disk space issues**: Run `task clean` to remove old generations
6. **Home Manager conflicts**: Creates `.backup` files when configs conflict with existing files
7. **Module import errors**: Check module is added to appropriate index.nix file
8. **Type errors**: Use module-utils.nix helpers for consistent option types

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

# Run specific VM test
task test:vm:single TEST=firewall

# Check central configuration
nix repl
:l <nixpkgs>
:l ./lib/config.nix
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

