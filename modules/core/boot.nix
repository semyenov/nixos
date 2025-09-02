{ config, pkgs, lib, ... }:

with lib;

{
  boot = {
    # EFI bootloader configuration with optimizations
    loader = {
      systemd-boot = {
        enable = true;
        # Number of generations to keep in boot menu
        configurationLimit = 10;
        # Automatically update systemd-boot on rebuild
        editor = false; # Disable editor for security
        # Console resolution
        consoleMode = "max";
        # Faster boot menu timeout when not interrupted
        graceful = true;
      };

      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };

      # Timeout for boot menu (in seconds)
      timeout = mkDefault 1; # Faster boot, hold space for menu
    };

    # Use latest kernel for better hardware support
    kernelPackages = mkDefault pkgs.linuxPackages_latest;

    # Enable kernel modules for better performance
    kernelModules = [
      "kvm-amd"
      "kvm-intel"
      "vfio"
      "vfio_pci"
      "vfio_iommu_type1"
    ];

    # Load modules early in initrd for faster boot
    initrd = {
      availableKernelModules = [
        "xhci_pci"
        "ahci"
        "nvme"
        "usbhid"
        "sd_mod"
        "sr_mod"
      ];

      # Enable systemd in initrd for parallel initialization
      systemd.enable = mkDefault true;

      # Compress initrd for faster loading
      compressor = "zstd";
      compressorArgs = [ "-19" "-T0" ];
    };

    # Optimized kernel parameters
    kernelParams = [
      "quiet"
      "splash"
      "loglevel=3"
      "rd.systemd.show_status=false"
      "rd.udev.log_level=3"
      "udev.log_priority=3"

      # Performance optimizations
      "mitigations=off" # Disable CPU vulnerability mitigations for better performance (security tradeoff)
      "nowatchdog" # Disable watchdog for faster boot
      "modprobe.blacklist=sp5100_tco" # Blacklist unused watchdog module

      # I/O optimizations
      "nohz_full=1-11" # Tickless kernel for CPU 1-11 (adjust based on your CPU)
      "rcu_nocbs=1-11" # Offload RCU callbacks

      # Memory optimizations  
      "transparent_hugepage=madvise"
      "numa_balancing=0" # Disable NUMA balancing if not needed
    ] ++ optionals (elem "nvidia" config.services.xserver.videoDrivers or [ ]) [
      "nvidia-drm.modeset=1" # NVIDIA Wayland support
      "nvidia.NVreg_PreserveVideoMemoryAllocations=1" # Preserve video memory
      "nvidia.NVreg_TemporaryFilePath=/var/tmp" # Use /var/tmp for NVIDIA temp files
    ];

    # Clean /tmp on boot
    tmp.cleanOnBoot = mkDefault true;

    # Plymouth for pretty boot screen
    plymouth = {
      enable = mkDefault false; # Enable if you want splash screen
      theme = "bgrt"; # Use firmware logo
    };

    # Enable support for various filesystems
    supportedFilesystems = [ "ntfs" "exfat" "btrfs" "xfs" ];

    # Kernel sysctl for boot performance
    kernel.sysctl = {
      "vm.swappiness" = mkDefault 10;
      "vm.vfs_cache_pressure" = mkDefault 50;
    };

    # Blacklist unnecessary kernel modules
    blacklistedKernelModules = [
      "pcspkr" # PC speaker
      "snd_pcsp" # PC speaker sound
    ];

    # Console configuration
    consoleLogLevel = mkDefault 3;
  };
}
