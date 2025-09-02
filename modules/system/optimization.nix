{ config, pkgs, lib, ... }:

{
  # System optimization
  systemd = {
    # Faster boot
    services.NetworkManager-wait-online.enable = false;

    # Temporary files
    tmpfiles.rules = [
      "d /tmp 1777 root root 10d"
      "d /var/tmp 1777 root root 30d"
      "e /nix/var/nix/daemon-socket - - - - -"
      "e /nix/var/nix/gc.lock - - - - -"
      "e /nix/var/nix/temproots - - - - -"
    ];

    # OOM killer configuration
    oomd = {
      enable = true;
      enableRootSlice = true;
      enableSystemSlice = true;
      enableUserSlices = true;
    };
  };

  # Filesystem optimizations - only for /tmp as others are defined in hardware-configuration.nix
  fileSystems = {
    # Use tmpfs for /tmp
    "/tmp" = {
      device = "tmpfs";
      fsType = "tmpfs";
      options = [ "mode=1777" "strictatime" "nosuid" "nodev" "size=8G" ];
    };
  };

  # Mount options for existing filesystems
  # These would need to be added to hardware-configuration.nix or merged properly

  # Swap configuration - moved to swapfile service below for better management

  # Kernel parameters for better performance
  boot.kernel.sysctl = {
    # Virtual memory
    "vm.swappiness" = 10;
    "vm.vfs_cache_pressure" = 50;
    "vm.dirty_background_ratio" = 5;
    "vm.dirty_ratio" = 10;
    "vm.dirty_writeback_centisecs" = 1500;

    # Network performance
    "net.core.netdev_max_backlog" = 5000;
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.ipv4.tcp_fastopen" = 3;
    "net.ipv4.tcp_rmem" = "4096 87380 16777216";
    "net.ipv4.tcp_wmem" = "4096 65536 16777216";
    "net.core.rmem_max" = 16777216;
    "net.core.wmem_max" = 16777216;

    # File system
    "fs.file-max" = 2097152;
    "fs.inotify.max_user_watches" = 524288;
    "fs.inotify.max_user_instances" = 1024;
  };

  # ZRAM for compressed memory (replaces traditional swap for better performance)
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
    priority = 100; # Higher priority than disk swap
  };

  # Optional: Traditional swapfile (disabled by default when ZRAM is enabled)
  # To enable, set services.swapfile.enable = true in your host configuration
  systemd.services.mkswapfile = {
    description = "Create swapfile";
    wantedBy = [ "swap.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      swapfile="/var/lib/swapfile"
      if [ ! -f "$swapfile" ]; then
        truncate -s 0 "$swapfile"
        chattr +C "$swapfile" 2>/dev/null || true # For btrfs
        fallocate -l 16G "$swapfile"
        chmod 600 "$swapfile"
        mkswap "$swapfile"
      fi
    '';
  };

  # Enable thermald for Intel CPU thermal management
  services.thermald.enable = true;

  # Power management
  powerManagement = {
    enable = true;
    cpuFreqGovernor = "performance";
  };

  # Enable fstrim for SSD
  services.fstrim = {
    enable = true;
    interval = "weekly";
  };

  # I/O scheduler
  services.udev.extraRules = ''
    # Set scheduler for NVMe
    ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"
    # Set scheduler for SSD
    ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
    # Set scheduler for HDD
    ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
  '';

  # Enable earlyoom
  services.earlyoom = {
    enable = true;
    freeMemThreshold = 5;
    freeSwapThreshold = 10;
    enableNotifications = true;
  };
}
