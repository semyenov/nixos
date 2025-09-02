{ config, pkgs, lib, ... }:

with lib;

{
  options.hardware.nvidia = {
    enable = mkEnableOption "NVIDIA GPU support";

    useOpenKernel = mkOption {
      type = types.bool;
      default = true;
      description = "Use open-source kernel modules for RTX 20-series and newer";
    };
  };

  config = mkIf config.hardware.nvidia.enable {
    # NVIDIA driver configuration
    services.xserver.videoDrivers = [ "nvidia" ];

    hardware = {
      # Graphics configuration
      graphics = {
        enable = true;
        enable32Bit = true; # Required for Steam and 32-bit games

        # Additional packages for graphics
        extraPackages = with pkgs; [
          nvidia-vaapi-driver
          vaapiVdpau
          libvdpau-va-gl
        ];

        extraPackages32 = with pkgs.pkgsi686Linux; [
          nvidia-vaapi-driver
          vaapiVdpau
          libvdpau-va-gl
        ];
      };

      # NVIDIA-specific settings
      nvidia = {
        # Use open kernel modules for RTX 20-series and newer
        open = mkDefault config.hardware.nvidia.useOpenKernel;

        # Enable kernel modesetting (required for Wayland)
        modesetting.enable = mkDefault true;

        # Power management
        powerManagement = {
          enable = mkDefault true;
          # Fine-grained power management for laptops
          finegrained = mkDefault false;
        };

        # NVIDIA Settings GUI application
        nvidiaSettings = mkDefault true;

        # Driver package selection - use production for stability
        package = mkDefault (
          if config.boot.kernelPackages ? nvidiaPackages.production then
            config.boot.kernelPackages.nvidiaPackages.production
          else
            config.boot.kernelPackages.nvidiaPackages.stable
        );

        # Force full composition pipeline (reduces tearing)
        forceFullCompositionPipeline = mkDefault false; # Can impact performance

        # Dynamic Boost (for laptops)
        dynamicBoost.enable = mkDefault false;

        # PRIME configuration for laptops with hybrid graphics
        prime = {
          offload = {
            enable = mkDefault false;
            enableOffloadCmd = mkDefault false;
          };
          sync.enable = mkDefault false;
          # Configure these if you have hybrid graphics:
          # intelBusId = "PCI:0:2:0";
          # nvidiaBusId = "PCI:1:0:0";
        };
      };
    };

    # Environment variables for NVIDIA
    environment.sessionVariables = mkMerge [
      {
        # Hardware acceleration
        LIBVA_DRIVER_NAME = "nvidia";
        GBM_BACKEND = "nvidia-drm";
        __GLX_VENDOR_LIBRARY_NAME = "nvidia";

        # CUDA cache
        CUDA_CACHE_PATH = "$HOME/.cache/cuda";
      }

      # Wayland-specific variables
      (mkIf config.services.xserver.displayManager.gdm.wayland {
        WLR_NO_HARDWARE_CURSORS = "1";
        NIXOS_OZONE_WL = "1";
        MOZ_ENABLE_WAYLAND = "1";
        # Fix for electron apps
        ELECTRON_OZONE_PLATFORM_HINT = "auto";
      })

      # VDPAU support
      (mkIf config.hardware.graphics.enable {
        VDPAU_DRIVER = "nvidia";
      })
    ];

    # NVIDIA tools
    environment.systemPackages = with pkgs; [
      nvtopPackages.nvidia # GPU monitoring
      nvidia-vaapi-driver
      libva
      libva-utils
      glxinfo
      vulkan-tools
      pciutils # For lspci
      nvitop # Better GPU monitoring
    ] ++ optionals config.hardware.nvidia.nvidiaSettings [
      config.hardware.nvidia.package.settings
    ] ++ optionals (config.hardware.nvidia.package ? persistenced) [
      config.hardware.nvidia.package.persistenced
    ];

    # Assertions for common issues
    assertions = [
      {
        assertion = !config.hardware.nvidia.open ||
          (lib.versionAtLeast config.boot.kernelPackages.kernel.version "6.0");
        message = "Open NVIDIA kernel modules require kernel 6.0 or newer";
      }
      {
        assertion = !config.hardware.nvidia.prime.offload.enable ||
          (!config.hardware.nvidia.prime.sync.enable);
        message = "NVIDIA PRIME offload and sync modes are mutually exclusive";
      }
    ];

    # Additional udev rules for NVIDIA
    services.udev.extraRules = ''
      # Create /dev/nvidia-uvm when the nvidia-uvm module is loaded
      KERNEL=="nvidia", RUN+="${pkgs.runtimeShell} -c 'mknod -m 666 /dev/nvidiactl c 195 255'"
      KERNEL=="nvidia_modeset", RUN+="${pkgs.runtimeShell} -c 'mknod -m 666 /dev/nvidia-modeset c 195 254'"
      KERNEL=="card*", SUBSYSTEM=="drm", DRIVERS=="nvidia", RUN+="${pkgs.runtimeShell} -c 'mknod -m 666 /dev/nvidia0 c 195 0'"
    '';
  };
}
