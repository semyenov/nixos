# Server Profile
# Optimized for production server deployments
# Focuses on stability, security, and automation

{ config, pkgs, lib, ... }:

{
  # Performance optimizations for server use
  performance = {
    kernel = {
      enable = true;
      profile = "throughput"; # Optimized for batch processing
      cpuScheduler = "schedutil";
      enableBBR2 = true;
      enablePSI = true;
      transparentHugepages = "always"; # Good for databases
      enableMitigations = true; # Always keep security on servers
    };

    zram = {
      enable = true;
      algorithm = "zstd";
      memoryPercent = 25; # Less ZRAM, more real memory for services
      swappiness = 100; # Lower for servers
    };

    filesystem = {
      enable = true;
      enableTmpfs = true;
      tmpfsSize = "2G"; # Smaller tmpfs for servers
      enableFstrim = true;
      fstrimInterval = "daily"; # More frequent for server workloads
      enableNocow = true; # For databases and VMs
    };
  };

  # No desktop environment
  services.xserver.enable = false;

  # Headless operation
  boot.kernelParams = [ "console=ttyS0" "console=tty0" ];

  # SSH access
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
      X11Forwarding = false;
    };
    ports = [ 22 ];
  };

  # Enhanced firewall for server
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 80 443 ];
    logRefusedConnections = true;
    logRefusedPackets = true;
  };

  # Backup configuration - more frequent
  services.backup = {
    enable = true;
    schedule = "*-*-* 02:00:00"; # Daily at 2 AM
    paths = [
      "/etc"
      "/var/lib"
      "/var/log"
      "/srv"
    ];
    exclude = [
      "/var/lib/docker"
      "/var/log/journal"
    ];
  };

  # Security - maximum for server
  security.hardening = {
    enable = true;
    profile = "hardened"; # Strong security for servers
    enableSystemdHardening = true;
    enableKernelHardening = true;
    enableAppArmor = false; # Enable if compatible with services
    enableAuditd = true; # Enable audit logging
  };

  # System maintenance - fully automated
  system.maintenance = {
    autoGarbageCollection = {
      enable = true;
      schedule = "daily";
      keepDays = 7;
      keepGenerations = 3; # Keep fewer for servers
    };

    monitoring = {
      enable = true;
      diskSpaceThreshold = 80; # Alert earlier on servers
      enableSmartMonitoring = true;
    };

    # Auto-updates enabled for servers
    autoUpdate = {
      enable = true;
      schedule = "04:00";
      flakeUrl = "github:NixOS/nixpkgs/nixos-25.05";
      allowReboot = true; # Auto-reboot for kernel updates
      rebootWindow = {
        start = "02:00";
        end = "05:00";
      };
      enableNotifications = true;
      onlySecurityUpdates = true; # Only security updates
    };
  };

  # Monitoring services
  services.monitoring = {
    enable = true;
    prometheus.enable = true;
    nodeExporter.enable = true;
    # Grafana disabled by default (enable if needed)
    grafana.enable = false;
  };

  # Fail2ban for additional security
  services.fail2ban = {
    enable = true;
    maxretry = 3;
    bantime = "1h";
    ignoreIP = [ "127.0.0.0/8" "::1" ];
  };

  # Minimal server packages
  environment.systemPackages = with pkgs; [
    vim
    htop
    tmux
    git
    curl
    wget
    rsync
    borgbackup
  ];

  # Disable unnecessary services
  services.avahi.enable = false;
  services.printing.enable = false;
  hardware.bluetooth.enable = false;

  # System hardening
  boot.kernel.sysctl = {
    # Disable magic SysRq key
    "kernel.sysrq" = 0;
    # Restrict dmesg access
    "kernel.dmesg_restrict" = 1;
  };
}

