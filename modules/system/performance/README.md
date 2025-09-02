# Performance Modules

System performance optimization modules providing tuning for different workload types.

## Modules

### `kernel.nix`
Kernel-level performance optimizations:
- **Profiles**:
  - `balanced`: General purpose (default)
  - `performance`: Maximum throughput, higher power usage
  - `low-latency`: Optimized for real-time responsiveness
  - `throughput`: Batch processing and server workloads
- CPU frequency scaling governors
- TCP BBR v2 congestion control
- Transparent Huge Pages configuration
- Pressure Stall Information (PSI) monitoring
- Optional CPU vulnerability mitigation bypass

### `zram.nix`
Compressed memory swap configuration:
- Multiple compression algorithms (zstd, lz4, lzo)
- Dynamic memory allocation
- Optimized swappiness for ZRAM (default: 180)
- Optional writeback to disk
- Automatic sizing based on system RAM

### `filesystem.nix`
Filesystem and I/O optimizations:
- tmpfs configuration for `/tmp`
- SSD TRIM support (fstrim)
- BTRFS CoW optimizations
- I/O scheduler selection
- Mount option optimization

## Usage

```nix
# Enable performance optimizations
performance = {
  kernel = {
    enable = true;
    profile = "performance";
    cpuScheduler = "performance";
    enableBBR2 = true;
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
    tmpfsSize = "8G";
  };
};
```

## Configuration Profiles

### Workstation
```nix
performance.kernel.profile = "performance";
performance.zram.memoryPercent = 50;
```

### Server
```nix
performance.kernel.profile = "throughput";
performance.zram.memoryPercent = 25;
```

### Laptop
```nix
performance.kernel.profile = "balanced";
performance.kernel.cpuScheduler = "schedutil";
```

## Benchmarking

Test performance improvements:
```bash
# CPU performance
sysbench cpu run

# Memory performance
sysbench memory run

# Disk I/O
fio --name=test --size=1G --rw=randrw
```

## Configuration Values

All performance values are centralized in `lib/config.nix`:
- Network buffer sizes
- Scheduler timings
- Memory thresholds
- Swappiness values

## Priority

**Priority: 85** - Performance modules load early to optimize system behavior from boot.