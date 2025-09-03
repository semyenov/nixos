# Security Module Index
# Security and hardening configuration modules
# Includes firewall, hardening, and security policies

{ config, pkgs, lib, ... }:

{
  imports = [
    ./firewall.nix # Firewall configuration and fail2ban
    ./hardening.nix # System hardening and security policies
  ];
}