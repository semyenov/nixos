# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a modular NixOS system configuration using Flakes and Home Manager. The configuration manages a desktop system with NVIDIA RTX 4060 graphics, GNOME desktop environment, comprehensive development tools, and security hardening.

## Directory Structure

```
.
├── flake.nix                 # Main flake configuration
├── flake.lock               # Locked dependencies
├── hardware-configuration.nix # Auto-generated hardware config
├── configuration.nix         # Legacy configuration (for reference)
├── hosts/
│   └── nixos/
│       └── configuration.nix # Host-specific configuration
├── modules/
│   ├── core/
│   │   ├── boot.nix        # Boot and kernel configuration
│   │   └── nix.nix         # Nix settings and optimization
│   ├── hardware/
│   │   └── nvidia.nix      # NVIDIA GPU configuration
│   ├── desktop/
│   │   └── gnome.nix       # GNOME desktop environment
│   ├── services/
│   │   ├── audio.nix       # PipeWire audio configuration
│   │   ├── docker.nix      # Docker and container tools
│   │   └── networking.nix  # Network configuration
│   ├── development/
│   │   ├── typescript.nix  # TypeScript/JavaScript tools
│   │   └── tools.nix       # General development tools
│   ├── security/
│   │   ├── firewall.nix    # Firewall and fail2ban
│   │   └── sops.nix        # Secrets management
│   └── system/
│       └── optimization.nix # System performance tuning
├── users/
│   └── semyenov/
│       └── home.nix        # User-specific Home Manager config
└── secrets/
    └── README.md           # Secrets management guide
```

## Common Commands

### System Management with Flakes
```bash
# Build and switch to new configuration (from this directory)
sudo nixos-rebuild switch --flake .#nixos

# Test configuration without switching
sudo nixos-rebuild test --flake .#nixos

# Build configuration without switching
sudo nixos-rebuild build --flake .#nixos

# Update flake inputs (nixpkgs, home-manager, etc.)
nix flake update

# Update specific input
nix flake lock --update-input nixpkgs

# Show flake info
nix flake show

# Check flake
nix flake check

# Enter development shell
nix develop

# Rollback to previous generation
sudo nixos-rebuild switch --rollback
```

### Home Manager
```bash
# Switch to new home configuration (if using standalone)
home-manager switch --flake .#semyenov

# Show generations
home-manager generations

# Remove old generations
home-manager expire-generations "-7 days"
```

### Garbage Collection
```bash
# Remove old generations and garbage collect
sudo nix-collect-garbage -d

# Remove generations older than 7 days
sudo nix-collect-garbage --delete-older-than 7d

# Optimize nix store
nix store optimise
```

### Secrets Management (SOPS)
```bash
# Generate age key
age-keygen -o ~/.config/sops/age/keys.txt

# Create new secrets file
sops secrets/my-secret.yaml

# Edit existing secrets
sops secrets/my-secret.yaml

# Convert SSH key to age
ssh-to-age < ~/.ssh/id_ed25519.pub
```

### TypeScript Development
```bash
# Package managers
npm install        # Install dependencies with npm
pnpm install      # Install with pnpm (faster, more efficient)
yarn install      # Install with yarn
bun install       # Install with bun (fastest)

# Run TypeScript directly
bun run script.ts # Execute TypeScript with bun
deno run script.ts # Execute with deno
npx tsx script.ts # Execute with tsx (via npx)

# TypeScript compilation
tsc               # Compile TypeScript files
tsc --watch       # Watch mode for continuous compilation

# Linting and formatting
eslint .          # Lint the codebase
prettier --write . # Format code with prettier
```

### Docker Commands
```bash
# Docker service management
sudo systemctl status docker    # Check Docker service status
sudo systemctl restart docker   # Restart Docker service

# Common Docker operations
docker ps                       # List running containers
docker ps -a                    # List all containers
docker images                   # List images
docker-compose up -d            # Start services in background
docker-compose down             # Stop and remove containers
docker system prune -a          # Clean up unused resources

# Lazydocker for TUI management
lazydocker
```

### Git Workflow
```bash
# Lazygit for TUI git management
lazygit

# Common git aliases (defined in home.nix)
gs  # git status
gc  # git commit
gp  # git push
gl  # git pull
gd  # git diff
ga  # git add
```

## Architecture Notes

### Modular Configuration
- Configuration is split into focused modules for better organization
- Each module handles a specific aspect of the system
- Modules can be easily enabled/disabled in flake.nix
- Host-specific configuration in `hosts/nixos/`
- User-specific configuration managed by Home Manager

### Key Features
- **Flakes**: Reproducible builds with locked dependencies
- **Home Manager**: Declarative user environment management
- **SOPS-nix**: Encrypted secrets management
- **Security Hardening**: Firewall, fail2ban, kernel hardening
- **Performance Optimization**: ZRAM, tmpfs, I/O scheduling, CPU governance
- **Development Environment**: Complete TypeScript/JavaScript toolchain with multiple runtimes

### Important Settings
- System state version: 25.05 (DO NOT change unless following migration guide)
- Nix flakes and nix-command are enabled as experimental features
- Automatic garbage collection runs weekly
- Automatic store optimization runs weekly
- Firewall is enabled with specific ports for development
- Docker uses overlay2 storage driver with automatic pruning

## Development Notes

### Working with the Configuration
1. Always test changes with `sudo nixos-rebuild test --flake .#nixos` before switching
2. Keep hardware-configuration.nix untouched (regenerate with `nixos-generate-config` if hardware changes)
3. User-specific packages should go in `users/semyenov/home.nix`
4. System-wide packages should be minimal (most go to Home Manager)
5. Use SOPS for any sensitive configuration (API keys, passwords, tokens)

### Adding New Modules
1. Create a new `.nix` file in the appropriate `modules/` subdirectory
2. Add the module to the imports list in `flake.nix`
3. Test the configuration before switching

### Troubleshooting
- Check system logs: `journalctl -xe`
- Check Nix build logs: `nixos-rebuild build --flake .#nixos --show-trace`
- Check Home Manager: `home-manager switch --flake .#semyenov --show-trace`
- List generations: `sudo nix-env --list-generations --profile /nix/var/nix/profiles/system`

## Shell Aliases and Shortcuts

The configuration includes many useful aliases:
- `rebuild`: Rebuild NixOS configuration
- `update`: Update flake inputs
- `clean`: Run garbage collection
- `ll`, `la`, `lt`: Enhanced ls commands with eza
- `v`: Open neovim
- `c`: Open VS Code
- `d`: Docker shortcut
- `dc`: Docker-compose shortcut

## Security Considerations

1. Firewall is enabled with minimal open ports
2. SSH is hardened (no root login, key-only authentication)
3. Fail2ban protects against brute force attacks
4. Kernel parameters are hardened for security
5. SOPS manages secrets encryption
6. Automatic security updates can be enabled if desired