# Maintenance Module Index
# System maintenance and automation
# Handles updates, garbage collection, and system health

{ config, pkgs, lib, ... }:

{
  imports = [
    ./auto-update.nix # Automated system updates
  ];
}