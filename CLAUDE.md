# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

NixOS system configuration using Flakes and Home Manager. Modular architecture with NVIDIA graphics support, GNOME desktop, and comprehensive development environment.

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

# Update flake inputs
nix flake update

# Check flake validity
nix flake check
```

### Quick Commands (Shell Aliases)
```bash
rebuild  # sudo nixos-rebuild switch --flake ~/Projects#nixos
update   # nix flake update  
clean    # sudo nix-collect-garbage -d
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

### Scripts Available
```bash
./apply-config.sh      # Interactive configuration switch
./fix-and-switch.sh    # Auto-fix common issues and switch
./complete-setup.sh    # Initial setup helper
```

## Architecture

### Module Organization
```
flake.nix                    # Entry point, imports all modules
├── hosts/nixos/             # Host-specific config (locale, users)
├── modules/
│   ├── core/               # Boot, kernel, Nix settings
│   ├── hardware/           # NVIDIA drivers
│   ├── desktop/            # GNOME environment
│   ├── services/           # Network, audio, Docker
│   ├── development/        # TypeScript, dev tools
│   ├── security/           # Firewall, SOPS secrets
│   └── system/             # Performance optimizations
└── users/semyenov/         # Home Manager user config
```

### Key Configuration Points

- **Flake Inputs**: nixpkgs (25.05), home-manager (25.05), sops-nix
- **State Version**: 25.05 (DO NOT change without migration)
- **User**: semyenov with sudo, docker, network access
- **Shell**: ZSH with Starship prompt
- **Development**: Node.js 22, TypeScript, Bun, Deno, multiple package managers
- **Security**: Firewall enabled, fail2ban, SOPS for secrets

### Adding/Modifying Configuration

1. **System packages**: Add to `hosts/nixos/configuration.nix`
2. **User packages**: Add to `users/semyenov/home.nix`  
3. **New module**: Create in `modules/`, add to `flake.nix` imports
4. **Test first**: Always run `nixos-rebuild test` before switch

### Secrets Management (SOPS)

```bash
# Setup
age-keygen -o ~/.config/sops/age/keys.txt

# Edit secrets
sops secrets/my-secret.yaml

# Access in config: config.sops.secrets.my_secret.path
```

### Troubleshooting

```bash
journalctl -xe                                    # System logs
nixos-rebuild build --flake .#nixos --show-trace # Build errors
home-manager switch --flake .#semyenov --show-trace # Home Manager errors
nix-env --list-generations --profile /nix/var/nix/profiles/system # List generations
```