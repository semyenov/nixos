{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.performance.filesystem;
in
{
  options.performance.filesystem = {
    enable = mkEnableOption "filesystem performance optimizations";

    enableTmpfs = mkOption {
      type = types.bool;
      default = true;
      description = "Use tmpfs for /tmp directory";
    };

    tmpfsSize = mkOption {
      type = types.str;
      default = "50%";
      description = "Size of tmpfs for /tmp (absolute or percentage)";
    };

    enableFstrim = mkOption {
      type = types.bool;
      default = true;
      description = "Enable periodic TRIM for SSDs";
    };

    fstrimInterval = mkOption {
      type = types.str;
      default = "weekly";
      description = "Interval for fstrim service";
    };

    mountOptions = {
      ssd = mkOption {
        type = types.listOf types.str;
        default = [ "noatime" "nodiratime" "discard=async" "compress=zstd:1" ];
        description = "Default mount options for SSDs";
      };

      hdd = mkOption {
        type = types.listOf types.str;
        default = [ "noatime" "nodiratime" ];
        description = "Default mount options for HDDs";
      };

      btrfs = mkOption {
        type = types.listOf types.str;
        default = [ "noatime" "compress=zstd:1" "space_cache=v2" "autodefrag" ];
        description = "Default mount options for Btrfs";
      };
    };

    enableBtrfsOptimizations = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Btrfs-specific optimizations";
    };

    enableNocow = mkOption {
      type = types.bool;
      default = true;
      description = "Disable copy-on-write for VM images and databases";
    };
  };

  config = mkIf cfg.enable {
    # Tmpfs for /tmp
    fileSystems = mkIf cfg.enableTmpfs {
      "/tmp" = {
        device = "tmpfs";
        fsType = "tmpfs";
        options = [
          "mode=1777"
          "strictatime"
          "nosuid"
          "nodev"
          "size=${cfg.tmpfsSize}"
        ];
      };
    };

    # SSD TRIM
    services.fstrim = mkIf cfg.enableFstrim {
      enable = true;
      interval = cfg.fstrimInterval;
    };

    # Btrfs optimizations
    services.btrfs.autoScrub = mkIf cfg.enableBtrfsOptimizations {
      enable = true;
      interval = "monthly";
      fileSystems = [ "/" ];
    };

    # Systemd tmpfiles rules
    systemd.tmpfiles.rules = [
      # Clean /tmp regularly
      "d /tmp 1777 root root 10d"
      "d /var/tmp 1777 root root 30d"

      # Nix daemon optimizations
      "e /nix/var/nix/daemon-socket - - - - -"
      "e /nix/var/nix/gc.lock - - - - -"
      "e /nix/var/nix/temproots - - - - -"
    ] ++ optionals cfg.enableNocow [
      # Set NOCOW for VM images directory
      "d /var/lib/libvirt/images 0755 root root - +C"
      # Set NOCOW for Docker
      "d /var/lib/docker 0755 root root - +C"
      # Set NOCOW for databases
      "d /var/lib/postgresql 0755 postgres postgres - +C"
      "d /var/lib/mysql 0755 mysql mysql - +C"
    ];

    # I/O optimizations
    services.udev.extraRules = ''
      # Increase nr_requests for better throughput
      ACTION=="add|change", KERNEL=="sd[a-z]|vd[a-z]|nvme[0-9]*", ATTR{queue/nr_requests}="256"
      
      # Set optimal I/O scheduler queue depth
      ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/io_poll}="1"
      ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/io_poll_delay}="0"
      
      # Enable write cache for SATA devices (if supported)
      ACTION=="add|change", KERNEL=="sd[a-z]", RUN+="${pkgs.hdparm}/bin/hdparm -W1 /dev/%k"
    '';

    # Kernel parameters for filesystem performance
    boot.kernel.sysctl = {
      # Inode cache
      "vm.vfs_cache_pressure" = mkDefault 50;

      # File handle limits
      "fs.file-max" = 2097152;
      "fs.nr_open" = 1048576;

      # Inotify limits for development
      "fs.inotify.max_user_watches" = 524288;
      "fs.inotify.max_user_instances" = 8192;
      "fs.inotify.max_queued_events" = 32768;

      # AIO limits
      "fs.aio-max-nr" = 1048576;

      # Lease break time
      "fs.lease-break-time" = 5;
    };

    # Enable compression for systemd journals
    services.journald.extraConfig = ''
      Compress=yes
      SystemMaxUse=1G
      RuntimeMaxUse=256M
      MaxFileSec=1week
      ForwardToSyslog=no
    '';

    # Nix store optimizations
    nix.settings = {
      auto-optimise-store = true;
      min-free = 1073741824; # 1GB
      max-free = 5368709120; # 5GB
    };

    nix.optimise = {
      automatic = true;
      dates = [ "03:00" ];
    };

    # Automatic garbage collection
    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
      persistent = true;
    };

    # Btrfs-specific mount options helper
    # Note: This would need to be applied to actual mount points in hardware-configuration.nix
    environment.etc."btrfs-mount-options.conf" = mkIf cfg.enableBtrfsOptimizations {
      text = ''
        # Recommended Btrfs mount options for performance
        # Add these to your filesystem mount options in hardware-configuration.nix:
        ${concatStringsSep "," cfg.mountOptions.btrfs}
        
        # For SSDs, also add:
        discard=async
        
        # For specific workloads:
        # - Databases: nodatacow,nodatasum
        # - VMs: nodatacow
        # - General: compress=zstd:1,space_cache=v2
      '';
    };
  };
}
