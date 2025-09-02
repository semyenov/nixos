# Kernel Performance Module
# 
# This module provides comprehensive kernel performance tuning options.
# It allows fine-grained control over CPU scheduling, memory management,
# network optimizations, and various kernel parameters.
#
# The module uses profiles to simplify configuration:
# - balanced: Default, good for mixed workloads
# - performance: Maximum throughput, higher power consumption
# - low-latency: Optimized for real-time responsiveness
# - throughput: Optimized for batch processing and servers
#
# All configuration values are centralized in lib/config.nix for maintainability.

{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.performance.kernel;
  centralConfig = import ../../../lib/config.nix;
  utils = import ../../../lib/module-utils.nix { inherit lib; };
  perfConfig = centralConfig.performance;
in
{
  options.performance.kernel = {
    enable = utils.mkServiceEnableOption "kernel-performance" "kernel performance optimizations and tuning";

    profile = utils.mkEnumOption {
      values = [ "balanced" "performance" "low-latency" "throughput" ];
      default = "balanced";
      description = ''
        Kernel optimization profile:
        - balanced: Good for general use
        - performance: Maximum performance, higher power usage
        - low-latency: Optimized for responsiveness
        - throughput: Optimized for batch processing
      '';
      example = "performance";
    };

    cpuScheduler = utils.mkEnumOption {
      values = [ "performance" "ondemand" "conservative" "powersave" "schedutil" ];
      default = "schedutil";
      description = ''
        CPU frequency scaling governor:
        - performance: Always run at maximum frequency
        - ondemand: Scale based on CPU load (legacy)
        - conservative: Gradual scaling for power saving
        - powersave: Always run at minimum frequency
        - schedutil: Modern scheduler-based scaling (recommended)
      '';
      example = "performance";
    };

    enableBBR2 = utils.mkModuleOption {
      type = types.bool;
      default = true;
      description = ''
        Enable TCP BBR v2 congestion control algorithm.
        BBR (Bottleneck Bandwidth and Round-trip time) provides:
        - Better throughput on high-latency connections
        - Reduced bufferbloat
        - Improved performance for modern internet connections
        Recommended for servers and systems with fast internet.
      '';
      example = true;
    };

    enablePSI = utils.mkModuleOption {
      type = types.bool;
      default = true;
      description = ''
        Enable Pressure Stall Information (PSI) monitoring.
        PSI provides accurate metrics about resource pressure for:
        - CPU stalls
        - Memory pressure
        - I/O delays
        Used by systemd-oomd and other tools for better resource management.
        Small overhead (~1% CPU) but valuable for system monitoring.
      '';
      example = true;
    };

    transparentHugepages = utils.mkEnumOption {
      values = [ "always" "madvise" "never" ];
      default = "madvise";
      description = ''
        Transparent Huge Pages (THP) configuration:
        - always: Always use huge pages (good for databases)
        - madvise: Only when requested by applications (balanced)
        - never: Disable huge pages (saves memory, good for containers)
        
        THP can improve performance by reducing TLB misses but may
        increase memory usage and latency for some workloads.
      '';
      example = "madvise";
    };

    enableMitigations = utils.mkModuleOption {
      type = types.bool;
      default = true;
      description = ''
        Enable CPU vulnerability mitigations (Spectre, Meltdown, etc.).
        
        WARNING: Disabling mitigations can improve performance by 5-30%
        but exposes the system to known CPU vulnerabilities.
        
        Only disable on:
        - Isolated systems
        - Gaming machines
        - Development environments
        
        NEVER disable on production servers or multi-user systems.
      '';
      example = true;
    };
  };

  config = mkIf cfg.enable {
    # CPU frequency scaling
    powerManagement = {
      enable = true;
      cpuFreqGovernor = cfg.cpuScheduler;
    };

    # Boot parameters
    boot.kernelParams = [
      # Transparent Huge Pages
      "transparent_hugepage=${cfg.transparentHugepages}"

      # Disable watchdog for performance
      "nowatchdog"

      # Intel P-state driver
      "intel_pstate=active"
    ] ++ optionals cfg.enablePSI [
      # Pressure Stall Information
      "psi=1"
    ] ++ optionals (!cfg.enableMitigations) [
      # Disable CPU mitigations (security vs performance tradeoff)
      "mitigations=off"
    ] ++ optionals (cfg.profile == "low-latency") [
      # Low latency optimizations
      "threadirqs"
      "nohz_full=1-N"
      "rcu_nocbs=1-N"
    ];

    # Kernel modules
    boot.kernelModules = [
      "tcp_bbr2"
      "tcp_bbr"
    ] ++ optionals config.virtualisation.docker.enable [
      "br_netfilter"
      "overlay"
    ];

    # Kernel sysctl parameters based on profile
    boot.kernel.sysctl = mkMerge [
      # Base settings for all profiles
      {
        # Core settings
        "kernel.sched_autogroup_enabled" = 1;
        "kernel.sched_cfs_bandwidth_slice_us" = perfConfig.timing.schedCfsBandwidth;

        # I/O settings
        "vm.dirty_expire_centisecs" = if cfg.profile == "performance" then perfConfig.timing.dirtyExpireCentisecs.performance else perfConfig.timing.dirtyExpireCentisecs.default;
        "vm.dirty_writeback_centisecs" = if cfg.profile == "performance" then perfConfig.timing.dirtyWritebackCentisecs.performance else perfConfig.timing.dirtyWritebackCentisecs.default;

        # Network - TCP congestion control
        "net.ipv4.tcp_congestion" = if cfg.enableBBR2 then "bbr2" else "bbr";
        "net.core.default_qdisc" = "cake";

        # Network buffers
        "net.core.rmem_default" = perfConfig.memory.buffers.rmemDefault;
        "net.core.wmem_default" = perfConfig.memory.buffers.wmemDefault;
        "net.core.rmem_max" = perfConfig.memory.buffers.rmemMax;
        "net.core.wmem_max" = perfConfig.memory.buffers.wmemMax;
        "net.ipv4.tcp_rmem" = perfConfig.memory.buffers.tcpMem;
        "net.ipv4.tcp_wmem" = perfConfig.memory.buffers.tcpMem;

        # TCP optimization
        "net.ipv4.tcp_fastopen" = mkDefault 3;
        "net.ipv4.tcp_tw_reuse" = mkDefault 1;
        "net.ipv4.tcp_fin_timeout" = mkDefault 10;
        "net.ipv4.tcp_slow_start_after_idle" = mkDefault 0;
        "net.ipv4.tcp_keepalive_time" = mkDefault 60;
        "net.ipv4.tcp_keepalive_intvl" = mkDefault 10;
        "net.ipv4.tcp_keepalive_probes" = mkDefault 6;
        "net.ipv4.tcp_mtu_probing" = mkDefault 1;
        "net.ipv4.tcp_syncookies" = mkDefault 1;

        # Enable TCP ECN
        "net.ipv4.tcp_ecn" = 1;

        # Connection tracking
        "net.netfilter.nf_conntrack_max" = 2000000;
        "net.netfilter.nf_conntrack_tcp_timeout_established" = 21600;
      }

      # Performance profile
      (mkIf (cfg.profile == "performance") {
        "kernel.sched_migration_cost_ns" = 5000000;
        "kernel.sched_min_granularity_ns" = 10000000;
        "kernel.sched_wakeup_granularity_ns" = 15000000;
        "vm.dirty_background_ratio" = 10;
        "vm.dirty_ratio" = 30;
        "vm.vfs_cache_pressure" = 50;
      })

      # Low-latency profile
      (mkIf (cfg.profile == "low-latency") {
        "kernel.sched_migration_cost_ns" = 500000;
        "kernel.sched_min_granularity_ns" = 2250000;
        "kernel.sched_wakeup_granularity_ns" = 3000000;
        "kernel.sched_latency_ns" = 6000000;
        "vm.dirty_background_ratio" = 3;
        "vm.dirty_ratio" = 10;
        "vm.vfs_cache_pressure" = 100;
      })

      # Throughput profile
      (mkIf (cfg.profile == "throughput") {
        "kernel.sched_migration_cost_ns" = 50000000;
        "kernel.sched_min_granularity_ns" = 10000000;
        "kernel.sched_wakeup_granularity_ns" = 25000000;
        "vm.dirty_background_ratio" = 20;
        "vm.dirty_ratio" = 60;
        "vm.vfs_cache_pressure" = 10;
      })

      # PSI monitoring thresholds  
      (mkIf cfg.enablePSI {
        "kernel.panic" = mkDefault 10;
        "kernel.panic_on_oops" = mkDefault 1;
      })
    ];

    # I/O scheduler configuration
    services.udev.extraRules = ''
      # NVMe: use none (multi-queue)
      ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"
      
      # SATA/SCSI SSDs: use mq-deadline or none
      ACTION=="add|change", KERNEL=="sd[a-z]|vd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
      
      # HDDs: use BFQ for better fairness
      ACTION=="add|change", KERNEL=="sd[a-z]|vd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
      
      # Set readahead for SSDs
      ACTION=="add|change", KERNEL=="sd[a-z]|vd[a-z]|nvme[0-9]*", ATTR{queue/rotational}=="0", ATTR{queue/read_ahead_kb}="256"
      
      # Set readahead for HDDs
      ACTION=="add|change", KERNEL=="sd[a-z]|vd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/read_ahead_kb}="1024"
    '';
  };
}
