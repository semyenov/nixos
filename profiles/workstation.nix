# Workstation Profile
# Optimized for development and daily desktop use
# Includes development tools, productivity software, and performance optimizations

{ config, pkgs, lib, ... }:

{
  # Performance optimizations for desktop use
  performance = {
    kernel = {
      enable = true;
      profile = "performance";
      cpuScheduler = "performance";
      enableBBR2 = true;
      enablePSI = true;
      transparentHugepages = "madvise";
      enableMitigations = true; # Keep security on workstation
    };

    zram = {
      enable = true;
      algorithm = "zstd";
      memoryPercent = 50;
      swappiness = 180;
    };

    filesystem = {
      enable = true;
      enableTmpfs = true;
      tmpfsSize = "16G"; # More RAM for development
      enableFstrim = true;
      fstrimInterval = "weekly";
    };
  };

  # Enable all development modules
  environment.sessionVariables.DEVELOPMENT = "1";

  # Desktop environment
  services.xserver.enable = true;
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;

  # Audio
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  # Docker for development
  services.docker = {
    enable = true;
    profile = "development";
  };

  # Backup configuration
  services.backup = {
    enable = true;
    schedule = "daily";
    paths = [
      "/home"
      "/etc/nixos"
      "/var/lib/docker"
    ];
  };

  # Security - balanced for development
  security.hardening = {
    enable = true;
    profile = "standard"; # Good balance for workstation
    enableSystemdHardening = true;
    enableKernelHardening = true;
  };

  # System maintenance
  system.maintenance = {
    autoGarbageCollection = {
      enable = true;
      schedule = "weekly";
      keepDays = 14;
      keepGenerations = 10; # Keep more for rollbacks
    };

    monitoring = {
      enable = true;
      diskSpaceThreshold = 85;
      enableSmartMonitoring = true;
    };

    # Auto-updates disabled for workstation
    autoUpdate.enable = false;
  };

  # Enable printing
  services.printing.enable = true;
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  # Enable flatpak for additional software
  services.flatpak.enable = true;

  # Power management for laptops
  services.power-profiles-daemon.enable = true;
  services.thermald.enable = true;

  # Additional workstation packages (core packages in host config)
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
}

