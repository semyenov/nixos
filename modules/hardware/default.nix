# Hardware Module Index
# Hardware detection and driver configuration
# Automatically detects and configures hardware components

{ config, pkgs, lib, ... }:

{
  imports = [
    ./nvidia.nix # NVIDIA graphics drivers
    ./auto-detect.nix # Hardware auto-detection
  ];
}
