# Minimal Profile
# Lightweight configuration using base profile system

{ config, pkgs, lib, ... }:

{
  imports = [
    (import ./base.nix { inherit config pkgs lib; profileType = "minimal"; })
  ];

  # Minimal packages (core packages already in host config)
  environment.systemPackages = [ ];

  # Disable all optional services
  services.avahi.enable = false;
  services.printing.enable = false;
  services.flatpak.enable = false;
  services.power-profiles-daemon.enable = false;
  services.thermald.enable = false;

  # Memory optimizations
  boot.kernel.sysctl = {
    "vm.swappiness" = 60;
    "vm.vfs_cache_pressure" = 100;
    "vm.dirty_background_ratio" = 5;
    "vm.dirty_ratio" = 10;
  };

  # Smaller journal size  
  services.journald.extraConfig = ''
    Storage=persistent
    Compress=yes
    SystemMaxUse=100M
    SystemKeepFree=500M
  '';

  # Minimal firewall logging
  networking.firewall = {
    allowedTCPPorts = [ ];
    allowedUDPPorts = [ ];
    logRefusedConnections = false;
  };

  # Conservative resource limits
  systemd.extraConfig = ''
    DefaultLimitNOFILE=1024:4096
    DefaultLimitNPROC=512:1024
  '';

  # Disable unused features
  documentation.enable = false;
  documentation.nixos.enable = false;
  programs.command-not-found.enable = false;
}
