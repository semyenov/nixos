# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

NixOS system configuration using Flakes and Home Manager. Modular architecture with NVIDIA graphics support, GNOME desktop, comprehensive development environment, and V2Ray proxy service.

## Commands

### System Management
```bash
# Build and switch configuration (from repository root)
sudo nixos-rebuild switch --flake .#nixos

# Test without switching
sudo nixos-rebuild test --flake .#nixos

# Show detailed errors
sudo nixos-rebuild switch --flake .#nixos --show-trace

# Rollback
sudo nixos-rebuild switch --rollback

# Check system version
nixos-version

# List system generations
nix-env --list-generations --profile /nix/var/nix/profiles/system
```

### Flake Operations
```bash
# Update all flake inputs
nix flake update

# Update specific input
nix flake lock --update-input nixpkgs

# Check flake validity
nix flake check

# Show flake structure
nix flake show

# Show flake metadata
nix flake metadata
```

### Home Manager
```bash
# Switch user configuration
home-manager switch --flake .#semyenov

# Debug Home Manager issues
home-manager switch --flake .#semyenov --show-trace

# Note: Home Manager creates .backup files when configs conflict
```

### Development Shell
```bash
# Enter development shell
nix develop

# Run command in dev shell
nix develop --command zsh
```

### Quick Commands (Shell Aliases)
```bash
rebuild  # sudo nixos-rebuild switch --flake ~/Projects#nixos
update   # nix flake update  
clean    # sudo nix-collect-garbage -d
```

### Testing & Validation
```bash
# Run configuration tests
./test-config.sh

# Test build without switching
sudo nixos-rebuild test --flake .#nixos

# Check configuration syntax
nix flake check
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
```

### Development

#### TypeScript/JavaScript
```bash
# Package managers (in order of speed)
bun install       # Fastest
pnpm install      # Efficient disk usage
yarn install      # Classic alternative
npm install       # Standard

# Direct execution
bun run script.ts
deno run script.ts
npx tsx script.ts

# Compilation
tsc              # Compile TypeScript
tsc --watch      # Watch mode

# Linting/Formatting
eslint .
prettier --write .
biome check .
```

#### Docker
```bash
docker ps -a
docker-compose up -d
docker system prune -a
lazydocker        # TUI management
```

## Architecture

### Module Organization
```
flake.nix                    # Entry point, imports all modules, defines dev shell
├── hosts/nixos/             
│   ├── configuration.nix    # Host-specific config (locale, users, system packages)
│   └── hardware-configuration.nix  # Generated hardware config (not in git)
├── modules/
│   ├── core/               # Boot, kernel, Nix settings
│   ├── hardware/           
│   │   ├── nvidia.nix      # NVIDIA drivers configuration
│   │   └── auto-detect.nix # Hardware auto-detection
│   ├── desktop/            # GNOME environment
│   ├── services/           
│   │   ├── networking.nix  # Network configuration
│   │   ├── audio.nix       # PipeWire audio
│   │   ├── docker.nix      # Container services
│   │   ├── v2ray.nix       # V2Ray proxy
│   │   ├── v2ray-sops.nix  # V2Ray secrets
│   │   ├── backup.nix      # Backup system (borg/restic)
│   │   └── monitoring.nix  # System monitoring
│   ├── development/        # TypeScript, dev tools
│   ├── security/           # Firewall, SOPS secrets
│   └── system/             # Performance optimizations
├── users/semyenov/         # Home Manager user config (packages, dotfiles)
├── scripts/                # Helper scripts
│   ├── setup-sops.sh       # SOPS key setup
│   └── ...
├── shells.nix              # Development shells
├── secrets/                # SOPS-encrypted secrets
│   ├── README.md           # Secrets documentation
│   └── v2ray.yaml.example  # V2Ray config template
└── test-config.sh          # Configuration validation
```

### Key Configuration Points

- **Flake Inputs**: nixpkgs (25.05), home-manager (25.05), sops-nix
- **State Version**: 25.05 (DO NOT change without migration)
- **User**: semyenov with sudo, docker, network access
- **Shell**: ZSH with Starship prompt
- **Development**: Node.js 22, TypeScript, Bun, Deno, multiple package managers
- **Security**: Firewall enabled, fail2ban, SOPS for secrets
- **V2Ray**: VLESS Reality proxy (disabled by default, needs secrets)

### First-Time Setup

**Automated Setup** (Recommended):
```bash
# Interactive setup wizard
./setup.sh

# Quick setup (runs all steps)
./setup.sh quick

# Individual steps
./setup.sh hardware  # Generate hardware configuration
./setup.sh sops      # Setup SOPS encryption
./setup.sh v2ray     # Configure V2Ray secrets
./setup.sh test      # Test configuration
./setup.sh apply     # Apply configuration
```

**Manual Setup**:
1. **Generate hardware configuration**:
   ```bash
   sudo nixos-generate-config --dir hosts/nixos/
   ```

2. **Setup SOPS encryption** (for secrets):
   ```bash
   # Generate age key
   age-keygen -o ~/.config/sops/age/keys.txt
   
   # Get host key for .sops.yaml
   ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub
   
   # Update .sops.yaml with your keys
   ```

3. **Configure V2Ray secrets** (if needed):
   ```bash
   cp secrets/v2ray.yaml.example secrets/v2ray.yaml
   sops secrets/v2ray.yaml  # Edit with your values
   ```

4. **Build and switch**:
   ```bash
   sudo nixos-rebuild switch --flake .#nixos
   ```

### Adding/Modifying Configuration

1. **System packages**: Add to `hosts/nixos/configuration.nix`
2. **User packages**: Add to `users/semyenov/home.nix`  
3. **New module**: Create in `modules/`, add to `flake.nix` imports
4. **Test first**: Always run `./test-config.sh` and `nixos-rebuild test` before switch
5. **Enable optional services**:
   ```nix
   # In hosts/nixos/configuration.nix or create a local.nix
   services.v2ray.enable = true;           # V2Ray proxy
   services.backup.enable = true;          # Automatic backups
   services.monitoring.enable = true;      # System monitoring
   hardware.autoDetect.enable = true;      # Hardware auto-detection
   ```

### Secrets Management (SOPS)

```bash
# Initial setup (once)
age-keygen -o ~/.config/sops/age/keys.txt
ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub

# Edit secrets
sops secrets/v2ray.yaml

# Access in config
# config.sops.secrets.my_secret.path
```

### Troubleshooting

```bash
# System logs
journalctl -xe
journalctl -u v2ray.service  # Service-specific

# Build errors
nixos-rebuild build --flake .#nixos --show-trace

# Home Manager errors  
home-manager switch --flake .#semyenov --show-trace

# Check generation differences
nix profile diff-closures --profile /nix/var/nix/profiles/system

# Garbage collection
sudo nix-collect-garbage -d
nix-store --optimise
```

## Important Notes

- **V2Ray is disabled by default** - Enable in host configuration when secrets are configured
- **SOPS keys must be configured** - The placeholder keys in .sops.yaml won't work
- **Home Manager conflicts** - Creates .backup files when configs conflict with existing files
- **Hardware config is not in git** - Must be generated per system
- **Wayland is default** - Electron apps have X11 fallback configurations available