# Minimal Profile
# Lightweight configuration for resource-constrained systems
# Only essential services and optimizations

{ config, pkgs, lib, ... }:

{
  # Conservative performance settings
  performance = {
    kernel = {
      enable = true;
      profile = "balanced";
      cpuScheduler = "schedutil";
      enableBBR2 = false; # Save resources
      enablePSI = false; # Disable monitoring
      transparentHugepages = "never"; # Save memory
      enableMitigations = true; # Keep basic security
    };

    zram = {
      enable = true;
      algorithm = "lz4"; # Faster, less CPU intensive
      memoryPercent = 25; # Conservative ZRAM usage
      swappiness = 60; # Default swappiness
    };

    filesystem = {
      enable = false; # Disable extra optimizations
    };
  };

  # Minimal desktop (if needed)
  services.xserver = {
    enable = false; # No GUI by default
    # Uncomment for minimal desktop:
    # displayManager.lightdm.enable = true;
    # windowManager.i3.enable = true;
  };

  # Basic networking only
  networking.networkmanager.enable = true;

  # Minimal firewall
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ ];
    allowedUDPPorts = [ ];
    logRefusedConnections = false; # Save resources
  };

  # No backup by default
  services.backup.enable = false;

  # Minimal security
  security.hardening = {
    enable = true;
    profile = "minimal"; # Basic hardening only
    enableSystemdHardening = false;
    enableKernelHardening = false;
  };

  # Conservative maintenance
  system.maintenance = {
    autoGarbageCollection = {
      enable = true;
      schedule = "monthly";
      keepDays = 7;
      keepGenerations = 2; # Minimal history
    };

    monitoring = {
      enable = false; # No monitoring to save resources
    };

    autoUpdate = {
      enable = false; # Manual updates only
    };
  };

  # Disable unnecessary services
  services = {
    printing.enable = false;
    avahi.enable = false;
    flatpak.enable = false;
    thermald.enable = false;
    power-profiles-daemon.enable = false;
  };

  # Minimal packages only
  environment.systemPackages = with pkgs; [
    vim
    git
    curl
    htop
  ];

  # Disable Docker
  virtualisation.docker.enable = false;

  # Memory optimizations
  boot.kernel.sysctl = {
    "vm.swappiness" = 60;
    "vm.vfs_cache_pressure" = 100;
    "vm.dirty_background_ratio" = 5;
    "vm.dirty_ratio" = 10;
  };

  # Smaller journal size
  services.journald.extraConfig = ''
    SystemMaxUse=100M
    RuntimeMaxUse=50M
  '';

  # Disable unnecessary kernel modules
  boot.blacklistedKernelModules = [
    "bluetooth"
    "btusb"
    "uvcvideo" # Webcam
  ];
}

