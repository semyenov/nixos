# Network Services Module Index
# Network-related services and configurations
# Includes V2Ray, networking, and other network services

{ config, pkgs, lib, ... }:

{
  imports = [
    ./networking.nix # Basic networking configuration
    ./v2ray-secrets.nix # V2Ray proxy with SOPS secrets
  ];
}

