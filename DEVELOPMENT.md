# Development Guide

This guide helps you develop and maintain this NixOS configuration with 2025 best practices for performance, security, and maintainability.

## Quick Start

### Enter Development Shell

```bash
# Recommended: Use the specialized NixOS config development shell
task shell TYPE=nixos

# Or use nix directly
nix develop .#nixos

# For quick access, just run (uses default shell)
nix develop
```

### Available Development Shells

| Shell | Command | Purpose |
|-------|---------|---------|
| **nixos** | `task shell TYPE=nixos` | NixOS configuration development (recommended for this project) |
| web | `task shell TYPE=web` | Node.js 22, TypeScript, pnpm, yarn, bun, deno |
| systems | `task shell TYPE=systems` | Rust, Go, C/C++, GCC, Clang, CMake |
| ops | `task shell TYPE=ops` | Python 3.11, Docker, Kubernetes, Terraform, Ansible |
| mobile | `task shell TYPE=mobile` | Flutter, Android tools, security testing tools |

## NixOS Development Shell Tools

The `nixos` shell includes everything needed for this project:

### Nix Tools
- **nixpkgs-fmt** - Format nix files
- **nil** - Nix language server
- **statix** - Lint nix files  
- **deadnix** - Find dead nix code
- **nix-tree** - Visualize dependencies
- **nix-diff** - Compare derivations
- **nvd** - Nix version diff

### Task Automation
- **task** - Task runner (run `task --list-all`)

### Secrets Management
- **sops** - Encrypt/decrypt secrets
- **age** - Encryption tool
- **ssh-to-age** - Convert SSH to age keys

### Git Tools
- **git** - Version control
- **gh** - GitHub CLI
- **git-crypt** - File encryption

### System Utilities
- **jq/yq** - JSON/YAML processing
- **ripgrep** - Fast search
- **fd** - Fast find
- **bat** - Better cat
- **eza** - Better ls
- **htop/btop** - Process monitoring
- **ncdu** - Disk usage

## Common Development Tasks

### Testing & Validation

```bash
# Run all tests
task test

# Check specific things
task test:flake      # Validate flake
task test:flake:current  # Check current system only
task test:format     # Check formatting
```

### Code Quality

```bash
# Format all nix files
task format

# Find dead code
deadnix

# Lint nix files
statix check

# Check for issues
nil diagnostics .
```

### Dependency Analysis

```bash
# Visualize dependencies
nix-tree

# Compare versions
nvd diff /run/current-system result

# Show dependency graph
nix-store -q --graph $(nix-build) | dot -Tpng > graph.png
```

### Working with Secrets

```bash
# Edit secrets
sops secrets/v2ray.yaml

# Configure V2Ray
task v2ray:config URL='vless://...'

# Create age key
age-keygen -o ~/.config/sops/age/keys.txt
```

### Git Workflow

```bash
# Check status
task git:status

# Commit changes
task git:commit MSG="feat: add feature"

# Auto-commit for rebuild
task git:commit:rebuild
```

## File Structure

```
.
├── flake.nix           # Main configuration entry
├── Taskfile.yml        # Task automation
├── hosts/nixos/        # Host-specific config
├── modules/            # Modular configuration
│   ├── core/           # Essential system config
│   ├── hardware/       # Hardware drivers
│   ├── desktop/        # Desktop environment
│   ├── services/       # System services
│   ├── development/    # Dev tools
│   ├── security/       # Security & hardening
│   └── system/         # System optimization
│       ├── performance/  # 2025 performance modules
│       └── maintenance/  # Auto-updates & monitoring
├── users/semyenov/     # User configuration
├── secrets/            # Encrypted secrets
├── shells.nix          # Development shells
└── tasks/              # Task modules
```

## Tips & Tricks

### Shell Aliases (in nixos shell)

The nixos development shell sets up these aliases:
- `ll` → `eza -la --icons`
- `cat` → `bat`
- `find` → `fd`
- `grep` → `rg`

### Quick Edits

```bash
# Find nix files
fd -e nix

# Search in nix files
rg "services\." -t nix

# View file with syntax highlighting
bat modules/services/docker.nix
```

### Debugging

```bash
# Check what changed
git diff

# See build logs
nix log /nix/store/...

# Debug evaluation
nix eval .#nixosConfigurations.nixos.config.services

# Check option docs
man configuration.nix
```

## Best Practices

### 2025 Performance Optimization

1. **ZRAM Configuration**
   - Use swappiness 150-200 for ZRAM (not 60!)
   - Enable zstd compression
   - Consider writeback for incompressible pages

2. **Kernel Profiles**
   - Start with "balanced" profile
   - Test "performance" for desktop systems
   - Use "low-latency" for audio/gaming
   - Use "throughput" for servers

3. **Filesystem Optimization**
   - Enable tmpfs for /tmp
   - Use TRIM for SSDs
   - Enable NOCOW for VMs and databases

### Security Hardening

1. **Progressive Hardening**
   ```bash
   # Start minimal
   security.hardening.profile = "minimal";
   task test && task rebuild
   
   # Then standard
   security.hardening.profile = "standard";
   task test && task rebuild
   
   # Finally hardened (if needed)
   security.hardening.profile = "hardened";
   ```

2. **Service-Specific Hardening**
   - Test each service after enabling hardening
   - Check logs: `journalctl -xe`
   - Disable problematic hardening per-service

### Development Workflow

1. **Always test before rebuild**
   ```bash
   task test && task rebuild
   ```

2. **Use the nixos shell for development**
   - Has all necessary tools
   - Consistent environment
   - No need to install tools globally

3. **Format code before committing**
   ```bash
   task format
   git add -A
   task git:commit MSG="your message"
   ```

4. **Keep flake.lock updated**
   ```bash
   task update
   task test
   task rebuild
   ```

5. **Document module options**
   - Add descriptions to options
   - Include examples
   - Note dependencies

### Module Development

1. **Create focused modules**
   - Single responsibility principle
   - Clear option definitions
   - Proper mkIf conditions

2. **Use priority helpers**
   ```nix
   # For defaults that can be overridden
   option = mkDefault value;
   
   # To force override conflicts
   option = mkForce value;
   ```

3. **Test module combinations**
   - Enable/disable combinations
   - Check for conflicts
   - Verify dependencies

## Troubleshooting

### Shell not working?

```bash
# Add experimental features to your nix config
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf

# Or use with flags
nix --extra-experimental-features 'nix-command flakes' develop
```

### Build failures?

```bash
# Get detailed trace
task rebuild:trace

# Check flake
task test:flake:all

# Clean and retry
task clean
task rebuild
```

### Need help?

```bash
# List all tasks
task --list-all

# Get task details
task --summary <task-name>

# Check this guide
cat DEVELOPMENT.md
```