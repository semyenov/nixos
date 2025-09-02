# Core Module Index
# Automatically imports all core system modules
# These modules are loaded first and provide base system configuration
#
# Priority: 100 (Highest) - Core modules load first
# Maintainers: system

{ config, pkgs, lib, ... }:

{
  imports = [
    ./nix.nix # Nix configuration and settings
    ./boot.nix # Boot loader and kernel configuration
  ];
}
