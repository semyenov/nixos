{ config, pkgs, lib, ... }:

{
  # This module now serves as a compatibility layer and default enabler
  # for the new modular performance system

  # Enable the new performance modules with sensible defaults
  performance = {
    # ZRAM configuration (modern best practices)
    zram = {
      enable = true;
      algorithm = "zstd";
      memoryPercent = 50;
      priority = 100;
      swappiness = 180; # Optimized for ZRAM
    };

    # Kernel optimizations
    kernel = {
      enable = true;
      profile = "balanced";
      cpuScheduler = "schedutil";
      enableBBR2 = true;
      enablePSI = true;
      transparentHugepages = "madvise";
      enableMitigations = true; # Security vs performance tradeoff
    };

    # Filesystem optimizations
    filesystem = {
      enable = true;
      enableTmpfs = true;
      tmpfsSize = "8G";
      enableFstrim = true;
      fstrimInterval = "weekly";
      enableBtrfsOptimizations = true;
      enableNocow = true;
    };
  };

  # System maintenance
  system.maintenance = {
    # Automatic garbage collection
    autoGarbageCollection = {
      enable = true;
      schedule = "weekly";
      keepDays = 14;
      keepGenerations = 5;
    };

    # System monitoring
    monitoring = {
      enable = true;
      diskSpaceThreshold = 90;
      enableSmartMonitoring = true;
    };

    # Auto-updates disabled by default (opt-in)
    autoUpdate = {
      enable = false;
      schedule = "04:00";
      allowReboot = false;
      enableNotifications = true;
    };
  };

  # Security hardening (opt-in for compatibility)
  security.hardening = {
    enable = lib.mkDefault false; # Users can enable this explicitly
    profile = "standard";
    enableSystemdHardening = true;
    enableKernelHardening = true;
  };

  # Legacy settings maintained for compatibility
  systemd = {
    # Faster boot
    services.NetworkManager-wait-online.enable = false;

    # OOM killer configuration
    oomd = {
      enable = true;
      enableRootSlice = true;
      enableSystemSlice = true;
      enableUserSlices = true;
    };
  };

  # Enable thermald for Intel CPU thermal management
  services.thermald.enable = true;

  # Enable earlyoom as additional OOM protection
  services.earlyoom = {
    enable = true;
    freeMemThreshold = 5;
    freeSwapThreshold = 10;
    enableNotifications = false; # Disable to avoid conflict with smartd
  };

  # Note for users:
  # This module now uses the new modular performance system.
  # You can customize individual aspects by setting options like:
  #   performance.zram.memoryPercent = 75;
  #   performance.kernel.profile = "performance";
  #   security.hardening.enable = true;
  #   system.maintenance.autoUpdate.enable = true;
  # 
  # For more granular control, you can disable this module and
  # import the specific modules you need directly.
}
