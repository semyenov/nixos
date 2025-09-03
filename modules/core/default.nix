# Core Module Index
# Automatically imports all core system modules
# These modules are loaded first and provide base system configuration

{ config, pkgs, lib, ... }:

{
  imports = [
    ./nix.nix # Nix configuration and settings
    ./boot.nix # Boot loader and kernel configuration
  ];
}