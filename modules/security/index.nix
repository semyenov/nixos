# Security Module Index
# Security-related modules for system hardening
# Includes firewall, secrets management, and security profiles

{ config, pkgs, lib, ... }:

{
  imports = [
    ./sops.nix # SOPS secret management (must load first)
    ./firewall.nix # Firewall and network security
    ./hardening.nix # System hardening profiles
  ];

}
