{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.performance.zram;
in
{
  options.performance.zram = {
    enable = mkEnableOption "ZRAM compressed memory swap";

    algorithm = mkOption {
      type = types.enum [ "lzo" "lz4" "zstd" "lzo-rle" ];
      default = "zstd";
      description = ''
        Compression algorithm for ZRAM.
        - zstd: Best balance of compression and speed (recommended)
        - lz4: Fastest but lower compression
        - lzo: Good compression but slower
        - lzo-rle: Improved LZO for better compression
      '';
    };

    memoryPercent = mkOption {
      type = types.int;
      default = 50;
      description = "Percentage of RAM to use for ZRAM devices";
    };

    memoryMax = mkOption {
      type = types.nullOr types.int;
      default = null;
      description = "Maximum memory in bytes for ZRAM (null for unlimited)";
    };

    priority = mkOption {
      type = types.int;
      default = 100;
      description = "Priority of ZRAM swap devices (higher = preferred)";
    };

    swappiness = mkOption {
      type = types.int;
      default = 180;
      description = ''
        Swappiness value for ZRAM (0-200).
        Higher values (150-200) are recommended for fast swap devices like ZRAM.
        Default: 180 (optimized for ZRAM performance)
      '';
    };

    writebackDevice = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "/dev/sda2";
      description = ''
        Optional backing device for ZRAM writeback.
        Incompressible or idle pages can be written to this device.
        Must be a block device (partition), not a file.
      '';
    };

    pageCluster = mkOption {
      type = types.int;
      default = 0;
      description = ''
        Number of pages to read/write in a single attempt.
        0 is recommended for ZRAM to avoid unnecessary decompression.
      '';
    };
  };

  config = mkIf cfg.enable {
    # ZRAM configuration
    zramSwap = {
      enable = true;
      algorithm = cfg.algorithm;
      memoryPercent = cfg.memoryPercent;
      memoryMax = cfg.memoryMax;
      priority = cfg.priority;
    };

    # Kernel parameters optimized for ZRAM
    boot.kernel.sysctl = {
      # Swappiness - higher for ZRAM
      "vm.swappiness" = cfg.swappiness;

      # Page cluster - 0 for ZRAM to avoid reading adjacent pages
      "vm.page-cluster" = cfg.pageCluster;

      # Watermark settings for better ZRAM utilization
      "vm.watermark_boost_factor" = 0;
      "vm.watermark_scale_factor" = 125;

      # Memory pressure settings
      "vm.vfs_cache_pressure" = 500;

      # Dirty page settings optimized for ZRAM
      "vm.dirty_background_ratio" = 1;
      "vm.dirty_ratio" = 50;

      # Min free kbytes - lower for better memory utilization
      "vm.min_free_kbytes" = mkDefault 65536;
    };

    # Configure writeback if specified
    systemd.services.zram-writeback = mkIf (cfg.writebackDevice != null) {
      description = "Configure ZRAM writeback device";
      after = [ "systemd-zram-setup@zram0.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = ''
          ${pkgs.bash}/bin/bash -c '
            echo ${cfg.writebackDevice} > /sys/block/zram0/backing_dev
            echo all > /sys/block/zram0/writeback
          '
        '';
      };
    };

    # Enable memory pressure monitoring
    systemd.services."memory-pressure-monitor" = {
      description = "Monitor memory pressure";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = ''
          ${pkgs.bash}/bin/bash -c '
            while true; do
              if [ -f /proc/pressure/memory ]; then
                pressure=$(grep "^some" /proc/pressure/memory | awk "{print \$2}" | cut -d= -f2)
                if (( $(echo "$pressure > 10" | bc -l) )); then
                  echo "Memory pressure detected: $pressure"
                  # Could trigger additional actions here
                fi
              fi
              sleep 30
            done
          '
        '';
        Restart = "always";
        RestartSec = 10;
        StandardOutput = "journal";
      };
    };

    # Provide alternative zswap configuration (disabled when zram is enabled)
    boot.kernelParams = mkIf (!cfg.enable) [
      "zswap.enabled=1"
      "zswap.compressor=zstd"
      "zswap.zpool=z3fold"
      "zswap.max_pool_percent=25"
      "zswap.shrinker_enabled=1"
    ];
  };
}
