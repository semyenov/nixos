# System Module Index
# System-wide configuration modules
# Includes performance, maintenance, and optimization settings

{ config, pkgs, lib, ... }:

{
  imports = [
    ./performance/index.nix # Performance optimizations
    ./maintenance/index.nix # System maintenance
    ./optimization.nix # Compatibility layer for legacy configs
  ];

}
