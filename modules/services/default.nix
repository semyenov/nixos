# Services Module Index
# Main index for all service modules
# Imports both network and system services, plus standalone services

{ config, pkgs, lib, ... }:

{
  imports = [
    ./network # Network services (V2Ray, networking)
    ./system # System services (backup, monitoring)
    ./audio.nix # Audio services (PipeWire)
    ./docker.nix # Docker containerization
  ];
}

