{ config, pkgs, ... }:

{
  boot = {
    # EFI bootloader configuration
    loader = {
      systemd-boot = {
        enable = true;
        # Number of generations to keep in boot menu
        configurationLimit = 10;
        # Automatically update systemd-boot on rebuild
        editor = false; # Disable editor for security
      };

      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };

      # Timeout for boot menu (in seconds)
      timeout = 3;
    };

    # Use latest kernel for better hardware support
    kernelPackages = pkgs.linuxPackages_latest;

    # Kernel parameters
    kernelParams = [
      "quiet"
      "splash"
      "nvidia-drm.modeset=1" # Required for NVIDIA Wayland support
    ];

    # Clean /tmp on boot
    tmp.cleanOnBoot = true;

    # Enable support for NTFS
    supportedFilesystems = [ "ntfs" ];
  };
}
