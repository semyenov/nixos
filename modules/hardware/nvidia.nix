{ config, pkgs, lib, ... }:

{
  # NVIDIA RTX 4060 Configuration
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
      # Use proprietary drivers (better performance)
      open = false;

      # Enable kernel modesetting (required for Wayland)
      modesetting.enable = true;

      # Power management
      powerManagement = {
        enable = true;
        # Fine-grained power management (experimental)
        finegrained = false;
      };

      # NVIDIA Settings GUI application
      nvidiaSettings = true;

      # Driver package selection
      package = config.boot.kernelPackages.nvidiaPackages.stable;

      # Force full composition pipeline (reduces tearing)
      forceFullCompositionPipeline = true;
    };
  };

  # Environment variables for NVIDIA
  environment.sessionVariables = {
    # Hardware acceleration
    LIBVA_DRIVER_NAME = "nvidia";
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";

    # Wayland compatibility
    WLR_NO_HARDWARE_CURSORS = "1";
    NIXOS_OZONE_WL = "1";

    # CUDA
    CUDA_CACHE_PATH = "$HOME/.cache/cuda";
  };

  # NVIDIA tools
  environment.systemPackages = with pkgs; [
    nvtopPackages.nvidia # GPU monitoring
    nvidia-vaapi-driver
    libva
    libva-utils
    glxinfo
    vulkan-tools
    cudaPackages.cudatoolkit
  ];
}
