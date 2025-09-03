# Workstation Profile
# Development-focused configuration using base profile system

{ config, pkgs, lib, ... }:

{
  imports = [
    (import ./base.nix { inherit config pkgs lib; profileType = "workstation"; })
  ];

  # Development environment flag
  environment.sessionVariables.DEVELOPMENT = "1";

  # Workstation-specific packages
  environment.systemPackages = with pkgs; [
    # Browsers (firefox enabled via programs.firefox.enable in host config)
    brave

    # Development
    vscode
    docker-compose

    # Productivity
    libreoffice
    thunderbird

    # Media
    vlc
    spotify

    # System monitoring (htop in host config)
    btop
    ncdu
  ];

  # Printing and discovery
  services.printing.enable = true;
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  # Flatpak for additional software
  services.flatpak.enable = true;

  # Power management for laptops
  services.power-profiles-daemon.enable = true;
  services.thermald.enable = true;

  # Workstation-specific optimizations
  boot.kernel.sysctl = {
    # Better interactive performance
    "kernel.sched_autogroup_enabled" = 1;
    "vm.swappiness" = 10; # Prefer RAM over swap for responsiveness
  };
}
