# Core Modules

Essential system configuration modules that form the foundation of the NixOS system.

## Modules

### `nix.nix`
Core Nix configuration including:
- Experimental features (flakes, nix-command)
- Garbage collection settings
- Binary cache configuration
- Build optimization settings

### `boot.nix`
Boot loader and kernel configuration:
- Systemd-boot configuration
- Kernel parameters
- Initial ramdisk settings
- Boot timeout and menu options

## Usage

These modules are automatically imported and should always be included in any NixOS configuration. They provide the base settings required for a functional system.

```nix
imports = [
  ./modules/core/index.nix
];
```

## Configuration Options

Key options available:
- `nix.settings` - Core Nix daemon settings
- `boot.loader` - Boot loader configuration
- `boot.kernelParams` - Kernel command line parameters

## Dependencies

These modules have no external dependencies and are loaded first in the module hierarchy.

## Priority

**Priority: 100** (Highest) - These modules are loaded before all others.