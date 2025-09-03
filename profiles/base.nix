# Base Profile System
# Common configuration shared across all profiles with profile-specific overrides
# Eliminates duplication while maintaining profile customization

{ config, pkgs, lib, profileType, ... }:

with lib;
let
  # Profile-specific configuration parameters
  profileConfigs = {
    minimal = {
      performance = {
        kernel.profile = "balanced";
        kernel.cpuScheduler = "schedutil";
        kernel.enableBBR2 = false;
        kernel.enablePSI = false;
        kernel.transparentHugepages = "never";
        zram.memoryPercent = 25;
        zram.algorithm = "lz4";
        zram.swappiness = 60;
        filesystem.enable = false;
      };

      desktop.enable = false;
      docker.enable = false;
      backup.enable = false;

      security.profile = "minimal";
      security.enableSystemdHardening = false;
      security.enableKernelHardening = false;

      maintenance = {
        autoUpdate.enable = false;
        monitoring.enable = false;
        garbageCollection.keepGenerations = 5;
      };
    };

    workstation = {
      performance = {
        kernel.profile = "performance";
        kernel.cpuScheduler = "performance";
        kernel.enableBBR2 = true;
        kernel.enablePSI = true;
        kernel.transparentHugepages = "madvise";
        zram.memoryPercent = 50;
        zram.algorithm = "zstd";
        zram.swappiness = 180;
        filesystem.enable = true;
        filesystem.tmpfsSize = "16G";
      };

      desktop.enable = true;
      docker.enable = true;
      docker.profile = "development";
      backup.enable = true;
      backup.paths = [ "/home" "/etc/nixos" "/var/lib/docker" ];

      security.profile = "standard";
      security.enableSystemdHardening = true;
      security.enableKernelHardening = true;

      maintenance = {
        autoUpdate.enable = false;
        monitoring.enable = true;
        monitoring.diskSpaceThreshold = 85;
        garbageCollection.keepGenerations = 10;
        garbageCollection.keepDays = 14;
      };
    };

    server = {
      performance = {
        kernel.profile = "throughput";
        kernel.cpuScheduler = "schedutil";
        kernel.enableBBR2 = true;
        kernel.enablePSI = true;
        kernel.transparentHugepages = "always";
        zram.memoryPercent = 25;
        zram.algorithm = "zstd";
        zram.swappiness = 100;
        filesystem.enable = true;
        filesystem.tmpfsSize = "2G";
        filesystem.fstrimInterval = "daily";
        filesystem.enableNocow = true;
      };

      desktop.enable = false;
      docker.enable = true;
      docker.profile = "production";
      backup.enable = true;
      backup.schedule = "daily";
      backup.paths = [ "/etc" "/var" "/home" "/opt" ];

      security.profile = "hardened";
      security.enableSystemdHardening = true;
      security.enableKernelHardening = true;
      security.enableAppArmor = true;

      maintenance = {
        autoUpdate.enable = true;
        autoUpdate.schedule = "weekly";
        autoUpdate.reboot = "02:00";
        monitoring.enable = true;
        monitoring.diskSpaceThreshold = 90;
        monitoring.enableSmartMonitoring = true;
        garbageCollection.keepGenerations = 20;
        garbageCollection.keepDays = 30;
      };
    };
  };

  cfg = profileConfigs.${profileType};
in
{
  # Performance configuration
  performance = {
    kernel = {
      enable = true;
      profile = cfg.performance.kernel.profile;
      cpuScheduler = cfg.performance.kernel.cpuScheduler;
      enableBBR2 = cfg.performance.kernel.enableBBR2;
      enablePSI = cfg.performance.kernel.enablePSI;
      transparentHugepages = cfg.performance.kernel.transparentHugepages;
      enableMitigations = true; # Always keep security
    };

    zram = {
      enable = true;
      algorithm = cfg.performance.zram.algorithm;
      memoryPercent = cfg.performance.zram.memoryPercent;
      swappiness = cfg.performance.zram.swappiness;
    };

    filesystem = mkMerge [
      {
        enable = cfg.performance.filesystem.enable;
        enableTmpfs = cfg.performance.filesystem.enable;
        enableFstrim = cfg.performance.filesystem.enable;
        fstrimInterval = cfg.performance.filesystem.fstrimInterval or "weekly";
      }
      (mkIf (cfg.performance.filesystem.enable) {
        tmpfsSize = cfg.performance.filesystem.tmpfsSize or "8G";
        enableNocow = cfg.performance.filesystem.enableNocow or false;
      })
    ];
  };

  # Desktop environment
  services.xserver = mkIf cfg.desktop.enable {
    enable = true;
    displayManager.gdm.enable = true;
    desktopManager.gnome.enable = true;
  };

  # Audio (only for desktop)
  services.pipewire = mkIf cfg.desktop.enable {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  # Docker configuration
  services.docker = mkIf cfg.docker.enable {
    enable = true;
    profile = cfg.docker.profile or "minimal";
  };

  # Backup configuration
  services.backup = mkIf cfg.backup.enable {
    enable = true;
    schedule = cfg.backup.schedule or "weekly";
    paths = cfg.backup.paths or [ "/home" "/etc/nixos" ];
  };

  # Security configuration
  security.hardening = {
    enable = true;
    profile = cfg.security.profile;
    enableSystemdHardening = cfg.security.enableSystemdHardening;
    enableKernelHardening = cfg.security.enableKernelHardening;
    enableAppArmor = cfg.security.enableAppArmor or false;
  };

  # System maintenance
  system.maintenance = {
    autoGarbageCollection = {
      enable = true;
      schedule = "weekly";
      keepDays = cfg.maintenance.garbageCollection.keepDays or 7;
      keepGenerations = cfg.maintenance.garbageCollection.keepGenerations;
    };

    monitoring = mkIf cfg.maintenance.monitoring.enable {
      enable = true;
      diskSpaceThreshold = cfg.maintenance.monitoring.diskSpaceThreshold or 80;
      enableSmartMonitoring = cfg.maintenance.monitoring.enableSmartMonitoring or false;
    };

    autoUpdate = mkIf cfg.maintenance.autoUpdate.enable {
      enable = true;
      schedule = cfg.maintenance.autoUpdate.schedule or "weekly";
      reboot = cfg.maintenance.autoUpdate.reboot or false;
    };
  };

  # Common networking
  networking.networkmanager.enable = mkDefault true;

  # Basic firewall
  networking.firewall.enable = mkDefault true;
}
