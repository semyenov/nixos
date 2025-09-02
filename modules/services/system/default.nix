# System Services Module Index
# Imports all system-level service modules

{ config, pkgs, lib, ... }:

{
  imports = [
    ./backup.nix
    ./monitoring.nix
  ];
}

