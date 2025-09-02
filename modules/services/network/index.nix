# Network Services Module Index
# Network-related services and configurations
# Includes V2Ray, networking, and other network services
#
# Priority: 70 - Loaded after security but before applications  
# Maintainers: network

{ config, pkgs, lib, ... }:

{
  imports = [
    ./networking.nix # Basic networking configuration
    ./v2ray-secrets.nix # V2Ray proxy with SOPS secrets
  ];
}
