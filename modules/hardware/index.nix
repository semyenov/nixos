# Hardware Module Index
# Automatically imports all hardware-related modules
# Handles hardware detection, drivers, and device-specific configuration

{ config, pkgs, lib, ... }:

{
  imports = [
    ./auto-detect.nix # Automatic hardware detection and optimization
    ./nvidia.nix # NVIDIA GPU drivers and configuration
  ];

}
