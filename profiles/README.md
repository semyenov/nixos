# NixOS Configuration Profiles

This directory contains pre-configured profiles for different use cases. Each profile optimizes the system for specific workloads and requirements.

## Available Profiles

### workstation.nix
**Purpose**: Development and daily desktop use  
**Best for**: Developers, power users, desktop/laptop systems

**Features**:
- Performance kernel profile with desktop optimizations
- 50% ZRAM with swappiness=180
- Docker and development tools enabled
- GNOME desktop environment
- Daily backups of home and development directories
- Standard security hardening
- Weekly garbage collection
- Monitoring enabled

**Use case**: Primary development machine, daily driver laptop/desktop

### server.nix
**Purpose**: Production server deployments  
**Best for**: Web servers, application servers, databases

**Features**:
- Throughput kernel profile for batch processing
- Conservative ZRAM (25%) for more real memory
- Headless operation (no GUI)
- SSH-only access with strict security
- Automated daily backups at 2 AM
- Hardened security profile
- Automatic security updates with reboot window
- Prometheus monitoring enabled
- Fail2ban protection

**Use case**: Production servers, CI/CD runners, database servers

### minimal.nix
**Purpose**: Resource-constrained systems  
**Best for**: VMs, containers, embedded systems, old hardware

**Features**:
- Balanced kernel with minimal features
- Conservative ZRAM (25%) with LZ4 compression
- No desktop environment
- Minimal packages (vim, git, curl, htop only)
- Basic security hardening
- Monthly garbage collection
- No monitoring or auto-updates
- Disabled unnecessary services

**Use case**: Minimal VMs, rescue systems, embedded devices

## How to Use

### Method 1: Import in your configuration

```nix
# In your hosts/nixos/configuration.nix or flake.nix
{
  imports = [
    ./profiles/workstation.nix  # Choose your profile
    # ... other imports
  ];
  
  # Override specific settings if needed
  performance.kernel.profile = "low-latency"; # Override profile setting
}
```

### Method 2: Extend in flake.nix

```nix
# In flake.nix
{
  nixosConfigurations = {
    my-workstation = nixpkgs.lib.nixosSystem {
      modules = [
        ./hosts/nixos/configuration.nix
        ./profiles/workstation.nix
        # ... other modules
      ];
    };
    
    my-server = nixpkgs.lib.nixosSystem {
      modules = [
        ./hosts/server/configuration.nix
        ./profiles/server.nix
        # ... other modules
      ];
    };
  };
}
```

### Method 3: Conditional profiles

```nix
# In your configuration
{
  imports = [
    (if config.networking.hostName == "workstation" then
      ./profiles/workstation.nix
    else if config.networking.hostName == "server" then
      ./profiles/server.nix
    else
      ./profiles/minimal.nix)
  ];
}
```

## Customization

All profile settings can be overridden in your main configuration:

```nix
{
  imports = [ ./profiles/workstation.nix ];
  
  # Override profile settings
  performance.zram.memoryPercent = 75; # Use more ZRAM
  security.hardening.profile = "hardened"; # Stronger security
  services.backup.schedule = "hourly"; # More frequent backups
}
```

## Profile Comparison

| Feature | Workstation | Server | Minimal |
|---------|------------|--------|---------|
| **Kernel Profile** | performance | throughput | balanced |
| **ZRAM** | 50% / zstd | 25% / zstd | 25% / lz4 |
| **Desktop** | GNOME | None | None |
| **Security** | standard | hardened | minimal |
| **Backups** | daily | 2 AM daily | disabled |
| **Auto-updates** | disabled | enabled | disabled |
| **Monitoring** | enabled | enabled | disabled |
| **Docker** | enabled | optional | disabled |
| **Target RAM** | 8GB+ | 4GB+ | 1GB+ |

## Creating Custom Profiles

To create a custom profile:

1. Copy an existing profile as a template
2. Modify settings for your use case
3. Import in your configuration

Example custom gaming profile:

```nix
# profiles/gaming.nix
{ config, pkgs, lib, ... }:
{
  imports = [ ./workstation.nix ];
  
  # Gaming-specific overrides
  performance.kernel.profile = "low-latency";
  hardware.opengl.driSupport32Bit = true;
  programs.steam.enable = true;
  
  environment.systemPackages = with pkgs; [
    mangohud
    gamemode
    lutris
  ];
}
```

## Best Practices

1. **Start with a base profile** - Don't configure from scratch
2. **Override selectively** - Only change what you need
3. **Test changes** - Use `nixos-rebuild test` before switching
4. **Document customizations** - Add comments for non-obvious changes
5. **Version control** - Commit profile changes separately

## Migration Guide

### From manual configuration to profiles:

1. Identify your use case (workstation/server/minimal)
2. Import the appropriate profile
3. Remove duplicate configuration from your main file
4. Test with `nixos-rebuild test`
5. Apply with `nixos-rebuild switch`

### Switching profiles:

1. Change the import statement
2. Review and adjust overrides
3. Test thoroughly before applying
4. Consider data backup before major changes