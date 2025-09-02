# NixOS Modules

This directory contains modular NixOS configuration organized by functionality.

## Module Categories

### Core (`core/`)
Essential system configuration that must be loaded first.

- **boot.nix** - Bootloader, kernel parameters, initrd
- **nix.nix** - Nix daemon settings, flakes, garbage collection

### Hardware (`hardware/`)
Hardware-specific configuration and drivers.

- **nvidia.nix** - NVIDIA GPU drivers and settings
- **auto-detect.nix** - Automatic hardware detection (optional)

### Desktop (`desktop/`)
Desktop environment configuration.

- **gnome.nix** - GNOME desktop with extensions and theming

### Services (`services/`)
System services and daemons.

- **networking.nix** - NetworkManager, DNS, network tools
- **audio.nix** - PipeWire audio system
- **docker.nix** - Docker and container runtime
- **v2ray-secrets.nix** - V2Ray proxy with SOPS secrets (uses official NixOS module)
- **backup.nix** - Simple backup service with BorgBackup
- **monitoring.nix** - System monitoring (optional)

### Development (`development/`)
Development tools and programming languages.

- **typescript.nix** - Node.js, TypeScript, package managers
- **tools.nix** - General development tools

### Security (`security/`)
Security and secrets management.

- **firewall.nix** - Firewall rules and fail2ban
- **sops.nix** - SOPS secrets configuration

### System (`system/`)
System-level optimizations and tweaks.

- **optimization.nix** - Performance tuning, ZRAM, tmpfs

## Module Structure

Each module follows this pattern:

```nix
{ config, pkgs, lib, ... }:

{
  # Module configuration
  options = {
    services.myService.enable = lib.mkEnableOption "My Service";
  };

  # Module implementation
  config = lib.mkIf config.services.myService.enable {
    # Configuration when enabled
  };
}
```

## Optional Modules

Some modules are disabled by default and must be explicitly enabled:

```nix
# In hosts/nixos/configuration.nix
{
  # Enable V2Ray proxy
  services.v2ray.enable = true;
  
  # Enable automatic backups
  services.backup.enable = true;
  
  # Enable system monitoring
  services.monitoring.enable = true;
  
  # Enable hardware auto-detection
  hardware.autoDetect.enable = true;
}
```

## Module Dependencies

Some modules depend on others:

1. **v2ray-secrets.nix** → requires **sops.nix** and SOPS secrets configured
2. **backup.nix** → standalone, works with any configuration
3. **monitoring.nix** → requires **networking.nix**

## Adding New Modules

1. Create module file in appropriate category:
   ```nix
   # modules/services/my-service.nix
   { config, pkgs, lib, ... }:
   {
     services.myService = {
       enable = lib.mkDefault false;
       # ... configuration
     };
   }
   ```

2. Add to `flake.nix`:
   ```nix
   modules = [
     # ... existing modules
     ./modules/services/my-service.nix
   ];
   ```

3. Enable in host configuration if needed:
   ```nix
   services.myService.enable = true;
   ```

4. Test and rebuild:
   ```bash
   ./nix.sh test
   ./nix.sh rebuild
   ```

## Best Practices

1. **Modularity**: Keep modules focused on single functionality
2. **Options**: Use `lib.mkDefault` for overridable defaults
3. **Dependencies**: Declare module dependencies explicitly
4. **Documentation**: Comment complex configurations
5. **Testing**: Test modules individually when possible

## Common Patterns

### Conditional Configuration
```nix
config = lib.mkIf config.services.myService.enable {
  # Only applied when enabled
};
```

### Default Values
```nix
services.myService.port = lib.mkDefault 8080;
```

### Merging Lists
```nix
environment.systemPackages = with pkgs; [
  package1
  package2
] ++ lib.optionals config.services.myService.enable [
  conditionalPackage
];
```

### Secret Management
```nix
sops.secrets."service/api_key" = {
  sopsFile = ../../secrets/service.yaml;
};

services.myService.apiKeyFile = 
  config.sops.secrets."service/api_key".path;
```