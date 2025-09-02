# System Module Index
# System-wide configuration modules
# Includes performance, maintenance, and optimization settings

{ config, pkgs, lib, ... }:

{
  imports = [
    ./performance # Performance optimizations
    ./maintenance # System maintenance
    ./optimization.nix # Compatibility layer for legacy configs
  ];

}
